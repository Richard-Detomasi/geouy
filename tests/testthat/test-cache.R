# La cache de load_geouy(). Ninguno usa la red: bajar_capa() se reemplaza por
# una funcion que devuelve una capa chica y cuenta cuantas veces la llamaron. Y
# ninguno toca la cache del usuario: cada test usa una carpeta propia.

cache_de_prueba <- function() {
  carpeta <- tempfile("cache-")
  viejas <- options(geouy.cache_dir = carpeta, geouy.cache_days = NULL, geouy.cache = NULL)
  list(carpeta = carpeta,
       cerrar = function() {
         options(viejas)
         unlink(carpeta, recursive = TRUE)
       })
}

capa_chica <- function() {
  sf::st_sf(codigo = 1:2, nombre = c("a", "b"),
            geometry = sf::st_sfc(sf::st_point(c(500000, 6200000)),
                                  sf::st_point(c(510000, 6210000)), crs = 32721))
}

# La misma capa con otros datos, como si el servidor la hubiera actualizado.
capa_cambiada <- function() {
  a <- capa_chica()
  a$codigo <- 8:9
  a
}

bajar_falsa <- function(capa = capa_chica(), env = parent.frame()) {
  cuenta <- new.env()
  cuenta$n <- 0
  local_mocked_bindings(bajar_capa = function(x, folder, ...) {
    cuenta$n <- cuenta$n + 1
    capa
  }, .env = env)
  cuenta
}

no_se_puede_bajar <- function(env = parent.frame()) {
  local_mocked_bindings(bajar_capa = function(x, folder, ...) {
    stop("Could not read the layer from https://x.uy.", call. = FALSE)
  }, .env = env)
}

fila <- function(capa) geouy::metadata[geouy::metadata$capa == capa, ]

# Los dos archivos de la copia de una capa.
archivos_de <- function(capa) {
  ficha <- archivo_ficha(capa)
  list(ficha = ficha, datos = datos_de(ficha, leer_ficha(ficha)[["md5"]]))
}

# Cambia un campo de la ficha de una copia, como si se hubiera guardado asi.
cambiar_ficha <- function(capa, campo, valor) {
  archivo <- archivo_ficha(capa)
  ficha <- read.dcf(archivo, keep.white = con_espacios)[1, ]
  ficha[[campo]] <- valor
  write.dcf(t(ficha), archivo, keep.white = con_espacios, width = 1e4)
}

envejecer <- function(capa, dias) {
  cambiar_ficha(capa, "fecha",
                format(Sys.time() - dias * 86400, "%Y-%m-%d %H:%M:%S", tz = "UTC"))
}

# Como si la copia se hubiera guardado cuando el metadata definia la capa de
# otra manera -otra direccion, otro CRS-.
de_otra_version <- function(capa) cambiar_ficha(capa, "huella", strrep("0", 32))

test_that("sin cache no se lee ni se escribe nada", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  n <- bajar_falsa()
  load_geouy("Secciones")
  load_geouy("Secciones")
  expect_equal(n$n, 2)
  expect_false(dir.exists(p$carpeta))
  # Control: con cache, la misma llamada si deja la copia.
  load_geouy("Secciones", cache = TRUE)
  expect_true(all(file.exists(unlist(archivos_de("Secciones")))))
  # Y con la copia hecha, sin cache se sigue yendo al servidor.
  load_geouy("Secciones")
  expect_equal(n$n, 4)
})

test_that("la primera vez se baja y se guarda, y la segunda sale de la copia", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  n <- bajar_falsa()
  expect_silent(a <- load_geouy("Secciones", cache = TRUE))
  expect_equal(n$n, 1)
  expect_message(b <- load_geouy("Secciones", cache = TRUE),
                 "Using the copy of 'Secciones' saved on [0-9]{4}-[0-9]{2}-[0-9]{2}")
  expect_equal(n$n, 1)
  expect_identical(b, a)
  # Lo mismo que da sin cache.
  expect_identical(b, load_geouy("Secciones"))
  copias <- cache_geouy()
  expect_equal(names(copias), c("capa", "saved", "rows", "size_mb", "file"))
  expect_equal(copias$capa, "Secciones")
  expect_equal(copias$rows, 2L)
  expect_lt(abs(as.numeric(difftime(Sys.time(), copias$saved, units = "mins"))), 5)
})

