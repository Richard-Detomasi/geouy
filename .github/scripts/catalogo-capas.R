# Mira que publican los organismos y avisa de lo que aparecio desde la corrida
# anterior. Es la contracara del chequeo semanal: aquel detecta que lo nuestro
# se rompa, este detecta que ellos sacaron algo nuevo.
#
# Va aparte de chequeo-capas.R a proposito. Son preguntas distintas, con
# salidas distintas, y sobre todo: si el catalogo falla, el chequeo de capas
# caidas tiene que seguir funcionando igual.
#
# Deliberadamente NO reporta "capas que ellos tienen y nosotros no". Eso da 72
# faltantes todas las semanas y muere a la primera. Reporta el diff contra la
# foto de la corrida anterior: lo que no estaba y ahora esta.
#
# Codigos de salida: 0 sin novedades, 2 hay algo nuevo, cualquier otro es que se
# rompio el script.

.comun <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  candidatos <- c(if (length(f)) file.path(dirname(normalizePath(f[1])), "comun.R"),
                  file.path(".github", "scripts", "comun.R"), "comun.R")
  hay <- candidatos[file.exists(candidatos)]
  if (!length(hay)) stop("No encuentro comun.R; se lo busco en: ",
                         paste(candidatos, collapse = ", "))
  hay[1]
}
source(.comun())

load("data/metadata.rda")

es_wfs <- function(url) grepl("request=GetFeature", url, ignore.case = TRUE)
# Con "&" y no "&&": aca se llama sobre la columna entera, no fila por fila.
es_archivo <- function(url, formato) formato %in% c("zip", "zip a") & !es_wfs(url)

# Vectorizada: se la llama tanto sobre una URL suelta como sobre la columna.
tipo_de_capa <- function(url) {
  tn <- rep(NA_character_, length(url))
  hay <- !is.na(url) & grepl("typenames?=", url, ignore.case = TRUE)
  if (any(hay)) {
    tn[hay] <- vapply(sub(".*[?&]typenames?=([^&#]*).*", "\\1", url[hay], ignore.case = TRUE),
                      utils::URLdecode, "", USE.NAMES = FALSE)
  }
  tn
}

# De que catalogo sale una capa WFS. La idea es mirar el workspace y no el
# servidor entero: el geoserver-vectorial del IDE publica 552 capas -catastro,
# cartografia nacional, todo- y el del MTOP 267. Una capa nueva ahi no tiene
# nada que ver con lo que hace el paquete y seria ruido todas las semanas. Los
# workspaces que usamos suman 207, y una capa nueva en INECenso si es del mismo
# tema que las que ya traemos.
#
# El workspace viene de dos lados segun el servidor:
#  - MIDES lo pone en el typeName ("INECenso:Secciones") y el servicio es global.
#  - IDE y MTOP lo ponen en la ruta. El del MTOP llega hasta la capa
#    (/geoserver/<workspace>/<capa>/ows), asi que hay que subir un escalon.
# ArcGIS (IGM) no tiene workspaces: cada servicio es su propio catalogo.
catalogo_de <- function(url) {
  base <- sub("\\?.*$", "", sub("^WFS:", "", url))
  # El metadata escribe el mismo servidor de dos formas -con :443 y sin- y son
  # el mismo catalogo. Sin normalizarlo se consultaba dos veces y la foto
  # guardaba 250 entradas repetidas.
  base <- sub("^(https)://([^/]+):443/", "\\1://\\2/", base)
  base <- sub("^(http)://([^/]+):80/", "\\1://\\2/", base)
  tn <- tipo_de_capa(url)
  prefijo <- if (!is.na(tn) && grepl(":", tn, fixed = TRUE)) sub(":.*$", "", tn) else NA_character_

  if (grepl("/arcgis/", base, ignore.case = TRUE)) {
    return(list(servicio = base, workspace = NA_character_, id = base, en_la_ruta = FALSE))
  }

  # El id se arma con la raiz del geoserver + el workspace, y NO con la URL
  # entera, porque el mismo catalogo se escribe de dos formas: unas filas piden
  # /geoserver/IDE/ows y otras /geoserver/ows con typeName "IDE:algo". Son las
  # mismas 119 capas. La raiz va incluida y no solo el servidor: un mismo host
  # puede tener /geoserver-vectorial y /geoserver-raster, y un workspace que se
  # llame igual en los dos no es el mismo catalogo.

  # Lo que hay entre /geoserver.../ y el /ows o /wfs final.
  m <- regmatches(base, regexec("^(.*/geoserver[^/]*)/(.*)/(ows|wfs)$", base, ignore.case = TRUE))[[1]]
  if (length(m) == 4) {
    ws <- strsplit(m[3], "/", fixed = TRUE)[[1]][1]
    return(list(servicio = paste0(m[2], "/", ws, "/", m[4]), workspace = ws,
                id = paste0(m[2], "|", ws), en_la_ruta = TRUE))
  }

  # Servicio global: el workspace sale del prefijo del typeName, si lo hay.
  raiz <- sub("/(ows|wfs)$", "", base, ignore.case = TRUE)
  list(servicio = base, workspace = prefijo, en_la_ruta = FALSE,
       id = if (is.na(prefijo)) base else paste0(raiz, "|", prefijo))
}

