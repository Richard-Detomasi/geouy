# Ningun test tiene que escribir en la cache del usuario. Los de test-cache.R
# usan cada uno su carpeta; esto es por si otro test prende la cache sin fijar
# una: caeria en la carpeta temporal de la sesion y no en la del usuario.
options(geouy.cache_dir = file.path(tempdir(), "geouy-cache-de-los-tests"))
