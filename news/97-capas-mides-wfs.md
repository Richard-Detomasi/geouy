* `Educacion secundaria` and `UTU` can be loaded again. They were downloaded
  from a folder of the MIDES map portal that only holds what someone exports,
  and had been returning a 404 error since October 2026. They now come from
  the WFS of the same server, and declare `id` as their code and `nombre` as
  their name, so `where_uy()` works with them. Their columns are named as the
  WFS names them.
* Eight layers that MIDES no longer publishes were removed: `Colegios privados
  N0a3`, `Jardines de infantes`, `Escuelas con N3`, `Educacion especial`,
  `Centros de lenguas extranjeras`, `Centros educativos comunitarios`,
  `Atencion al usuario del MSP` and `Atencion a victimas del terrorismo de
  Estado`. They came from that same folder and the WFS has no replacement for
  them. Asking for one of them used to fail with a download error; now
  `load_geouy()` says that the name is not in `metadata`.
* The layer `Zonas URB INT 2004` was removed, from `metadata` and from the
  units that `add_geom()` accepts: the server only has 6 of its zones, all of
  them in one segment.