test_that("la opcion geouy.cache prende la cache", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  n <- bajar_falsa()
  options(geouy.cache = TRUE)
  load_geouy("Secciones")
  suppressMessages(load_geouy("Secciones"))
  expect_equal(n$n, 1)
  # El argumento manda sobre la opcion.
  load_geouy("Secciones", cache = FALSE)
  expect_equal(n$n, 2)
})

test_that("con una copia vigente anda sin internet", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  # bajar_capa() es la de verdad: si se llegara a llamar, cortaria por la
  # conexion.
  local_mocked_bindings(has_internet = function() FALSE)
  guardar_copia(capa_chica(), fila("Secciones"))
  expect_message(a <- load_geouy("Secciones", cache = TRUE), "Using the copy")
  expect_equal(nrow(a), 2)
  # Control: sin cache, y con cache pero sin copia, corta por la conexion.
  expect_error(load_geouy("Secciones"), "No internet access")
  expect_error(load_geouy("Peajes", cache = TRUE), "No internet access")
})

test_that("con una copia vigente no hace falta la carpeta de los zip", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  guardar_copia(capa_chica(), fila("Deptos"))
  # Una carpeta que no existe no se crea, y un archivo en su lugar no molesta.
  carpeta <- file.path(tempfile(), "no", "existe")
  avisos <- 0
  withCallingHandlers(
    expect_message(load_geouy("Deptos", folder = carpeta, cache = TRUE), "Using the copy"),
    warning = function(w) {
      avisos <<- avisos + 1
      invokeRestart("muffleWarning")
    })
  expect_equal(avisos, 0)
  expect_false(dir.exists(carpeta))
  archivo <- tempfile()
  file.create(archivo)
  on.exit(unlink(archivo), add = TRUE)
  expect_message(load_geouy("Deptos", folder = archivo, cache = TRUE), "Using the copy")
  # Control: cuando hay que bajar, es el error de la carpeta, con y sin cache.
  expect_error(load_geouy("Deptos", folder = archivo), "valid directory")
  expect_error(load_geouy("Deptos", folder = archivo, cache = TRUE, refresh = TRUE),
               "valid directory")
})

test_that("cuando la cache baja un zip lo baja de verdad, aunque haya uno en la carpeta", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  carpeta <- tempfile()
  dir.create(carpeta)
  on.exit(unlink(carpeta, recursive = TRUE), add = TRUE)
  local_mocked_bindings(has_internet = function() TRUE)
  n <- 0
  # Lo que se baja no es un zip: alcanza para saber si se bajo o no.
  local_mocked_bindings(download.file = function(url, destfile, ...) {
    n <<- n + 1
    writeLines("no es un zip", destfile)
    0L
  })
  zip <- file.path(carpeta, "Deptos.zip")
  writeLines("un zip de antes", zip)
  expect_error(suppressWarnings(load_geouy("Deptos", folder = carpeta, cache = TRUE)),
               "not with a zip containing a shapefile")
  expect_equal(n, 1)
  writeLines("un zip de antes", zip)
  expect_error(suppressWarnings(
    load_geouy("Deptos", folder = carpeta, cache = TRUE, refresh = TRUE)),
    "not with a zip containing a shapefile")
  expect_equal(n, 2)
  # Control: sin cache, el zip que esta en la carpeta se usa sin bajar nada.
  writeLines("un zip de antes", zip)
  expect_error(suppressWarnings(load_geouy("Deptos", folder = carpeta)),
               "not with a zip containing a shapefile")
  expect_equal(n, 2)
})

test_that("una copia vieja se renueva", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  n <- bajar_falsa()
  load_geouy("Secciones", cache = TRUE)
  envejecer("Secciones", 31)
  # Sin mensaje: no se uso la copia.
  expect_silent(load_geouy("Secciones", cache = TRUE))
  expect_equal(n$n, 2)
  expect_lt(dias_de_la_copia(ficha_copia(fila("Secciones"))), 1)
  # Los dias se pueden cambiar, y con Inf la copia vale siempre.
  envejecer("Secciones", 10)
  options(geouy.cache_days = 7)
  expect_silent(load_geouy("Secciones", cache = TRUE))
  expect_equal(n$n, 3)
  envejecer("Secciones", 4000)
  options(geouy.cache_days = Inf)
  expect_message(load_geouy("Secciones", cache = TRUE), "Using the copy")
  expect_equal(n$n, 3)
})

