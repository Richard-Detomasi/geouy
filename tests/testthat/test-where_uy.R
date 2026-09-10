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
})

test_that("where_uy consulta un cod numerico venga como numero o como texto", {
  skip_if_offline()

  loc <- load_geouy("Localidades pg")
  cod <- loc$CODLOC[[1]]

  # La columna manda: si es numerica, un id de texto que sea un numero sirve.
  expect_equal(nrow(where_uy(c = "Localidades pg", d = "cod", e = as.character(cod))), 1)

  # Y si no es un numero, el error dice cual de los elementos no lo es, en vez
  # de convertirlo a NA y hablar de NA.
  expect_error(where_uy(c = "Localidades pg", d = "cod", e = "c"), "not numbers")
})

test_that("where_uy consulta las capas cuyo cod es de texto", {
  skip_if_offline()

  # Diez de las sesenta y cuatro capas que declaran cod declaran uno de texto
  # -gml_id o globalid-, y ahi la consulta era imposible: con un numero la
  # columna nunca matcheaba, y con texto la coercion a numero lo volvia NA.
  # Se toma un id real de la propia capa, por lo mismo que arriba.
  peajes <- load_geouy("Peajes")
  id <- peajes$gml_id[[1]]

  uno <- where_uy(c = "Peajes", d = "cod", e = id)
  expect_s3_class(uno, "sf")
  expect_equal(nrow(uno), 1)
  expect_equal(uno$gml_id[[1]], id)

  expect_equal(nrow(where_uy(c = "Peajes", d = "cod", e = peajes$gml_id[1:3])), 3)

  # El aviso nombra el que falto, no el vector entero.
  expect_warning(where_uy(c = "Peajes", d = "cod", e = c(id, "NO_EXISTE")), "NO_EXISTE")
})

test_that("where_uy avisa cuando la consulta no puede funcionar", {
  skip_if_offline()

  # El mensaje de "no hay coincidencias" dice contra que columna se comparo y
  # que aspecto tienen sus valores. Antes decia "verify ids" a secas, que sonaba
  # a que el id estaba mal incluso cuando la consulta era imposible.
  expect_error(where_uy(c = "Peajes", d = "cod", e = 1), "gml_id")

  # Una capa sin cod declarado tiene que decir eso, y no reventar mas abajo con
  # un error de tidyselect.
  expect_error(where_uy(c = "Educacion especial", d = "cod", e = 1),
               "have not still a variable")
})

test_that("where_uy valida sus argumentos antes de salir a la red", {
  expect_error(where_uy(c = "Peajes", d = "otra cosa", e = 1), "cod")
  expect_error(where_uy(c = c("Peajes", "Rutas"), d = "cod", e = 1), "one layer")
  expect_error(where_uy(c = "Peajes", d = "cod", e = character(0)), "at least one")
  expect_error(where_uy(c = "No existe esta capa", d = "cod", e = 1), "not correct")
})