# Las capas que declara un GetCapabilities. Se pide 1.1.0 y no 2.0.0 a
# proposito: con 2.0.0 el geoserver del MIDES contesta una excepcion para todo
# el workspace porque una capa suelta -aulas_comunitarias- tiene el esquema
# roto, y se lleva puesta la consulta entera.
capas_publicadas <- function(servicio) {
  sep <- if (grepl("?", servicio, fixed = TRUE)) "&" else "?"
  r <- consultar(paste0(servicio, sep, "service=WFS&version=1.1.0&request=GetCapabilities"),
                 FALSE, tope = 8388608L)
  if (r$curl != 0L || !identical(r$codigo, "200")) return(NULL)
  if (grepl("ExceptionReport|ServiceException", r$texto, ignore.case = TRUE)) return(NULL)
  # El ArcGIS del IGM escribe <wfs:Name>; los geoserver, <Name> pelado.
  n <- regmatches(r$texto, gregexpr("<(?:[A-Za-z0-9_]+:)?Name>[^<]+</(?:[A-Za-z0-9_]+:)?Name>",
                                    r$texto, perl = TRUE))[[1]]
  if (!length(n)) return(NULL)
  n <- unique(sub("</[^>]*>$", "", sub("^<[^>]*>", "", n)))
  # El <Name> del servicio -"WFS"- y los de los operadores no son capas.
  n[nzchar(n) & !n %in% c("WFS", "wfs")]
}

# ---- Los catalogos que hay que mirar, sacados del metadata ------------------

wfs <- metadata[!is.na(metadata$url) & es_wfs(metadata$url), , drop = FALSE]
fuentes <- list()
for (u in unique(wfs$url)) {
  c1 <- catalogo_de(u)
  # Ante dos formas del mismo catalogo gana la que trae el workspace en la ruta:
  # el GetCapabilities acotado pesa 7 KB donde el global pesa 148.
  if (is.null(fuentes[[c1$id]]) || (c1$en_la_ruta && !fuentes[[c1$id]]$en_la_ruta)) {
    fuentes[[c1$id]] <- c1
  }
}

indices <- unique(directorio_de(metadata$url[!is.na(metadata$url) &
                                             es_archivo(metadata$url, metadata$formato)]))

# ---- Lo que se lee hoy ------------------------------------------------------

anterior <- NULL
if (file.exists("catalogo-capas.rds")) {
  # Una foto ilegible no es lo mismo que no tener foto, pero tratarla igual es
  # preferible a que el script muera: se rearma y se pierde una corrida.
  anterior <- tryCatch(readRDS("catalogo-capas.rds"), error = function(e) {
    message("La foto anterior no se pudo leer: ", conditionMessage(e))
    NULL
  })
}

visto <- list()
fallaron <- character()
sin_indice <- character()

for (f in fuentes) {
  capas <- capas_publicadas(f$servicio)
  if (!is.null(capas) && !is.na(f$workspace)) {
    # startsWith y no grep: un workspace con un punto o un corchete en el
    # nombre seria una expresion regular y no un prefijo literal.
    propias <- capas[startsWith(capas, paste0(f$workspace, ":"))]
    # Los servicios acotados al workspace tambien devuelven los nombres con
    # prefijo, asi que si el filtro no deja nada es que lo que vino no es el
    # catalogo que esperabamos. Vale mas darlo por lectura fallida que guardar
    # las 135 capas del servidor entero bajo el id de un workspace.
    capas <- if (length(propias)) propias else NULL
  }
  if (is.null(capas)) fallaron <- c(fallaron, f$id) else visto[[f$id]] <- capas
}

