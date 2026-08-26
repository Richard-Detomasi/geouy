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

endpoint <- function(url, repositor) {
  # Las capas del SGM no traen URL: el campo guarda el nombre de la capa y la URL
  # la arma load_geouy(). Se pide la capa concreta y no el GetCapabilities, porque
  # si no las tres darian OK con que el servidor este vivo.
  if (identical(repositor, "SGM")) {
    return(paste0("http://geoservicios.sgm.gub.uy/wfsPCN1000.cgi",
                  "?service=WFS&version=1.0.0&request=GetFeature",
                  "&typeName=", utils::URLencode(url, reserved = TRUE),
                  "&maxFeatures=1"))
  }
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

consultar <- function(url, solo_cabecera) {
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
  n <- suppressWarnings(min(file.info(cuerpo)$size, 65536L))
  texto <- if (!is.na(n) && n > 0) readChar(cuerpo, n, useBytes = TRUE) else ""
  list(codigo = p[1], bytes = as.numeric(p[2]),
       url = paste(p[-(1:2)], collapse = ":"), curl = 0L, texto = texto)
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

filas <- vector("list", nrow(metadata))
for (i in seq_len(nrow(metadata))) {
  capa <- metadata$capa[i]
  url  <- endpoint(metadata$url[i], metadata$repositor[i])
  if (is.na(url)) {
    filas[[i]] <- data.frame(capa = capa, servidor = "-", motivo = "URL invalida en el metadata", ok = FALSE)
    cat(sprintf("%-5s %-32s %s\n", "FALLA", capa, "URL invalida")); next
  }
  cab <- es_archivo(metadata$url[i], metadata$formato[i])
  r <- consultar(url, cab)
  motivo <- clasificar(r, cab)
  filas[[i]] <- data.frame(capa = capa, servidor = sub("^(https?://[^/?]+).*", "\\1", r$url),
                           motivo = motivo, ok = motivo == "ok")
  cat(sprintf("%-5s %-32s %s\n", if (motivo == "ok") "ok" else "FALLA", capa, motivo))
}
res <- do.call(rbind, filas)
caidas <- res[!res$ok, ]
cat("\n==== ", nrow(res) - nrow(caidas), " de ", nrow(res), " capas responden ====\n", sep = "")

saveRDS(res, "chequeo-capas.rds")
# Una huella de QUE esta caido, sin fecha: el workflow la usa para no repetir el
# mismo aviso cada semana cuando no cambio nada.
writeLines(sort(sprintf("%s\t%s", caidas$capa, caidas$motivo)), "chequeo-capas.estado")

con <- file("chequeo-capas.md", "w", encoding = "UTF-8")
if (nrow(caidas) == 0) {
  writeLines(sprintf("Las %d capas del metadata responden.", nrow(res)), con)
} else {
  limpiar <- function(x) gsub("[|`\r\n]", " ", x)
  writeLines(c(
    sprintf("**%d de %d capas no responden.**", nrow(caidas), nrow(res)), "",
    "| Capa | Servidor | Qué pasa |", "|---|---|---|",
    sprintf("| `%s` | %s | %s |", limpiar(caidas$capa), limpiar(caidas$servidor), limpiar(caidas$motivo)), "",
    "Se pide una sola feature por capa, o la cabecera si es un archivo: esto dice",
    "si el servicio está y la capa existe, no que los datos sigan siendo los mismos."), con)
}
close(con)

# 2 es el hallazgo esperado, o sea que hay capas caidas. Cualquier otro codigo
# distinto de cero significa que se rompio el chequeador, que es otra cosa y tiene
# que dejar el workflow en rojo.
quit(status = if (nrow(caidas) > 0) 2L else 0L)
