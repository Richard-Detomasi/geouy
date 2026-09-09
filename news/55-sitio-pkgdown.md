* The pkgdown site was rebuilt. It had been generated for v0.2.6, so it was
  missing the `Secciones11`, `Segmentos11` and `Zonas11` layers, still credited
  the SGM as the source of the three layers the IGM serves now, and documented
  functions that no longer exist.
* The changelog page of the site was empty. `NEWS.md` opened with a title
  heading above the version headings, and pkgdown takes the top-level headings
  of the file as the versions, so it found none and rendered nothing.
