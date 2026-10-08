* `Calles` now includes Montevideo. Its URL asks the service for two layers,
  the street axes from UTE, which cover the rest of the country, and those
  from the Intendencia de Montevideo, but only the first one was being read.
  Both are now read and joined, keeping all their columns, with the code and
  the name of each copied to `id` and `nombre` and a `capa` column saying
  which one each row comes from. Each part can also be loaded on its own, as
  `Calles del interior` and `Calles de Montevideo`.
