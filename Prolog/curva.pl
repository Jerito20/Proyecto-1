% =====================================================================
%  PRACTICA I - Area bajo la curva (Parte Prolog)
%  Enfoque: programacion logica / declarativa.
%
%  En vez de describir "que pasos ejecutar", describimos que relacion
%  debe cumplirse entre una imagen, una coordenada, su color, la
%  altura de una columna y el area total. Prolog se encarga de
%  encontrar los valores que satisfacen esas relaciones (findall/3).
%
%  Uso en SWI-Prolog:
%     ?- [curva].
%     ?- resolver('test_curva.pbm').
% =====================================================================

:- initialization(main).

main :-
    ( current_prolog_flag(argv, [Archivo|_]) -> true ; Archivo = 'curva_binaria_P4.pbm' ),
    resolver(Archivo).

% ---------------------------------------------------------------------
% 1. LECTURA DEL ARCHIVO PBM P4
%    Relaciona el nombre de un archivo con su ancho, alto y sus bytes
%    crudos (almacenados en un termino compuesto que actua como
%    arreglo de acceso O(1) via arg/3).
% ---------------------------------------------------------------------

leer_pbm(Archivo, Ancho, Alto, ArrayDatos) :-
    open(Archivo, read, Stream, [type(binary)]),
    leer_encabezado(Stream, Ancho, Alto),
    read_stream_to_codes(Stream, ListaBytes),
    close(Stream),
    ArrayDatos =.. [datos|ListaBytes].   % lista -> termino compuesto (arreglo)

leer_encabezado(Stream, Ancho, Alto) :-
    get_byte(Stream, _CodP),   % 'P'
    get_byte(Stream, _Cod4),   % '4'
    leer_numero(Stream, Ancho),
    leer_numero(Stream, Alto),
    get_byte(Stream, _Separador). % el unico whitespace antes de los datos binarios

leer_numero(Stream, Numero) :-
    saltar_espacios_y_comentarios(Stream),
    leer_digitos(Stream, Digitos),
    number_codes(Numero, Digitos).

saltar_espacios_y_comentarios(Stream) :-
    peek_byte(Stream, C),
    ( es_espacio(C) ->
        get_byte(Stream, _), saltar_espacios_y_comentarios(Stream)
    ; C =:= 0'# ->
        saltar_linea(Stream), saltar_espacios_y_comentarios(Stream)
    ; true
    ).

saltar_linea(Stream) :-
    get_byte(Stream, C),
    ( C =:= 10 -> true ; saltar_linea(Stream) ).

es_espacio(32). es_espacio(9). es_espacio(10). es_espacio(13).

leer_digitos(Stream, [C|Resto]) :-
    peek_byte(Stream, C),
    code_type(C, digit(_)), !,
    get_byte(Stream, C),
    leer_digitos(Stream, Resto).
leer_digitos(_, []).

% ---------------------------------------------------------------------
% 2. ACCESO A PIXELES INDIVIDUALES
%    pixel(X, Y, Datos, BytesPorFila, Bit) es verdadero cuando Bit es
%    el valor (0 o 1) del pixel en la columna X, fila Y.
%    Convencion PBM: bit 1 = negro, bit 0 = blanco; el bit mas
%    significativo del byte corresponde al pixel mas a la izquierda.
% ---------------------------------------------------------------------

bytes_por_fila(Ancho, BytesPorFila) :-
    BytesPorFila is (Ancho + 7) // 8.

pixel(X, Y, Datos, BytesPorFila, Bit) :-
    ByteIndex is Y*BytesPorFila + X // 8,
    Idx is ByteIndex + 1,           % arg/3 es indexado desde 1
    arg(Idx, Datos, Byte),
    BitPos is 7 - (X mod 8),
    Bit is (Byte >> BitPos) /\ 1.

es_negro(X, Y, Datos, BytesPorFila) :- pixel(X, Y, Datos, BytesPorFila, 1).

% ---------------------------------------------------------------------
% 3. LA FUNCION DISCRETA f(X)
%    altura(X, Datos, Alto, BytesPorFila, F): F es la cantidad de
%    pixeles negros consecutivos contando desde abajo (Y = Alto-1)
%    hacia arriba, hasta el primer pixel blanco.
% ---------------------------------------------------------------------

altura(X, Datos, Alto, BytesPorFila, F) :-
    YInicial is Alto - 1,
    contar_negros(X, YInicial, Datos, BytesPorFila, 0, F).

