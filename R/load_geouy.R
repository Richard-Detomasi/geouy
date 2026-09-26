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
#' @param make_valid Logical. With \code{TRUE}, the default, the geometries that
#'   are invalid as published are repaired with \code{sf::st_make_valid()}, and a
#'   message says how many were repaired; any that cannot be repaired are left as
#'   they are, with a warning. Invalid means rejected by either of the two
#'   geometry engines \code{sf} uses: GEOS, which flags a ring that crosses
#'   itself, or s2, which also rejects a repeated vertex. Curved geometries,
#'   which neither engine can evaluate, and geometry collections are left as
#'   they are. With \code{FALSE}
#'   the geometries are neither checked nor repaired: apart from the
#'   transformation to \code{crs}, they are returned as the server publishes them.
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

load_geouy <- function(c, crs = 32721, folder = tempdir(), make_valid = TRUE){
  x <- geouy::metadata 
  folder <- normalizePath(folder,"/")
  # Sin try(): envolver un stop() propio en try() lo atrapa, la funcion sigue
  # con el nombre equivocado y el usuario termina viendo "argumento tiene
  # longitud cero" unas lineas mas abajo, cuando el filtro no deja ninguna fila.
  #
  # El length(c) != 1 entra en la misma guarda y con el mismo mensaje, sin
  # agregar uno nuevo. Es por un caso peor que el nombre equivocado: con dos
  # capas, la condicion del if fallaba por longitud, el try() se tragaba ese
  # error tambien, y el filtro de abajo reciclaba y dejaba UNA de las dos. O
  # sea que load_geouy(c("Peajes", "Rutas")) bajaba Rutas sin avisar nada.
  if (length(c) != 1 || !c %in% x$capa) {
    stop("The name of the geometry you will load is not correct. Verify in the metadata file")
  }
  if (!curl::has_internet()) stop("No internet access detected. Please check your connection.")
  x <- x[x$capa == c,]
  enco <- x$enc
  if (x$formato %in% c("zip", "zip a")) {
    if (!is.character(folder) | length(folder) != 1) {
      stop(glue::glue("You must enter a valid directory..."))
    }
    # download ----
    # Mismo caso que en tiles_geouy(): el try() tapaba tanto "ya existe" como
    # "no se puede crear". Pasandole un archivo en vez de un directorio, la
    # descarga fallaba despues y el mensaje culpaba al servidor. Se reusa el
    # mensaje de la guarda de arriba, sin agregar uno nuevo.
    if (!dir.exists(folder)) {
      suppressWarnings(dir.create(folder, recursive = TRUE))
      if (!dir.exists(folder)) stop(glue::glue("You must enter a valid directory..."))
    }
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
  # Antes de transformar: se valida en el CRS en que se publico la capa, que es
  # donde el organismo la dibujo.
  if (isTRUE(make_valid)) a <- sanear(a, c)
  a <- a %>% sf::st_transform(crs)
  return(a)
}

# Un dato oficial no es necesariamente un dato valido, y sf usa dos motores que no
# coinciden en que es valido:
#
#  - GEOS, geometria plana, que es lo que se usa en un CRS proyectado. Marca los
#    anillos que se cruzan a si mismos: dos en "Departamentos" y en "Deptos", en
#    la misma coordenada.
#  - s2, geometria esferica, que sf usa por omision con coordenadas geograficas.
#    Ademas rechaza los vertices consecutivos repetidos, que GEOS acepta. Medido:
#    GEOS no ve ningun problema en "Secciones" ni en "Segmentos", y s2 rechaza 10
#    y 20 geometrias respectivamente.
#
# Las operaciones que calcula s2 contra una de esas geometrias -un st_join(), un
# st_centroid()- cortan con error, que es lo que rompia which_uy() (#34). Asi que "invalida" es invalida para cualquiera
# de los dos, y se chequean los dos siempre, sin importar como tenga configurado
# sf el usuario en ese momento: sf_use_s2() es estado global y lo puede cambiar
# despues de cargar la capa.
#
# Se reparan solo esas, no la capa entera: el resto conserva exactamente las
# coordenadas que publico el organismo. La unica excepcion es de tipo, no de
# coordenadas: si la capa es de POLYGON y una reparacion parte una geometria en
# dos, la capa entera pasa a MULTIPOLYGON para no quedar mezclada. Lo que mas
# cuesta es validar: menos de un segundo en la mayoria de las capas, y unos cinco
# en "Zonas", que tiene 78.035 geometrias.
#
# Y si sanear falla, la capa se devuelve como estaba, con un warning que lo dice:
# todo va envuelto, para que sanear no sea la razon de que una capa deje de
# cargar.
sanear <- function(a, capa) {
  if (!nrow(a)) return(a)
  tryCatch(reparar_invalidas(a, capa), error = function(e) {
    warning(glue::glue("The geometries of '{capa}' could not be checked or repaired ",
                       "({conditionMessage(e)}); the layer is returned as is."),
            call. = FALSE)
    a
  })
}

reparar_invalidas <- function(a, capa) {
  geom <- sf::st_geometry(a)
  # GEOS y s2 solo entienden geometrias lineales. Las curvas -MULTISURFACE,
  # MULTICURVE, que publica el MTOP en "Balnearios", "Lagunas publicas" y "Cursos
  # de agua navegables y flotables", y RENARE en "CONEAT"- ni siquiera se pueden
  # evaluar: st_is_valid() da NA y st_make_valid() falla. No son invalidas, son de
  # un tipo que estos motores no manejan, asi que quedan como estan y sin avisar.
  # Sin esto, cada carga de esas capas decia que ninguna de sus geometrias se
  # podia reparar, y en "CONEAT", con 237.681, intentarlo sumaba casi tres minutos.
  # Las colecciones -GEOMETRYCOLLECTION- tampoco se tocan: pueden traer curvas
  # adentro, y al repararlas se perderian las partes de otra dimension, como un
  # punto junto a un poligono. No las publica ninguna de las capas que se pueden
  # descargar.
  evaluables <- which(sf::st_is(geom, c("POINT", "MULTIPOINT", "LINESTRING",
                                        "MULTILINESTRING", "POLYGON",
                                        "MULTIPOLYGON")))
  if (!length(evaluables)) return(a)
  malas <- evaluables[invalidas(a[evaluables, ])]
  if (!length(malas)) return(a)

  tipo <- as.character(sf::st_geometry_type(a, by_geometry = FALSE))
  familia <- sub("^MULTI", "", tipo)
  dimension <- unname(c(POINT = 0L, LINESTRING = 1L, POLYGON = 2L)[familia])
  crs <- sf::st_crs(geom)

  # Primer paso: la reparacion comun, que no mueve nada que no haga falta.
  arreglos <- reparar(geom[malas], familia, dimension)
  bien <- validadas(arreglos, crs)

  # Segundo paso, solo para las que siguen invalidas: con precision de
  # milimetro. Hay vertices a un nanometro de otro vertice -en "Deptos", Maldonado
  # y Rocha, a 1e-9 m- o de una arista que no es la suya, que es ruido de punto
  # flotante y no dato: GEOS los da por distintos, y en coordenadas geograficas
  # s2 los ve como un vertice repetido o como dos aristas que se cruzan, y
  # rechaza la geometria. Con la grilla de milimetro pasan a coincidir y
  # st_make_valid() lo resuelve. Va como segundo paso y no para todas porque la
  # grilla tambien puede llevarse detalles mas chicos que un milimetro, y eso
  # solo se justifica donde hace falta.
  con_grilla <- rep(FALSE, length(malas))
  precision <- precision_milimetro(crs)
  if (any(!bien) && !is.na(precision)) {
    resto <- which(!bien)
    segundos <- reparar(geom[malas[resto]], familia, dimension, precision)
    ok <- validadas(segundos, crs)
    arreglos[resto[ok]] <- segundos[ok]
    bien[resto[ok]] <- TRUE
    con_grilla[resto[ok]] <- TRUE
  }

  if (any(bien)) {
    nuevas <- sf::st_sfc(arreglos[bien], crs = sf::st_crs(geom))
    if (!is.na(dimension)) {
      multi <- paste0("MULTI", familia)
      if (tipo == familia && all(lengths(nuevas) == 1)) {
        # La capa es de geometrias simples y ninguna reparacion la partio.
        nuevas <- sf::st_cast(nuevas, familia)
      } else if (tipo == familia) {
        # Alguna reparacion partio una geometria en dos: la capa pasa entera a
        # MULTI, que no pierde nada, en vez de quedar mezclada.
        geom <- sf::st_cast(geom, multi)
      }
    }
    geom[malas[bien]] <- nuevas
    sf::st_geometry(a) <- geom
    grilla <- if (any(con_grilla)) {
      glue::glue(" ({sum(con_grilla)} of them at millimetre precision, which can ",
                 "drop detail smaller than that)")
    } else ""
    message(glue::glue("{sum(bien)} of {length(geom)} geometries of '{capa}' ",
                       "were invalid as published and were repaired with ",
                       "sf::st_make_valid(){grilla}. Use make_valid = FALSE to get ",
                       "them as the server publishes them."))
  }
  # Las que no se pudieron reparar quedan como estaban, pero la capa sigue
  # teniendo geometrias invalidas y probablemente corte mas adelante: eso si
  # tiene que verse.
  if (any(!bien)) {
    warning(glue::glue("{sum(!bien)} of {length(geom)} geometries of '{capa}' ",
                       "are invalid as published and could not be repaired; ",
                       "they are left as is."), call. = FALSE)
  }
  a
}

# Repara las geometrias con GEOS, que es el motor que saca los vertices
# repetidos, y devuelve una lista con una geometria por entrada, o NULL donde no
# se pudo. Nunca cambia la dimension de una fila: si la reparacion la deja sin
# nada de su dimension -un poligono sin area colapsa a una linea-, esa queda
# NULL y la geometria original se conserva.
#
# Todas juntas primero, porque es mucho mas rapido: con 2000 invalidas, una sola
# llamada a st_make_valid() tarda unas cien veces menos que una por fila. Solo pasan de
# a una las que vuelven como coleccion o de otra dimension, y todas de a una si
# la llamada conjunta falla.
reparar <- function(g, familia, dimension, precision = NA) {
  # En una capa de tipo GEOMETRY no hay una familia a la que volver: cada fila
  # tiene que conservar su propia dimension.
  esperada <- if (is.na(dimension)) sf::st_dimension(g) else rep(dimension, length(g))
  if (!is.na(precision)) g <- sf::st_set_precision(g, precision)
  juntas <- tryCatch(con_s2(FALSE, sf::st_make_valid(g)), error = function(e) NULL)

  if (is.null(juntas)) {
    return(lapply(seq_along(g), function(i) {
      r <- tryCatch(con_s2(FALSE, sf::st_make_valid(g[i])), error = function(e) NULL)
      if (is.null(r)) NULL else a_su_dimension(r, familia, esperada[i])
    }))
  }

  dim_r <- sf::st_dimension(juntas)
  directas <- !sf::st_is(juntas, "GEOMETRYCOLLECTION") & !sf::st_is_empty(juntas) &
    !is.na(dim_r) & !is.na(esperada) & dim_r == esperada
  salida <- vector("list", length(g))
  if (any(directas)) {
    listas <- if (is.na(dimension)) juntas[directas] else sf::st_cast(juntas[directas], paste0("MULTI", familia))
    salida[directas] <- unclass(listas)
  }
  for (i in which(!directas)) {
    salida[i] <- list(a_su_dimension(juntas[i], familia, esperada[i]))
  }
  salida
}

# Deja una geometria ya reparada en la dimension que tenia, o NULL si no queda
# nada de esa dimension.
a_su_dimension <- function(r, familia, esperada) {
  if (is.na(esperada) || all(sf::st_is_empty(r))) return(NULL)
  if (any(sf::st_is(r, "GEOMETRYCOLLECTION"))) {
    objetivo <- c("POINT", "LINESTRING", "POLYGON")[esperada + 1L]
    r <- suppressWarnings(sf::st_collection_extract(r, objetivo))
  }
  r <- r[!sf::st_is_empty(r) & sf::st_dimension(r) %in% esperada]
  if (!length(r)) return(NULL)
  unida <- sf::st_combine(r)
  if (familia %in% c("POINT", "LINESTRING", "POLYGON")) {
    unida <- sf::st_cast(unida, paste0("MULTI", familia))
  }
  unida[[1]]
}

# Cuales de las geometrias reparadas son validas para los dos motores. La
# reparacion es con GEOS, y hay geometrias que s2 rechaza y GEOS no sabe arreglar
# -un poligono de aristas largas que se cruzan sobre la esfera-: esas no pueden
# figurar como reparadas, porque el mensaje estaria diciendo algo falso.
validadas <- function(arreglos, crs) {
  bien <- !vapply(arreglos, is.null, logical(1))
  if (any(bien)) {
    candidatas <- sf::st_sf(geometry = sf::st_sfc(arreglos[bien], crs = crs))
    siguen <- invalidas(candidatas)
    if (length(siguen)) bien[which(bien)[siguen]] <- FALSE
  }
  bien
}

# La precision que equivale a un milimetro en las unidades del CRS, o NA si las
# unidades no se conocen. Sin esta cuenta, la misma cifra que es un milimetro en
# metros seria un metro en un CRS en kilometros, o cien en uno sin CRS con
# coordenadas en grados.
precision_milimetro <- function(crs) {
  if (is.na(crs)) return(NA_real_)
  unidades <- crs$units_gdal
  if (identical(unidades, "degree")) return(1e8)  # 1e-8 grados, alrededor de 1 mm
  if (identical(unidades, "metre")) return(1000)
  NA_real_
}

# Las filas invalidas para GEOS o para s2. Si el chequeo esferico no se puede
# hacer -una capa sin CRS, o uno que no se puede llevar a 4326-, queda el plano.
invalidas <- function(a) {
  plana <- con_s2(FALSE, sf::st_is_valid(a))
  esferica <- tryCatch(
    con_s2(TRUE, sf::st_is_valid(
      if (isTRUE(sf::st_is_longlat(a))) a else sf::st_transform(a, 4326))),
    error = function(e) rep(TRUE, nrow(a)))
  # NA es una geometria que ni siquiera se puede evaluar: tambien va a reparar.
  which(is.na(plana) | !plana | is.na(esferica) | !esferica)
}

# Evalua expr con s2 prendido o apagado, y deja sf_use_s2() como estaba.
con_s2 <- function(usar, expr) {
  anterior <- suppressMessages(sf::sf_use_s2(usar))
  on.exit(suppressMessages(sf::sf_use_s2(anterior)), add = TRUE)
  expr
}
