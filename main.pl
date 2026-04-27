% ---DEFINICIONES DE BASE Y MAZO ---
%Determina si cumple con el formato de carta
es_carta(Numero-Palo) :- 
    member(Palo, [oro, espada, basto, copa]),
    member(Numero, [rey, caballo, sota, 7, 6, 5, 4, 3, 2, ancho]).

%indica el valor de una carta
valor_carta(Numero-Palo, N) :-
    es_carta(Numero-Palo),
    valor_aux(Numero, N).
valor_aux(rey, 10).
valor_aux(caballo, 9).
valor_aux(sota, 8).
valor_aux(ancho, 1).
valor_aux(N, N) :- member(N, [2, 3, 4, 5, 6, 7]).

%Generación del mazo de manera random
generar_mazo(MazoMezclado) :-
    findall(N-P, (
        member(P, [oro, espada, basto, copa]), 
        member(N, [rey, caballo, sota, 7, 6, 5, 4, 3, 2, ancho])
    ), MazoOrdenado),
    random_permutation(MazoOrdenado, MazoMezclado).

% ---LÓGICA MATEMÁTICA Y BÚSQUEDA (MOTOR) ---

%Suma los valores de un conjunto de cartas
suma_cartas(Cartas, S) :-
    suma_cartas_(Cartas, 0, S).

%auxiliar tail recursivo
suma_cartas_([], S, S).
suma_cartas_([Carta|Resto], Cont, Suma) :-
    valor_carta(Carta, Valor),
    Cont1 is Cont + Valor,
    suma_cartas_(Resto, Cont1, Suma).

%indica si la suma de los valores da 15
suma_15(Cartas) :-
    suma_cartas(Cartas, 15).

%encuentra la combinacion de cartas que sume 15
encontrar_15(Mano, Mesa, CartaMano, ElegidasMesa, RestoMano, RestoMesa) :-
    select(CartaMano, Mano, RestoMano),
    subconjunto(Mesa, ElegidasMesa, RestoMesa),
    suma_15([CartaMano|ElegidasMesa]).

% ---INTERFAZ DE USUARIO (IMPRESIÓN Y LECTURA) ---

%Muestra al usuario las opciones en cada turno
ejecutar_jugada_interactiva(jugador(Nom, Mano, Gan, Pts, Esc), jugador(Nom, R_Mano, NuevasGan, Pts, N_Esc), Mesa, R_Mesa) :-
    format('~nTurno de: ~a~n', [Nom]),
    format('~n=================', []),
    format('~nTus cartas: ',[]),
    imprimir_mano(Mano,1),
    format('~n=================~n', []),
    findall(opt(CM, EM, RMes, RMan), encontrar_15(Mano, Mesa, CM, EM, RMan, RMes), Opciones),
    (Opciones \= [] ->
        %si hay opciones para levantar
        imprimir_opciones(Opciones, 1),                 
        write('Elegi el numero de jugada: '),
        read(Num),
        nth1(Num, Opciones, opt(CartaM, Elegidas, R_Mesa, R_Mano)),
        append([CartaM|Elegidas], Gan, NuevasGan),
        (R_Mesa == [] -> N_Esc is Esc + 1, writeln('¡¡¡ ESCOBA !!!') ; N_Esc = Esc)
    ;   %si no hay opciones entonces debe descartar
        writeln('No hay capturas. Elegi una carta para tirar:'),
        imprimir_mano(Mano, 1),
        write('Numero de carta: '),
        read(Num),
        nth1(Num, Mano, CartaTirada, R_Mano),
        R_Mesa = [CartaTirada|Mesa],
        NuevasGan = Gan,
        N_Esc = Esc
    ).

%Muestra las opciones que tiene para levantar de la mesa
imprimir_opciones([], _).
imprimir_opciones([opt(CM, EM, _,_)|Resto], N):-
    format('~w: Levantar ~w usando ~w de la mesa~n', [N, CM, EM]),
    N1 is N+1,
    imprimir_opciones(Resto, N1).
%Muestra las cartas que tiene el jugador en la mano
imprimir_mano([], _).
imprimir_mano([C|Resto], N):-
    format('~w: ~w~n', [N,C]),
    N1 is N+1,
    imprimir_mano(Resto, N1).

% ---FLUJO PRINCIPAL Y RECURSIÓN DE PUNTOS ---

