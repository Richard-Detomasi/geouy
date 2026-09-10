# Fragmentos del NEWS

Cada cambio que merezca una línea en el `NEWS.md` va acá, en **su propio
archivo**. Al preparar una release se consolidan todos en el `NEWS.md` y se
borran.

## Por qué

Cuando varios PR agregan su entrada directamente al `NEWS.md`, chocan entre
ellos: todos escriben en el mismo lugar del mismo archivo. Con un archivo por
cambio eso no puede pasar, porque nadie más lo toca.

Se probó antes la vía automática -`NEWS.md merge=union` en el `.gitattributes`-
y resuelve el conflicto **sólo cuando se fusiona desde la línea de comandos**:
GitHub no aplica los merge drivers, así que al mergear desde la web el conflicto
aparece igual.

## Cómo se usa

Creá un archivo con el número del PR y unas palabras que digan de qué se trata:

```
news/52-tidyselect-add-geom.md
```

Adentro va la entrada tal como quedaría en el `NEWS.md`, con su viñeta:

```markdown
* `add_geom()` no longer uses an external vector inside a selection, which
  `tidyselect` deprecated in 1.1.0.
```

Un par de convenciones que conviene mantener:

- **En inglés**, como el resto del `NEWS.md`.
- **Qué cambió para quien usa el paquete**, no cómo está implementado.
- Si el PR arregla algo, decir qué pasaba antes: es lo que sirve leer después.
- Podés poner más de una viñeta si el PR trae varias cosas.

El número del PR no se conoce hasta abrirlo, así que lo normal es crear el
archivo en el segundo commit, después de que GitHub asigne el número. Si te
resulta más cómodo, empezá con el nombre de la rama y renombralo después.

## Al preparar una release

```r
source(".github/scripts/consolidar-news.R")
```

Junta los fragmentos bajo el encabezado de la versión actual del `DESCRIPTION`,
los borra, y dice qué hizo. Después se revisa el `NEWS.md` a mano: el script
ordena y pega, no escribe.
