*log history of geouy package development*

## geouy v0.3.0

* `add_geom()` no longer uses an external vector inside a selection, which
  `tidyselect` deprecated in 1.1.0 and has announced will become an error. The
  `rename()` in the middle was not needed either: `select()` can rename while
  selecting, so it is now a single call.
* The `NEWS.md` entries of a change now live in their own file under `news/`
  until a release consolidates them, so two pull requests no longer collide on
  the same lines of the same file.
* The weekly layer check no longer reports a static file as down on a single
  404. Those files are regenerated periodically, and while they are being
  recreated they answer 404 even though the service is fine. The check now
  looks at the directory index first: if the file is still listed there, it is
  most likely being regenerated rather than withdrawn.
* The pkgdown site was rebuilt. It had been generated for v0.2.6, so it was
  missing the `Secciones11`, `Segmentos11` and `Zonas11` layers, still credited
  the SGM as the source of the three layers the IGM serves now, and documented
  functions that no longer exist.
* The changelog page of the site was empty. `NEWS.md` opened with a title
  heading above the version headings, and pkgdown takes the top-level headings
  of the file as the versions, so it found none and rendered nothing.
* `citation("geouy")` printed the year as `????`. It was taken from the `Date`
  field of the DESCRIPTION, which this package does not have; it now comes from
  `Date/Publication`, the field CRAN adds when it publishes, and falls back to
  the current year when neither is there.
* The `textVersion` of the citation was written outside the call to
  `bibentry()`, so it was an unused variable and what `citation()` showed was
  the text `bibentry` builds on its own.
* The layer `Educación en Primera Infancia e Inicial` could not be loaded by
  the name the README gives. The script that builds `metadata` ran every
  character column through `iconv(x, "latin1", "UTF-8")`, and since the file is
  itself UTF-8 that double-encoded the only accented name in the table, so
  `load_geouy()` answered that the name was not correct. The rest of the table
  is ASCII, so no other layer was affected.
* The weekly check now also looks at what the organisms publish, not only at
  whether what the package already uses still answers. It takes a snapshot of
  the catalogues the package draws from -the WFS workspaces and the directory
  index of the static files- and reports what appeared since the previous run.
  It deliberately does not report everything published that the package does
  not use: that would be seventy-odd entries every single week.
* `where_uy(d = "cod")` can now query the layers whose code is textual. It used
  to run the ids through `as.numeric()` whenever `d = "cod"`, so a layer that
  declares `gml_id` or `globalid` as its code -ten of the sixty-four that
  declare one- could not be queried at all: a number never matched the column,
  and a text id was turned into `NA` before it got there. The ids are now
  compared using the type of the column itself.
* `where_uy()` says which column it compared against and what its values look
  like when nothing matches, instead of only "verify ids", which read as if the
  id were wrong even when the query could not have worked.
* `where_uy()` no longer stops with `the condition has length > 1` when several
  non-numeric ids are given at once, and the warning about ids that found no
  match now names them instead of interpolating the whole vector.
* `load_geouy()`, `which_uy()` and `plot_geouy()` now stop when the input is
  wrong, instead of printing the reason and carrying on. Their checks were
  written as `try(if (...) stop(...))`, and a `try()` around a `stop()` catches
  the very error the code has just raised: the message was printed but the
  function kept going and failed later with something unrelated. A layer name
  that is not in the metadata came back as "argument is of length zero"; an
  object that is not `sf` came back, in `which_uy()`, as "restarting
  interrupted promise evaluation"; and `plot_geouy()` did not fail at all, it
  returned a ggplot of an object that is not a layer.
* `load_geouy()` no longer returns a different layer than the one asked for
  when given more than one name. The condition failed on length, the `try()`
  swallowed that error too, and the filter below recycled and kept one of them,
  so `load_geouy(c("Peajes", "Rutas"))` quietly downloaded `Rutas`.
