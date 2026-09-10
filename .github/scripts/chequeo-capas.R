# Recorre las capas del metadata y comprueba que cada servicio siga respondiendo.
#
# A proposito NO usa el paquete ni sf: lee data/metadata.rda directo y consulta
# con curl. Asi el chequeo corre sin compilar el stack espacial y no se cae por un
# problema de instalacion, que no es lo que quiere detectar. La contracara es que
# esto es una prueba de humo del servicio: dice si el servicio esta y la capa
# existe, no que sf pueda leerla y transformarla.
#
# Tampoco baja las capas enteras: pide una sola feature. Bajarlas completas serian
# gigabytes por semana contra servidores del Estado, y CONEAT sola tarda cuatro
# minutos.

if (!nzchar(Sys.which("curl"))) stop("No se encontro curl en el PATH")
load("data/metadata.rda")

# Los formatos "zip" son de dos clases distintas y no se comprueban igual: 39 son
# consultas WFS con outputFormat=shape-zip -o sea, se pueden acotar a una feature-
# y 17 son archivos estaticos que pesan cientos de MB, a los que solo se les pide
# la cabecera.
es_wfs <- function(url) grepl("request=GetFeature", url, ignore.case = TRUE)
es_archivo <- function(url, formato) formato %in% c("zip", "zip a") && !es_wfs(url)

acotar <- function(url) {
  # Si la capa ya declara un maxFeatures -Rutas trae 50- hay que reemplazarlo, no
  # agregar un segundo parametro con el mismo nombre.
  if (grepl("([?&])maxFeatures=", url, ignore.case = TRUE)) {
    sub("maxFeatures=[^&#]*", "maxFeatures=1", url, ignore.case = TRUE)
  } else {
    paste0(url, if (grepl("?", url, fixed = TRUE)) "&" else "?", "maxFeatures=1")
  }
}

endpoint <- function(url) {
  url <- sub("^WFS:", "", url)
  if (!grepl("^https?://", url, ignore.case = TRUE)) {
    return(NA_character_)
  }
  if (es_wfs(url)) return(acotar(url))
  # Endpoints WFS sin GetFeature (ArcGIS): solo se puede certificar el servicio.
  if (grepl("WFSServer|/wfs", url, ignore.case = TRUE)) {
    return(paste0(url, if (grepl("?", url, fixed = TRUE)) "&" else "?",
                  "service=WFS&request=GetCapabilities"))
  }
  url
}

# tope: cuantos bytes del cuerpo se leen. 64 KB alcanzan de sobra para
# reconocer un GML, un JSON o un zip por su primer bloque, y evitan cargar una
# capa entera en memoria. El indice de un directorio es otra cosa: el de MIDES
# pesa 118 KB y el archivo que se busca puede estar en cualquier parte, asi que
# ahi se pide mas.
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

# Los archivos estaticos de algunos servidores se regeneran: se borran y se
# vuelven a crear, y mientras tanto devuelven 404 aunque el servicio este
# perfecto. Nos paso con "Educacion especial", que estuvo casi veinte horas asi
# y volvio sola: el chequeo la reporto caida y no lo estaba.
#
# Antes de darla por caida se mira el indice del directorio. Si el archivo sigue
# listado ahi, lo mas probable es que se este regenerando y no que lo hayan dado
# de baja. De los tres servidores que sirven archivos estaticos solo uno publica
# indice, asi que cuando no hay se reporta como antes.
#
# Ojo: uno de esos servidores contesta HTTP 200 con una pagina de error en vez
# de 404, asi que mirar el codigo no alcanza. Se exige que el cuerpo tenga
# varias entradas de archivo, que es lo que distingue un listado de una pagina
# cualquiera servida con 200.
figura_en_el_indice <- function(url) {
  archivo <- basename(sub("[?#].*", "", url))
  if (!nzchar(archivo)) return(FALSE)
  indice <- sub("[^/]*$", "", sub("[?#].*", "", url))
  # El indice se lee entero: el archivo buscado puede estar al final. Se pone un
  # techo igual, para que un servidor que devuelva algo enorme no llene la
  # memoria del runner.
  r <- consultar(indice, FALSE, tope = 4194304L)
  if (r$curl != 0L || !identical(r$codigo, "200")) return(FALSE)
  listados <- regmatches(r$texto, gregexpr('href="[^"?/][^"]*"', r$texto))[[1]]
  listados <- sub('href="', "", sub('"$', "", listados))
  if (length(listados) < 2) return(FALSE)
  archivo %in% listados
}

