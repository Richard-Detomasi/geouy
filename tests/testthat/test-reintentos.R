# Los reintentos de lo que se baja de la red (#27). Ninguno usa la red ni
# espera: el intento es una funcion armada a mano, y esperar() se reemplaza por
# una que anota cuanto se habria esperado.

# Fuera de R CMD check son tres intentos; adentro, uno. Los tests fijan los tres
# para dar lo mismo en los dos casos.
tres_intentos <- function(env = parent.frame()) {
  local_mocked_bindings(intentos_por_omision = function() 3L, .env = env)
}

falla_500 <- function() {
  warning("GDAL Error 1: HTTP error code : 500")
  stop("Cannot open \"WFS:https://x.uy/ows\"; Check connection parameters.")
}

test_that("lo que anda a la primera se pide una sola vez, sin mensajes ni esperas", {
  tres_intentos()
  esperas <- numeric()
  local_mocked_bindings(esperar = function(s) esperas <<- c(esperas, s))
  n <- 0
  expect_silent(r <- con_reintentos(function() { n <<- n + 1; "ok" }, "Prueba", "https://x.uy/ows"))
  expect_equal(r, "ok")
  expect_equal(n, 1)
  expect_length(esperas, 0)
})

test_that("un fallo de un momento se reintenta, con un mensaje antes de cada intento", {
  tres_intentos()
  esperas <- numeric()
  local_mocked_bindings(esperar = function(s) esperas <<- c(esperas, s))
  n <- 0
  intento <- function() { n <<- n + 1; if (n < 3) falla_500() else "ok" }
  mensajes <- character()
  avisos <- character()
  r <- withCallingHandlers(
    con_reintentos(intento, "Prueba", "https://x.uy/ows"),
    message = function(m) { mensajes <<- c(mensajes, conditionMessage(m)); invokeRestart("muffleMessage") },
    warning = function(w) { avisos <<- c(avisos, conditionMessage(w)); invokeRestart("muffleWarning") })
  expect_equal(r, "ok")
  expect_equal(n, 3)
  expect_equal(esperas, c(5, 10))
  expect_match(mensajes[1], "Attempt 1 of 3 to read the layer 'Prueba' failed; retrying in 5 seconds")
  expect_match(mensajes[2], "Attempt 2 of 3")
  # Los avisos de GDAL de los intentos que fallaron no llegan al usuario.
  expect_length(avisos, 0)
})

test_that("si sigue fallando, el error dice cuantos intentos se hicieron", {
  tres_intentos()
  esperas <- numeric()
  local_mocked_bindings(esperar = function(s) esperas <<- c(esperas, s))
  n <- 0
  expect_error(
    suppressMessages(con_reintentos(function() { n <<- n + 1; falla_500() },
                                    "Prueba", "https://x.uy/ows")),
    "Could not read the layer 'Prueba' from https://x.uy after 3 attempts")
  expect_equal(n, 3)
  expect_equal(esperas, c(5, 10))
})

test_that("lo que esperar no arregla no se reintenta", {
  tres_intentos()
  esperas <- numeric()
  local_mocked_bindings(esperar = function(s) esperas <<- c(esperas, s))
  for (causa in c("GDAL Error 1: HTTP error code : 404",
                  "HTTP status was '400 Bad Request'",
                  "GDAL Error 1: SSL certificate problem: certificate has expired",
                  "cannot open destfile '/x/y.zip', reason 'Permission denied'")) {
    n <- 0
    intento <- function() { n <<- n + 1; warning(causa); stop("Cannot open.") }
    expect_error(con_reintentos(intento, "Prueba", "https://x.uy/ows"), causa, fixed = TRUE)
    expect_equal(n, 1, info = causa)
  }
  expect_length(esperas, 0)
})

test_that("los avisos del intento que anda siguen saliendo", {
  tres_intentos()
  local_mocked_bindings(esperar = function(s) NULL)
  n <- 0
  intento <- function() {
    n <<- n + 1
    if (n == 1) falla_500()
    warning("aviso del intento que anduvo")
    "ok"
  }
  expect_warning(r <- suppressMessages(con_reintentos(intento, "Prueba", "https://x.uy/ows")),
                 "aviso del intento que anduvo")
  expect_equal(r, "ok")
})

test_that("con warn = 2 el reintento sigue andando", {
  tres_intentos()
  local_mocked_bindings(esperar = function(s) NULL)
  viejas <- options(warn = 2)
  on.exit(options(viejas), add = TRUE)
  n <- 0
  intento <- function() { n <<- n + 1; if (n == 1) falla_500() else "ok" }
  expect_equal(suppressMessages(con_reintentos(intento, "Prueba", "https://x.uy/ows")), "ok")
  expect_equal(n, 2)
})

