* `citation("geouy")` printed the year as `????`. It was taken from the `Date`
  field of the DESCRIPTION, which this package does not have; it now comes from
  `Date/Publication`, the field CRAN adds when it publishes, and falls back to
  the current year when neither is there.
* The `textVersion` of the citation was written outside the call to
  `bibentry()`, so it was an unused variable and what `citation()` showed was
  the text `bibentry` builds on its own.