# Un 200 no alcanza: los geoserver contestan las excepciones con codigo 200 y un
# XML de error. Uno de esos que vi media 507 bytes, asi que un umbral de tamano no
# sirve; hay que mirar si lo que vino se parece a datos.
clasificar <- function(r, solo_cabecera) {
  if (r$curl != 0L || r$codigo == "000") return("sin respuesta")
  if (!identical(r$codigo, "200")) return(paste("HTTP", r$codigo))
  if (solo_cabecera) return(if (r$codigo == "200") "ok" else paste("HTTP", r$codigo))
  if (grepl("ExceptionReport|ServiceException|<html", r$texto, ignore.case = TRUE))
    return("el servicio devolvio un error")
  if (grepl("^PK", r$texto)) return("ok")                       # un zip de verdad
  if (grepl("<([[:alnum:]_.-]+:)?FeatureCollection\\b", r$texto, perl = TRUE) ||
      grepl('"type"\\s*:\\s*"FeatureCollection"', r$texto, perl = TRUE)) return("ok")
  if (grepl("<([[:alnum:]_.-]+:)?WFS_Capabilities\\b", r$texto, perl = TRUE)) return("ok")
  "respondio algo que no son datos"
}

# El servicio puede responder perfecto y la ficha estar mintiendo igual: si el
# cod o el name que declara no existen en la capa, where_uy() falla con "Can't
# extract columns that don't exist". Nos paso con diez capas, y todas menos las
# ultimas seis apareceron de casualidad mirando otra cosa.
#
# Se pregunta por DescribeFeatureType y no por una feature: devuelve el esquema
# sin datos, 1.7 KB contra 210 KB, y da los nombres en atributos name="...".
# Buscar el nombre de la columna adentro del cuerpo de una feature no sirve:
# "depto" matchea dentro de "coddepto", el nombre de la capa aparece en la URL
# que el propio XML incluye, y sobre todo <gml:name> es parte del estandar GML,
# asi que casi toda capa lo trae exista o no la columna.
esquema <- function(url) {
  if (!grepl("[tT]ype[nN]ames?=", url)) return(NULL)
  tn <- sub(".*[tT]ype[nN]ames?=([^&#]*).*", "\\1", url)
  # Dos capas separadas por coma no tienen un esquema unico.
  if (grepl(",", tn, fixed = TRUE)) return(NULL)
  base <- sub("\\?.*", "", sub("^WFS:", "", url))
  r <- consultar(paste0(base, "?service=WFS&version=1.0.0",
                        "&request=DescribeFeatureType&typeName=", tn), FALSE)
  if (r$curl != 0L || !identical(r$codigo, "200")) return(NULL)
  if (grepl("ExceptionReport|ServiceException", r$texto, ignore.case = TRUE)) return(NULL)
  campos <- regmatches(r$texto, gregexpr('name="[A-Za-z_0-9]+"', r$texto))[[1]]
  campos <- unique(sub('name="', "", sub('"$', "", campos)))
  if (length(campos) == 0) NULL else campos
}

# gml_id no figura en ningun esquema porque no es un campo de la capa: es el
# identificador de la feature. Pero sf lo agrega como columna al leer, asi que
# las nueve capas que lo declaran estan bien y no hay que avisar por ellas.
# Comprobado en Peajes y en Lagunas publicas: las dos lo traen.
columnas_declaradas_faltantes <- function(fila) {
  declaradas <- c(cod = fila$cod, name = fila$name)
  declaradas <- declaradas[!is.na(declaradas) & declaradas != "gml_id"]
  if (length(declaradas) == 0) return(NULL)
  campos <- esquema(fila$url)
  if (is.null(campos)) return(NULL)   # sin esquema consultable, no se opina
  faltan <- declaradas[!declaradas %in% campos]
  if (length(faltan) == 0) return(NULL)
  sprintf("%s='%s'", names(faltan), faltan)
}

