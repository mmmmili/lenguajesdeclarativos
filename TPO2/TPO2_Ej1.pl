%Cambios para websocket
%------------------------------------------------------------
:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/websocket)).

:- dynamic conexion_jugador/2.
:- http_handler(/, aceptar_conexion, []).

aceptar_conexion(Request) :-
    http_upgrade_to_websocket(registrar_jugador, [], Request).

registrar_jugador(WebSocket) :-
    ws_send(WebSocket, text('Ingrese su nombre')),
    ws_receive(WebSocket, Reply),
    Nombre = Reply.data,
    assertz(conexion_jugador(Nombre, WebSocket)),
    findall(jugador(Nom, WebSocketID, [], [], 0, 0), conexion_jugador(Nom, WebSocketID), ListaJugadores),
    
    (   length(ListaJugadores, 2)
    ->  % El segundo jugador limpia la base y lanza el juego en un hilo nuevo
        retractall(conexion_jugador(_, _)),
        
        thread_create((
            sleep(0.1), 
            anunciar_inicio(ListaJugadores),
            phrase(escoba_loop(ListaJugadores, JugadoresFinales), [[mazo([]), mesa([]), jugadores([])]], _),
            determinar_ganador_final(JugadoresFinales)
        ), _, [detached(true)]),
        
        dormir_hasta_partida
        
    ;   % El primer jugador avisa y se queda durmiendo sin tocar la red
        ws_send(WebSocket, text('Esperando rival...')),
        dormir_hasta_partida
    ).

% Espera activa hasta que llegue un segundo jugador
dormir_hasta_partida :-
    sleep(1),
    dormir_hasta_partida.

anunciar_inicio(Jugadores) :- 
    forall(
            member(jugador(Nombre, IDWS, _, _, _, _), Jugadores),
            (
                atom_concat('Comienza el juego, ', Nombre, Mensaje),
                ws_send(IDWS, text(Mensaje))
                )
            ).
%----------------------------------------------------------------------------
% definiciones de base y mazo
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

% lógica matematica y busqueda

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

% impresión y lectura

%Muestra al usuario las opciones en cada turno
ejecutar_jugada_interactiva(jugador(Nom, IDWS, Mano, Gan, Pts, Esc), jugador(Nom, IDWS, R_Mano, NuevasGan, Pts, N_Esc), Mesa, R_Mesa):-
    ws_send(IDWS, text('Tu turno')),
    ws_send(IDWS, text('===============')),
    ws_send(IDWS, text('Tus cartas: ')),
    imprimir_mano(IDWS, Mano,1),
    ws_send(IDWS, text('===============')),
    findall(opt(CM, EM, RMesa, RMano), encontrar_15(Mano, Mesa, CM, EM, RMano, RMesa), Opciones),
    (Opciones \= [] ->
        % si hay opciones para levantar
        imprimir_opciones(IDWS, Opciones, 1),
        ws_send(IDWS, text('Elejí el número de jugada: ')),
        ws_receive(IDWS, R),
        normalize_space(atom(TextoLimpio), R.data),
        atom_number(TextoLimpio, Num),
        nth1(Num, Opciones, opt(CartaM, Elegidas, RMesa, RMano)),
        append([CartaM|Elegidas], Gan, NuevasGan),
        (RMesa == [] -> N_Esc is Esc + 1, ws_send(IDWS, text('¡¡¡ ESCOBA!!!')) ; N_Esc = Esc),
        R_Mesa = RMesa,
        R_Mano = RMano,
        ws_send(IDWS, text('Jugada realizada, esperando al rival....'))
    ;   % si no hay opciones entonces debe descartar
        ws_send(IDWS, text('No hay capturas. Elegí una carta para tirar: ')),
        imprimir_mano(IDWS, Mano, 1),
        ws_send(IDWS, text('Numero de carta: ')),
        ws_receive(IDWS, R),
        normalize_space(atom(TextoLimpio), R.data),
        atom_number(TextoLimpio, Num),
        nth1(Num, Mano, CartaTirada, R_Mano),
        R_Mesa = [CartaTirada|Mesa],
        NuevasGan = Gan,
        N_Esc = Esc,
        ws_send(IDWS, text('Carta lanzada, esperando al rival....'))
    ).



