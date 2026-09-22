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
