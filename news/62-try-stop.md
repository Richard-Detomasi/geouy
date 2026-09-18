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
