# Practica I - From Pixels to the Integral: Area Under a Curve

**Curso:** ST0244 - Programming Languages Programming
**Profesor:** Alexander Narváez Berrío
**Universidad EAFIT**

## Integrantes

- Jerónimo Espinosa López — Prolog
- Mateo Zuluaga Buitrago — Haskell

## Entorno de desarrollo

- **Prolog:** SWI-Prolog (probado en versión 9.x)
- **Haskell:** _(completar por Mateo: GHC / Stack / Cabal y versión usada)_
- Sistema operativo: _(completar)_

## Estructura del repositorio

```
README.md
Haskell/        -> implementación funcional
Prolog/         -> implementación lógica/declarativa
curva_binaria_P4.pbm  -> archivo de entrada suministrado por el profesor
```

## Cómo ejecutar la solución en Prolog

1. Instalar SWI-Prolog: https://www.swi-prolog.org/download/stable
2. Desde la raíz del repositorio:
   ```
   swipl Prolog/curva.pl curva_binaria_P4.pbm
   ```
   o, dentro del intérprete interactivo:
   ```prolog
   ?- [ 'Prolog/curva.pl' ].
   ?- resolver('curva_binaria_P4.pbm').
   ```
3. El programa imprime: dimensiones de la imagen, el área bajo la curva,
   el vector de alturas M[x]=f(x) como gráfico de barras, la
   reconstrucción de la curva escalada a consola, y 10 valores de
   muestra x_i -> f(x_i).

## Cómo ejecutar la solución en Haskell

_(completar por Mateo con los comandos exactos, por ejemplo:)_
```
cd Haskell
ghc Main.hs -o curva
./curva ../curva_binaria_P4.pbm
```

## Estrategia de visualización en consola

La imagen original (567 x 319 píxeles) es mucho más grande que una
terminal de texto normal, así que ambas soluciones usan **muestreo
espacial (spatial sampling)**: en vez de recorrer las 567 columnas
originales, se toman 80 muestras distribuidas uniformemente a lo largo
del dominio (una cada ~7 columnas). Las alturas resultantes se
re-escalan proporcionalmente a un número fijo de filas de texto (20
filas para la curva, 40 caracteres de ancho para el histograma de
`M[x]`), de modo que la forma general de la curva se conserva aunque
no se dibuje cada píxel individual.

## Área obtenida

Con el archivo `curva_binaria_P4.pbm` suministrado (567 x 319 píxeles):

**Área = 108,660 píxeles cuadrados**

Este valor coincide con el resultado de referencia del ejemplo en C++
mostrado en el enunciado de la práctica, y debe coincidir también con
el resultado obtenido por la implementación en Haskell.

## Comparación de paradigmas (resumen)

- **Haskell (funcional):** el problema se ve como una cadena de
  transformaciones puras sobre datos: `dominio -> alturas -> area`,
  típicamente `M = map f [0..ancho-1]` y `area = sum M`.
- **Prolog (lógico/declarativo):** el problema se ve como un conjunto
  de relaciones que deben cumplirse: `pixel/5`, `altura/5` describen
  *qué* relación existe entre una coordenada y su color/altura, y
  `findall/3` le pide a Prolog que encuentre *todos* los valores de
  `X` que satisfacen esa relación, en vez de iterar explícitamente.
