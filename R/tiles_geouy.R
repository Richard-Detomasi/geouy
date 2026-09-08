# Bajar directamente al destino deja un archivo a medias si la descarga se corta,
# y ese archivo despues se toma por bueno: probado con un .jpg recortado al 40%,
# la funcion devuelve un raster sin avisar nada. Bajando a un temporal en la misma
# carpeta y renombrando solo al terminar bien, una interrupcion deja un ".part"
# que nadie mira, y el destino solo existe si esta completo.
descarga_tile <- function(url, destino) {
  temporal <- tempfile(paste0(basename(destino), ".part-"), tmpdir = dirname(destino))
  on.exit(unlink(temporal), add = TRUE)
  estado <- tryCatch(
    utils::download.file(url, temporal, mode = "wb", method = "libcurl"),
    error = function(e) e)
  detalle <- if (inherits(estado, "error")) {
    conditionMessage(estado)
  } else if (!identical(as.integer(estado), 0L)) {
    glue::glue("download.file() returned status {as.integer(estado)}")
  } else if (!isTRUE(file.size(temporal) > 0)) {
    "the downloaded file is empty"
  }
  if (!is.null(detalle)) {
    stop(glue::glue("Could not download '{basename(url)}' from the IDEuy tiles ",
                    "repository. The server may be out of service, try in ",
                    "https://visualizador.ide.uy/ideuy/core/load_public_project/ideuy/\n",
                    "Details: {detalle}"), call. = FALSE)
  }
  if (!file.rename(temporal, destino)) {
    stop(glue::glue("Downloaded '{basename(url)}' but could not move it into {dirname(destino)}."),
         call. = FALSE)
  }
  invisible(destino)
}

#' This function allows to Download .jpg or .tif files from the IDEuy tiles repository, according to a 'sf' object bbox.
#' @family service
#' @param x An 'sf' object with the same crs as the homonym parameter
#' @param d numeric; buffer distance for all, or for each of the elements in x; in case dist is a units object, it should be convertible to arc_degree if x has geographic coordinates, and to st_crs(x)$units otherwise. Default NA, but if x is a only one point buffer default is 100.
#' @param format Format of the archives to download (avaiable: "rgb" and "rgbi"). Default "rgb". Mind the size before asking: one "rgb" tile weighs 3 to 67 MB in the urban flight and around 250 MB in the national one, and one "rgbi" tile weighs about 380 MB and 1.3 GB respectively. The whole tile is downloaded and only then cropped to x.
#' @param folder Folder where are the files or be download
#' @param urban logical; If FALSE take orthophotos of national flight with 32cm per pixel, if TRUE take urban flight with 10cm per pixel (available for every locality covered by the urban flight)
#' @keywords IDE orthophotos Uruguay
#' @return raster::stack object with th cropped tif corresponding to x bbox
#' @importFrom sf st_join st_crs st_bbox st_transform
#' @importFrom dplyr filter %>% distinct
#' @importFrom methods is as
#' @importFrom stringr str_sub str_pad
#' @importFrom raster brick crop extent crs mosaic
#' @importFrom glue glue
#' @importFrom sp SpatialPolygons
#' @importFrom utils download.file
#' @importFrom rlang .data
#' @importFrom fs dir_ls
#' @importFrom curl has_internet
#' @export
#' @examples
#'\dontrun{
#' # Not run because a whole tile is downloaded, and the tile is the unit: the
#' # crop to the requested area happens after the download, so asking for a
#' # small area does not download less. The tile covering this point weighs
#' # 66.7 MB, and that is not the worst case: an urban .jpg ranges from 3 to
#' # 67 MB depending on the tile -a twentyfold spread inside one locality-
#' # and a national one is around 250 MB.
#' x <- data.frame(x = 577968, y = 6147753, id = 1)
#' x <- sf::st_as_sf(x, coords = c("x", "y"), crs = 32721)
#' tiles_geouy(x, urban = TRUE)
#'}