filas <- vector("list", nrow(metadata))
for (i in seq_len(nrow(metadata))) {
  capa <- metadata$capa[i]
  url  <- endpoint(metadata$url[i])
  if (is.na(url)) {
    filas[[i]] <- data.frame(capa = capa, servidor = "-", motivo = "URL invalida en el metadata", ok = FALSE)
    cat(sprintf("%-5s %-32s %s\n", "FALLA", capa, "URL invalida")); next
  }
  cab <- es_archivo(metadata$url[i], metadata$formato[i])
  r <- consultar(url, cab)
  motivo <- clasificar(r, cab)
  # Un 404 en un archivo estatico puede ser una regeneracion en curso.
  if (cab && identical(r$codigo, "404") && figura_en_el_indice(url)) {
    motivo <- "no se puede bajar ahora, pero sigue listado en el directorio"
  }
  # Las columnas solo se miran si la capa respondio: si el servicio esta caido,
  # avisar ademas que no se pudo verificar la ficha es ruido sobre ruido.
  faltan <- if (motivo == "ok") columnas_declaradas_faltantes(metadata[i, ]) else NULL
  filas[[i]] <- data.frame(capa = capa, servidor = sub("^(https?://[^/?]+).*", "\\1", r$url),
                           motivo = motivo, ok = motivo == "ok",
                           columnas = if (is.null(faltan)) NA_character_ else paste(faltan, collapse = " "))
  estado <- if (motivo != "ok") "FALLA" else if (!is.null(faltan)) "FICHA" else "ok"
  cat(sprintf("%-5s %-32s %s\n", estado, capa,
              if (motivo != "ok") motivo else if (!is.null(faltan))
                paste("declara una columna que no existe:", paste(faltan, collapse = " ")) else ""))
}
res <- do.call(rbind, filas)
caidas <- res[!res$ok, ]
# Dos problemas distintos y con urgencias distintas: que un servicio no responda
# no depende de nosotros y suele arreglarse solo; que la ficha declare una
# columna que no existe es nuestro y rompe where_uy() todos los dias.
fichas <- res[res$ok & !is.na(res$columnas), ]
cat("\n==== ", nrow(res) - nrow(caidas), " de ", nrow(res), " capas responden ====\n", sep = "")
if (nrow(fichas) > 0)
  cat("==== ", nrow(fichas), " declaran una columna que no existe ====\n", sep = "")

saveRDS(res, "chequeo-capas.rds")
# Una huella de QUE esta mal, sin fecha: el workflow la usa para no repetir el
# mismo aviso cada semana cuando no cambio nada. Incluye las dos clases, asi que
# si una capa vuelve pero otra estrena un problema de ficha, el aviso se
# actualiza igual.
writeLines(sort(c(sprintf("%s\t%s", caidas$capa, caidas$motivo),
                  sprintf("%s\tficha: %s", fichas$capa, fichas$columnas))),
           "chequeo-capas.estado")

limpiar <- function(x) gsub("[|`\r\n]", " ", x)
con <- file("chequeo-capas.md", "w", encoding = "UTF-8")
partes <- character()
if (nrow(caidas) > 0) {
  partes <- c(partes,
    sprintf("**%d de %d capas no responden.**", nrow(caidas), nrow(res)), "",
    "| Capa | Servidor | Qué pasa |", "|---|---|---|",
    sprintf("| `%s` | %s | %s |", limpiar(caidas$capa), limpiar(caidas$servidor), limpiar(caidas$motivo)), "",
    "Se pide una sola feature por capa, o la cabecera si es un archivo: esto dice",
    "si el servicio está y la capa existe, no que los datos sigan siendo los mismos.", "")
}
if (nrow(fichas) > 0) {
  partes <- c(partes,
    sprintf("**%d capas responden, pero declaran una columna que no existe.**", nrow(fichas)), "",
    "| Capa | Columna declarada |", "|---|---|",
    sprintf("| `%s` | %s |", limpiar(fichas$capa), limpiar(fichas$columnas)), "",
    "Estas son nuestras y rompen `where_uy()`: el servicio responde bien, lo que",
    "está mal es lo que el metadata dice de él. Se comparan las columnas que la",
    "fila declara en `cod` y `name` contra el esquema que el servicio publica por",
    "`DescribeFeatureType`.", "")
}
if (length(partes) == 0) {
  partes <- sprintf("Las %d capas del metadata responden, y las columnas que declaran existen.", nrow(res))
}
writeLines(partes, con)
close(con)

# 2 es el hallazgo esperado: hay algo para avisar. Cualquier otro codigo distinto
# de cero significa que se rompio el chequeador, que es otra cosa y tiene que
# dejar el workflow en rojo.
quit(status = if (nrow(caidas) > 0 || nrow(fichas) > 0) 2L else 0L)
