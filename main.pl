% --- Definiciones de Base (Tus predicados originales) ---

es_carta(Numero-Palo) :- 
    member(Palo, [oro, espada, basto, copa]),
    member(Numero, [rey, caballo, sota, 7, 6, 5, 4, 3, 2, ancho]).

valor_carta(Numero-Palo, N) :-
    es_carta(Numero-Palo),
    valor_aux(Numero, N).

valor_aux(rey, 10).
valor_aux(caballo, 9).
valor_aux(sota, 8).
valor_aux(N, N) :- member(N, [2, 3, 4, 5, 6, 7]).
valor_aux(ancho, 1).     

% --- Lógica de Suma ---

suma_cartas(Cartas, S) :-
    suma_cartas_(Cartas, 0, S).

suma_cartas_([], S, S).
suma_cartas_([Carta|Resto], Cont, Suma) :-
    valor_carta(Carta, Valor),
    Cont1 is Cont + Valor,
    suma_cartas_(Resto, Cont1, Suma).

suma_15(Cartas) :-
    suma_cartas(Cartas, 15).

% --- Generación del Mazo ---

generar_mazo(Mazo) :-
    findall(N-P, (member(P, [oro, espada, basto, copa]), member(N, [rey, caballo, sota, 7, 6, 5, 4, 3, 2, ancho])), Mazo).

% --- Lógica de Estados (DCG) ---

% repartir las cartas al jugador actual
repartir_jugador --> 
    [estado(Mazo, Mesa, _, Ganadas)], 
    {
        length(Nuevas, 3),
        append(Nuevas, RestoMazo, Mazo)
    },
    [estado(RestoMazo, Mesa, Nuevas, Ganadas)].

encontrar_15 -->
    [estado(Mazo, Mesa, Mano, Ganadas)],
    {
        select(CartaMano, Mano, RestoMano),
        subconjunto(Mesa, ElegidasMesa, RestoMesa),
        suma_15([CartaMano|ElegidasMesa]),
        append([CartaMano|ElegidasMesa], Ganadas, NuevasGanadas)
    },
    [estado(Mazo, RestoMesa, RestoMano, NuevasGanadas)].

% --- Auxiliares ---

subconjunto([], [], []).
subconjunto([X|Resto], [X|Sub], Otros) :- subconjunto(Resto, Sub, Otros).
subconjunto([X|Resto], Sub, [X|Otros]) :- subconjunto(Resto, Sub, Otros).