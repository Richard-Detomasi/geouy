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
test_that("load_geouy corta con el nombre de capa equivocado", {
  # El stop() estaba envuelto en try(), asi que se imprimia el mensaje pero la
  # funcion seguia, el filtro no dejaba ninguna fila y el error que llegaba al
  # usuario era "argumento tiene longitud cero". No hace falta conexion: la
  # validacion corre antes de salir a la red.
  expect_error(load_geouy("No existe esta capa"),
               "name of the geometry you will load is not correct")
})

test_that("load_geouy no baja una capa distinta de la pedida", {
  # Con dos capas, la condicion del if fallaba por longitud, el try() se tragaba
  # ese error tambien, y el filtro de abajo reciclaba: load_geouy(c("Peajes",
  # "Rutas")) devolvia Rutas sin avisar nada. Entra en la misma guarda que el
  # nombre equivocado, con el mismo mensaje.
  expect_error(load_geouy(c("Peajes", "Rutas")),
               "name of the geometry you will load is not correct")
})

test_that("load_geouy culpa al directorio y no al servidor cuando el folder no sirve", {
  # dir.create() estaba envuelto en try(), que tapaba tanto "ya existe" -que es
  # lo que se queria tapar- como "no se puede crear". Pasandole un archivo en
  # lugar de un directorio, la descarga fallaba despues y el mensaje decia que
  # el servidor no habia devuelto un zip, que es exactamente al reves.
  archivo <- tempfile()
  file.create(archivo)
  expect_error(load_geouy("Deptos", folder = archivo), "valid directory")
})
