# Lo que comparten chequeo-capas.R y catalogo-capas.R. Son dos preguntas
# distintas -que se rompio contra que aparecio- pero salen a la red igual, y no
# conviene que una consulte con timeouts o reintentos distintos de la otra.

# tope: cuantos bytes del cuerpo se leen. 64 KB alcanzan de sobra para reconocer
# un GML, un JSON o un zip por su primer bloque, y evitan cargar una capa entera
# en memoria. Un indice de directorio o un GetCapabilities son otra cosa: el
# indice de MIDES pesa 118 KB y el GetCapabilities del IDE casi 400 KB, asi que
# ahi hay que pedir mas.
consultar <- function(url, solo_cabecera, tope = 65536L) {
  cuerpo <- tempfile()
  on.exit(unlink(cuerpo), add = TRUE)
  args <- c("-sS", "-o", shQuote(cuerpo),
            "-w", shQuote("GEOUY:%{http_code}:%{size_download}:%{url_effective}"),
            "--connect-timeout", "15", "--max-time", "90", "-L",
            "--retry", "2", "--retry-delay", "5", "--retry-all-errors")
  if (solo_cabecera) args <- c(args, "-I")
  salida <- suppressWarnings(system2("curl", c(args, "--", shQuote(url)),
                                     stdout = TRUE, stderr = FALSE))
  estado <- attr(salida, "status"); if (is.null(estado)) estado <- 0L
  linea <- grep("^GEOUY:", salida, value = TRUE)
  if (estado != 0L || !length(linea)) {
    return(list(codigo = "000", bytes = 0, url = url, curl = estado, texto = ""))
  }
  p <- strsplit(sub("^GEOUY:", "", linea[length(linea)]), ":", fixed = TRUE)[[1]]
  n <- suppressWarnings(min(file.info(cuerpo)$size, tope))
  texto <- if (!is.na(n) && n > 0) readChar(cuerpo, n, useBytes = TRUE) else ""
  list(codigo = p[1], bytes = as.numeric(p[2]),
       url = paste(p[-(1:2)], collapse = ":"), curl = 0L, texto = texto)
}

# Un listado de directorio de Apache tiene muchos href RELATIVOS a archivos del
# propio directorio. Las dos condiciones importan:
#
#  - Relativos: sit.mvot.gub.uy/shp/ contesta 200 con una pagina normal cuyos
#    unicos href son un favicon y un enlace a otro dominio. Sin exigir que sean
#    relativos, esa pagina pasaba por listado.
#  - Mas de uno: hay servidores que contestan 200 con una pagina de error.
#
# Devuelve el estado aparte de los archivos, porque no es lo mismo que el
# servidor no conteste -hay que reintentar- a que ese directorio simplemente no
# publique indice, que es una propiedad estable y no un problema.
listado_del_indice <- function(indice) {
  r <- consultar(indice, FALSE, tope = 4194304L)
  if (r$curl != 0L || !identical(r$codigo, "200")) {
    return(list(estado = "sin respuesta", archivos = character()))
  }
  n <- regmatches(r$texto, gregexpr('href="[^"?/][^"]*"', r$texto))[[1]]
  n <- sub('href="', "", sub('"$', "", n))
  n <- unique(n[!grepl("://", n, fixed = TRUE)])
  if (length(n) < 2) list(estado = "sin indice", archivos = character())
  else list(estado = "ok", archivos = n)
}

# Directorio al que pertenece un archivo servido por URL.
directorio_de <- function(url) sub("[^/]*$", "", sub("[?#].*", "", url))