tiles_geouy <- function(x, d = NA, format = "rgb", folder = tempdir(), urban = FALSE){
  # checks ----
  if (!is(x, "sf")) stop(glue::glue("The object {x} you want to process is not class sf"))
  if (!is.character(folder) | length(folder) != 1) stop("You must enter a valid directory...")
  if (!format %in% c("rgb", "rgbi")) stop("The format you want to download is not avaiable")
  if (!curl::has_internet()) stop("No internet access detected. Please check your connection.")
   # download ----
  suppressWarnings(try(dir.create(folder)))
  if (nrow(x) == 1 & is.na(d)) x <- sf::st_buffer(x, dist = 100)
  if (!is.na(d)) x <- sf::st_buffer(x, dist = d)
  # El area de recorte se arma pasando el bbox a geometria: asi no depende del
  # orden de las coordenadas y conserva el CRS de origen. Pasarlo como vector
  # invertia los ejes (st_bbox da xmin, ymin, xmax, ymax y raster::extent espera
  # xmin, xmax, ymin, ymax) y el recorte terminaba abarcando el tile entero.
  bbox <- x %>% sf::st_transform(5381) %>% sf::st_bbox()
  # Sin superficie no hay nada que recortar: geometrias vacias o degeneradas
  # (puntos repetidos o alineados, sin buffer) morian mas adelante dentro de
  # raster, con un mensaje que no le dice nada al usuario.
  if (any(!is.finite(bbox)) || bbox[["xmin"]] >= bbox[["xmax"]] || bbox[["ymin"]] >= bbox[["ymax"]]) {
    stop("The geometry you have in x has no area to crop. Set a buffer distance in d.", call. = FALSE)
  }
  bb = bbox %>% sf::st_as_sfc() %>% sf::as_Spatial()
  if (urban == FALSE) {
    # Solo un fallo real de descarga produce un objeto "try-error". Los NA que
    # traen algunas columnas de la grilla son datos validos del servicio.
    x2 <- try(geouy::load_geouy("Grilla ortofotos nacional", crs = 5381), silent = TRUE)
    if (inherits(x2, "try-error")) {
      # Se adjunta el error original: no todo fallo es del servidor (puede ser
      # falta de conexion o un problema de lectura local).
      stop("IDEuy Server out of service, try in https://visualizador.ide.uy/ideuy/core/load_public_project/ideuy/\n",
           "Details: ", conditionMessage(attr(x2, "condition")), call. = FALSE)
    }
    # Un servicio que responde 200 sin features devuelve un sf valido y vacio,
    # asi que no hay error y el codigo seguia de largo: el st_join no encontraba
    # nada y al usuario se le decia que su punto estaba mal cuando el problema
    # era del servicio. La comprobacion va ANTES del join, porque despues un
    # cero significa las dos cosas a la vez.
    if (nrow(x2) == 0) {
      stop("The IDEuy national tile layer came back with no tiles at all, so ",
           "the service is not returning data right now. This is not a problem ",
           "with x.", call. = FALSE)
    }
    x2 <- x2 %>% 
      sf::st_join(x %>% sf::st_transform(5381), left = F) %>% 
      dplyr::distinct(.data$nombre, .keep_all = TRUE)
    if (nrow(x2) == 0) {
      stop("The geometry in x is not in Uruguay, or its crs is not the one it ",
           "declares.", call. = FALSE)
    }
  } else {
    # Idem grilla nacional: se comprueba el resultado de la descarga, no sus NA.
    x2 <- try(geouy::load_geouy("Grilla ortofotos urbana", crs = 5381), silent = TRUE)
    if (inherits(x2, "try-error")) {
      stop("IDEuy Server out of service, try in https://visualizador.ide.uy/ideuy/core/load_public_project/ideuy/\n",
           "Details: ", conditionMessage(attr(x2, "condition")), call. = FALSE)
    }
    # Ya no se filtra por localidad: el vuelo urbano cubre 86 y el st_join con la
    # geometria del usuario alcanza para quedarse con los tiles que le sirven.
    # Idem grilla nacional: capa vacia es problema del servicio, no de x.
    if (nrow(x2) == 0) {
      stop("The IDEuy urban tile layer came back with no tiles at all, so the ",
           "service is not returning data right now. This is not a problem ",
           "with x.", call. = FALSE)
    }
    x2 <- x2 %>%
      sf::st_join(x %>% sf::st_transform(5381), left = F) %>%
      dplyr::distinct(.data$nombre, .keep_all = TRUE)
    if (nrow(x2) == 0) {
      stop("No urban-flight orthophotos cover the geometry in x. ",
           "Use urban = FALSE for the national flight, which covers the whole ",
           "country at 32 cm per pixel, or check the crs of x.", call. = FALSE)
    }
  }
  
  # Descarga ----
  # Las URLs vienen en la propia capa, una columna por formato. Antes se armaban
  # con glue(), lo que obligaba a escribir fija la carpeta de la ciudad
  # ("01_Ciudad_MVD"): ese numero es correlativo dentro de cada remesa y no se
  # puede deducir del codigo de localidad, y por eso el vuelo urbano estaba
  # limitado a Montevideo. Tomandolas de la capa quedan disponibles las 86
  # localidades, y ademas deja de importar como reordene la IDE sus carpetas.
  if (format == "rgb") {
    # El .jgw es el world file. Sin el, el .jpg no queda georreferenciado y el
    # recorte posterior trabajaria sobre coordenadas de pixel: hay que bajarlo,
    # aunque el que se lee despues sea el .jpg.
    rasters <- as.character(x2$rgb_jpg)
    urls <- c(rasters, as.character(x2$rgb_jgw))
  } else {
    rasters <- as.character(x2$rgbi_8bits)
    urls <- rasters
  }
  destinos <- file.path(folder, basename(urls))
  # Dos tiles distintos que compartieran nombre de archivo se pisarian en la
  # carpeta, y el segundo ni siquiera se bajaria porque el primero ya existe.
  # Hoy no pasa -37.400 nombres entre las dos grillas y los cuatro formatos, sin
  # una sola repeticion-, pero si la IDE cambiara el esquema conviene que se note
  # aca y no en un raster con un tile repetido y otro faltante.
  if (anyNA(urls) || anyDuplicated(destinos)) {
    stop("The IDEuy tile layer returned unusable download URLs (missing, or ",
         "different tiles sharing one file name). Please report this.", call. = FALSE)
  }
  for (i in seq_along(urls)) {
    # Aca habia un `if (!file.exists(a[i]))` sobre la URL, que nunca es un
    # archivo: siempre daba FALSE, asi que la funcion se rebajaba todo en cada
    # llamada. Se saca por ser codigo muerto, pero no se lo reemplaza por la
    # comprobacion sobre el archivo local, que seria lo obvio: un archivo a
    # medias de un intento anterior tiene tamano mayor que cero y se daria por
    # bueno. Probado con un .jpg recortado al 40%: la funcion devuelve un raster
    # sin avisar. Un cache de verdad tiene que validar lo que ya esta en disco
    # contra el servidor, y eso va con el issue de no rebajar 70 MB cada vez.
    message(glue::glue("Trying to download {basename(urls[i])}..."))
    # De a una URL por vez. download.file() con un vector devuelve 0 si al menos
    # una de las descargas anduvo, asi que el par .jpg/.jgw se bajaba junto y un
    # world file faltante pasaba inadvertido: el raster quedaba sin georreferenciar.
    descarga_tile(urls[i], destinos[i])
  }
  # Se leen exactamente los archivos de esta consulta. Antes se barria la carpeta
  # buscando cualquier .jpg y se filtraba por fecha de modificacion, lo que tomaba
  # archivos ajenos y a la vez dejaba fuera los que ya estuvieran descargados.
  ar <- file.path(folder, basename(rasters))
  # Return ----
  if (length(ar) == 1) {
    a3 <- raster::brick(ar)
  } else {
    # Con `[` en vez de `[[` se guarda una lista adentro de la lista, y R avisa
    # "implicit list embedding of S4 objects is deprecated". Hoy es un warning;
    # esta anunciado que pasa a error.
    rast.list <- vector("list", length(ar))
    for (i in seq_along(ar)) rast.list[[i]] <- raster::brick(ar[i])
    rast.list$fun <- mean
    # El mosaico es lo mas caro de la funcion y estaba calculado dos veces
    # seguidas, la primera para nada.
    a3 <- do.call(raster::mosaic, rast.list)
  }
  # El CRS y el recorte van despues del if/else, para los dos caminos. Estaban
  # solo en la rama de un tile: con dos o mas, el resultado salia sin CRS -y por
  # lo tanto sin georreferenciar- y sin recortar, devolviendo la union entera de
  # los tiles en vez del area pedida. Pidiendo 300 m alrededor de un punto se
  # bajan 3 tiles y volvia un raster de 17713 x 19436 pixeles para un area de
  # unos 6000 de lado.
  # Los .jpg del formato "rgb" vienen con world file y sin CRS declarado, asi
  # que hay que ponerselo. Los .tif de "rgbi" en cambio SI lo declaran, y no es
  # el mismo: dicen SIRGAS-ROU98_UTM_Zone_21S, no WGS84. Pisarlo sin mirar le
  # cambiaba el datum al raster en silencio, asi que solo se asigna cuando el
  # archivo no trajo ninguno.
  if (is.na(raster::crs(a3))) {
    suppressWarnings(raster::crs(a3) <- "+proj=utm +zone=21 +south +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs")
  }
  # La transformacion de bb va despues de tener el CRS del raster: al reves, sf
  # no tiene destino al que transformar y falla con "crs not found".
  bb <- sf::st_transform(bb %>% sf::st_as_sf(), raster::crs(a3))
  suppressWarnings(a3 <- raster::crop(a3, bb))
  # raster::plotRGB(a3)
  return(a3)
}