* `load_geouy()` and `tiles_geouy()` now say that the directory they were given
  cannot be used, instead of blaming the server. `dir.create()` was wrapped in
  `try()` to ignore the "directory already exists" case, but that also hid "the
  path is a file" and "no permission": the download then wrote nowhere and the
  error that reached the user said the server had not returned a zip.
* `tiles_geouy()` no longer builds its "not class sf" message by interpolating
  the whole object. `glue()` is vectorised, so it produced one message per
  column of the object and pasted them one after another. It is the same shape
  that produced the "bad error message" the package was archived for.
* The example of `plot_geouy()` no longer downloads a layer. It used a column of
  the MIDES `Secciones` layer, which is what got the package archived in 2025
  when that layer dropped `AREA`; it now draws a few zones built by hand, so it
  runs without network access and never depends on a remote schema.
* `plot_geouy()` now passes `...` to `ggplot2::theme()`, as its documentation
  said. It used to ignore it silently, so a call with an argument that
  `theme()` rejects, such as `plot.title = 1`, used to draw the map and now
  stops with the error from ggplot2.
* `geocode_ide_uy()` and `reverse_ide_uy()` have runnable examples; they were
  commented out. They also no longer stop with "subscript out of bounds" when
  every address is empty, and `geocode_ide_uy()` no longer waits ten seconds
  after the last address, when there is no next request to space out.
* The text returned by `is.uy4326()`, `is.uy32721()`, `is.uy5381()` and
  `is.uy5382()` changed: it said "Your object have ... Ururguay" and now says
  "Your object has ... Uruguay". That text is the return value, so code that
  compares it exactly has to be updated. Their documentation also said they
  return a logical value; they return a character string.
* Several parts of the documentation described something other than what the
  code does, and the code of the vignette did not run. Both are fixed.
* `load_geouy()` now repairs the geometries that are invalid as published, with
  `sf::st_make_valid()`, and a message says how many it repaired. It checks them
  as both GEOS and s2 see them, because they disagree: s2, which `sf` uses by
  default with geographic coordinates, also rejects repeated vertices, which
  GEOS accepts. Most census layers had some, among them `Departamentos`,
  `Secciones`, `Segmentos` and `Zonas`, so spatial joins in `EPSG:4326` against
  them failed, and so did `which_uy()` with `Departamentos`. Only the invalid
  geometries are repaired. Those that s2 still rejects after the repair,
  because a vertex lies within a few nanometres of another vertex or edge, are
  repaired again on a millimetre grid, and the message says how many. Any that
  cannot be repaired are left as they are, with a warning: in `Calles`, 759
  lines of zero length. Curved geometries, as in `CONEAT` or `Balnearios`, are
  left untouched, since neither engine can evaluate them, and so are geometry
  collections. With `make_valid = FALSE` the geometries are neither checked nor
  repaired.
* The layer `Educación en Primera Infancia e Inicial` was removed. It was the
  same data as `Jardines de infantes`, row by row and column by column: the
  server publishes the same file under two names. `Jardines de infantes` is the
  name that describes what the layer contains, so that is the one that stays.
* The package now points to its current repository,
  <https://github.com/Richard-Detomasi/geouy>: the `DESCRIPTION` gained a `URL`
  field and `BugReports` points there, as do `citation("geouy")`, `?geouy`, the
  vignette and the tutorial. They pointed to the old one, where bug reports
  would not be seen and `install_github()` installed a version without any of
  these fixes.
* `reverse_ide_uy()` returns `lat` and `lon` as numbers, as they came in. They
  were coming back as text, so `r$lat + 1` failed. Rows whose coordinates are
  `NaN` are now dropped like those with `NA`: they used to be sent to the
  service, which answers with an error, and the whole call failed.
* `Calles` now includes Montevideo. Its URL asks the service for two layers,
  the street axes from UTE, which cover the rest of the country, and those
  from the Intendencia de Montevideo, but only the first one was being read.
  Both are now read and joined, keeping all their columns, with the code and
  the name of each copied to `id` and `nombre` and a `capa` column saying
  which one each row comes from. Each part can also be loaded on its own, as
  `Calles del interior` and `Calles de Montevideo`.
