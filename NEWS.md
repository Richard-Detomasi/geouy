*log history of geouy package development*

## geouy v0.3.0

First version since the package was archived on CRAN in 2025.

### Loading layers

* `load_geouy()` repairs the geometries that are invalid in the published data.
  Most census layers had some, and spatial operations in `EPSG:4326` against
  them failed, as did `which_uy()` with `Departamentos`. Only invalid geometries
  are repaired, and a message reports how many; `make_valid = FALSE` skips the
  repair.
* `load_geouy()` makes up to three attempts at each download or read (a single
  one while `R CMD check` runs), and does not retry errors that retrying cannot
  fix, such as HTTP 404 or a broken certificate. The options `geouy.attempts`
  and `geouy.retry_wait` change the number of attempts and the wait before the
  first retry. Large downloads are no longer cut off after 60 seconds, and when
  a download or a read fails, the error reports which layer, which server and
  why.
* `load_geouy()` takes a single layer name: given several, it used to download
  one of them without saying so, and now it stops. It also stops with a clear
  message when the name or the folder is wrong, and no longer returns a
  different layer than the one requested when a download fails.
* `Calles` now includes Montevideo. Its two parts can also be loaded on their
  own, as `Calles del interior` and `Calles de Montevideo`; the joined layer
  keeps the columns of both, adds `id` and `nombre` for all rows, and a `capa`
  column with the part each row comes from.
* Adds four layers from the MIDES resource guide: `Centros de lenguas
  extranjeras`, `Centros educativos comunitarios`, `Atencion al usuario del
  MSP` and `Atencion a victimas del terrorismo de Estado`. `Educación en
  Primera Infancia e Inicial` was removed: it was the same data as `Jardines de
  infantes`.
* `Secciones`, `Segmentos` and `Zonas` now return the 2023 census, which the
  server publishes under the same names and with different columns. The 2011
  census is in the new layers `Secciones11`, `Segmentos11` and `Zonas11`.
* Several layers work again or return the right data: the five layers read from
  the IGM; `Municipios10`, `Municipios15` and `CONEAT`, from their new servers;
  `OTs` and `Escuelas`, over WFS; `Zonas11`; and `Localidades pt`, which
  returned polygons instead of points. Several layers declared a code or name
  column they do not have, so `where_uy()` failed on them; they are fixed. Both
  `Localidades` layers are from 2023, not 2011, and `Barrios` from 2011, not
  1985.

### Other functions

* `tiles_geouy()` works again: it failed on every call. It crops to the
  requested area, works with `urban = TRUE` in every locality of the urban
  orthophotos and not only in Montevideo, distinguishes a service that is down
  from an area outside the coverage, and no longer leaves half-downloaded
  files. It keeps the CRS that the "rgbi" tiles declare, instead of replacing
  it with WGS84, and checks that the tiles can be combined before building the
  mosaic, instead of returning a raster with made-up values.
* `where_uy()` can query the layers whose code column is text, accepts several
  values of it, and its errors say which column it compared against and which
  values had no match.
* `which_uy()` and `plot_geouy()` stop with a clear message when the input is
  wrong, instead of failing later with an unrelated error.
* `plot_geouy()` honors `viri_opt`, passes `...` to `ggplot2::theme()`, picks
  the color scale from the type of the variable and no longer changes the
  default theme of the session.
* `reverse_ide_uy()` returns `lat` and `lon` as numbers, as they were given,
  instead of as text, and drops the rows without coordinates before querying the
  service. `geocode_ide_uy()` and `reverse_ide_uy()` no longer fail when every
  row is empty, and `geocode_ide_uy()` no longer waits after the last address.
* `add_geom()` accepts `Segmentos URB INT 2004`.
* The text returned by `is.uy4326()`, `is.uy32721()`, `is.uy5381()` and
  `is.uy5382()` says "Your object has ... Uruguay" instead of "Your object have
  ... Ururguay": code that compares it exactly has to be updated.
* `citation("geouy")` prints the year instead of `????`.

### Package

* No example can make `R CMD check` fail when a remote service is down, and the
  example of `plot_geouy()` no longer downloads anything. The validation
  message of `plot_geouy()` interpolated the whole layer and produced the error
  that got the package archived; it and a similar one in `tiles_geouy()` now
  build a single message.
* geouy now requires R 4.1.0 or later. It no longer depends on `fs`,
  `ggthemes` and `sp`, and no longer asks for `unrar` or 7-Zip in
  `SystemRequirements`.
* The package points to its new repository,
  <https://github.com/Richard-Detomasi/geouy>.

## geouy v0.2.8 (2023-08-22)

* update geouy.R for changes in roxygen2
* debug warning in add_geom.R

## geouy v0.2.7 (2023-05-16)

* Debug testing errors
* update plot_geouy for deprecated ggplot2::aes_string 
* update which_uy for changes in tidyselect 0.1.1

## geouy v0.2.6 (2022-10-04)

* Add Municipios 2010 and 2015, and Territorial Offices of MIDES to metadata 
* Update geocode_ide_uy() because server of IDEuy change
* Add a reverse_ide_uy() function for reverse geocoding 
* Change geoservice of "Departamentos"
* Change code variable name of "Municipios"
* Update URLs 

## geouy v0.2.5 (2021-08-12)

* Add demographic links from IDEuy
* Add an encoding variable to metadata.
* Implementation of encoding definition to load_geouy()
* Add a uy_deptos_grid and a mvd_barrios_grid as geofacet grid dataset 
* Improve citacion year and version

## geouy v0.2.4 (2021-05-02)