test_that("si no se puede renovar, se usa la copia vieja y el aviso dice por que", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  bajar_falsa()
  load_geouy("Secciones", cache = TRUE)
  envejecer("Secciones", 31)
  no_se_puede_bajar()
  avisos <- character()
  a <- withCallingHandlers(
    load_geouy("Secciones", cache = TRUE),
    warning = function(w) {
      avisos <<- c(avisos, conditionMessage(w))
      invokeRestart("muffleWarning")
    })
  expect_equal(nrow(a), 2)
  expect_length(avisos, 1)
  expect_match(avisos, "'Secciones' could not be downloaded, so the copy saved on [0-9-]+ is used")
  expect_match(avisos, "Could not read the layer from https://x.uy.", fixed = TRUE)
  # La copia vieja sigue ahi para la proxima.
  expect_equal(cache_geouy()$capa, "Secciones")
  # Control: sin copia, el mismo fallo es el error de siempre.
  expect_error(load_geouy("Peajes", cache = TRUE), "Could not read the layer from")
})

test_that("refresh = TRUE baja siempre; si falla es un error y la copia queda", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  n <- bajar_falsa()
  load_geouy("Secciones", cache = TRUE)
  expect_silent(load_geouy("Secciones", cache = TRUE, refresh = TRUE))
  expect_equal(n$n, 2)
  antes <- archivos_de("Secciones")
  no_se_puede_bajar()
  expect_error(load_geouy("Secciones", cache = TRUE, refresh = TRUE),
               "Could not read the layer from")
  expect_identical(archivos_de("Secciones"), antes)
  expect_message(load_geouy("Secciones", cache = TRUE), "Using the copy")
})

test_that("al renovar no quedan los datos de antes", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  bajar_falsa()
  load_geouy("Secciones", cache = TRUE)
  antes <- archivos_de("Secciones")
  # La capa no cambio: mismos datos, y la ficha con la fecha nueva.
  envejecer("Secciones", 5)
  load_geouy("Secciones", cache = TRUE, refresh = TRUE)
  expect_identical(archivos_de("Secciones"), antes)
  expect_lt(dias_de_la_copia(ficha_copia(fila("Secciones"))), 1)
  # La capa cambio: datos nuevos con otro nombre, y los anteriores se van.
  bajar_falsa(capa_cambiada())
  load_geouy("Secciones", cache = TRUE, refresh = TRUE)
  expect_false(identical(archivos_de("Secciones")$datos, antes$datos))
  expect_false(file.exists(antes$datos))
  expect_length(list.files(p$carpeta), 2)
  expect_equal(suppressMessages(load_geouy("Secciones", cache = TRUE))$codigo, 8:9)
})

test_that("si guardar se corta a mitad de camino, la copia anterior sigue sirviendo", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  bajar_falsa()
  load_geouy("Secciones", cache = TRUE)
  bajar_falsa(capa_cambiada())
  # El primer rename anda -los datos nuevos- y el segundo no -la ficha-.
  veces <- 0
  local_mocked_bindings(renombrar = function(de, a) {
    veces <<- veces + 1
    if (veces == 1) file.rename(de, a) else FALSE
  })
  expect_warning(b <- load_geouy("Secciones", cache = TRUE, refresh = TRUE),
                 "could not be saved")
  expect_equal(veces, 2)
  expect_equal(b$codigo, 8:9)
  # El servidor se cae: el respaldo es la copia de antes, entera.
  envejecer("Secciones", 31)
  no_se_puede_bajar()
  expect_warning(a <- load_geouy("Secciones", cache = TRUE), "copy saved on")
  expect_equal(a$codigo, 1:2)
})

test_that("si la suma de los datos nuevos no se puede calcular, no se guarda y queda la anterior", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  bajar_falsa()
  load_geouy("Secciones", cache = TRUE)
  antes <- archivos_de("Secciones")
  bajar_falsa(capa_cambiada())
  # tools::md5sum() devuelve NA cuando no puede leer el archivo.
  with_mocked_bindings(
    expect_warning(b <- load_geouy("Secciones", cache = TRUE, refresh = TRUE),
                   "could not be saved"),
    suma_md5 = function(archivo) NA_character_)
  expect_equal(b$codigo, 8:9)
  expect_identical(archivos_de("Secciones"), antes)
  expect_setequal(list.files(p$carpeta), basename(unlist(antes)))
  expect_equal(suppressMessages(load_geouy("Secciones", cache = TRUE))$codigo, 1:2)
})

