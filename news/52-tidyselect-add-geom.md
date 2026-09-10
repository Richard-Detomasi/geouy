* `add_geom()` no longer uses an external vector inside a selection, which
  `tidyselect` deprecated in 1.1.0 and has announced will become an error. The
  `rename()` in the middle was not needed either: `select()` can rename while
  selecting, so it is now a single call.