contar_negros(X, Y, Datos, BytesPorFila, Acc, F) :-
    Y >= 0,
    es_negro(X, Y, Datos, BytesPorFila), !,
    Y1 is Y - 1, Acc1 is Acc + 1,
    contar_negros(X, Y1, Datos, BytesPorFila, Acc1, F).
contar_negros(_, _, _, _, Acc, Acc).

% ---------------------------------------------------------------------
% 4. VECTOR DE ALTURAS  M = [f(0), f(1), ..., f(n-1)]
%    Construido declarativamente: "encuentra TODOS los F que
%    satisfacen la relacion altura/5 para cada X del dominio".
% ---------------------------------------------------------------------

vector_alturas(Datos, Alto, Ancho, BytesPorFila, M) :-
    MaxX is Ancho - 1,
    findall(F,
        ( between(0, MaxX, X), altura(X, Datos, Alto, BytesPorFila, F) ),
        M).

% ---------------------------------------------------------------------
% 5. AREA (suma de Riemann, Delta x = 1)
% ---------------------------------------------------------------------

area(M, Area) :- sum_list(M, Area).

% ---------------------------------------------------------------------
% 6 y 7. VISUALIZACION EN CONSOLA
%    Estrategia de escalado: se toman AnchoConsola muestras
%    distribuidas uniformemente sobre las Ancho columnas originales
%    (spatial sampling), y las alturas se re-escalan proporcionalmente
%    a AltoConsola filas de texto. Esto preserva la forma general de
%    la curva sin tener que imprimir cada pixel original.
% ---------------------------------------------------------------------

mostrar_curva(M, Ancho) :-
    AnchoConsola = 80, AltoConsola = 20,
    muestrear(M, Ancho, AnchoConsola, Muestras),
    max_list(Muestras, MaxM0),
    ( MaxM0 =:= 0 -> MaxM = 1 ; MaxM = MaxM0 ),
    findall(E, ( member(V, Muestras), E is round(V / MaxM * AltoConsola) ), Escaladas),
    forall(between(1, AltoConsola, FilaArriba),
        ( Nivel is AltoConsola - FilaArriba + 1,
          dibujar_fila(Escaladas, Nivel), nl )).

muestrear(M, Ancho, NOut, Muestras) :-
    length(M, Ancho),
    findall(V,
        ( between(0, NOut-1, I),
          X is min(Ancho-1, (I*Ancho) // NOut),
          nth0(X, M, V) ),
        Muestras).

dibujar_fila([], _).
dibujar_fila([H|T], Nivel) :-
    ( H >= Nivel -> write('#') ; write(' ') ),
    dibujar_fila(T, Nivel).

mostrar_alturas(M, Ancho) :-
    AnchoConsola = 80,
    muestrear(M, Ancho, AnchoConsola, Muestras),
    max_list(Muestras, MaxM0),
    ( MaxM0 =:= 0 -> MaxM = 1 ; MaxM = MaxM0 ),
    forall(member(V, Muestras),
        ( Bloques is round(V / MaxM * 40),
          dibujar_bloques(Bloques), format(" ~w~n", [V]) )).

dibujar_bloques(0) :- !.
dibujar_bloques(N) :- N > 0, write('█'), N1 is N - 1, dibujar_bloques(N1).

% ---------------------------------------------------------------------
% 8. VALORES DE MUESTRA  x_i -> f(x_i)
% ---------------------------------------------------------------------

mostrar_valores(M, Ancho) :-
    NMuestras = 10,
    MaxI is NMuestras - 1,
    forall(between(0, MaxI, I),
        ( X is min(Ancho-1, (I*Ancho) // NMuestras),
          nth0(X, M, F),
          format("x_~w = ~w  ->  f(x_~w) = ~w pixeles~n", [I, X, I, F]) )).

% ---------------------------------------------------------------------
% PUNTO DE ENTRADA
% ---------------------------------------------------------------------

resolver(Archivo) :-
    leer_pbm(Archivo, Ancho, Alto, Datos),
    bytes_por_fila(Ancho, BytesPorFila),
    vector_alturas(Datos, Alto, Ancho, BytesPorFila, M),
    area(M, Area),
    format("~n=== PRACTICA I - PROLOG ===~n"),
    format("Imagen: ~w x ~w pixeles~n", [Ancho, Alto]),
    format("Area = ~w pixeles cuadrados~n~n", [Area]),
    format("--- Vector de alturas M[x] = f(x) (grafico de barras) ---~n"),
    mostrar_alturas(M, Ancho),
    nl,
    format("--- Reconstruccion de la curva (muestreada a consola) ---~n"),
    mostrar_curva(M, Ancho),
    nl,
    format("--- Valores de muestra ---~n"),
    mostrar_valores(M, Ancho).