test_that("unos datos que no son los de la ficha no se usan", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  n <- bajar_falsa()
  load_geouy("Secciones", cache = TRUE)
  # Otro sf en el lugar de los datos: se lee sin problema, pero no es lo que se
  # guardo.
  saveRDS(capa_cambiada(), archivos_de("Secciones")$datos)
  expect_silent(a <- load_geouy("Secciones", cache = TRUE))
  expect_equal(a$codigo, 1:2)
  expect_equal(n$n, 2)
  # Un archivo danado tampoco.
  writeBin(as.raw(1:10), archivos_de("Secciones")$datos)
  expect_silent(a <- load_geouy("Secciones", cache = TRUE))
  expect_equal(a$codigo, 1:2)
  expect_equal(n$n, 3)
  # Y la copia quedo rehecha.
  expect_message(load_geouy("Secciones", cache = TRUE), "Using the copy")
  expect_equal(n$n, 3)
})

test_that("un RDS que no es una capa no se usa, aunque la suma coincida", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  x <- fila("Secciones")
  guardar_copia(capa_chica(), x)
  falso <- tempfile()
  on.exit(unlink(falso), add = TRUE)
  saveRDS(1:3, falso)
  file.copy(falso, datos_de(archivo_ficha("Secciones"), suma_md5(falso)))
  cambiar_ficha("Secciones", "md5", suma_md5(falso))
  expect_false(is.null(ficha_copia(x)))
  expect_null(datos_copia(x, ficha_copia(x)))
  n <- bajar_falsa()
  expect_silent(a <- load_geouy("Secciones", cache = TRUE))
  expect_s3_class(a, "sf")
  expect_equal(n$n, 1)
})

test_that("una suma que no tiene forma de suma invalida la ficha", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  x <- fila("Secciones")
  guardar_copia(capa_chica(), x)
  # Va a parar al nombre de un archivo: no puede sacar la lectura de la carpeta.
  cambiar_ficha("Secciones", "md5", "../../otro")
  expect_null(leer_ficha(archivo_ficha("Secciones")))
  expect_null(ficha_copia(x))
  expect_equal(nrow(cache_geouy()), 0)
})

test_that("la copia vale solo para la capa como la define hoy el metadata", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  n <- bajar_falsa()
  load_geouy("Secciones", cache = TRUE)
  de_otra_version("Secciones")
  expect_silent(load_geouy("Secciones", cache = TRUE))
  expect_equal(n$n, 2)
  expect_false(is.null(ficha_copia(fila("Secciones"))))
  # Tampoco sirve de respaldo cuando no se puede bajar, ni siquiera vigente.
  de_otra_version("Secciones")
  with_mocked_bindings(
    expect_error(load_geouy("Secciones", cache = TRUE), "Could not read the layer from"),
    bajar_capa = function(x, folder, ...) {
      stop("Could not read the layer from https://x.uy.", call. = FALSE)
    })
  # Leer no la borra; se va cuando se guarda otra capa.
  expect_equal(cache_geouy()$capa, "Secciones")
  load_geouy("Peajes", cache = TRUE)
  expect_equal(cache_geouy()$capa, "Peajes")
})

test_that("la huella cambia con todo lo que define a la capa en el metadata", {
  x <- fila("Secciones")
  h <- huella_capa(x)
  expect_match(h, "^[0-9a-f]{32}$")
  expect_identical(huella_capa(x), h)
  for (campo in c("url", "crs", "formato", "enc", "cod", "name")) {
    y <- x
    y[[campo]] <- if (is.numeric(y[[campo]])) y[[campo]] + 1 else paste0(y[[campo]], "x")
    expect_false(identical(huella_capa(y), h), info = campo)
  }
  # Solo "Calles" junta varias capas, y sus partes tienen fila propia, que
  # tambien cuenta para la huella. Son las dos capas que pide su direccion.
  partes <- partes_de(fila("Calles"))
  expect_equal(nrow(partes), 2)
  expect_setequal(sub(".*typeName=", "", partes$url),
                  strsplit(sub(".*typeName=", "", fila("Calles")$url), ",")[[1]])
  expect_false("Calles" %in% partes$capa)
  sin_partes <- with_mocked_bindings(huella_capa(fila("Calles")),
                                     partes_de = function(x) geouy::metadata[0, ])
  expect_false(identical(huella_capa(fila("Calles")), sin_partes))
  expect_equal(nrow(partes_de(x)), 0)
  expect_equal(nrow(partes_de(fila("Deptos"))), 0)
})

