
test_that("tiles_geouy no arma el mensaje interpolando el objeto entero", {
  # Interpolaba {x} con glue(), que vectoriza: armaba un mensaje por cada
  # columna y los pegaba uno atras de otro. Es la misma forma que produjo el
  # "bad error message" por el que archivaron el paquete.
  falso <- data.frame(a = 1:3, b = letters[1:3], c = 7:9)
  expect_error(tiles_geouy(x = falso), "not class sf")
  m <- tryCatch(tiles_geouy(x = falso), error = conditionMessage)
  expect_equal(m, "The object you want to process is not class sf")

  # Y el directorio invalido tiene que decir que es el directorio.
  punto <- sf::st_sf(a = 1, geometry = sf::st_sfc(sf::st_point(c(575000, 6140000)), crs = 32721))
  archivo <- tempfile()
  file.create(archivo)
  expect_error(tiles_geouy(x = punto, folder = archivo), "valid directory")
})