test_that("las opciones cambian los intentos y la espera, y con 1 se apaga", {
  tres_intentos()
  esperas <- numeric()
  local_mocked_bindings(esperar = function(s) esperas <<- c(esperas, s))
  viejas <- options(geouy.attempts = NULL, geouy.retry_wait = NULL)
  on.exit(options(viejas), add = TRUE)
  options(geouy.attempts = 1)
  n <- 0
  expect_error(con_reintentos(function() { n <<- n + 1; falla_500() }, "Prueba", "https://x.uy/ows"),
               "from https://x.uy.\nDetails", fixed = TRUE)
  expect_equal(n, 1)
  expect_length(esperas, 0)

  # La espera se duplica en cada intento, con un tope de 30 segundos.
  options(geouy.attempts = 6, geouy.retry_wait = 10)
  expect_error(suppressMessages(con_reintentos(falla_500, "Prueba", "https://x.uy/ows")),
               "after 6 attempts")
  expect_equal(esperas, c(10, 20, 30, 30, 30))

  # Una primera espera mas larga que el tope se mantiene.
  esperas <- numeric()
  options(geouy.attempts = 3, geouy.retry_wait = 60)
  expect_error(suppressMessages(con_reintentos(falla_500, "Prueba", "https://x.uy/ows")))
  expect_equal(esperas, c(60, 60))
})

test_that("una opcion que no tiene sentido da un error que la nombra", {
  tres_intentos()
  viejas <- options(geouy.attempts = NULL, geouy.retry_wait = NULL)
  on.exit(options(viejas), add = TRUE)
  options(geouy.attempts = 0)
  expect_error(con_reintentos(function() "ok", "Prueba", "https://x.uy/ows"), "geouy.attempts")
  options(geouy.attempts = Inf)
  expect_error(con_reintentos(function() "ok", "Prueba", "https://x.uy/ows"), "geouy.attempts")
  options(geouy.attempts = 3, geouy.retry_wait = -1)
  expect_error(con_reintentos(function() "ok", "Prueba", "https://x.uy/ows"), "geouy.retry_wait")
})

test_that("una descarga que falla no deja un zip a medias en la carpeta", {
  tres_intentos()
  local_mocked_bindings(esperar = function(s) NULL)
  local_mocked_bindings(has_internet = function() TRUE, .package = "curl")
  carpeta <- tempfile()
  dir.create(carpeta)
  # download.file() que escribe un pedazo y devuelve un estado distinto de 0.
  local_mocked_bindings(download.file = function(url, destfile, ...) {
    writeLines("a medias", destfile)
    1L
  }, .package = "utils")
  expect_error(suppressMessages(load_geouy("Deptos", folder = carpeta)), "after 3 attempts")
  expect_length(list.files(carpeta), 0)
})

test_that("un rename que falla da un error que lo dice, y no deja el zip a medias", {
  tres_intentos()
  local_mocked_bindings(has_internet = function() TRUE, .package = "curl")
  local_mocked_bindings(renombrar = function(de, a) FALSE)
  carpeta <- tempfile()
  dir.create(carpeta)
  local_mocked_bindings(download.file = function(url, destfile, ...) {
    writeLines("completo", destfile)
    0L
  }, .package = "utils")
  expect_error(suppressMessages(load_geouy("Deptos", folder = carpeta)), "could not be saved")
  expect_length(list.files(carpeta), 0)
})

test_that("una carpeta donde no se puede escribir es un error local, sin bajar nada", {
  tres_intentos()
  skip_on_os("windows")
  carpeta <- tempfile()
  dir.create(carpeta)
  Sys.chmod(carpeta, "0555")
  on.exit(Sys.chmod(carpeta, "0755"), add = TRUE)
  # Como root se puede escribir igual, y el test no probaria nada.
  skip_if(file.access(carpeta, 2) == 0, "se puede escribir en la carpeta igual")
  local_mocked_bindings(has_internet = function() TRUE, .package = "curl")
  n <- 0
  local_mocked_bindings(download.file = function(...) { n <<- n + 1; 0L }, .package = "utils")
  expect_error(load_geouy("Deptos", folder = carpeta), "valid directory")
  expect_equal(n, 0)
})

test_that("durante R CMD check el valor por omision es un solo intento", {
  viejo <- Sys.getenv("_R_CHECK_PACKAGE_NAME_", NA)
  on.exit(if (is.na(viejo)) Sys.unsetenv("_R_CHECK_PACKAGE_NAME_")
          else Sys.setenv("_R_CHECK_PACKAGE_NAME_" = viejo), add = TRUE)
  Sys.setenv("_R_CHECK_PACKAGE_NAME_" = "geouy")
  expect_equal(intentos_por_omision(), 1L)
  Sys.unsetenv("_R_CHECK_PACKAGE_NAME_")
  expect_equal(intentos_por_omision(), 3L)
  # La opcion manda sobre el valor por omision, tambien durante el check.
  Sys.setenv("_R_CHECK_PACKAGE_NAME_" = "geouy")
  viejas <- options(geouy.attempts = 2)
  on.exit(options(viejas), add = TRUE)
  expect_equal(opcion_intentos(), 2L)
})
