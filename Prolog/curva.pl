% Practica I - Area bajo la curva - Parte Prolog
% Jeronimo Espinosa Lopez

% Para correr:
%   ?- [curva].
%   ?- resolver('curva_binaria_P4.pbm').

:- initialization(main).

main :-
    ( current_prolog_flag(argv, [Archivo|_]) -> true ; Archivo = 'curva_binaria_P4.pbm' ),
    resolver(Archivo).

% --- lectura del pbm ---
% guardo todos los bytes en un termino compuesto (arg/3 accede en O(1))

leer_pbm(Archivo, Ancho, Alto, ArrayDatos) :-
    open(Archivo, read, Stream, [type(binary)]),
    leer_encabezado(Stream, Ancho, Alto),
    read_stream_to_codes(Stream, ListaBytes),
    close(Stream),
    ArrayDatos =.. [datos|ListaBytes].

leer_encabezado(Stream, Ancho, Alto) :-
    get_byte(Stream, _),   % P
    get_byte(Stream, _),   % 4
    leer_numero(Stream, Ancho),
    leer_numero(Stream, Alto),
    get_byte(Stream, _).   % espacio antes de los datos binarios

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

% --- acceso a pixeles ---
% en P4, bit 1 = negro, bit 0 = blanco. bit mas significativo = pixel de mas a la izquierda

bytes_por_fila(Ancho, BytesPorFila) :-
    BytesPorFila is (Ancho + 7) // 8.

pixel(X, Y, Datos, BytesPorFila, Bit) :-
    ByteIndex is Y*BytesPorFila + X // 8,
    Idx is ByteIndex + 1,
    arg(Idx, Datos, Byte),
    BitPos is 7 - (X mod 8),
    Bit is (Byte >> BitPos) /\ 1.

es_negro(X, Y, Datos, BytesPorFila) :- pixel(X, Y, Datos, BytesPorFila, 1).

% --- f(x): pixeles negros consecutivos desde abajo ---

altura(X, Datos, Alto, BytesPorFila, F) :-
    YInicial is Alto - 1,
    contar_negros(X, YInicial, Datos, BytesPorFila, 0, F).

contar_negros(X, Y, Datos, BytesPorFila, Acc, F) :-
    Y >= 0,
    es_negro(X, Y, Datos, BytesPorFila), !,
    Y1 is Y - 1, Acc1 is Acc + 1,
    contar_negros(X, Y1, Datos, BytesPorFila, Acc1, F).
contar_negros(_, _, _, _, Acc, Acc).

% --- vector de alturas M = [f(0), f(1), ..., f(n-1)] ---
% findall busca todos los F que cumplen la relacion altura/5 para cada X

vector_alturas(Datos, Alto, Ancho, BytesPorFila, M) :-
    MaxX is Ancho - 1,
    findall(F,
        ( between(0, MaxX, X), altura(X, Datos, Alto, BytesPorFila, F) ),
        M).

% --- area (riemann, delta x = 1) ---

area(M, Area) :- sum_list(M, Area).

% --- visualizacion en consola ---
% la imagen original es mas ancha que la terminal, entonces tomo 80 muestras
% distribuidas uniformemente en vez de recorrer cada columna, y reescalo
% las alturas para que quepan en una cantidad fija de filas/caracteres

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
    MaxI is NOut - 1,
    findall(V,
        ( between(0, MaxI, I),
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
dibujar_bloques(N) :- N > 0, write('#'), N1 is N - 1, dibujar_bloques(N1).

% --- valores de muestra x_i -> f(x_i) ---

mostrar_valores(M, Ancho) :-
    NMuestras = 10,
    MaxI is NMuestras - 1,
    forall(between(0, MaxI, I),
        ( X is min(Ancho-1, (I*Ancho) // NMuestras),
          nth0(X, M, F),
          format("x_~w = ~w  ->  f(x_~w) = ~w pixeles~n", [I, X, I, F]) )).

resolver(Archivo) :-
    leer_pbm(Archivo, Ancho, Alto, Datos),
    bytes_por_fila(Ancho, BytesPorFila),
    vector_alturas(Datos, Alto, Ancho, BytesPorFila, M),
    area(M, Area),
    format("~nImagen: ~w x ~w pixeles~n", [Ancho, Alto]),
    format("Area = ~w pixeles cuadrados~n~n", [Area]),
    format("Vector de alturas M[x] = f(x):~n"),
    mostrar_alturas(M, Ancho),
    nl,
    format("Curva reconstruida:~n"),
    mostrar_curva(M, Ancho),
    nl,
    format("Valores de muestra:~n"),
    mostrar_valores(M, Ancho).