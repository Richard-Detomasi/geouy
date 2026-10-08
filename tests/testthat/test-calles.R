# Las capas que juntan varias del mismo servicio, como "Calles" (#75). Las tres
# primeras no usan la red; la ultima carga la capa real.

test_that("capas_de_la_url() separa los typeName y con_una_capa() deja uno solo", {
  u <- "https://x.uy/ows?service=WFS&request=GetFeature&typeName=A:uno,A:dos&outputFormat=json"
  expect_equal(capas_de_la_url(u), c("A:uno", "A:dos"))
  expect_equal(con_una_capa(u, "A:dos"),
               "https://x.uy/ows?service=WFS&request=GetFeature&typeName=A:dos&outputFormat=json")
  expect_equal(capas_de_la_url("https://x.uy/capa.zip"), character())
  expect_equal(capas_de_la_url("https://x.uy/ows?typeName=IDE:Carreteras%20Uruguay"),
               "IDE:Carreteras Uruguay")
})

test_that("cada parte de una capa que junta varias tiene su propia fila en el metadata", {
  md <- geouy::metadata
  compuestas <- md[vapply(md$url, function(u) length(capas_de_la_url(u)) > 1, NA), ]
  # Control: si no hubiera ninguna, el resto del test no comprobaria nada.
  expect_gt(nrow(compuestas), 0)
  for (i in seq_len(nrow(compuestas))) {
    for (parte in capas_de_la_url(compuestas$url[i])) {
      expect_equal(sum(md$url == con_una_capa(compuestas$url[i], parte)), 1,
                   info = parte)
    }
  }
})

test_that("unir_capas() conserva todas las columnas y completa codigo, nombre y capa", {
  linea <- function(x0) sf::st_linestring(rbind(c(x0, 0), c(x0 + 10, 0)))
  # Como las reales: el codigo es texto en una y entero en la otra, y la
  # geometria no se llama igual.
  interior <- sf::st_sf(id = c("10", "11"), nombre = c("A", "B"), tipo = c("t", "u"),
                        geometry = sf::st_sfc(linea(0), linea(20), crs = 32721))
  montevideo <- sf::st_sf(cod_nombre = 5L, nom_calle = "C", sentido_nu = 1,
                          the_geom = sf::st_sfc(linea(40), crs = 32721))
  fila <- function(capa, cod, name, crs = 32721) data.frame(capa = capa, cod = cod, name = name, crs = crs)
  r <- unir_capas(
    list(list(datos = interior, fila = fila("Calles del interior", "id", "nombre")),
         list(datos = montevideo, fila = fila("Calles de Montevideo", "cod_nombre", "nom_calle"))),
    fila("Calles", "id", "nombre"))
  expect_s3_class(r, "sf")
  expect_equal(nrow(r), 3)
  expect_true(all(c("tipo", "cod_nombre", "nom_calle", "sentido_nu") %in% names(r)))
  expect_type(r$id, "character")
  expect_equal(r$id, c("10", "11", "5"))
  expect_equal(r$nombre, c("A", "B", "C"))
  expect_equal(r$capa, c("Calles del interior", "Calles del interior", "Calles de Montevideo"))
  expect_true(is.na(r$tipo[3]) && is.na(r$cod_nombre[1]))
  expect_equal(sf::st_crs(r)$epsg, 32721L)

  # Una parte en otro CRS se lleva al de la capa unida.
  en_4326 <- sf::st_transform(montevideo, 4326)
  r <- unir_capas(
    list(list(datos = interior, fila = fila("Calles del interior", "id", "nombre")),
         list(datos = en_4326, fila = fila("Calles de Montevideo", "cod_nombre", "nom_calle"))),
    fila("Calles", "id", "nombre"))
  expect_equal(sf::st_crs(r)$epsg, 32721L)

  # Una parte sin filas no impide la union.
  r <- unir_capas(
    list(list(datos = interior, fila = fila("Calles del interior", "id", "nombre")),
         list(datos = montevideo[0, ], fila = fila("Calles de Montevideo", "cod_nombre", "nom_calle"))),
    fila("Calles", "id", "nombre"))
  expect_equal(nrow(r), 2)

  # Columnas con el mismo nombre y tipos que no se apilan pasan a texto, y una
  # columna capa que traiga una parte no se pierde.
  con_fecha <- interior
  con_fecha$alta <- as.Date(c("2020-01-01", "2021-01-01"))
  con_texto <- montevideo
  con_texto$alta <- "sin dato"
  con_texto$capa <- "propia"
  r <- unir_capas(
    list(list(datos = con_fecha, fila = fila("Calles del interior", "id", "nombre")),
         list(datos = con_texto, fila = fila("Calles de Montevideo", "cod_nombre", "nom_calle"))),
    fila("Calles", "id", "nombre"))
  expect_equal(r$alta, c("2020-01-01", "2021-01-01", "sin dato"))
  expect_equal(r$capa_original, c(NA, NA, "propia"))
  expect_equal(r$capa[3], "Calles de Montevideo")

  # Una columna declarada que la capa no trae da un error que la nombra.
  expect_error(
    unir_capas(list(list(datos = interior, fila = fila("Calles del interior", "falta", "nombre"))),
               fila("Calles", "id", "nombre")),
    "falta")
})

test_that("Calles trae el interior y Montevideo", {
  skip_if_offline()
  skip_on_cran()
  # Los warnings son de las lineas de largo cero que no se pueden reparar.
  a <- suppressWarnings(suppressMessages(load_geouy("Calles")))
  expect_setequal(unique(a$capa), c("Calles del interior", "Calles de Montevideo"))
  expect_type(a$id, "character")
})
