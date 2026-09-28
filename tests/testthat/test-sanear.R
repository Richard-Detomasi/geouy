# Geometrias armadas a mano para los caminos de sanear() que las capas reales no
# recorren. No usan la red, asi que corren tambien en el paso bloqueante del CI.

o <- c(575000, 6140000)
en_lugar <- function(m, dx) m + matrix(rep(o + c(dx, 0), each = nrow(m)), nrow(m))
cuadrado <- function(dx) sf::st_polygon(list(en_lugar(rbind(c(0, 0), c(100, 0), c(100, 100), c(0, 100), c(0, 0)), dx)))
# Un anillo que se cruza a si mismo: invalido para GEOS y para s2.
mono <- function(dx) sf::st_polygon(list(en_lugar(rbind(c(0, 0), c(100, 100), c(100, 0), c(0, 100), c(0, 0)), dx)))
# Un vertice repetido: GEOS lo acepta, s2 lo rechaza. Es lo que tienen las capas
# censales.
repetido <- function(dx) sf::st_polygon(list(en_lugar(rbind(c(0, 0), c(100, 0), c(100, 0), c(100, 100), c(0, 100), c(0, 0)), dx)))

capa <- function(geoms) sf::st_sf(id = seq_along(geoms), geometry = sf::st_sfc(geoms, crs = 32721))
invalidas_en_4326 <- function(a) sum(!sf::st_is_valid(sf::st_transform(a, 4326)))

test_that("sanear repara un anillo cruzado y la capa sigue siendo de un solo tipo", {
  a <- capa(list(cuadrado(0), mono(500)))
  expect_message(r <- sanear(a, "prueba"), "1 of 2 geometries")
  expect_equal(nrow(r), 2)
  expect_equal(invalidas_en_4326(r), 0)
  # El moño reparado son dos triangulos: la capa pasa entera a MULTIPOLYGON en
  # vez de quedar mezclada, que la haria de tipo GEOMETRY.
  expect_equal(as.character(sf::st_geometry_type(r, by_geometry = FALSE)), "MULTIPOLYGON")
})

test_that("una capa MULTIPOLYGON reparada sigue siendo MULTIPOLYGON", {
  a <- capa(lapply(list(cuadrado(0), mono(500)), function(g) sf::st_multipolygon(list(g))))
  r <- suppressMessages(sanear(a, "prueba"))
  expect_equal(as.character(sf::st_geometry_type(r, by_geometry = FALSE)), "MULTIPOLYGON")
  expect_equal(invalidas_en_4326(r), 0)
})

test_that("sanear repara lo que s2 rechaza aunque GEOS lo acepte", {
  skip_if_not(sf::sf_use_s2())
  a <- capa(list(cuadrado(0), repetido(500)))
  expect_true(all(sf::st_is_valid(a)))       # GEOS: todo bien
  expect_equal(invalidas_en_4326(a), 1)      # s2: una mal
  expect_message(r <- sanear(a, "prueba"), "1 of 2 geometries")
  expect_equal(invalidas_en_4326(r), 0)
  expect_equal(as.character(sf::st_geometry_type(r, by_geometry = FALSE)), "POLYGON")
})

test_that("sanear no toca una capa sana ni las geometrias sanas", {
  a <- capa(list(cuadrado(0), cuadrado(500)))
  expect_silent(r <- sanear(a, "prueba"))
  expect_identical(r, a)

  # En una capa MULTIPOLYGON, la geometria sana queda identica.
  b <- capa(lapply(list(cuadrado(0), mono(500)), function(g) sf::st_multipolygon(list(g))))
  r <- suppressMessages(sanear(b, "prueba"))
  expect_identical(sf::st_geometry(r)[[1]], sf::st_geometry(b)[[1]])

  # En una capa POLYGON donde la reparacion parte una geometria en dos, la capa
  # pasa entera a MULTIPOLYGON: la sana cambia de tipo, pero no de coordenadas.
  b <- capa(list(cuadrado(0), mono(500)))
  r <- suppressMessages(sanear(b, "prueba"))
  expect_equal(sf::st_coordinates(sf::st_geometry(r)[1])[, 1:2],
               sf::st_coordinates(sf::st_geometry(b)[1])[, 1:2])
})

test_that("si la reparacion falla, la capa vuelve como estaba y se avisa", {
  a <- capa(list(cuadrado(0), mono(500)))
  local_mocked_bindings(st_make_valid = function(...) stop("falla simulada"), .package = "sf")
  expect_warning(r <- sanear(a, "prueba"), "could not be repaired")
  expect_identical(r, a)
})

test_that("sanear devuelve tal cual una capa vacia", {
  a <- capa(list(cuadrado(0)))[0, ]
  expect_silent(r <- sanear(a, "prueba"))
  expect_equal(nrow(r), 0)
})