test_that("leer una copia que no sirve no borra nada", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  x <- fila("Secciones")
  guardar_copia(capa_chica(), x)
  f <- archivos_de("Secciones")
  saveRDS(capa_cambiada(), f$datos)
  expect_null(datos_copia(x, ficha_copia(x)))
  expect_true(all(file.exists(unlist(f))))
  de_otra_version("Secciones")
  expect_null(ficha_copia(x))
  writeLines("esto no es una ficha", f$ficha)
  expect_null(ficha_copia(x))
  expect_true(all(file.exists(unlist(f))))
})

test_that("si otra sesion renueva la copia en el medio, es como si no hubiera copia", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  x <- fila("Secciones")
  guardar_copia(capa_chica(), x)
  ficha <- ficha_copia(x)
  # Los datos se van despues de comprobar la suma y antes de leerlos.
  unlink(archivos_de("Secciones")$datos)
  local_mocked_bindings(suma_md5 = function(archivo) ficha[["md5"]])
  expect_silent(datos <- datos_copia(x, ficha))
  expect_null(datos)
})

test_that("una capa sin filas no se guarda", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  bajar_falsa(capa_chica()[0, ])
  a <- load_geouy("Secciones", cache = TRUE)
  expect_equal(nrow(a), 0)
  expect_equal(nrow(cache_geouy()), 0)
})

test_that("una capa que junta varias no se guarda si una de sus partes vino vacia", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  x <- fila("Calles")
  partes <- partes_de(x)$capa
  # unir_capas() anota en la columna capa de que parte sale cada fila.
  completa <- capa_chica()
  completa$capa <- partes
  falta_una <- completa
  falta_una$capa <- partes[1]
  expect_false(guardar_copia(falta_una, x))
  expect_false(guardar_copia(capa_chica(), x))
  expect_equal(nrow(cache_geouy()), 0)
  expect_true(guardar_copia(completa, x))
  expect_equal(cache_geouy()$capa, "Calles")
})

test_that("si la copia no se puede guardar, la capa se devuelve igual, con un aviso", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  bajar_falsa()
  # Un rename que falla: no quedan archivos a medias.
  local_mocked_bindings(renombrar = function(de, a) FALSE)
  expect_warning(a <- load_geouy("Secciones", cache = TRUE),
                 "'Secciones' was loaded, but its copy could not be saved")
  expect_equal(nrow(a), 2)
  expect_length(list.files(p$carpeta), 0)
  # La carpeta de la cache es un archivo.
  unlink(p$carpeta, recursive = TRUE)
  file.create(p$carpeta)
  expect_warning(a <- load_geouy("Secciones", cache = TRUE), "could not be saved")
  expect_equal(nrow(a), 2)
})

test_that("las columnas de cualquier tipo vuelven de la copia como se guardaron", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  rara <- capa_chica()
  rara$dia <- as.Date(c("2020-01-01", NA))
  rara$hora <- as.POSIXct(c("2020-01-01 10:00:00", "2021-05-05 05:05:05"),
                          tz = "America/Montevideo")
  rara$clase <- factor(c("a", "b"), levels = c("b", "a"))
  rara$lista <- list(1:3, "x")
  rara$logico <- c(TRUE, NA)
  rara$real <- c(0.1 + 0.2, NA)
  bajar_falsa(rara)
  a <- load_geouy("Secciones", cache = TRUE)
  expect_message(b <- load_geouy("Secciones", cache = TRUE), "Using the copy")
  expect_identical(b, a)
  expect_identical(b, load_geouy("Secciones"))
  expect_identical(datos_copia(fila("Secciones"), ficha_copia(fila("Secciones"))), rara)
})

test_that("cache_geouy() lista y clear_cache_geouy() borra solo lo que guardo load_geouy()", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  expect_equal(nrow(cache_geouy()), 0)
  expect_length(clear_cache_geouy(), 0)
  bajar_falsa()
  load_geouy("Secciones", cache = TRUE)
  load_geouy("Peajes", cache = TRUE)
  # Archivos del usuario en la misma carpeta, uno con nombre parecido.
  saveRDS(1, file.path(p$carpeta, "Secciones.rds"))
  writeLines("mias", file.path(p$carpeta, "notas.txt"))
  copias <- cache_geouy()
  expect_equal(copias$capa, c("Peajes", "Secciones"))
  expect_true(all(file.exists(copias$file)))
  # Un nombre que no esta, o ninguno, no borra nada.
  expect_equal(clear_cache_geouy("No existe"), character())
  expect_equal(clear_cache_geouy(character()), character())
  expect_equal(nrow(cache_geouy()), 2)
  expect_equal(clear_cache_geouy("Peajes"), "Peajes")
  expect_equal(cache_geouy()$capa, "Secciones")
  expect_equal(clear_cache_geouy(), "Secciones")
  expect_equal(nrow(cache_geouy()), 0)
  expect_setequal(list.files(p$carpeta), c("Secciones.rds", "notas.txt"))
  expect_error(clear_cache_geouy(1), "names of the layers")
})

