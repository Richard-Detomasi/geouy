## Resubmission of an archived package

geouy was archived on 2025-08-20. The problem was the additional check with
`--run-donttest`, where the example of `plot_geouy()` failed with
`bad error message`. It had two causes:

* The example plotted a column of a remote layer, the MIDES `Secciones` WFS
  layer, which was republished with the 2023 census and no longer included that
  column.
* The validation that caught the missing column built its message by
  interpolating the whole `sf` object with `glue()`, which is vectorised, so it
  produced one message per column of the layer instead of a single one.

In this version:

* The example of `plot_geouy()` no longer downloads anything: it draws a few
  zones built in the example itself, and is no longer in `\donttest{}`.
* Every example run by `--run-donttest` that accesses a remote service wraps the
  whole remote operation in `try()`, including the ones that download more than
  once, so a change or an outage on the server cannot make the check fail.
* When a download or a read fails, `load_geouy()`, which the other functions
  that load layers use, stops with a message that names the layer and the
  server, instead of an unrelated error from further down.
* The two validation messages that interpolated a whole `sf` object no longer do
  so.

## R CMD check results

0 errors | 0 warnings | 1 note

* checking CRAN incoming feasibility ... NOTE

  Maintainer: 'Richard Detomasi <richard.detomasi@gmail.com>'

  New submission

  Package was archived on CRAN

  CRAN repository db overrides:
    X-CRAN-Comment: Archived on 2025-08-20 as issues were not corrected
      despite reminders.

With `--run-donttest`, the examples that download data depend on the response
time of the remote servers: `load_geouy()` took about 3 seconds of CPU and 29 of
elapsed time.

## Example in \dontrun{}

The example of `tiles_geouy()` is the only one in `\dontrun{}`. The function
downloads whole orthophoto tiles before cropping them, and a tile weighs from
3 MB to 1.3 GB depending on the flight and the format. `\donttest{}` would
still run it in the checks with `--run-donttest`.

## Test environments

* local: Pop!_OS 22.04 (Ubuntu based), R 4.6.1, with `--as-cran --run-donttest`
* GitHub Actions: ubuntu-latest (R-devel, release, oldrel-1), macOS (release)
  and Windows (release), with `--as-cran`; the R-devel job also runs the
  examples with `--run-donttest`

## Downstream dependencies

There are currently no downstream dependencies on CRAN. 'ech', which imports
geouy, was archived on the same day for that reason.