test_that("una fila que la reparacion deja sin area no se lleva la geometria de otra", {
  # Un poligono sin area colapsa a una linea al repararlo: esa fila queda como
  # estaba, avisando, y la otra se repara bien. Antes, st_collection_extract()
  # sobre las dos juntas descartaba la primera y la segunda se reciclaba en las
  # dos filas.
  sin_area <- sf::st_polygon(list(en_lugar(rbind(c(0, 0), c(100, 0), c(200, 0), c(50, 0), c(0, 0)), 0)))
  a <- capa(list(sin_area, mono(500)))
  expect_warning(expect_message(r <- sanear(a, "prueba"), "1 of 2 geometries"), "could not be repaired")
  expect_equal(nrow(r), 2)
  expect_equal(sf::st_coordinates(sf::st_geometry(r)[1])[, 1:2], sf::st_coordinates(sf::st_geometry(a)[1])[, 1:2])
  expect_true(sf::st_is_valid(sf::st_geometry(r)[2]))
})

test_that("una reparacion que baja de dimension nunca hace fallar la carga", {
  colineal <- sf::st_polygon(list(en_lugar(rbind(c(0, 0), c(50, 0), c(100, 0), c(0, 0)), 0)))
  a <- capa(list(cuadrado(500), colineal))
  expect_warning(r <- sanear(a, "prueba"), "could not be repaired")
  expect_equal(as.character(sf::st_geometry_type(r, by_geometry = FALSE)), "POLYGON")
})

test_that("en una capa geografica tambien se chequea con GEOS", {
  # Un hueco que queda afuera del anillo exterior: GEOS lo rechaza, s2 no.
  ext <- rbind(c(-56, -35), c(-55, -35), c(-55, -34), c(-56, -34), c(-56, -35))
  hueco <- rbind(c(-54, -35), c(-53, -35), c(-53, -34), c(-54, -35))
  a <- sf::st_sf(id = 1, geometry = sf::st_sfc(sf::st_polygon(list(ext, hueco)), crs = 4326))
  expect_message(r <- sanear(a, "prueba"), "1 of 1 geometries")
  expect_true(con_s2(FALSE, sf::st_is_valid(r)))
})

test_that("con s2 apagado igual se detecta lo que s2 rechaza, y el estado queda como estaba", {
  a <- capa(list(cuadrado(0), repetido(500)))
  anterior <- suppressMessages(sf::sf_use_s2(FALSE))
  on.exit(suppressMessages(sf::sf_use_s2(anterior)))
  expect_message(r <- sanear(a, "prueba"), "1 of 2 geometries")
  expect_false(sf::sf_use_s2())
  suppressMessages(sf::sf_use_s2(TRUE))
  expect_equal(invalidas_en_4326(r), 0)
})

test_that("una capa sin CRS no hace fallar la carga", {
  a <- sf::st_sf(id = 1:2, geometry = sf::st_sfc(cuadrado(0), mono(500)))
  expect_message(r <- sanear(a, "prueba"), "1 of 2 geometries")
  expect_true(all(con_s2(FALSE, sf::st_is_valid(r))))
})

test_that("en una capa de tipo mixto ninguna fila cambia de dimension", {
  # Una linea degenerada -sus dos puntos iguales- se repararia a un punto. En una
  # capa GEOMETRY eso no puede pasar: queda como estaba.
  linea <- sf::st_linestring(en_lugar(rbind(c(0, 0), c(0, 0)), 0))
  a <- sf::st_sf(id = 1:2, geometry = sf::st_sfc(linea, mono(500), crs = 32721))
  r <- suppressWarnings(suppressMessages(sanear(a, "prueba")))
  expect_equal(as.integer(sf::st_dimension(sf::st_geometry(r))), c(1L, 2L))
})

test_that("lo que sigue invalido despues de reparar no figura como reparado", {
  skip_if_not(sf::sf_use_s2())
  # Aristas largas que se cruzan sobre la esfera: GEOS la ve valida, s2 no, y
  # repararla con GEOS no la cambia.
  anillo <- rbind(c(-70, -20), c(-60, -30), c(-75, 10), c(-105, 30), c(-115, 40), c(-70, -20))
  a <- sf::st_sf(id = 1, geometry = sf::st_sfc(sf::st_polygon(list(anillo)), crs = 4326))
  expect_true(con_s2(FALSE, sf::st_is_valid(a)))
  expect_false(con_s2(TRUE, sf::st_is_valid(a)))
  m <- character()
  expect_warning(r <- withCallingHandlers(sanear(a, "prueba"), message = function(x) {
    m <<- c(m, conditionMessage(x)); invokeRestart("muffleMessage")
  }), "could not be repaired")
  expect_false(any(grepl("were repaired", m)))
  expect_identical(r, a)
})

