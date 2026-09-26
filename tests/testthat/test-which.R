context("Testing which_uy")

test_that("crs parameter working", {
  skip_if_offline()
  skip_on_cran()
  
  a <- load_geouy("Peajes")
  b <- which_uy(a,"Departamentos")
  c <- which_uy(b,"Secciones", d = c("full"))
  a1 <- sf::st_crs(b)
  testthat::expect_equal(a1[1], list(input = "EPSG:32721"))
  testthat::expect_is(b, "sf")
  # El test fijaba los quince nombres de columna que salian del cruce, y tres de
  # ellos -AREA, PERIMETER y CDEPTO_ISO- desaparecieron cuando el INE republico
  # la capa con el censo 2023, que trajo en cambio viv_tot_23 y las tres de
  # poblacion. Fijar la lista entera ata el test al esquema de un organismo que
  # puede cambiarlo cuando quiera, y ademas no es lo que la funcion promete.
  # Lo que which_uy() promete es conservar las columnas de x y agregarle una por
  # cada unidad consultada, asi que eso es lo que se comprueba.
  testthat::expect_is(c, "sf")
  testthat::expect_true(all(names(a) %in% names(c)))
  testthat::expect_true(all(c("cod_Departamentos", "name_Departamentos",
                              "full_Secciones") %in% names(c)))
  testthat::expect_equal(nrow(c), nrow(a))
})
test_that("which_uy corta con una entrada que no es sf o una capa que no existe", {
  # Sin el try(), el objeto que no es sf daba "entrada en evaluacion: recursivo
  # por defecto o problemas anteriores?": el argumento se llama c y su valor por
  # defecto llama a c(), asi que interrumpir esa promesa dejaba a R en un estado
  # del que el mensaje no dice nada.
  expect_error(which_uy(x = data.frame(a = 1:3)), "not class sf")

  punto <- sf::st_sf(a = 1, geometry = sf::st_sfc(sf::st_point(c(0, 0)), crs = 32721))
  expect_error(which_uy(x = punto, c = "capa que no existe"),
               "name of the geometry you will load is not correct")
})

test_that("which_uy cruza puntos en coordenadas geograficas contra Departamentos", {
  skip_if_offline()
  skip_if_not(sf::sf_use_s2())
  # La capa trae dos anillos cruzados y cuatro geometrias con vertices repetidos.
  # Con s2, que sf activa por omision en coordenadas geograficas, este cruce
  # cortaba con "Loop 4 is not valid: Edge 4 is degenerate" (#34).
  p <- sf::st_as_sf(data.frame(lon = c(-56.2067, -54.9500, -57.9167),
                               lat = c(-34.9067, -34.9667, -31.4500)),
                    coords = c("lon", "lat"), crs = 4326)
  r <- suppressMessages(which_uy(p, c = "Departamentos", d = "name"))
  expect_equal(r[["name_Departamentos"]], c("MONTEVIDEO", "MALDONADO", "SALTO"))

  # Y la capa tal como la publica el organismo sigue disponible.
  cruda <- load_geouy("Departamentos", make_valid = FALSE)
  expect_gt(sum(!sf::st_is_valid(cruda)), 0)
})
