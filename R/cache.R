# La cache de load_geouy(): una copia de cada capa en la maquina del usuario.
#
# Es optativa y esta apagada por omision. Lo que guarda es la capa tal como la
# devuelve bajar_capa(), antes de reparar geometrias y de transformar el CRS,
# para que make_valid y crs se apliquen en cada llamada igual que sin cache:
# pedir la copia y pedir la capa al servidor tienen que dar lo mismo.
#
# Cada copia son dos archivos:
#
#  - Los datos, un RDS que lleva su suma md5 en el nombre
#    (Secciones.<md5>.geouy.rds). Con la suma en el nombre, un archivo de datos
#    no cambia nunca: si la capa cambia, es otro archivo.
#  - La ficha (Secciones.geouy.dcf), un texto que dice de que capa es, de donde
#    salio, cuando se bajo y cual es la suma de sus datos. Permite listar la
#    cache sin abrir los datos -CONEAT son 237.681 poligonos-.
#
# La ficha es lo unico que se reemplaza, y se reemplaza de un saque, con un
# rename. Asi la copia pasa de una version a la siguiente sin estados
# intermedios: si guardar falla o el proceso se corta, la ficha sigue apuntando
# a los datos anteriores, que siguen ahi. Y quien lee comprueba que los datos
# tengan la suma que dice la ficha antes de usarlos.
#
# No reemplaza al servidor: quien pide una capa por primera vez la necesita
# publicada. Sirve para no bajar lo mismo en cada sesion y para seguir
# trabajando cuando el servidor no responde.

# La carpeta es la de cache del usuario que define R (tools::R_user_dir), que es
# donde CRAN permite guardar. Con la opcion se la puede llevar a otro lado, por
# ejemplo adentro de un proyecto, para que los datos queden junto al analisis.
carpeta_cache <- function() {
  carpeta <- getOption("geouy.cache_dir", tools::R_user_dir("geouy", "cache"))
  if (!is.character(carpeta) || length(carpeta) != 1 || is.na(carpeta) || !nzchar(carpeta)) {
    stop("The option geouy.cache_dir must be the path of a folder.", call. = FALSE)
  }
  carpeta
}

# Pasados estos dias la copia se da por vieja y se intenta bajar la capa de
# nuevo. Inf la deja valer para siempre.
opcion_dias <- function() {
  d <- getOption("geouy.cache_days", 30)
  if (!is.numeric(d) || length(d) != 1 || is.na(d) || d < 0) {
    stop("The option geouy.cache_days must be a number of days, 0 or more.", call. = FALSE)
  }
  d
}

# Estas terminaciones son lo que marca a un archivo como de la cache: es lo
# unico que se lee, se pisa o se borra. Si el usuario apunta geouy.cache_dir a
# una carpeta con archivos suyos, no se tocan, salvo que terminen asi.
sufijo_datos <- ".geouy.rds"
sufijo_ficha <- ".geouy.dcf"
# Todo lo que la cache puede dejar en la carpeta: datos, fichas, y los
# parciales de una escritura en curso o que se corto.
patron_cache <- "\\.geouy\\.(rds|dcf)(\\.[0-9]+\\.parcial)?$"

# El nombre de la capa puede traer espacios; en el del archivo van como "_". Dos
# capas distintas podrian caer en el mismo nombre, y por eso la ficha guarda el
# de la capa y se compara al leer. Un test comprueba que hoy ninguna coincide.
archivo_ficha <- function(capa, carpeta = carpeta_cache()) {
  paste0(file.path(carpeta, gsub("[^A-Za-z0-9]+", "_", capa)), sufijo_ficha)
}

# Los datos a los que apunta una ficha, dada la suma que la ficha declara.
datos_de <- function(ficha, md5) {
  paste0(substr(ficha, 1, nchar(ficha) - nchar(sufijo_ficha)), ".", md5, sufijo_datos)
}

# Si la forma de guardar cambia en una version futura, cambiar este numero deja
# sin efecto las copias hechas con la anterior.
version_cache <- "1"