%Muestra las opciones que tiene para levantar de la mesa
imprimir_opciones(_, [], _).
imprimir_opciones(IDWS, [opt(CM, EM, _, _)|Resto], N):-
    format(string(Texto), '~w: Levantar ~w usando ~w de la mesa', [N, CM, EM]),
    ws_send(IDWS, text(Texto)),
    N1 is N+1,
    imprimir_opciones(IDWS, Resto, N1).
%Muestra las cartas que tiene el jugador en la mano
imprimir_mano([], _).
imprimir_mano([C|Resto], N):-
    format('~w: ~w~n', [N,C]),
    N1 is N+1,
    imprimir_mano(Resto, N1).

imprimir_mano(_, [], _).
imprimir_mano(IDWS, [C|Resto], N):-
    format(string(Texto), '~w: ~w', [N,C]),
    ws_send(IDWS, text(Texto)),
    N1 is N+1,
    imprimir_mano(IDWS, Resto, N1).

% flujo principal y recursión de puntos

%Predicado principal
escoba :-
    writeln('Ingrese el numero de puerto'),
    read(Puerto),
    % Borramos conexiones viejas por si quedó basura de una partida anterior
    retractall(conexion_jugador(_, _)),
    % Levantamos el servidor en red
    http_server(http_dispatch, [port(Puerto)]),
    format('=============================================~n', []),
    format('  SERVIDOR DE ESCOBA ACTIVO (Puerto ~d)~n', [Puerto]),
    format('  Esperando a que los jugadores se conecten...~n', []),
    format('=============================================~n', []).

obtener_puntajes([], []).
obtener_puntajes([jugador(_, _, _, _, P, _)|Ps], [P|Resto]) :-
    obtener_puntajes(Ps, Resto).

%Prepara el juego, lanza la ronda, y al final calcula los puntos
escoba_loop(JugadoresIniciales, JugadoresConPuntajeFinal) -->
    preparar_juego(JugadoresIniciales),
    jugar_partida,
    state(S),
    { 
        member(jugadores(PsFinalMano), S),
        calcular_puntajes_finales(PsFinalMano, JugadoresConPuntajeFinal) 
    }.

%Genera el mazo y coloca los jugadores en el estado inicial
preparar_juego(Jugadores) -->
    { generar_mazo(Mazo) },
    % Solo mazo y jugadores; la mesa la crea repartir_mesa_inicial
    state(_, [mazo(Mazo), jugadores(Jugadores)]),
    repartir_mesa_inicial.

% lógica de rondas y reparto (DCG)

%Mientras haya cartas se sigue jugando
jugar_partida -->
    state(S), 
    { member(mazo(Mazo), S), Mazo \= [] },
    repartir_a_todos,
    jugar_ronda_de_3,
    jugar_partida.
%Cuando no haya mas cartas, se termina el juego
jugar_partida, [S] -->
    [S],
    { member(mazo([]), S) },
    !,
    { writeln('No quedan mas cartas en el mazo.') }.

% Si el jugador actual de turno tiene cartas en la mano, jugamos el turno y seguimos
jugar_ronda_de_3 -->
    state(S),
    { member(jugadores([jugador(_, _, [_|_], _, _, _)|_]), S) }, % Tiene al menos una carta
    !,
    rotar_turno_jugador,
    jugar_ronda_de_3.

% Si el primer jugador ya tiene la mano vacía, cerramos la ronda de 3 de forma limpia
jugar_ronda_de_3 -->
    state(S),
    { member(jugadores([jugador(_, _, [], _, _, _)|_]), S) },
    { writeln('Se terminaron las 3 cartas de la mano. Repartiendo de nuevo...') }.

