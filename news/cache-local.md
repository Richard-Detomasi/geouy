* `load_geouy()` gains the arguments `cache` and `refresh`. With `cache = TRUE`
  the layer is saved in the cache folder of the user the first time it is
  loaded, and read from there afterwards, also without an internet connection.
  The copy is used for 30 days (`options(geouy.cache_days = )` changes it);
  after that the layer is downloaded again, and if the download fails the old
  copy is used, with a warning. `refresh = TRUE` downloads it again at any
  time, and stops with an error if it cannot. The cache is off by default, and
  `options(geouy.cache = TRUE)` turns it on for the session.
* New functions `cache_geouy()`, which lists the saved copies, and
  `clear_cache_geouy()`, which deletes them.
* When there is no internet connection, the error of `load_geouy()` no longer
  shows the call in front of the message.
* `load_geouy()` no longer warns that the folder given in `folder` does not
  exist when it is about to create it.