# Las filas del metadata de las partes de una capa que junta varias, como
# "Calles"; ninguna si la capa no es de esas. Es la misma cuenta que hace
# bajar_capa() para decidir si llama a leer_partes().
partes_de <- function(x) {
  md <- geouy::metadata
  if (x$formato %in% c("zip", "zip a")) return(md[0, ])
  nombres <- capas_de_la_url(x$url)
  if (length(nombres) < 2) return(md[0, ])
  urls <- vapply(nombres, function(parte) con_una_capa(x$url, parte), character(1))
  md[md$url %in% urls, ]
}

# Todo lo que el metadata dice de una capa y que cambia lo que bajar_capa()
# devuelve, resumido en una suma. Si en una version nueva del paquete la capa
# pasa a salir de otra direccion, o cambian su CRS, su codificacion o las
# columnas que declara, la copia es de otra cosa -a "Secciones" le paso: cambio
# de censo- y no se usa ni como respaldo. En una capa que junta varias cuentan
# tambien las filas de sus partes, porque lo guardado ya viene unido.
huella_capa <- function(x) {
  filas <- rbind(x, partes_de(x))
  campos <- c("capa", "url", "crs", "formato", "enc", "cod", "name")
  lineas <- vapply(seq_len(nrow(filas)), function(i) {
    paste(vapply(campos, function(k) as.character(filas[[k]][i]), character(1)),
          collapse = "\x1f")
  }, character(1))
  archivo <- tempfile()
  on.exit(borrar(archivo), add = TRUE)
  writeBin(charToRaw(paste(c(version_cache, lineas), collapse = "\n")), archivo)
  suma_md5(archivo)
}

suma_md5 <- function(archivo) unname(tools::md5sum(archivo))

# unlink() toma los nombres como patrones, salvo que se le diga que no: con una
# carpeta que se llame "cache[1]" borraria lo de "cache1". Aca se borra siempre
# por nombre exacto.
borrar <- function(archivos) unlink(archivos, expand = FALSE)

# Una ficha es un registro DCF, el formato del DESCRIPTION: texto que se puede
# abrir y leer. Devuelve un vector con nombres, o NULL si no hay ficha, no se
# puede leer, le falta algun campo o la suma no tiene forma de suma -va a parar
# al nombre de un archivo, y no puede traer cualquier cosa-.
campos_ficha <- c("capa", "url", "huella", "fecha", "md5", "filas")
# Sin esto, DCF junta los espacios seguidos y una URL que los tuviera no
# volveria igual.
con_espacios <- c("capa", "url")
leer_ficha <- function(archivo) {
  if (!file.exists(archivo)) return(NULL)
  r <- suppressWarnings(tryCatch(read.dcf(archivo, keep.white = con_espacios),
                                 error = function(e) NULL))
  if (is.null(r) || nrow(r) != 1 || !all(campos_ficha %in% colnames(r))) return(NULL)
  r <- r[1, ]
  if (anyNA(r[campos_ficha]) || !grepl("^[0-9a-f]{32}$", r[["md5"]])) return(NULL)
  r
}

# La fecha se guarda en UTC, para que no dependa de la zona de la maquina.
fecha_ficha <- function(ficha) {
  as.POSIXct(ficha[["fecha"]], tz = "UTC", format = "%Y-%m-%d %H:%M:%S")
}

dias_de_la_copia <- function(ficha) {
  as.numeric(difftime(Sys.time(), fecha_ficha(ficha), units = "days"))
}

# El dia en que se guardo la copia, en la hora de la maquina del usuario.
dia_local <- function(ficha) format(fecha_ficha(ficha), "%Y-%m-%d", tz = "")

# La ficha describe la capa tal como la define hoy el metadata.
ficha_al_dia <- function(ficha, x) {
  identical(ficha[["capa"]], x$capa) && identical(ficha[["huella"]], huella_capa(x))
}