* Four new point layers from the MIDES resource guide: `Centros de lenguas
  extranjeras`, `Centros educativos comunitarios`, `Atencion al usuario del
  MSP` and `Atencion a victimas del terrorismo de Estado`. They declare `ID`
  as their code and `NOMBRE` as their name, so `where_uy()` works with them.
* `load_geouy()` retries when reading a layer from a web service, or
  downloading its zip file, fails: up to three attempts in all, waiting 5 and
  then 10 seconds, with a message before each new attempt. Failures that
  waiting cannot fix, such as a layer that does not exist or a broken
  certificate, are not retried, and the final error says how many attempts
  were made. `options(geouy.attempts = 1)` turns it off; `geouy.attempts` and
  `geouy.retry_wait` change the number of attempts and the first wait. While
  `R CMD check` runs, the default is a single attempt, so that a server that is
  down does not make the check slower. A zip whose download fails half-way is no
  longer left behind as if it had been downloaded.
* geouy no longer depends on `fs`, `ggthemes` and `sp`, which it did not use,
  and `SystemRequirements` no longer asks for `unrar` or 7-Zip: no function
  handles `.rar` files anymore.
* `add_geom()` accepts `Segmentos URB INT 2004`. Its list of layers said
  `Segm URB INT 2004`, a name the metadata does not have, so that layer could
  not be used with either name.
* Fix `tiles_geouy()` returning the whole union of the tiles when the area
  spans more than one. The crop to the requested area, and the CRS, were only
  applied on the single-tile path; asking for 300 m around a point came back as
  a 1200x2400 raster with `crs` NA instead of the 600 metres of side that were
  asked for. Both are now applied on either path.
* `tiles_geouy()` keeps the CRS the file declares, and only sets one when the
  file brought none. The `.jpg` of the "rgb" format come with a world file and
  no CRS, so there it is needed; the `.tif` of "rgbi" do declare one, and it
  says SIRGAS-ROU98 UTM 21S rather than WGS84, so overwriting it was silently
  changing the datum of the raster.
* `tiles_geouy()` tells apart a service returning no tiles at all from a
  geometry that falls outside the covered area. A WFS answering 200 with no
  features comes back as a valid empty `sf`, and the message the user got said
  their geometry was not in Uruguay when the problem was the service.
* The example of `tiles_geouy()` no longer downloads a tile. The tile is the
  unit of download -the crop happens afterwards- so asking for a small area
  does not download less: the tile in the example weighs 66.7 MB. The sizes are
  now documented in the `format` argument, where an "rgbi" tile of the national
  flight reaches 1.3 GB.
* The examples of `is.uy4326()`, `is.uy32721()`, `is.uy5381()` and
  `is.uy5382()` now shield both downloads. They wrapped only the first one, but
  each of these functions fetches the `Uruguay` layer internally to compare
  against, so one unreachable service was enough to turn `R CMD check
  --run-donttest` into an ERROR. It happened on Windows, where the TLS
  revocation check failed on that second download.
* Fix the `cod` and `name` columns declared for six more layers. The five
  `Secc*11` ones named `codsecc`, with one `c` too many, when the layers carry
  `codsec`; and `Rutas` named `numero` and `nombre` in lower case when the layer
  returns `NUMERO` and `NOMBRE`. `where_uy()` failed on all six with "Can't
  extract columns that don't exist".
* `tiles_geouy()` checks that the tiles can be mosaicked before trying. The
  dangerous case is the number of bands: `raster::mosaic()` does not reject it,
  it takes the maximum and recycles the tile that has fewer, so a one-band tile
  next to a three-band one comes back as three bands with the single one
  repeated -a raster carrying made-up values, with no warning at all. When the
  counts are not divisors of each other the error does exist, but reads
  "number of items to replace is not a multiple of replacement length", which
  names neither the tile nor the layer. Resolution, grid origin and CRS are
  checked too, and the message now says which tile differs and in what.