%Predicado principal
escoba :- 
% Inicializamos jugadores, cada uno tiene (nombre, Mano, cartas ganadas, puntaje acumulado, cantidad de escobas)
    Jugadores = [jugador('Ignacio', [], [], 0, 0), 
                jugador('Mili', [], [], 0, 0)
                ],
    % Iniciamos el juego
    phrase(escoba_loop(Jugadores, JugadoresFinales), [[mazo([]), mesa([]), jugadores([])]], [_]),
    % Calculamos quién ganó esa única mano
    determinar_ganador_final(JugadoresFinales).

obtener_puntajes([], []).
obtener_puntajes([jugador(_, _, _, P, _)|Ps], [P|Resto]) :-
    obtener_puntajes(Ps, Resto).

%Prepara el juego, lanza la ronda, y al final calcula los puntos
escoba_loop(PtsFijos, PtsTotales) -->
    preparar_juego(PtsFijos),
    jugar_partida,
    state(S),
    { 
        member(jugadores(PsFinalMano), S),
        calcular_puntajes_finales(PsFinalMano, PtsTotales) 
    }.

%Genera el mazo y coloca los jugadores en el estado inicial
preparar_juego(PtsFijos) -->
    { generar_mazo(Mazo) },
    % Solo mazo y jugadores; la mesa la crea repartir_mesa_inicial
    state(_, [mazo(Mazo), jugadores(PtsFijos)]),
    repartir_mesa_inicial.

% --- LÓGICA DE RONDAS Y REPARTO (DCG) ---

%Mientras haya cartas se sigue jugando
jugar_partida -->
    state(S), 
    { member(mazo(Mazo), S), Mazo \= [] },
    repartir_a_todos,
    jugar_ronda_de_3,
    jugar_partida.
%Cuando no haya mas cartas, se termina el juego
jugar_partida -->
    state(S),
    { member(mazo([]), S) },
    { writeln('No quedan mas cartas en el mazo.') }.

%Si se usaron todas las cartas de la mano entonces se vuelve a repartir
jugar_ronda_de_3 -->
    state(S), { member(jugadores([jugador(_, [], _, _, _)|_]), S) }, !.
%Mientras los jugadores tengan cartas entonces sigue la ronda
jugar_ronda_de_3 -->
    rotar_turno_jugador,
    jugar_ronda_de_3.

%Toma al primer jugador de la lista, hace que juege y luego lo manda al final de la lista para que juegue otro
rotar_turno_jugador -->
    state(S0, S),
    {
        select(jugadores([P|Ps]), S0, S1),
        select(mesa(Mesa0), S1, S2),
        format('~n=================', []),
        format('~nCartas en mesa: ~w', [Mesa0]),
        format('~n=================', []),
        ejecutar_jugada_interactiva(P, P_Act, Mesa0, Mesa1),
        append(Ps, [P_Act], JugadoresRotados),
        S = [jugadores(JugadoresRotados), mesa(Mesa1)|S2]
    }.

%Reparte 3 cartas a cada jugador para iniciar la ronda
repartir_a_todos -->
    state(S0, S),
    {
        select(mazo(M0), S0, S1),
        select(jugadores(Ps0), S1, S2),
        repartir_manos_recursivo(Ps0, Ps1, M0, M1),
        S = [jugadores(Ps1), mazo(M1)|S2]
    }.
%Auxiliar recursivo para repartir
repartir_manos_recursivo([], [], M, M).
repartir_manos_recursivo([jugador(N, _, G, P, E)|Ps], [jugador(N, Nuevas, G, P, E)|Ps1], M0, M) :-
    length(Nuevas, 3),
    append(Nuevas, M1, M0),
    repartir_manos_recursivo(Ps, Ps1, M1, M).

%Coloca las primeras 4 cartas en la mesa
repartir_mesa_inicial -->
    state(S0, S),
    {
        select(mazo(M0), S0, S1),
        length(Cuatro, 4),
        append(Cuatro, RestoMazo, M0),
        S = [mesa(Cuatro), mazo(RestoMazo)|S1]
    }.

% ---CÁLCULO DE PUNTAJES (REGLAS REALES) ---

%calcula los puntajes finales
calcular_puntajes_finales(PtsFijos, PtsTotales) :-
    maplist(sumar_puntos_fijos, PtsFijos, PtsTemp),
    otorgar_punto_mayoria(PtsTemp, PtsTemp2, total),
    otorgar_punto_mayoria(PtsTemp2, PtsTemp3, oros),
    otorgar_punto_mayoria(PtsTemp3, PtsTotales, sietes).