# Lee y valida la ficha de la copia de una capa, sin abrir los datos. Devuelve
# NULL si no hay copia o si no sirve.
#
# Leer nunca borra. Una copia que no sirve se reemplaza sola cuando la capa se
# vuelve a bajar, y lo que quede de mas lo saca podar_cache(). Si la lectura
# borrara, podria llevarse la copia que otra sesion de R acaba de guardar.
ficha_copia <- function(x) {
  archivo <- archivo_ficha(x$capa)
  ficha <- leer_ficha(archivo)
  if (is.null(ficha) || !ficha_al_dia(ficha, x) || is.na(fecha_ficha(ficha))) return(NULL)
  if (!file.exists(datos_de(archivo, ficha[["md5"]]))) return(NULL)
  ficha
}

# Lee los datos de una copia cuya ficha ya se valido. Devuelve NULL si no
# tienen la suma que dice la ficha o si lo que hay no es un sf.
datos_copia <- function(x, ficha) {
  archivo <- datos_de(archivo_ficha(x$capa), ficha[["md5"]])
  if (!identical(suma_md5(archivo), ficha[["md5"]])) return(NULL)
  # Sin warnings: si otra sesion renovo la copia justo ahora, estos datos ya
  # no estan, y readRDS() lo dice con un aviso ademas del error.
  datos <- tryCatch(suppressWarnings(readRDS(archivo)), error = function(e) NULL)
  if (inherits(datos, "sf")) datos else NULL
}

# Guarda la copia de una capa recien bajada. Nunca corta la carga: si no se
# puede guardar -la carpeta no se puede crear, no hay lugar-, avisa con un
# warning y la capa se devuelve igual.
#
# Cada archivo se escribe con otro nombre y se renombra al final, igual que el
# zip en bajar_capa(): un archivo a medias nunca queda con el nombre
# definitivo. Primero los datos, que por llevar la suma en el nombre no pisan
# a los anteriores, y despues la ficha, que es la que pasa la copia de una
# version a la otra. Si algo falla antes de ese ultimo paso, la copia anterior
# queda entera y sigue sirviendo de respaldo.
guardar_copia <- function(a, x) {
  # Una capa sin filas puede ser un servicio que contesto vacio por un rato:
  # guardarla dejaria ese rato fijo por un mes. Lo mismo si es una capa que
  # junta varias y una de sus partes vino vacia; unir_capas() anota en la
  # columna capa de que parte sale cada fila.
  if (!inherits(a, "sf") || !nrow(a)) return(invisible(FALSE))
  partes <- partes_de(x)
  if (nrow(partes) && !all(partes$capa %in% a[["capa"]])) return(invisible(FALSE))
  carpeta <- carpeta_cache()
  ficha_final <- archivo_ficha(x$capa, carpeta)
  parciales <- paste0(c(datos_de(ficha_final, "nueva"), ficha_final),
                      ".", Sys.getpid(), ".parcial")
  on.exit(borrar(parciales), add = TRUE)
  listo <- tryCatch({
    # Sin warning: si otra sesion creo la carpeta recien, dir.create() avisa
    # que ya existe, y eso no es un problema.
    if (!dir.exists(carpeta)) dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
    if (!dir.exists(carpeta)) stop("the folder could not be created")
    saveRDS(a, parciales[1])
    md5 <- suma_md5(parciales[1])
    # Sin la suma no hay nombre para los datos ni forma de comprobarlos.
    if (is.na(md5) || !grepl("^[0-9a-f]{32}$", md5)) stop("the checksum could not be computed")
    datos_final <- datos_de(ficha_final, md5)
    anterior <- leer_ficha(ficha_final)
    ficha <- c(capa = x$capa, url = x$url, huella = huella_capa(x),
               fecha = format(Sys.time(), "%Y-%m-%d %H:%M:%S", tz = "UTC"),
               md5 = md5, filas = as.character(nrow(a)),
               geouy = as.character(utils::packageVersion("geouy")),
               sf = as.character(utils::packageVersion("sf")))
    write.dcf(t(ficha), parciales[2], keep.white = con_espacios, width = 1e4)
    # Si la capa no cambio desde la vez anterior, los datos ya estan con ese
    # nombre. Se renombra encima igual: reemplaza un archivo que pudiera estar
    # danado, y lo deja con fecha de hoy, que es lo que mira la poda.
    if (!renombrar(parciales[1], datos_final)) stop("the files could not be renamed")
    if (!renombrar(parciales[2], ficha_final)) stop("the files could not be renamed")
    # A los datos anteriores ya no los nombra la ficha. Se la vuelve a leer por
    # si otra sesion guardo en el medio y los puso otra vez en uso.
    if (!is.null(anterior) && !identical(anterior[["md5"]], md5)) {
      ahora <- leer_ficha(ficha_final)
      if (is.null(ahora) || !identical(ahora[["md5"]], anterior[["md5"]])) {
        borrar(datos_de(ficha_final, anterior[["md5"]]))
      }
    }
    TRUE
  }, warning = function(w) w, error = function(e) e)
  if (!isTRUE(listo)) {
    warning(glue::glue("The layer '{x$capa}' was loaded, but its copy could not be saved ",
                       "in {carpeta}: {conditionMessage(listo)}"), call. = FALSE)
    return(invisible(FALSE))
  }
  # La limpieza es de paso: que falle no puede cortar la carga ni ensuciarla.
  try(suppressWarnings(podar_cache(carpeta)), silent = TRUE)
  invisible(TRUE)
}

