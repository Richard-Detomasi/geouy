# Junta los fragmentos de news/ en el NEWS.md, bajo el encabezado de la version
# que declara el DESCRIPTION, y los borra.
#
# Se corre a mano al preparar una release:
#   source(".github/scripts/consolidar-news.R")
#
# Es deliberadamente conservador: inserta y borra, no reescribe. El encabezado
# de version de este NEWS.md tiene un formato propio ("## geouy v0.2.9") y no
# conviene tocarlo desde un script.

consolidar_news <- function(dir_news = "news", archivo = "NEWS.md",
                            descripcion = "DESCRIPTION", borrar = TRUE) {
  stopifnot(file.exists(archivo), dir.exists(dir_news))

  fragmentos <- setdiff(list.files(dir_news, pattern = "\\.md$", full.names = TRUE),
                        file.path(dir_news, "README.md"))
  if (length(fragmentos) == 0) {
    message("No hay fragmentos en ", dir_news, "/. No se toca el ", archivo, ".")
    return(invisible(character()))
  }

  version <- read.dcf(descripcion, fields = "Version")[[1]]
  news <- readLines(archivo, warn = FALSE)
  # El encabezado de la version en curso. Se busca el que empieza con "## " y
  # contiene la version del DESCRIPTION, sin asumir como esta escrito el resto.
  cabecera <- grep(paste0("^##\\s.*", gsub(".", "\\.", version, fixed = TRUE)), news)
  if (length(cabecera) != 1) {
    stop("Esperaba un solo encabezado de la version ", version, " en ", archivo,
         " y encontre ", length(cabecera), ". Revisalo a mano.", call. = FALSE)
  }

  # Los fragmentos van en orden del numero que llevan adelante, que con el
  # numero de PR queda en orden de creacion. Ordenar por nombre no sirve: como
  # texto, "100" va antes que "99".
  numero <- suppressWarnings(as.numeric(sub("^(\\d+).*", "\\1", basename(fragmentos))))
  fragmentos <- fragmentos[order(numero, basename(fragmentos), na.last = TRUE)]
  entradas <- unlist(lapply(fragmentos, function(f) {
    linea <- readLines(f, warn = FALSE)
    # Se descartan las lineas vacias del principio y del final para que no
    # queden huecos entre una entrada y la siguiente.
    linea <- linea[cumsum(nzchar(linea)) > 0]
    rev(rev(linea)[cumsum(nzchar(rev(linea))) > 0])
  }))
  if (length(entradas) == 0) {
    stop("Los fragmentos estan vacios. No se toca el ", archivo, ".", call. = FALSE)
  }

  # Va una linea en blanco despues del encabezado y ninguna al final: las
  # entradas nuevas quedan pegadas a las que ya estaban, como viñetas de la
  # misma lista.
  salida <- append(news, c("", entradas), after = cabecera)
  # Si el archivo ya tenia una linea en blanco despues del encabezado, ahora
  # habria dos seguidas.
  sobrante <- cabecera + 1 + length(entradas) + 1
  if (sobrante <= length(salida) && !nzchar(salida[sobrante])) salida <- salida[-sobrante]
  writeLines(salida, archivo, useBytes = TRUE)

  message(length(fragmentos), " fragmento(s) sumados a ", archivo,
          " bajo la version ", version, ":")
  for (f in fragmentos) message("  - ", basename(f))
  if (borrar) {
    unlink(fragmentos)
    message("Fragmentos borrados. Revisa el ", archivo, " antes de commitear.")
  } else {
    message("Fragmentos conservados (borrar = FALSE).")
  }
  invisible(fragmentos)
}

# Se corre al sourcear: es lo unico para lo que existe este archivo. Si se
# quiere sólo la función, sin ejecutarla:
#   source(".github/scripts/consolidar-news.R", local = new.env())
consolidar_news()