test_that("clear_cache_geouy() saca una copia aunque tenga la ficha rota o le falten los datos", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  bajar_falsa()
  for (capa in c("Secciones", "Secciones11", "Peajes", "Rutas")) load_geouy(capa, cache = TRUE)
  writeLines("esto no es una ficha", archivo_ficha("Secciones"))
  unlink(archivos_de("Peajes")$datos)
  # El inventario no lista ninguna de las dos.
  expect_equal(cache_geouy()$capa, c("Rutas", "Secciones11"))
  expect_setequal(clear_cache_geouy(c("Secciones", "Peajes", "Secciones")),
                  c("Secciones", "Peajes"))
  # Se fueron sus archivos y nada mas: "Secciones11" empieza igual que "Secciones".
  expect_equal(cache_geouy()$capa, c("Rutas", "Secciones11"))
  expect_length(list.files(p$carpeta), 4)
})

test_that("una carpeta con comodines en el nombre no hace borrar en otra", {
  raiz <- tempfile("comodines-")
  dir.create(raiz)
  on.exit(unlink(raiz, recursive = TRUE), add = TRUE)
  # Para unlink(), "cache[1]" como patron es la carpeta "cache1".
  otra <- file.path(raiz, "cache1")
  viejas <- options(geouy.cache_dir = otra, geouy.cache_days = NULL, geouy.cache = NULL)
  on.exit(options(viejas), add = TRUE)
  bajar_falsa()
  load_geouy("Secciones", cache = TRUE)
  en_la_otra <- list.files(otra)
  options(geouy.cache_dir = file.path(raiz, "cache[1]"))
  load_geouy("Secciones", cache = TRUE)
  load_geouy("Secciones", cache = TRUE, refresh = TRUE)
  expect_equal(clear_cache_geouy("Secciones"), "Secciones")
  load_geouy("Secciones", cache = TRUE)
  expect_equal(clear_cache_geouy(), "Secciones")
  expect_length(list.files(file.path(raiz, "cache[1]")), 0)
  expect_identical(list.files(otra), en_la_otra)
})

test_that("clear_cache_geouy() dice lo que borro, no lo que quiso borrar", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  skip_on_os("windows")
  bajar_falsa()
  load_geouy("Secciones", cache = TRUE)
  Sys.chmod(p$carpeta, "0555")
  on.exit(Sys.chmod(p$carpeta, "0755"), add = TRUE)
  # Como root se puede borrar igual, y el test no probaria nada.
  skip_if(file.access(p$carpeta, 2) == 0, "se puede escribir en la carpeta igual")
  expect_equal(clear_cache_geouy(), character())
  expect_equal(clear_cache_geouy("Secciones"), character())
  expect_equal(cache_geouy()$capa, "Secciones")
})

test_that("crs y make_valid se aplican a la copia igual que a la capa bajada", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  # Un poligono que se cruza a si mismo, como los que publican los servidores.
  m <- rbind(c(0, 0), c(1000, 1000), c(1000, 0), c(0, 1000), c(0, 0))
  m[, 1] <- m[, 1] + 500000
  m[, 2] <- m[, 2] + 6200000
  cruzado <- sf::st_sf(codigo = 1L, geometry = sf::st_sfc(sf::st_polygon(list(m)), crs = 32721))
  n <- bajar_falsa(cruzado)
  suppressMessages(load_geouy("Secciones", cache = TRUE))
  mensajes <- character()
  b <- withCallingHandlers(
    load_geouy("Secciones", cache = TRUE, crs = 4326),
    message = function(msj) {
      mensajes <<- c(mensajes, conditionMessage(msj))
      invokeRestart("muffleMessage")
    })
  expect_true(any(grepl("were invalid as published and were repaired", mensajes)))
  expect_equal(sf::st_crs(b)$epsg, 4326L)
  expect_true(all(sf::st_is_valid(b)))
  # La copia guarda lo publicado: sin reparar, sale como vino.
  suppressMessages(d <- load_geouy("Secciones", cache = TRUE, make_valid = FALSE))
  expect_false(any(sf::st_is_valid(d)))
  expect_equal(sf::st_crs(d)$epsg, 32721L)
  expect_equal(n$n, 1)
})

