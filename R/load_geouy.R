# Cuando un servicio no responde, lo que sube es el error crudo de GDAL o el de
# download.file: "Cannot open data source" y poco mas. No dice que capa se
# estaba pidiendo ni a que servidor, que es justo lo que hace falta para saber
# si el problema es de uno o es ajeno. Estas dos funciones lo traducen a un
# mensaje que si lo dice, y dejan el original al final por si el motivo era otro.
falla_de_servicio <- function(capa, url, accion, detalle = NULL,
                              causa = "The server may be down or the layer may have changed.") {
  # El prefijo "WFS:" que GDAL necesita en la URL no es parte del servidor.
  servidor <- sub("^WFS:", "", url)
  servidor <- sub("^(https?://[^/?#]+).*", "\\1", servidor)
  mensaje <- glue::glue("Could not {accion} the layer '{capa}' from {servidor}.")
  # La especulacion sirve cuando no hay nada mejor, pero estorba cuando si lo
  # hay: quien la pasa en NULL es porque ya tiene la causa real y no quiere que
  # el mensaje diga "puede estar caido" arriba de un detalle que dice otra cosa.
  if (!is.null(causa)) mensaje <- glue::glue("{mensaje} {causa}")
  # El error original va al final, pero solo cuando lo hay: si el fallo lo
  # detecto el paquete, la causa ya esta dicha y repetirla no aporta.
  if (!is.null(detalle)) mensaje <- glue::glue("{mensaje}\nDetails: {detalle}")
  stop(mensaje, call. = FALSE)
}

descarga_o_falla <- function(expr, capa, url, accion = "read") {
  # GDAL y download.file suelen decir la causa real en un warning -"SSL
  # certificate problem: unable to get local issuer certificate", "Timeout of N
  # seconds was reached"- y recien despues tirar un error generico que no la
  # menciona: "Cannot open ...; Check connection parameters". Quedarse solo con
  # el error deja al usuario buscando un servidor caido cuando el problema
  # puede ser, por ejemplo, que a ese servidor le falta la cadena de
  # certificados. Por eso los avisos se copian y se suman al detalle.
  avisos <- character()
  # expr llega sin evaluar y se fuerza aca adentro, de modo que el fallo ocurra
  # dentro del tryCatch. Se atrapan errores y no warnings: los handlers de
  # tryCatch son de salida, asi que un warning recuperable de GDAL abortaria la
  # lectura y perderia un objeto valido. withCallingHandlers no tiene ese
  # problema, y aca ademas no se llama a invokeRestart("muffleWarning"): el
  # aviso se copia y sigue su camino, para que la lectura que igual funciona no
  # pierda los avisos que el usuario tendria que ver.
  tryCatch(
    withCallingHandlers(force(expr),
                        warning = function(w) avisos <<- c(avisos, conditionMessage(w))),
    error = function(e) {
      original <- conditionMessage(e)
      # Con options(warn = 2) el aviso ya viene adentro del error, y GDAL a
      # veces repite el suyo palabra por palabra: se descarta lo que ya este
      # dicho. La comparacion es literal a proposito, porque los mensajes traen
      # rutas y comillas que como expresion regular no significarian lo mismo.
      avisos <- unique(avisos)
      avisos <- avisos[!vapply(avisos, grepl, logical(1), x = original, fixed = TRUE)]
      # Un fallo puede venir detras de cientos de avisos distintos, y volcarlos
      # todos convierte el error en algo que nadie lee. Con los primeros alcanza
      # para saber que paso; el resto se cuenta.
      # Un fallo puede venir detras de muchos avisos distintos, y volcarlos todos
      # convierte el error en algo que nadie lee; ademas stop() corta el mensaje
      # a 8190 caracteres, asi que de nada sirve pasarse. En los fallos reales
      # medidos -certificado, capa inexistente, host que no resuelve- GDAL emite
      # uno solo, de modo que este tope casi nunca entra en juego.
      tope <- 5L
      if (length(avisos) > tope) {
        avisos <- c(avisos[seq_len(tope)],
                    glue::glue("... and {length(avisos) - tope} more warnings"))
      }
      detalle <- paste(c(original, avisos), collapse = "\n")
      # Si hay aviso, hay causa dicha, y la frase generica sobra: pasarla igual
      # deja el mensaje contradiciendose solo -"el servidor puede estar caido"
      # arriba de "SSL certificate problem"-. La decision es por si hay aviso o
      # no, no por lo que el aviso diga: los textos cambian entre versiones de
      # GDAL y entre idiomas, y no se puede colgar de ahi el comportamiento.
      if (length(avisos)) falla_de_servicio(capa, url, accion, detalle, causa = NULL)
      else falla_de_servicio(capa, url, accion, detalle)
    })
}

