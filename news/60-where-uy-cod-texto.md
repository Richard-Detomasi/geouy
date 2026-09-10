* `where_uy(d = "cod")` can now query the layers whose code is textual. It used
  to run the ids through `as.numeric()` whenever `d = "cod"`, so a layer that
  declares `gml_id` or `globalid` as its code -ten of the sixty-four that
  declare one- could not be queried at all: a number never matched the column,
  and a text id was turned into `NA` before it got there. The ids are now
  compared using the type of the column itself.
* `where_uy()` says which column it compared against and what its values look
  like when nothing matches, instead of only "verify ids", which read as if the
  id were wrong even when the query could not have worked.
* `where_uy()` no longer stops with `the condition has length > 1` when several
  non-numeric ids are given at once, and the warning about ids that found no
  match now names them instead of interpolating the whole vector.
