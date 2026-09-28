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
  cannot be repaired are left as they are, with a warning: in `Calles`, 572
  lines of zero length. Curved geometries, as in `CONEAT` or `Balnearios`, are
  left untouched, since neither engine can evaluate them, and so are geometry
  collections. With
  `make_valid = FALSE` the geometries are neither checked nor repaired.