* The test suite passes again. Four tests asserted values from remote layers
  that changed: `test-plot.R` and `test-which.R` named columns of `Secciones`
  that the 2023 census replaced, `test-where_uy.R` looked up a locality code
  that no longer exists, and `test-load.R` downloaded a layer from the Ambiente
  server, which cannot be read at all. They now assert what each function
  promises -an `sf` back, the columns it adds, one row per input- instead of
  the schema of a service we do not control.
* Two test blocks that reach the network gained `skip_if_offline()`, which also
  covers `skip_on_cran()`. Every example that reaches the network was already
  inside `\donttest{}` or `\dontrun{}`, and the vignette does not evaluate its
  chunks.

* Fix `Localidades pt` returning polygons. Both `Localidades` rows asked the
  server for the same layer, `INECenso:Localidades_pg`, so the one meant to be
  points quietly returned the polygons. The server does publish
  `INECenso:Localidades_pt`, which is what the row asks for now. Its name
  column is `NOMLOC`, not `NOMBLOC`, so that is corrected too.
* Fix the year of both `Localidades` rows, which said 2011 while the layers
  carry the 2023 census: they come from the same workspace as `Secciones`,
  `Segmentos` and `Zonas` and share their `viv_tot_23` and `pob_tot_23`
  columns.

* Fix the layer name of `Zonas11`, which asked for `INECenso2011:Zona_2011`
  while the MIDES geoserver publishes it as `zona_2011`. The failure was hard
  to spot: the server answers HTTP 200 with a `ServiceException` inside, so
  there is no 404 and no network error, and `st_read()` complains about
  something else. The layer returns 69,752 zones.
* Fix the `cod` and `name` columns declared for the three 2011 census layers.
  `Secciones11`, `Segmentos11` and `Zonas11` named them in upper case, but the
  layers return them in lower case, so `where_uy()` failed on all three with
  "Can't extract columns that don't exist". The 2023 layers do return upper
  case names and were already correct.

* Fix `load_geouy()` returning a different layer than the one requested. After
  downloading, the code picked the most recent `.shp` in the whole folder,
  which defaults to `tempdir()` and is shared between calls. `unzip()` does not
  raise an error when the file is not a zip -it warns and returns `NULL`, and
  the warning was swallowed by a `try()`- so a server answering with an error
  page left the previous layer's shapefile as the newest one, and it was read
  and returned with no warning at all. Only the files `unzip()` reports as
  extracted are considered now, and the unusable download is removed so a
  retry can succeed.
* `load_geouy()` now reports which layer and which server failed for every
  remote read, not only for the zip downloads. Layers read over WFS used to
  surface the raw GDAL error, which names neither.
* Failures of `load_geouy()` now carry the reason the server or the client
  actually reported. GDAL names the cause in a warning -"SSL certificate
  problem: unable to get local issuer certificate", "Could not resolve host"-
  and then raises a generic error that does not, so the message kept only the
  generic half. The warnings are now collected and added to the details without
  being muffled, so a read that still succeeds does not lose them. When a cause
  is known the message no longer guesses that the server may be down, which had
  it contradicting its own details.

* The example of `which_uy()` now shields both downloads. It covered only the
  first one, and the two layers come from different servers, so one of them
  being unreachable was enough to turn `R CMD check` into an ERROR.
* Fix a crash in `load_geouy()`: when a zip layer failed to download, the
  retry used `download.file(..., mode = "a")`, which segfaults and aborts the
  R session when the server does not answer. The download is now attempted
  once in `"wb"` mode and reports which layer and server failed.
* Examples that rely on remote services now check the result of the download
  before using it, so an unreachable server no longer turns into an error in
  `R CMD check`.
* `plot_geouy()` now says which variable is missing instead of printing the
  whole object. The message interpolated the `sf` object, and since `glue()` is
  vectorised it produced one message per column, each carrying all its values.
  This is what reached CRAN's check in 2025, when the "Secciones" layer stopped
  shipping the variable the example asked for.
