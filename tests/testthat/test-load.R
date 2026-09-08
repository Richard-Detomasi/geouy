context("Testing load_geouy")

test_that("connections working", {
  skip_if_offline()
  skip_on_cran()
  
  # Una capa de cada rama de load_geouy(): "Secciones" viene por WFS y "Deptos"
  # por zip. Antes la del zip salia del servidor de Ambiente, que no manda la
  # cadena de certificados: ninguna herramienta que los verifique puede entrar,
  # asi que el test fallaba por algo ajeno al paquete y ademas no cubria lo que
  # queria cubrir.
  testthat::expect_is(load_geouy("Secciones"), "sf")
  testthat::expect_is(load_geouy("Deptos"), "sf")
  # testthat::expect_is(load_geouy("Centros poblados pg"), "sf")
})

test_that("crs parameter working", {
  skip_if_offline()
  skip_on_cran()
  
  testthat::expect_error(load_geouy("Deptos", folder = 1))
  testthat::expect_error(load_geouy("Deptos", folder = c("c://", "c://")))
  
  a <- load_geouy("Secciones", crs = 4326)
  a1 <- sf::st_crs(a)
  testthat::expect_equal(a1[1], list(input = "EPSG:4326"))
  a <- load_geouy("Secciones", crs = 32721)
  a1 <- sf::st_crs(a)
  testthat::expect_equal(a1[1], list(input = "EPSG:32721"))
  })