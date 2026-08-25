#' This function allows to Download .jpg or .tif files from the IDEuy tiles repository, according to a 'sf' object bbox.
#' @family service
#' @param x An 'sf' object with the same crs as the homonym parameter
#' @param d numeric; buffer distance for all, or for each of the elements in x; in case dist is a units object, it should be convertible to arc_degree if x has geographic coordinates, and to st_crs(x)$units otherwise. Default NA, but if x is a only one point buffer default is 100.
#' @param format Format of the archives to download (avaiable: "rgb" and "rgbi") Default "rgb"
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
#'\donttest{
#' x <- data.frame(x = 577968, y = 6147753, id = 1)
#' x <- sf::st_as_sf(x, coords = c("x", "y"), crs = 32721)
#' x_tiles <- try(tiles_geouy(x, urban = TRUE), silent = TRUE)
#' if (!inherits(x_tiles, "try-error")) x_tiles
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
  for (i in seq_along(urls)) {
    message(glue::glue("Trying to download {basename(urls[i])}..."))
    # De a una URL por vez. download.file() con un vector devuelve 0 si al menos
    # una de las descargas anduvo, asi que el par .jpg/.jgw se bajaba junto y un
    # world file faltante pasaba inadvertido: el raster quedaba sin georreferenciar.
    estado <- tryCatch(
      utils::download.file(urls[i], destinos[i], mode = "wb", method = "libcurl"),
      error = function(e) e)
    if (inherits(estado, "error") || !identical(as.integer(estado), 0L)) {
      stop(glue::glue("Could not download '{basename(urls[i])}' from the IDEuy tiles ",
                      "repository. The server may be out of service, try in ",
                      "https://visualizador.ide.uy/ideuy/core/load_public_project/ideuy/"),
           call. = FALSE)
    }
  }
  # Se leen exactamente los archivos de esta consulta. Antes se barria la carpeta
  # buscando cualquier .jpg y se filtraba por fecha de modificacion, lo que tomaba
  # archivos ajenos y a la vez dejaba fuera los que ya estuvieran descargados.
  ar <- file.path(folder, basename(rasters))
  # Return ----
  if (length(ar) == 1) {
    a3 <- raster::brick(ar)
    suppressWarnings(raster::crs(a3) <- "+proj=utm +zone=21 +south +ellps=WGS84 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs")
    bb <- sf::st_transform(bb %>% sf::st_as_sf(), raster::crs(a3))
    suppressWarnings(a3 <- raster::crop(a3, bb))
  } else {
    rast.list <- list()
    for (i in 1:length(ar)) { rast.list[i] <- raster::brick(ar[i]) }
    # And then use do.call on the list of raster objects
    rast.list$fun <- mean
    a3 <- do.call(raster::mosaic,rast.list)
    a3 <- do.call(raster::mosaic, rast.list)
  }
  # raster::plotRGB(a3)
  return(a3)
}