test_that("los argumentos y las opciones que no tienen sentido dan un error que los nombra", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  n <- bajar_falsa()
  expect_error(load_geouy("Secciones", cache = "si"), "cache must be TRUE or FALSE")
  expect_error(load_geouy("Secciones", cache = NA), "cache must be TRUE or FALSE")
  expect_error(load_geouy("Secciones", cache = TRUE, refresh = 1), "refresh must be TRUE or FALSE")
  # refresh se valida aunque sin cache no tenga efecto.
  expect_error(load_geouy("Secciones", refresh = NA), "refresh must be TRUE or FALSE")
  options(geouy.cache_days = "treinta")
  expect_error(load_geouy("Secciones", cache = TRUE), "geouy.cache_days")
  options(geouy.cache_days = -1)
  expect_error(load_geouy("Secciones", cache = TRUE), "geouy.cache_days")
  options(geouy.cache_days = NULL, geouy.cache_dir = 3)
  expect_error(load_geouy("Secciones", cache = TRUE), "geouy.cache_dir")
  expect_error(cache_geouy(), "geouy.cache_dir")
  expect_equal(n$n, 0)
  # Sin cache esas opciones no se miran.
  expect_silent(load_geouy("Secciones"))
  expect_silent(load_geouy("Secciones", refresh = TRUE))
  expect_equal(n$n, 2)
})

test_that("cada capa del metadata tiene su archivo, y su ficha vuelve igual", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  md <- geouy::metadata
  archivos <- vapply(md$capa, archivo_ficha, character(1))
  expect_equal(anyDuplicated(archivos), 0)
  for (i in seq_len(nrow(md))) {
    # La columna capa es para las que juntan varias, que si no no se guardan.
    a <- capa_chica()
    partes <- partes_de(md[i, ])$capa
    if (length(partes)) a$capa <- partes
    guardar_copia(a, md[i, ])
    expect_false(is.null(ficha_copia(md[i, ])), info = md$capa[i])
    expect_identical(leer_ficha(archivo_ficha(md$capa[i]))[["url"]], md$url[i])
  }
  expect_equal(nrow(cache_geouy()), nrow(md))
  # Una direccion con espacios seguidos, que DCF juntaria si no se le avisa.
  # Sin podar: esa direccion no es la del metadata, y la poda se la llevaria.
  rara <- md[1, ]
  rara$url <- "https://x.uy/ows?filtro=uno  dos"
  with_mocked_bindings(guardar_copia(capa_chica(), rara),
                       podar_cache = function(...) invisible(character()))
  expect_identical(leer_ficha(archivo_ficha(rara$capa))[["url"]], rara$url)
})

test_that("las copias de capas que ya no estan en el metadata se sacan al guardar", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  vieja <- fila("Secciones")
  vieja$capa <- "Capa dada de baja"
  # Sin podar, para poder dejarla; despues se guarda otra con la poda de verdad.
  with_mocked_bindings(guardar_copia(capa_chica(), vieja),
                       podar_cache = function(...) invisible(character()))
  expect_equal(cache_geouy()$capa, "Capa dada de baja")
  guardar_copia(capa_chica(), fila("Secciones"))
  expect_equal(cache_geouy()$capa, "Secciones")
  expect_length(list.files(p$carpeta), 2)
})

test_that("la primera vez que se usa una carpeta en la sesion tambien se poda", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  vieja <- fila("Peajes")
  vieja$capa <- "Capa dada de baja"
  with_mocked_bindings({
    guardar_copia(capa_chica(), vieja)
    guardar_copia(capa_chica(), fila("Secciones"))
  }, podar_cache = function(...) invisible(character()))
  expect_equal(nrow(cache_geouy()), 2)
  # Sale de la copia: no se guarda nada, y la poda corre igual.
  bajar_falsa()
  expect_message(load_geouy("Secciones", cache = TRUE), "Using the copy")
  expect_equal(cache_geouy()$capa, "Secciones")
})

