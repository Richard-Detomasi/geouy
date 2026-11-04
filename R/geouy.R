#' \code{geouy} package
#'
#' The toolbox have functions to load and process geographic information for Uruguay.
#'
#' See the README on
#' \href{https://github.com/Richard-Detomasi/geouy/blob/master/README.md}{Github}
#'
#' @name geouy
#' @aliases geouy-package
"_PACKAGE"

## quiets concerns of R CMD check re: the .'s that appear in pipelines
if (getRversion() >= "2.15.1") utils::globalVariables(
  c(".", "label", "link", "lat", "lon", "all_of")
  )
