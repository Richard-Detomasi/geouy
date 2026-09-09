test_that("where_uy filtra por codigo y por nombre", {
  skip_if_offline()

  # El test buscaba el codigo 2220, que la capa dejo de traer cuando se
  # republico con el censo 2023. Un valor puntual de un servicio ajeno queda
  # viejo sin que nadie se entere, asi que ahora se toma un codigo real de la
  # propia capa y se comprueba el comportamiento, que es lo que la funcion
  # promete: devolver la fila del codigo pedido.
  loc <- load_geouy("Localidades pg")
  cod <- loc$CODLOC[[1]]
  nom <- as.character(loc$NOMBLOC[[1]])

  una <- where_uy(c = "Localidades pg", d = "cod", e = cod)
  expect_s3_class(una, "sf")
  expect_equal(nrow(una), 1)
  expect_equal(una$CODLOC[[1]], cod)

  expect_equal(nrow(where_uy(c = "Localidades pg", d = "name", e = nom)), 1)

  # Dos codigos, uno de ellos inexistente: avisa que hubo menos coincidencias.
  inexistente <- max(loc$CODLOC) + 1
  expect_warning(where_uy(c = "Localidades pg", d = "cod", e = c(cod, inexistente)))

  # Un codigo que no existe no devuelve nada, y lo dice.
  expect_error(where_uy(c = "Localidades pg", d = "cod", e = inexistente))

  # Los tipos tienen que corresponderse con lo que se pide.
  expect_warning(expect_error(where_uy(c = "Localidades pg", d = "cod", e = "c")))
  expect_error(where_uy(c = "Localidades pg", d = "name", e = 1))
})