# Las copias que hay en la carpeta, segun sus fichas. Solo mira los archivos
# con las terminaciones de la cache, y no abre los datos ni comprueba su suma.
inventario <- function(carpeta = carpeta_cache()) {
  vacio <- data.frame(capa = character(), saved = as.POSIXct(character(), tz = "UTC"),
                      rows = integer(), size_mb = numeric(), file = character(),
                      ficha = character(), huella = character(),
                      stringsAsFactors = FALSE)
  if (!dir.exists(carpeta)) return(vacio)
  fichas <- list.files(carpeta, pattern = paste0(gsub(".", "\\.", sufijo_ficha, fixed = TRUE), "$"),
                       full.names = TRUE)
  filas <- lapply(fichas, function(archivo) {
    ficha <- leer_ficha(archivo)
    if (is.null(ficha)) return(NULL)
    datos <- datos_de(archivo, ficha[["md5"]])
    if (!file.exists(datos)) return(NULL)
    data.frame(capa = ficha[["capa"]], saved = fecha_ficha(ficha),
               rows = suppressWarnings(as.integer(ficha[["filas"]])),
               size_mb = round(file.size(datos) / 1024^2, 2), file = datos,
               ficha = archivo, huella = ficha[["huella"]], stringsAsFactors = FALSE)
  })
  filas <- Filter(Negate(is.null), filas)
  if (!length(filas)) return(vacio)
  r <- do.call(rbind, filas)
  r <- r[order(r$capa), ]
  rownames(r) <- NULL
  r
}