test_that("los vertices separados por un nanometro se reparan para s2", {
  skip_if_not(sf::sf_use_s2())
  # Dos vertices consecutivos a 1e-10 m: GEOS los ve distintos y la geometria
  # valida; en coordenadas geograficas s2 los ve iguales y la rechaza. Es lo que
  # tienen Maldonado y Rocha en "Deptos", a 1e-9 m.
  anillo <- en_lugar(rbind(c(0, 0), c(100, 0), c(100 + 1e-10, 0), c(100, 100), c(0, 100), c(0, 0)), 0)
  a <- capa(list(sf::st_polygon(list(anillo))))
  expect_true(con_s2(FALSE, sf::st_is_valid(a)))
  skip_if(invalidas_en_4326(a) == 0, "s2 no rechaza este caso en esta version")
  expect_message(r <- sanear(a, "prueba"), "1 of 1 geometries")
  expect_equal(invalidas_en_4326(r), 0)
})

test_that("la grilla de milimetro se usa solo donde hace falta, y se avisa", {
  skip_if_not(sf::sf_use_s2())
  # Un moño se repara sin grilla: el mensaje no la menciona.
  expect_message(sanear(capa(list(mono(0))), "prueba"), "repaired with sf::st_make_valid\\(\\)\\.")
  # Los vertices a un nanometro solo se reparan con la grilla: el mensaje lo dice.
  anillo <- en_lugar(rbind(c(0, 0), c(100, 0), c(100 + 1e-10, 0), c(100, 100), c(0, 100), c(0, 0)), 0)
  expect_message(sanear(capa(list(sf::st_polygon(list(anillo)))), "prueba"), "millimetre precision")
})

test_that("en unidades que no son metros ni grados no se aplica la grilla", {
  # Un moño con un hueco valido de 0,4 m, en un CRS en kilometros. La grilla de
  # "milimetro" calculada como si fueran metros seria de un metro y se llevaria
  # el hueco.
  km <- sf::st_crs("+proj=utm +zone=21 +south +datum=WGS84 +units=km")
  ext <- rbind(c(0, 0), c(10, 10), c(10, 0), c(0, 10), c(0, 0))
  hueco <- rbind(c(2, 4.8), c(2.0004, 4.8), c(2.0004, 5.2), c(2, 5.2), c(2, 4.8))
  a <- sf::st_sf(id = 1, geometry = sf::st_sfc(sf::st_polygon(list(ext, hueco)), crs = km))
  expect_true(is.na(precision_milimetro(km)))
  expect_true(is.na(precision_milimetro(sf::st_crs(NA))))
  expect_equal(precision_milimetro(sf::st_crs(32721)), 1000)
  expect_equal(precision_milimetro(sf::st_crs(4326)), 1e8)
  r <- suppressWarnings(suppressMessages(sanear(a, "prueba")))
  # Un punto adentro del hueco no puede caer en el poligono: el hueco sigue ahi.
  en_el_hueco <- sf::st_sfc(sf::st_point(c(2.0002, 5)), crs = km)
  expect_false(con_s2(FALSE, lengths(sf::st_intersects(en_el_hueco, r)) > 0))
})

test_that("las geometrias curvas quedan como estan y sin avisar", {
  # GEOS y s2 no evaluan curvas: st_is_valid() da NA. No son invalidas, y sanear
  # no tiene que decir que no las pudo reparar. Es lo que publica el MTOP en
  # "Balnearios", "Lagunas publicas" y "Cursos de agua navegables y flotables".
  curvas <- sf::st_sf(id = 1:2, geometry = sf::st_as_sfc(c(
    "MULTICURVE((575000 6140000, 575100 6140100))",
    "MULTICURVE((575200 6140000, 575300 6140100))"), crs = 32721))
  expect_silent(r <- sanear(curvas, "prueba"))
  expect_identical(r, curvas)

  # Mezclada con un poligono invalido: el poligono se repara, la curva no se toca.
  mezcla <- sf::st_sf(id = 1:2, geometry = c(
    sf::st_as_sfc("CURVEPOLYGON((575000 6140000, 575100 6140000, 575100 6140100, 575000 6140000))", crs = 32721),
    sf::st_sfc(mono(500), crs = 32721)))
  expect_message(r <- sanear(mezcla, "prueba"), "1 of 2 geometries")
  expect_identical(sf::st_geometry(r)[[1]], sf::st_geometry(mezcla)[[1]])
  expect_true(con_s2(FALSE, sf::st_is_valid(sf::st_geometry(r)[2])))
})

test_that("las colecciones quedan como estan y sin avisar", {
  # Repararla dejaba solo la parte de mayor dimension: el punto se perdia.
  con_punto <- capa(list(sf::st_geometrycollection(list(sf::st_point(o), mono(500)))))
  expect_silent(r <- sanear(con_punto, "prueba"))
  expect_identical(r, con_punto)

  # Con una curva adentro, st_is_valid() da NA, como con las curvas sueltas.
  con_curva <- sf::st_sf(id = 1, geometry = sf::st_as_sfc(
    "GEOMETRYCOLLECTION(CIRCULARSTRING(575000 6140000, 575050 6140050, 575100 6140000))",
    crs = 32721))
  expect_silent(r <- sanear(con_curva, "prueba"))
  expect_identical(r, con_curva)
})
