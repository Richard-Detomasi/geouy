* `load_geouy()` retries when reading a layer from a web service, or
  downloading its zip file, fails: up to three attempts in all, waiting 5 and
  then 10 seconds, with a message before each new attempt. Failures that
  waiting cannot fix, such as a layer that does not exist or a broken
  certificate, are not retried, and the final error says how many attempts
  were made. `options(geouy.attempts = 1)` turns it off; `geouy.attempts` and
  `geouy.retry_wait` change the number of attempts and the first wait. A zip
  whose download fails half-way is no longer left behind as if it had been
  downloaded.