* `plot_geouy()` now picks the colour scale from the type of the variable.
  `discrete` was computed with `is.numeric()` on a one-column data frame, which
  is always FALSE, so categorical variables were drawn on a continuous scale.
* `plot_geouy()` now honours `viri_opt`, which was documented but ignored: the
  scale had `option = "D"` hardcoded. The default stays viridis, so existing
  maps keep their colours.
* `plot_geouy()` no longer calls `theme_set()`, which changed the default
  ggplot2 theme for the whole R session. The returned plot is unchanged.
* `plot_geouy()` reports missing or invalid `other_lab` and `l` combinations up
  front, instead of failing later while drawing.
* Fix `tiles_geouy()`, which aborted on every call with a false "IDEuy Server
  out of service". The grid layers now carry administrative columns with
  legitimate NA values, so validating the download with `noNA()` always failed;
  the outcome of the download is checked instead, and the original error is
  reported along with the message.
* Five layers point at a service that works again. `Municipios10` and
  `Municipios15` moved with the SIT to `sit.mvot.gub.uy` after the ministry was
  split in 2020; `CONEAT` is now served by DGRN over https, which also removes
  the last plain-http URL in the package; and `OTs` and `Escuelas` no longer
  download a zip, since the same MIDES geoserver publishes them over WFS. Of
  the four candidate school layers, `IDE:Escuelas_UY`, `IDE:escuelas` and
  `IDE:escuelaspublicas` turned out to be the same 2267 records, while
  `IDE:anep_escuelas_ceip_2015_ei` only covers CEIP 2015 with 989.
* Five more layers work again, this time from the IGM server. Three of them
  (`Areas administrativas`, `Centros poblados pg` and `Centros poblados pt`)
  were read from the SGM service at `geoservicios.sgm.gub.uy`, whose host no
  longer resolves; the other two (`Limites departamentales` and `Municipios`)
  pointed at IGM paths that now answer with an ArcGIS error. The IGM has
  reorganised its services under a `Limites/` folder and publishes the
  1:1,000,000 national chart -the same product the package used to request as
  `wfsPCN1000.cgi`- as `Millon`, so the five layers are read from there.
  `repositor` for the three SGM layers becomes `"IGM"`; `productor` stays as
  `"SGM"`, which is who made the data.
* Remove the SGM branch of `load_geouy()`. It built its own URL against
  `geoservicios.sgm.gub.uy` and ignored the one in `metadata`, so it could not
  reach the layers anywhere else. With the three layers now served by the IGM
  no row has `repositor == "SGM"` and the branch was unreachable.

* Fix the urban grid filter in `tiles_geouy()`: `ortofotos:grilla_urbana`
  identifies localities by code ("MVD") since the urban flight was extended
  beyond Montevideo.
* Fix the crop area of `tiles_geouy()`: the bounding box was handed to
  `raster::extent()` with its axes swapped, so the whole tile was returned
  instead of the requested area and the `d` parameter had no effect.
* `tiles_geouy()` now fails with an informative message when the geometry has
  no area to crop.

* `tiles_geouy(urban = TRUE)` now works for the whole country. The urban flight
  covers 86 localities across ten deliveries, but only Montevideo was reachable:
  the download URLs were built by hand and the per-city folder in the path
  ("01_Ciudad_MVD") is sequential within each delivery, so it could not be
  derived from the locality code. The layer already ships the complete URLs, so
  they are taken from it and the locality filter is gone.
* `tiles_geouy()` no longer leaves a half-downloaded file under its final name.
  Each file is downloaded to a temporary name in the same folder and renamed
  only once it is complete, so an interrupted download can no longer be read
  back as if it were valid.
* `tiles_geouy()` now reports which file failed to download. The `.jpg` and its
  world file used to be requested in a single call, and `download.file()`
  returns 0 when at least one of several URLs succeeds, so a missing world file
  went unnoticed and the raster was left ungeoreferenced.

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