# De un indice de directorio solo interesan los archivos que el paquete podria
# llegar a bajar. El de MIDES lista 493 entradas y 83 son zip: seguir las otras
# 410 -xml y txt de acompanamiento- seria ruido garantizado.
for (i in indices) {
  r <- listado_del_indice(i)
  if (identical(r$estado, "sin indice")) {
    # No es una falla: ese directorio no publica listado y no lo va a publicar.
    sin_indice <- c(sin_indice, i)
    next
  }
  if (identical(r$estado, "sin respuesta")) {
    fallaron <- c(fallaron, i)
    next
  }
  visto[[i]] <- grep("\\.(zip|rar|7z)$", r$archivos, value = TRUE, ignore.case = TRUE)
}

# ---- La foto ----------------------------------------------------------------

# La foto NO es "lo que hay publicado hoy" sino "todo lo que vimos alguna vez":
# la union de la anterior con la de hoy. Asi ninguna lectura incompleta puede
# sacar entradas de la foto, que es justo lo que la semana siguiente las
# devolveria como novedad. Y de paso hace innecesario cualquier cuidado
# especial con las fuentes que fallan o que vuelven vacias: si no aportan nada,
# la foto queda como estaba.
#
# El precio es que una capa dada de baja se queda en la foto para siempre, y si
# vuelve no se avisa. Es barato: las bajas no son lo que esto reporta, de eso ya
# se ocupa el chequeo de capas caidas.
foto <- list()
for (id in union(names(anterior), names(visto))) {
  foto[[id]] <- sort(union(anterior[[id]], visto[[id]]))
}

# ---- El diff ----------------------------------------------------------------

usadas <- c(na.omit(tipo_de_capa(metadata$url)),
            basename(sub("[?#].*", "", metadata$url[es_archivo(metadata$url, metadata$formato)])))
sin_prefijo <- function(x) sub("^[^:]*:", "", x)
ya_la_tenemos <- function(x) sin_prefijo(x) %in% sin_prefijo(usadas)

novedades <- list()
if (!is.null(anterior)) {
  for (id in names(visto)) {
    if (is.null(anterior[[id]])) next   # fuente nueva: no es novedad del organismo
    nuevas <- setdiff(visto[[id]], anterior[[id]])
    if (length(nuevas)) novedades[[id]] <- nuevas
  }
}

con <- file("catalogo-capas.md", "w", encoding = "UTF-8")
w <- function(...) cat(..., "\n", sep = "", file = con)

if (is.null(anterior)) {
  w("Primera corrida del catálogo: se guardó la foto y no hay con qué comparar.")
  w("")
  w("Quedaron registradas ", length(unlist(foto)), " entradas en ", length(foto), " catálogos.")
} else if (!length(novedades)) {
  w("Sin novedades: los organismos no publicaron nada nuevo desde la corrida anterior.")
} else {
  w("Apareció esto desde la corrida anterior:")
  w("")
  for (id in names(novedades)) {
    w("**", id, "**")
    w("")
    for (x in novedades[[id]]) {
      w("- `", x, "`", if (ya_la_tenemos(x)) " — el paquete ya la usa" else "")
    }
    w("")
  }
  w("Esto es sólo lo que **apareció**: lo que el organismo publica y el paquete")
  w("no usa, si ya estaba en la foto anterior, no se repite.")
}

if (length(fallaron)) {
  w("")
  w("No contestaron, así que se arrastró lo que tenían la corrida anterior:")
  w("")
  for (x in fallaron) w("- `", x, "`")
}

if (length(sin_indice)) {
  w("")
  w("Estos directorios no publican listado, así que de ahí no se puede saber qué")
  w("hay. No es una caída: es cómo está configurado el servidor.")
  w("")
  for (x in sin_indice) w("- `", x, "`")
}
close(con)

# La huella de lo nuevo, para que el workflow no repita el mismo aviso cada
# semana. Vacia cuando no hay novedades.
estado <- unlist(lapply(names(novedades), function(id) paste0(id, "|", novedades[[id]])))
writeLines(sort(as.character(estado)), "catalogo-capas.estado")

# La foto se guarda al final a proposito. Si se guardara antes y el script se
# rompiera armando el informe, la novedad quedaria absorbida por la foto nueva y
# no se reportaria nunca.
saveRDS(foto, "catalogo-capas.rds")

cat(readLines("catalogo-capas.md"), sep = "\n")
cat("\n")
quit(status = if (length(novedades)) 2L else 0L)
