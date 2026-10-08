* `reverse_ide_uy()` returns `lat` and `lon` as numbers, as they came in. They
  were coming back as text, so `r$lat + 1` failed. Rows whose coordinates are
  `NaN` are now dropped like those with `NA`: they used to be sent to the
  service, which answers with an error, and the whole call failed.
