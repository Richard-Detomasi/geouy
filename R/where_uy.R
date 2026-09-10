#' This function return an 'sf' object with the geometry of the consult id or group of ids, of an administrative units in Uruguay.
#' @family service
#' @param c Define the geometries to consult: may be: "Departamentos", "Secciones", "Zonas", etc. View(metadata) for details.
#' @param d A vector who determines the variables to be consult, with two options: "cod" or "name". Default "cod".
#' @param e A vector who determines the ids or names to identify. It is matched
#'   against the column the metadata declares, using that column's own type: a
#'   numeric code is compared as a number and a textual one, such as `gml_id` or
#'   the INE codes like "UY-MO", as text.
#' @param crs Define the Coordinate Reference Systems you want the output, default 32721
#' @keywords IDE MIDES INE
#' @return sf object with the geometries of the d ids
#' @export
#' @examples
#'\donttest{
#' x <- try(where_uy(c = "Localidades pg", d = "cod", e = c(1020, 2020)), silent = TRUE)
#' if (!inherits(x, "try-error")) x
#'}

where_uy <- function(c = "Localidades pg", d = "cod", e, crs = 32721) {
  # Sin try() alrededor de los stop(). Un try() atrapa el error que el propio
  # codigo acaba de levantar, la funcion sigue como si nada y el usuario termina
  # viendo un error de mas abajo que no habla del problema real.
  if (length(d) != 1 || !d %in% c("cod", "name")) {
    stop("The argument d may be either \"cod\" or \"name\".")
  }
  if (length(c) != 1) {
    stop("You may consult one layer at a time in c.")
  }
  if (missing(e) || length(e) == 0) {
    stop("You may give at least one id in e.")
  }

  md <- geouy::metadata
  if (!c %in% md$capa) {
    stop("The name of the geometry you will load is not correct. Verify in the metadata file")
  }
  md <- md[md$capa %in% c, ]
  a <- if (identical(d, "cod")) md$cod else md$name
  if (is.na(a)) {
    stop(glue::glue("The layer {c} have not still a variable {d}, Please make an issue to suggest changes."))
  }

  y <- geouy::load_geouy(c, crs = crs)
  if (!a %in% names(y)) {
    stop(glue::glue("The metadata declares {a} as the {d} of {c}, ",
                    "but the layer does not bring that column."))
  }
  columna <- dplyr::pull(y, a)

  # Se compara en el tipo de la columna en vez de forzar todo a numero. Antes,
  # con d = "cod" se hacia as.numeric(e) siempre, y eso dejaba afuera las capas
  # cuyo codigo es de texto -gml_id, globalid, o los codigos del INE tipo
  # "UY-MO"-, que son diez de las sesenta y cuatro que declaran cod: ahi la
  # consulta era imposible de las dos formas, con numero porque la columna nunca
  # matchea y con texto porque la coercion lo convertia en NA.
  if (is.numeric(columna) && is.character(e)) {
    numeros <- suppressWarnings(as.numeric(e))
    if (anyNA(numeros)) {
      stop(glue::glue("The {d} of {c} is numeric, and these elements are not ",
                      "numbers: {enumerar(e[is.na(numeros)])}"))
    }
    e <- numeros
  } else if (!is.numeric(columna)) {
    columna <- as.character(columna)
    e <- as.character(e)
  }

  y <- y[columna %in% e, ]

  # El mensaje de "no hay coincidencias" dice contra que columna se comparo y
  # que aspecto tienen sus valores. Antes decia "verify ids" a secas, que sonaba
  # a que el id del usuario estaba mal incluso cuando la consulta era imposible.
  if (nrow(y) == 0) {
    stop(glue::glue("Sorry, your consult has not matches in {a}, the {d} of {c}. ",
                    "That column holds values like {enumerar(unique(columna), 3)}"))
  }
  faltan <- setdiff(e, columna)
  if (length(faltan) > 0) {
    warning(glue::glue("These elements have no match in {a}: {enumerar(faltan)}"))
  }
  y
}

# Los mensajes tienen que quedar acotados: stop() corta a 8190 caracteres, y una
# consulta con cientos de ids llegaria a eso sin problema.
enumerar <- function(x, tope = 5) {
  x <- as.character(x)
  if (length(x) > tope) {
    paste0(paste(x[seq_len(tope)], collapse = ", "), " and ", length(x) - tope, " more")
  } else {
    paste(x, collapse = ", ")
  }
}