%Toma al primer jugador de la lista, hace que juege y luego lo manda al final de la lista para que juegue otro
rotar_turno_jugador -->
    state(S0, S),
    {
        member(jugadores([J|JugadoresRestantes]), S0),
        member(mesa(Mesa0), S0),
        member(mazo(Mazo), S0),
        Jugadores = [J|JugadoresRestantes],
        enviar_a_todos(Jugadores, '================='),
        format(string(Texto), 'Cartas en mesa: ~w', [Mesa0]),
        enviar_a_todos(Jugadores, Texto),
        enviar_a_todos(Jugadores, '================='),
        ejecutar_jugada_interactiva(J, J_Act, Mesa0, Mesa1),
        append(JugadoresRestantes, [J_Act], JugadoresRotados),
        S = [jugadores(JugadoresRotados), mesa(Mesa1), mazo(Mazo)]
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
repartir_manos_recursivo([jugador(N, IDWS, _, G, P, E)|Ps], [jugador(N, IDWS, Nuevas, G, P, E)|Ps1], M0, M) :-
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

% cálculo de puntajes

%calcula los puntajes finales
calcular_puntajes_finales(PtsFijos, PtsTotales) :-
    maplist(sumar_puntos_fijos, PtsFijos, PtsTemp),
    otorgar_punto_mayoria(PtsTemp, PtsTemp2, total),
    otorgar_punto_mayoria(PtsTemp2, PtsTemp3, oros),
    otorgar_punto_mayoria(PtsTemp3, PtsTotales, sietes).

%suma de puntos que no dependen del rival, 2 por cantidad de escobas y 1 punto por tener el 7 de oro
sumar_puntos_fijos(jugador(N, IDWS, M, G, P, E), jugador(N, IDWS, M, G, P_Act, 0)) :-
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
obtener_cantidad(total, jugador(_, _, _, G, _, _), Cant) :- length(G, Cant).   %1 punto por mayoria de cartas
obtener_cantidad(oros, jugador(_, _, _, G, _, _), Cant) :- findall(_, member(_-oro, G), L), length(L, Cant).   %1 punto por mayoria de oros
obtener_cantidad(sietes, jugador(_, _, _, G, _, _), Cant) :- findall(_, member(7-_, G), L), length(L, Cant).   %1 punto por mayoria de 7s

%encuentra al jugador al que le corresponde cada punto
sumar_si_es_maximo(Criterio, Max, J_In, J_Out) :-
    J_In = jugador(N, IDWS, M, G, P, E),
    obtener_cantidad(Criterio, J_In, Cant),
    (Cant == Max -> P1 is P + 1 ; P1 = P),
    J_Out = jugador(N, IDWS, M, G, P1, E).

%Obtiene los puntajes y determina al ganador del juego
determinar_ganador_final(Jugadores) :-
    obtener_puntajes(Jugadores, Puntajes),
    max_list(Puntajes, Max),
    
    % Buscamos todos los nombres que alcanzaron el puntaje máximo
    findall(Nombre, member(jugador(Nombre, _, _, _, Max, _), Jugadores), Ganadores),
    
    (   length(Ganadores, 1)
    ->  [GanadorUnico] = Ganadores,
        mostrar_tabla_final(Jugadores, GanadorUnico)
    ;   % Si hay más de uno, hay un empate
        atomic_list_concat(Ganadores, ' y ', NombresEmpatados),
        format(string(MensajeEmpate), '¡EMPATE! entre ~a', [NombresEmpatados]),
        mostrar_tabla_final(Jugadores, MensajeEmpate)
    ).

%se muestra la tabla final de puntos a todos los jugadores
mostrar_tabla_final(Jugadores, ResultadoFinal) :-
    enviar_a_todos(Jugadores, '===================================='),
    enviar_a_todos(Jugadores, '       ¡PARTIDA TERMINADA!          '),
    enviar_a_todos(Jugadores, '===================================='),
    
    forall(member(jugador(Nom, _, _, _, Pts, _), Jugadores),
           (
               format(string(LineaPuntos), 'Jugador: ~w  |  Puntos Totales: ~d', [Nom, Pts]),
               enviar_a_todos(Jugadores, LineaPuntos)
           )),
           
    enviar_a_todos(Jugadores, '------------------------------------'),
    
    % Si es ganador único dirá "EL GANADOR FINAL ES: Ignacio", si es empate dirá "EL GANADOR FINAL ES: ¡EMPATE! entre..."
    format(string(LineaGanador), '  EL RESULTADO FINAL ES: ~a', [ResultadoFinal]),
    enviar_a_todos(Jugadores, LineaGanador),
    enviar_a_todos(Jugadores, '====================================').

%envia u mensaje a todos los jugadores
enviar_a_todos(Jugadores, Mensaje) :- forall(member(jugador(_, IDWS, _, _, _, _), Jugadores), ws_send(IDWS, text(Mensaje))).

% auxiliares

%Obtener estado actual y cambios de estado
state(S), [S] --> [S].
state(S0, S), [S] --> [S0].

%Genera todas las combinaciones de una lista
subconjunto([], [], []).
subconjunto([X|Resto], [X|Sub], Otros) :- subconjunto(Resto, Sub, Otros).
subconjunto([X|Resto], Sub, [X|Otros]) :- subconjunto(Resto, Sub, Otros).