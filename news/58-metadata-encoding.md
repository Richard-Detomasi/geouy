* The layer `Educación en Primera Infancia e Inicial` could not be loaded by
  the name the README gives. The script that builds `metadata` ran every
  character column through `iconv(x, "latin1", "UTF-8")`, and since the file is
  itself UTF-8 that double-encoded the only accented name in the table, so
  `load_geouy()` answered that the name was not correct. The rest of the table
  is ASCII, so no other layer was affected.