test_that("la poda del primer uso es por carpeta, aunque dos se nombren igual", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  aca <- getwd()
  on.exit(setwd(aca), add = TRUE)
  # La misma ruta relativa en dos proyectos son dos carpetas.
  options(geouy.cache_dir = "cache")
  vieja <- fila("Peajes")
  vieja$capa <- "Capa dada de baja"
  bajar_falsa()
  for (proyecto in c(tempfile("proyecto-"), tempfile("proyecto-"))) {
    dir.create(proyecto)
    on.exit(unlink(proyecto, recursive = TRUE), add = TRUE)
    setwd(proyecto)
    with_mocked_bindings({
      guardar_copia(capa_chica(), vieja)
      guardar_copia(capa_chica(), fila("Secciones"))
    }, podar_cache = function(...) invisible(character()))
    expect_equal(nrow(cache_geouy()), 2)
    expect_message(load_geouy("Secciones", cache = TRUE), "Using the copy")
    expect_equal(cache_geouy()$capa, "Secciones", info = proyecto)
  }
})

test_that("si la huella de una capa no se puede calcular, la poda no saca su copia", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  n <- bajar_falsa()
  load_geouy("Secciones", cache = TRUE)
  antes <- list.files(p$carpeta)
  # tools::md5sum() devuelve NA cuando no puede leer el archivo, y la huella
  # sale de ahi.
  with_mocked_bindings(expect_equal(podar_cache(), character()),
                       suma_md5 = function(archivo) NA_character_)
  expect_identical(list.files(p$carpeta), antes)
  expect_message(load_geouy("Secciones", cache = TRUE), "Using the copy")
  expect_equal(n$n, 1)
})

test_that("lo que deja una escritura cortada se saca, pero no antes de un dia", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  dir.create(p$carpeta)
  en <- function(nombre) file.path(p$carpeta, nombre)
  suma <- strrep("a", 32)
  viejos <- en(c("Peajes.nueva.geouy.rds.123.parcial", paste0("Rutas.", suma, ".geouy.rds"),
                 "Zonas.geouy.dcf"))
  recien <- en(c("Deptos.geouy.dcf.456.parcial", paste0("Uruguay.", suma, ".geouy.rds")))
  ajenos <- en(c("Peajes.rds", "notas.txt", "copia.geouy.rds.bak"))
  for (archivo in c(viejos, recien, ajenos)) writeLines("x", archivo)
  hace_dos_dias <- Sys.time() - 2 * 86400
  Sys.setFileTime(c(viejos, ajenos), hace_dos_dias)
  guardar_copia(capa_chica(), fila("Secciones"))
  expect_false(any(file.exists(viejos)))
  expect_true(all(file.exists(recien)))
  expect_true(all(file.exists(ajenos)))
  expect_equal(cache_geouy()$capa, "Secciones")
  # Borrar una capa no toca lo demas; borrar todo se lleva tambien lo reciente,
  # y nunca lo ajeno.
  clear_cache_geouy("Secciones")
  expect_true(all(file.exists(recien)))
  clear_cache_geouy()
  expect_false(any(file.exists(recien)))
  expect_true(all(file.exists(ajenos)))
})

test_that("unos datos sueltos o una ficha que no se puede leer no cortan la carga", {
  p <- cache_de_prueba()
  on.exit(p$cerrar(), add = TRUE)
  n <- bajar_falsa()
  dir.create(p$carpeta)
  writeLines("esto no es una ficha", file.path(p$carpeta, "Secciones.geouy.dcf"))
  writeLines("ni esto", file.path(p$carpeta, "Peajes.geouy.dcf"))
  writeLines("datos sin ficha", datos_de(archivo_ficha("Rutas"), strrep("b", 32)))
  expect_silent(a <- load_geouy("Secciones", cache = TRUE))
  expect_equal(nrow(a), 2)
  expect_silent(load_geouy("Rutas", cache = TRUE))
  expect_equal(cache_geouy()$capa, c("Rutas", "Secciones"))
  expect_message(load_geouy("Secciones", cache = TRUE), "Using the copy")
  expect_message(load_geouy("Rutas", cache = TRUE), "Using the copy")
  expect_equal(n$n, 2)
})

test_that("por omision la carpeta es la de cache del usuario que define R", {
  viejas <- options(geouy.cache_dir = NULL)
  on.exit(options(viejas), add = TRUE)
  expect_equal(carpeta_cache(), tools::R_user_dir("geouy", "cache"))
})