%suma de puntos que no dependen del rival, 2 por cantidad de escobas y 1 punto por tener el 7 de oro
sumar_puntos_fijos(jugador(N, _, G, P, E), jugador(N, [], [], P_Act, 0)) :-
    P_Escobas is E * 2,
    (member(7-oro, G) -> P_Siete = 1 ; P_Siete = 0),
    P_Act is P + P_Escobas + P_Siete.

%otorga los puntos solo al jugador que cumpla con las condiciones
otorgar_punto_mayoria(PtsFijos, PtsTotales, Criterio) :-
    maplist(obtener_cantidad(Criterio), PtsFijos, Cantidades),
    max_list(Cantidades, Max),
    include(==(Max), Cantidades, Ganadores),
    (length(Ganadores, 1) ->
        maplist(sumar_si_es_maximo(Criterio, Max), PtsFijos, PtsTotales)
    ;
        PtsTotales = PtsFijos
    ).
%Auxiliares para calcular las cantidades
obtener_cantidad(total, jugador(_, _, G, _, _), Cant) :- length(G, Cant).   %1 punto por mayoria de cartas
obtener_cantidad(oros, jugador(_, _, G, _, _), Cant) :- findall(_, member(_-oro, G), L), length(L, Cant).   %1 punto por mayoria de oros
obtener_cantidad(sietes, jugador(_, _, G, _, _), Cant) :- findall(_, member(7-_, G), L), length(L, Cant).   %1 punto por mayoria de 7s

%encuentra al jugador al que le corresponde cada punto
sumar_si_es_maximo(Criterio, Max, J_In, J_Out) :-
    J_In = jugador(N, M, G, P, E),
    obtener_cantidad(Criterio, J_In, Cant),
    (Cant == Max -> P1 is P + 1 ; P1 = P),
    J_Out = jugador(N, M, G, P1, E).

%Obtiene los puntajes y determina al ganador del juego
determinar_ganador_final(Jugadores) :-
    obtener_puntajes(Jugadores, Puntajes),
    max_list(Puntajes, Max),
    member(jugador(Nombre, _, _, Max, _), Jugadores),
    mostrar_tabla_final(Jugadores, Nombre).

% Busca quién tiene el 7 de oro
quien_tiene_el_7(Jugadores, Nombre) :-
    member(jugador(Nombre, _, Ganadas, _, _), Jugadores),
    member(7-oro, Ganadas), !.
quien_tiene_el_7(_, 'Nadie').

% Busca quién ganó la mayoría de una categoría
quien_gano_mayoria(Jugadores, Criterio, Nombre) :-
    maplist(obtener_cantidad(Criterio), Jugadores, Cantidades),
    max_list(Cantidades, Max),
    % Filtramos quiénes llegaron al máximo
    include(==(Max), Cantidades, Ganadores),
    (length(Ganadores, 1) -> 
        % Si hay uno solo, buscamos su nombre
        member(jugador(Nombre, _, G, _, _), Jugadores),
        obtener_cantidad(Criterio, jugador(Nombre, _, G, _, _), Max)
    ; 
        % Si hay empate o nadie sumó, devolvemos 'Empate'
        Nombre = 'Empate'
    ).

%Se muestra la tabla de puntajes al final
mostrar_tabla_final(Jugadores, Ganador) :-
    % Calculamos los hitos para mostrar
    quien_tiene_el_7(Jugadores, SieteOro),
    quien_gano_mayoria(Jugadores, total, MasCartas),
    quien_gano_mayoria(Jugadores, oros, MasOros),

    format('~n====================================', []),
    format('~n       ¡PARTIDA TERMINADA!          ', []),
    format('~n====================================', []),
    forall(member(jugador(Nom, _, _, Pts,_), Jugadores),
           format('~nJugador: ~w  |  Puntos Totales: ~d', [Nom, Pts])),
    
    format('~n------------------------------------', []),
    format('~nRESUMEN DE ESTA MANO:', []),
    format('~n- 7 de Oro: ~w', [SieteOro]),
    format('~n- Más Cartas: ~w', [MasCartas]),
    format('~n- Más Oros: ~w', [MasOros]),
    format('~n------------------------------------', []),
    format('~n  EL GANADOR FINAL ES: ~a', [Ganador]),
    format('~n====================================~n', []).

% ---AUXILIARES ---

%Estado actual y cambios de estado
state(S), [S] --> [S].
state(S0, S), [S] --> [S0].

%Genera todas las combinaciones de una lista
subconjunto([], [], []).
subconjunto([X|Resto], [X|Sub], Otros) :- subconjunto(Resto, Sub, Otros).
subconjunto([X|Resto], Sub, [X|Otros]) :- subconjunto(Resto, Sub, Otros).