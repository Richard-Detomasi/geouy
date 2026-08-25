# Las variables que el usuario puede pedir son las columnas menos la geometria:
# ofrecerle "geometry" como opcion valida solo confunde. Se usa la misma lista
# para validar y para el mensaje, para que no puedan decir cosas distintas.
variables_de <- function(x) {
  setdiff(names(x), attr(x, "sf_column", exact = TRUE))
}

# El mensaje no vuelca datos, pero una tabla muy ancha igual da una lista larga.
listar <- function(v, max = 20) {
  if (length(v) > max) paste0(paste(v[seq_len(max)], collapse = ", "),
                              ", ... (", length(v) - max, " more)")
  else paste(v, collapse = ", ")
}

#' @name plot_geouy
#' @title plot_geouy
#' @description This function allows you to set ggplot2 theme in our suggested format.
#' @family plot
#' @param x An sf object like load_geouy() results
#' @param col Variable of "x" to plot (character)
#' @param viri_opt A character string indicating the colormap option to use. Four options are available: "magma" (or "A"), "inferno" (or "B"), "plasma" (or "C"), "viridis" (or "D", the default option) and "cividis" (or "E")
#' @param l If NULL none label added, if "\%" porcentage with 1 decimal labels, if "n" the value is the label, if "c" put other variable in other_lab. Default NULL
#' @param other_lab If l is "c" put here the variable name for the labels.
#' @param ... All parameters allowed from ggplot2 themes.
#'
#' @keywords ggplot2 sf maps
#' @import ggplot2 ggthemes
#' @return ggplot object of a choropleth map with x geometries and col values.
#' @export
#'
#' @examples
#' \donttest{
#' secc <- try(load_geouy("Secciones"), silent = TRUE)
#' if (!inherits(secc, "try-error")) plot_geouy(x = secc, col = "pob_tot_23")
#' }
#' 

plot_geouy <- function(x, col, viri_opt = "plasma", l = NULL, other_lab = NULL, ...){
  try(if (!methods::is(x, "sf")) stop("The object you want to process is not class sf"))
  # El mensaje interpolaba {x}, el objeto sf completo. Y glue() vectoriza, asi
  # que no armaba un mensaje largo: armaba uno por cada columna, con todos sus
  # valores adentro. Cuando una capa cambia y deja de traer la variable pedida
  # -que es lo que paso con "Secciones" y el Censo 2023- lo que sale es una
  # avalancha en lugar del nombre que falta.
  disponibles <- variables_de(x)
  assertthat::assert_that(col %in% disponibles,
    msg = glue::glue("The variable '{col}' is not in x. Available: {listar(disponibles)}"))
  if (!is.null(l)) assertthat::assert_that(l %in% c("%", "n", "c"), msg = "Sorry... :( \n l parameter is not a valid value, please review!.")
  # isTRUE() alrededor del %in%: con l = NULL el %in% da logical(0), y
  # `TRUE && logical(0)` da NA, con lo cual el if se cae con "valor ausente
  # donde TRUE/FALSE es necesario" con solo pedir other_lab sin pedir l. Con l
  # de largo 2 el && directamente da error desde R 4.3. isTRUE() resuelve los
  # dos casos y conserva la coercion del %in%, que acepta un factor.
  if (isTRUE(l %in% "c")) {
    # Pedir etiquetas de otra variable sin decir cual fallaba mas adelante, al
    # dibujar, con "Problem while computing aesthetics".
    assertthat::assert_that(!is.null(other_lab),
      msg = "other_lab must be given when l is \"c\": it names the variable to label with.")
    assertthat::assert_that(other_lab %in% disponibles,
      msg = glue::glue("The variable '{other_lab}' given in other_lab is not in x. ",
                       "Available: {listar(disponibles)}"))
  }
  if (!is.null(l) && l %in% "%" & is.numeric(x[[col]]) & sum(x[[col]] > 1, na.rm = T) == 0) {
      x[[col]] <- x[[col]] * 100
    }
  
  theme_set(theme_bw())
  mapa <- ggplot2::ggplot(data = x) +
    ggplot2::geom_sf(data = x, aes(!!!ensyms(fill = col)))  +
    viridis::scale_fill_viridis(name = col, option = "D", direction = -1,
                                discrete = is.numeric(x[,col] %>% sf::st_set_geometry(NULL))) +
    ggplot2::xlab(NULL) + ggplot2::ylab(NULL) +
    labs(title = glue::glue("Mapa de variable: {tolower(col)}")) +
    theme_light() +
    theme(panel.grid.major = element_line(colour = "transparent"),
          axis.text = element_text(size = 8),
          legend.text = element_text(size = 7),
          legend.title = element_text(size = 7),
          axis.title = element_text(size = 7),
          plot.title = element_text(size = 9),
          plot.subtitle = element_text(size = 8),
          plot.caption = element_text(size = 8, hjust = -0.001),
          legend.key.size = unit(0.4, "cm")) + coord_sf(datum = NA)  +
    ggspatial::annotation_scale(location = "tr", width_hint = 0.4) +
    ggspatial::annotation_north_arrow(location = "tr", which_north = "true",
                                      pad_x = unit(0.095, "in"), pad_y = unit(0.25, "in"),
                                      style = ggspatial::north_arrow_fancy_orienteering)
  
  if(!is.null(l) && l %in% "%"){
    ll <- x %>% dplyr::mutate(label = .data[[col]] %>% as.numeric(.) %>% round(1) %>% paste0("%")) %>%
      dplyr::filter(!is.na(.data[[col]]))
    mapa <- mapa + geom_sf_text(data = ll, aes(label = label),
                                colour = "white", size = 3, hjust = 0.5)
  }
  if(!is.null(l) && l %in% "n"){
    mapa <- mapa + geom_sf_text(aes(label = .data[[col]]),
                                colour = "white", size = 3, hjust = 0.5)
  }
  if(!is.null(l) && l %in% "c"){
    mapa <- mapa + geom_sf_text(aes(label = .data[[other_lab]]),
                                colour = "white", size = 3, hjust = 0.5)
  }
  return(mapa)
}