# Saca lo que ya no se va a usar, que es lo que CRAN pide de una cache:
#
#  - Las copias de capas que ya no estan en el metadata, o que se guardaron
#    cuando el metadata las definia de otra manera: una version nueva del
#    paquete puede dar de baja una capa o mudarla, y esa copia no se usaria
#    nunca mas.
#  - Lo que dejo una escritura que se corto o una version anterior de la copia:
#    parciales, datos que ninguna ficha nombra, fichas sin datos o que no se
#    pueden leer. Solo los de mas de un dia, para no sacarle el archivo a otra
#    sesion que este guardando en este momento.
#
# Una copia vencida no se saca: es el respaldo para cuando el servidor no
# responde, y el dia que hace falta puede ser la unica que queda.
podar_cache <- function(carpeta = carpeta_cache()) {
  # La lista de archivos se toma antes que el inventario: lo que otra sesion
  # guarde despues de este punto no esta en la lista, y no se toca.
  todos <- list.files(carpeta, pattern = patron_cache, full.names = TRUE)
  copias <- inventario(carpeta)
  md <- geouy::metadata
  al_dia <- vapply(seq_len(nrow(copias)), function(i) {
    x <- md[md$capa == copias$capa[i], ]
    if (nrow(x) != 1) return(FALSE)
    huella <- huella_capa(x)
    # Si la huella no se pudo calcular no se sabe si la copia sirve, y se deja:
    # sacarla seria vaciar la cache por un tropiezo al leer un archivo.
    is.na(huella) || identical(copias$huella[i], huella)
  }, logical(1))
  for (i in which(!al_dia)) {
    # Se vuelve a leer la ficha: si otra sesion acaba de guardar ahi una copia
    # buena, ya no es la que se habia visto.
    ahora <- leer_ficha(copias$ficha[i])
    if (is.null(ahora) || identical(ahora[["huella"]], copias$huella[i])) {
      borrar(c(copias$file[i], copias$ficha[i]))
    }
  }
  sueltos <- setdiff(todos, c(copias$file[al_dia], copias$ficha[al_dia]))
  edad <- as.numeric(difftime(Sys.time(), file.mtime(sueltos), units = "days"))
  borrar(sueltos[!is.na(edad) & edad > 1])
  invisible(copias$capa[!al_dia])
}

# La poda corre al guardar, y ademas la primera vez que se usa cada carpeta en
# la sesion: asi lo que quedo viejo se va aunque no se guarde nada nuevo.
estado_cache <- new.env(parent = emptyenv())
podar_una_vez <- function(carpeta = carpeta_cache()) {
  # Una carpeta que todavia no existe no tiene nada para sacar, y no se anota:
  # su camino completo recien es siempre el mismo cuando existe. Antes puede
  # escribirse distinto -en macOS la carpeta temporal esta detras de un enlace,
  # en Windows puede venir con nombres cortos- y se podaria dos veces.
  if (!dir.exists(carpeta)) return(invisible())
  # Con el camino completo: "cache" es otra carpeta si cambio el directorio de
  # trabajo.
  cual <- normalizePath(carpeta, mustWork = FALSE)
  if (cual %in% estado_cache$podadas) return(invisible())
  r <- try(suppressWarnings(podar_cache(carpeta)), silent = TRUE)
  # Si fallo, queda para la proxima.
  if (!inherits(r, "try-error")) estado_cache$podadas <- c(estado_cache$podadas, cual)
  invisible()
}

# La carga con cache. bajar es la funcion que trae la capa del servidor.
#
#  - Hay copia y no es vieja: se usa, sin salir a la red -ni siquiera se mira
#    si hay conexion, asi que anda sin internet-.
#  - No hay copia, o es vieja: se baja y se guarda. Si no se puede bajar y hay
#    una copia vieja, se usa esa, con un warning que dice de cuando es y por
#    que no se pudo bajar.
#  - refresh = TRUE: se baja siempre. Si no se puede, es un error y la copia
#    queda como estaba: quien pide datos nuevos no tiene que recibir los
#    viejos con un aviso que se puede pasar por alto.
cargar_con_cache <- function(x, bajar, refresh = FALSE) {
  dias <- opcion_dias()
  podar_una_vez()
  if (isTRUE(refresh)) {
    a <- bajar()
    guardar_copia(a, x)
    return(a)
  }
  ficha <- ficha_copia(x)
  if (!is.null(ficha) && dias_de_la_copia(ficha) <= dias) {
    datos <- datos_copia(x, ficha)
    if (!is.null(datos)) {
      message(glue::glue("Using the copy of '{x$capa}' saved on {dia_local(ficha)}. ",
                         "Use refresh = TRUE to download it again."))
      return(datos)
    }
    ficha <- NULL
  }
  a <- tryCatch(bajar(), error = function(e) e)
  if (!inherits(a, "error")) {
    guardar_copia(a, x)
    return(a)
  }
  if (!is.null(ficha)) {
    datos <- datos_copia(x, ficha)
    if (!is.null(datos)) {
      warning(glue::glue("The layer '{x$capa}' could not be downloaded, so the copy ",
                         "saved on {dia_local(ficha)} is used.\n{conditionMessage(a)}"),
              call. = FALSE)
      return(datos)
    }
  }
  stop(a)
}

