# Practica I - Area bajo la curva (Haskell + Prolog)

Curso: Lenguajes y Paradigmas de Computación -0262

## Equipo

- Jerónimo Espinosa López 
- Mateo Zuluaga Buitrago 

## Qué hace esto

El profe nos dio una imagen binaria (`curva_binaria_P4.pbm`, formato PBM P4) que representa una curva. La idea es leer cada columna de la imagen, contar cuántos píxeles negros consecutivos tiene desde abajo (eso es f(x)), armar el vector de alturas M = [f(0), f(1), ..., f(n-1)], y sumar todo para sacar el área bajo la curva (suma de Riemann con Δx = 1).

Lo mismo se resuelve dos veces, con dos paradigmas distintos, y debe dar la misma área en ambos.

## Estructura

- `Prolog/curva.pl` — solución en Prolog
- `Haskell/` — solución en Haskell (Mateo)
- `curva_binaria_P4.pbm` — imagen de entrada

## Correr la parte de Prolog

Necesitas SWI-Prolog instalado.

```
swipl Prolog/curva.pl curva_binaria_P4.pbm
```

o dentro del intérprete:

```prolog
?- [ 'Prolog/curva.pl' ].
?- resolver('curva_binaria_P4.pbm').
```

Imprime las dimensiones de la imagen, el área, el vector de alturas como gráfico de barras, una reconstrucción de la curva en consola, y 10 valores x_i -> f(x_i).

## Correr la parte de Haskell

Necesitas GHC instalado (viene con GHCup: https://www.haskell.org/ghcup/).

```
cd Haskell
ghc -O2 Main.hs -o curva
./curva ../curva_binaria_P4.pbm
```

En Windows el ejecutable queda como `curva.exe`, se corre igual: `./curva.exe ../curva_binaria_P4.pbm`.

## Cómo mostramos la imagen en la consola

La imagen es de 567x319 píxeles, mucho más ancha de lo que cabe en una terminal, así que en vez de recorrer las 567 columnas para dibujar, tomamos 80 muestras repartidas uniformemente a lo largo de la imagen y reescalamos las alturas para que quepan en un número fijo de filas/caracteres. Se pierde algo de detalle pero se mantiene la forma general de la curva.

## Resultado

Con la imagen que nos dio el profe (567x319 píxeles):

**Área = 108660 píxeles cuadrados**

Debe coincidir con lo que dé la versión en Haskell.

## Prolog vs Haskell

En Haskell el problema se arma como una cadena de transformaciones: se le aplica f a todo el dominio con `map` y se suma con `sum`. Es "hago esto, después esto".

En Prolog no hay ese "paso a paso": uno define relaciones (`pixel/5`, `altura/5` dicen qué tiene que cumplirse entre una coordenada y su color/altura) y le pide a Prolog, con `findall/3`, que encuentre todos los valores que las cumplen. No se está iterando explícitamente, se está preguntando.
