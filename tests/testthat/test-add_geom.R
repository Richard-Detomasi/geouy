test_that("add_geom works", {
  # add_geom() baja la capa de la unidad pedida, asi que sale a la red.
  # skip_if_offline() llama a skip_on_cran() de entrada, y ademas cubre el caso
  # de estar sin conexion, que skip_on_cran() solo no atrapa.
  skip_if_offline()

  pobre_x_dpto <- as.data.frame(cbind(nomdpto = c("ARTIGAS", "DURAZNO", "FLORIDA", "LAVALLEJA"),
                        Pobreza = c(0.26, 0.27, 0.07, 0.10)))
  pobre_x_dpto_geo <- add_geom(data = pobre_x_dpto, unit = "Deptos", variable = "nomdpto")
  testthat::expect_equal(ncol(pobre_x_dpto_geo), 3)
})