#' This function allows to take oficial uruguayan geometries, as object "sf", from various servers.
#' @family service
#' @param c Define the geometries to download: may be: "Departamentos", "Secciones", "Zonas", etc. View(metadata) for details.
#' @param crs Define the Coordinate Reference Systems you want the output, default 32721
#' @param folder Folder where are the files download if formato == "zip" in metadata. Default tempdir()
#' @importFrom curl has_internet
#' @importFrom sf st_read st_transform
#' @importFrom glue glue
#' @importFrom utils download.file unzip
#' @keywords IDE MIDES INE
#' @return sf object with the requested geometries 
#' @export
#' @examples
#'\donttest{
#' secc <- try(load_geouy(c = "Secciones"), silent = TRUE)
#' if (!inherits(secc, "try-error")) head(secc)
#'}

load_geouy <- function(c, crs = 32721, folder = tempdir()){
  x <- geouy::metadata 
  folder <- normalizePath(folder,"/")
  try(if (!c %in% x$capa) stop("The name of the geometry you will load is not correct. Verify in the metadata file"))
  if (!curl::has_internet()) stop("No internet access detected. Please check your connection.")
  x <- x[x$capa == c,]
  enco <- x$enc
  if (x$repositor %in% "SGM") {
    wfs_sgm <- "WFS:http://geoservicios.sgm.gub.uy/wfsPCN1000.cgi?"
    a <- descarga_o_falla(sf::st_read(wfs_sgm, x$url, crs = x$crs), c, wfs_sgm)
  } else if (x$formato %in% c("zip", "zip a")) {
    if (!is.character(folder) | length(folder) != 1) {
      stop(glue::glue("You must enter a valid directory..."))
    }
    # download ----
    suppressWarnings(try(dir.create(folder)))
    f = glue::glue("{folder}/{x$capa}.zip")
    if (!file.exists(f)) {
      message(glue::glue("Intentando descargar {x$capa}..."))
      # El reintento en modo "a" (append) sobre el mismo archivo no aportaba
      # nada -pedia otra vez la misma URL- y ademas es peligroso: cuando el
      # servidor no responde, download.file() con mode = "a" aborta R con un
      # segfault, que ningun try() del usuario puede recuperar. Con mode = "wb"
      # el fallo es un error normal, que si se puede manejar.
      descarga_o_falla(utils::download.file(x$url, f, mode = "wb", method = "libcurl"),
                       c, x$url, accion = "download")
    }
    # Hay que mirar lo que el unzip extrajo, y no barrer la carpeta entera. Si
    # lo que se bajo no era un zip -por ejemplo, una pagina de error servida con
    # codigo 200-, unzip() no da error: avisa con un warning y devuelve NULL.
    # El barrido entonces encontraba el shapefile de OTRA capa descargada antes
    # en la misma carpeta, que por omision es tempdir() y se comparte entre
    # llamadas, y load_geouy() devolvia esos datos como si fueran los pedidos,
    # sin avisar nada.
    extraidos <- descarga_o_falla(utils::unzip(f, exdir = folder),
                                  c, x$url, accion = "unzip")
    archivo <- extraidos[grepl("\\.shp$", extraidos, ignore.case = TRUE)]
    if (length(archivo) == 0) {
      # El archivo que no sirve se borra: si queda, la comprobacion de mas
      # arriba saltea la descarga y todas las llamadas siguientes fallan igual.
      unlink(f)
      falla_de_servicio(c, x$url, "unzip",
                        causa = "The server answered, but not with a zip containing a shapefile.")
    }
    archivo <- archivo[which.max(file.info(archivo)$mtime)]
    if(!enco == "UTF-8"){
      a <- descarga_o_falla(
        sf::st_read(archivo, crs = x$crs, options = glue::glue("ENCODING=", enco)), c, x$url)
    } else {
      a <- descarga_o_falla(sf::st_read(archivo, crs = x$crs), c, x$url)
    }
  } else {
    if(!enco == "UTF-8"){
      a <- descarga_o_falla(
        sf::st_read(x$url, crs = x$crs, options = glue::glue("ENCODING=", enco)), c, x$url)
    } else {
      a <- descarga_o_falla(sf::st_read(x$url, crs = x$crs), c, x$url)
    }
  }
  a <- a %>% sf::st_transform(crs)
  return(a)
}