* plot_goeuy % bug fixed
* tutorial
* Add wfs for CONEAT of RENARE
* Update links of INE wfs, connecting to "Geoportal del Instituto Nacional de Estadística" made by IDE-Uy
* Update links of DINAMA wfs, because institutional changes make a change in server name
* Add metadata_tables for tables with geocodings
* Add to metadata cod variables for Padrones
* Add verification of internet access

## geouy v0.2.3 (2020-09-15)

* Add C++11 system requirement for sf update.
* Add CCZ datasets to metadata.
* Add a where_uy() to get an sf object by a name or id consult. 
* Add a add_geom() to add a geom variable to a data.frame by a link variable.
* Improve plot_geouy() fixing bugs, and made compatible with ech:: library.


## geouy v0.2.2 (2020-07-31)

* Add loc_agr_ine dataset of "Localidades agragadas" of INE.
* Add a geouy.R to discribe the package and set globals variables
* replace ggsn with ggspatial to improve north and scale aesthetics in plot_geouy 
* remove lat and long axis in plot_goeuy
* Add a param labels in plot_geouy for labels posiblity, if "%" porcentage with 1 decimal labels, if "n" the value is the label, if "c" put other variable in other_lab

## geouy v0.2.1 (2020-06-09)
 
* Add educational layers to load_geouy(): "Colegios privados N0a3", "Educación en Primera Infancia e Inicial",  "Jardines de infantes", "Escuelas",   "Escuelas con N3", "Educacion especial", "Educacion secundaria" y "UTU".
* Add tryCatch for download.file() in load_geouy() to diferents zip files.

## geouy v0.2.0 (2020-05-07)

* Verify compatibility with 1.0
* Change the use of to RCurl::getURL at geocode_ide_uy()
* Try change tiles_ide_uy() from raster to terra, but at the crop step the ptr slot is lost.
* Improvement of plot_geouy
* Remove tiles_ide_uy() function, because IDEuy change require methods


## geouy v0.1.9 (2020-03-20)

* Update test with CRS structure for sf 0.9 version
* Limits in geocode_geouy(), you must be part of uruguayan public organism and  fill this (forms)[https://www.gub.uy/agencia-gobierno-electronico-sociedad-informacion-conocimiento/comunicacion/publicaciones/formularios-publicacion-consumo-servicios-pdi] if your organism is not yet vinculated.


## geouy v0.1.8 (2020-03-17)

* Add to 'tiles_ide_uy()' function options to download .jpg in addition to .tif
* Add more testthat for 'tiles_ide_uy()' function
* Add zip format to 'load_goeuy()'
* Add MVOTMA datasets to metadata, i.e.: Ambientes acuaticos, Areas protegidas, Batimetria, Secciones catastrales, Padrones rurales y urbanos, Secciones policiales, Playas and Cuencas hidrograficas in its 5 nivels.
* Add to tiles_ide_uy the posibility for Montevideo tiles with urban = TRUE give orthophotos with 10cm per pixel 
* Solved bug with raster::mosaic for combination of multiple tiles to cover a bbox.
* Add a complementary function for 5382 crs evaluation

## geouy v0.1.7 (2020-02-26)

* Add layers for IDEuy orthophotos grids at 'load_geouy()' 
* Add a 'tiles_ide_uy()' function and it's testthat dile
* Add a complementary function for 5381 crs evaluation
* Change all 'paste()' with 'glue()'
* Add to testthat files 'skip_on...()' functions for a faster evaluation.

## geouy v0.1.6 (2020-02-09)

* Add \value to .Rd files
* Add all variables option to which_uy function
* Complementary functions for the evaluation of typical Uruguayan CRS codes (4326 and 32721)

## geouy v0.1.5 (2020-01-24)

* omit the redundant part "Toolbox for" in your title.
* web reference for the data source/used API in Description 
* write package names, software names and API names in single quotes.
* replace \dontrun{} by \donttest{} in Rd-files 
* Added in metadata the links to "Secc MVD 2004", "Segm MVD 2004", "Segm URB INT 2004", "Zonas MVD 2004", "Zonas URB INT 2004", "Localidades pt", "Instituciones deportivas"

## geouy v0.1.4 (2020-01-22)

 * New function `which_uy()` which allows to add to an "sf" object its spatial coincidence with one or more administrative units in Uruguay, generating the corresponding variables.
 * Added in metadata the links to "Departamentos" and "Barrios" of the INE, renaming "Departamentos" from IGM to "Limites departamentales"
 * testthat for the new function.

## geouy v0.1.3 (2020-01-17)

  * Change readLines for xml2::read_html in geocode_ide_uy()
  * Incorporate Viridis colors to 'plot_geouy()'
  * Added testthat function to all functions   


## geouy v0.1.1 (2020-01-15)

  * After first release of it to CRAN R, details were corrected in the package documentation
  * Was added checks in Travis (linux and mac), Appveyor and Codecov 
  * Generated a DOI in Zenodo 


## geouy v0.1.0 (2019-12-30)

Launch of **geouy** v0.1.0 on [GitHUb](https://github.com/RichDeto/geouy) with the following data sets:    
  * Localidades_pg    
  * Secciones    
  * Asentamientos irregulares    
  * Balnearios    
  * Departamentos    
  * Areas administrativas
  * Segmentos
  * Zonas
  * Centros poblados pg
  * Centros poblados pt
  * Cursos de agua
  * Lagunas
  * Rutas
  * Calles
  * Peajes
  * Postes kilometros
  
  
And the following functions:  
  * `load_geouy()`    
  * `geocode_ide_uy()`    
  * `plot_geouy()`