#' Copies of Layers Saved by load_geouy()
#'
#' \code{cache_geouy()} lists the layers that \code{\link{load_geouy}()} saved
#' with \code{cache = TRUE}, and \code{clear_cache_geouy()} deletes them.
#'
#' @family service
#' @param c Names of the layers whose copies are deleted. With \code{NULL},
#'   the default, all the copies are deleted.
#' @details The copies are in the cache folder of the user that R assigns to
#'   the package, \code{tools::R_user_dir("geouy", "cache")}, or in the folder
#'   given in \code{options(geouy.cache_dir = )}. The names of their files end
#'   in \code{.geouy.rds} or \code{.geouy.dcf}, or in one of those followed by
#'   \code{.parcial} while a copy is being saved. Those endings are reserved
#'   for the cache: only files with them are listed or deleted, and any other
#'   file in that folder is left alone.
#'
#'   The list comes from the records saved next to the data, without opening
#'   the data: \code{load_geouy()} checks a copy when it is about to use it.
#'   Copies of layers that are no longer in \code{\link{metadata}}, or that
#'   are defined there in a different way than when they were saved, are
#'   deleted the first time the cache is used in a session and every time a
#'   layer is saved.
#' @return \code{cache_geouy()} returns a data frame with one row per saved
#'   layer: its name (\code{capa}), when it was saved (\code{saved}), its
#'   number of features (\code{rows}), the size of the file in MB
#'   (\code{size_mb}) and its path (\code{file}).
#'   \code{clear_cache_geouy()} returns, invisibly, the names of the layers
#'   whose copies were deleted.
#' @export
#' @examples
#' # A folder of the session, so that the example leaves nothing behind
#' old <- options(geouy.cache_dir = file.path(tempdir(), "geouy-cache"))
#' cache_geouy()
#' clear_cache_geouy()
#' options(old)
cache_geouy <- function() {
  inventario()[, c("capa", "saved", "rows", "size_mb", "file")]
}

#' @rdname cache_geouy
#' @export
clear_cache_geouy <- function(c = NULL) {
  if (!is.null(c) && !is.character(c)) {
    stop("c must be the names of the layers to delete, or NULL to delete all.", call. = FALSE)
  }
  carpeta <- carpeta_cache()
  todos <- list.files(carpeta, pattern = patron_cache, full.names = TRUE)
  if (is.null(c)) {
    # Todo lo de la cache, tambien lo que haya dejado una escritura cortada.
    capas <- inventario(carpeta)$capa
    de_cual <- lapply(capas, function(capa) archivos_de_la_capa(capa, todos, carpeta))
    borrar(todos)
  } else {
    # Por el nombre de los archivos y no por el inventario: asi tambien se va
    # una copia con la ficha rota o sin sus datos, que el inventario no lista.
    capas <- unique(c)
    de_cual <- lapply(capas, function(capa) archivos_de_la_capa(capa, todos, carpeta))
    borrar(unlist(de_cual))
  }
  # Solo las que tenian algo y de verdad se fueron: unlink() no avisa si no
  # pudo.
  se_fue <- vapply(de_cual, function(a) length(a) > 0 && !any(file.exists(a)), logical(1))
  invisible(capas[se_fue])
}

# Los archivos de la cache que son de una capa: su ficha, sus datos -puede
# haber de mas de una version- y sus parciales.
archivos_de_la_capa <- function(capa, todos, carpeta) {
  ficha <- archivo_ficha(capa, carpeta)
  base <- substr(ficha, 1, nchar(ficha) - nchar(sufijo_ficha))
  todos[startsWith(todos, paste0(base, "."))]
}
