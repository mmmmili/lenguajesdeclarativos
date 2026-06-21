

:- dynamic mi_nombre/1.
:- dynamic mi_mano/1.
:- dynamic mesa_actual/1.
:- dynamic opciones_actuales/1.   
:- dynamic modo_actual/1.        
:- dynamic contexto_lectura/1.    
:- dynamic ultimo_mensaje/1.


iniciar_cliente(Nombre) :-
    retractall(mi_nombre(_)),
    retractall(mi_mano(_)),
    retractall(mesa_actual(_)),
    retractall(opciones_actuales(_)),
    retractall(modo_actual(_)),
    retractall(contexto_lectura(_)),
    retractall(ultimo_mensaje(_)),
    assert(mi_nombre(Nombre)),
    assert(mi_mano([])),
    assert(mesa_actual([])),
    assert(opciones_actuales([])),
    assert(modo_actual(esperando)),
    assert(contexto_lectura(ninguno)),
    assert(ultimo_mensaje('')).



recibir_linea(Texto, Accion) :-
    retractall(ultimo_mensaje(_)),
    assert(ultimo_mensaje(Texto)),
    interpretar(Texto, Accion),
    aplicar_efecto(Texto, Accion).

% --- reglas de interpretación---

interpretar(Texto, pedir_nombre) :-
    Texto == "Ingrese su nombre", !.

interpretar(Texto, esperando_rival) :-
    Texto == "Esperando rival...", !.

interpretar(Texto, inicio_juego(Texto)) :-
    sub_atom(Texto, 0, _, _, 'Comienza el juego'), !.

interpretar(Texto, ignorar) :-
    sub_atom(Texto, 0, _, _, '====='), !.

interpretar(Texto, actualizar_mesa(Cartas)) :-
    sub_atom(Texto, 0, _, Resto, 'Cartas en mesa: '),
    sub_atom(Texto, _, Resto, 0, ListaStr),
    parsear_lista_cartas(ListaStr, Cartas), !.

interpretar(Texto, inicio_turno) :-
    Texto == "Tu turno", !.

interpretar(Texto, mostrar_mano) :-
    sub_atom(Texto, 0, _, _, 'Tus cartas'), !.

interpretar(Texto, opcion_captura) :-
    sub_atom(Texto, _, _, _, ': Levantar '), !.

interpretar(Texto, sin_capturas) :-
    sub_atom(Texto, 0, _, _, 'No hay capturas'), !.

interpretar(Texto, linea_numerada(Carta)) :-
    % formato "N: numero-palo"
    split_string(Texto, ":", "", [_NumStr, RestoStr]),
    normalize_space(string(CartaStr), RestoStr),
    sub_atom(CartaStr, _, _, _, '-'),
    \+ sub_atom(CartaStr, _, _, _, ' '),
    term_to_atom(Carta, CartaStr), !.

interpretar(Texto, pedir_jugada) :-
    sub_atom(Texto, 0, _, _, 'Elej'), !.

interpretar(Texto, pedir_descarte) :-
    sub_atom(Texto, 0, _, _, 'Numero de carta'), !.

interpretar(Texto, escoba) :-
    sub_atom(Texto, _, _, _, 'ESCOBA'), !.

interpretar(Texto, jugada_realizada) :-
    ( sub_atom(Texto, 0, _, _, 'Jugada realizada')
    ; sub_atom(Texto, 0, _, _, 'Carta lanzada')
    ), !.

interpretar(Texto, fin_partida) :-
    sub_atom(Texto, _, _, _, 'PARTIDA TERMINADA'), !.

interpretar(Texto, linea_resultado(Texto)) :-
    ( sub_atom(Texto, 0, _, _, 'Jugador: ')
    ; sub_atom(Texto, 0, _, _, '  EL RESULTADO FINAL ES')
    ), !.

interpretar(Texto, ignorar) :-
    sub_atom(Texto, 0, _, _, '------'), !.

interpretar(Texto, puntaje_parcial(Texto)) :-
    sub_atom(Texto, 0, _, _, 'PUNTAJE: '), !.

interpretar(Texto, info(Texto)).  % default: cualquier otra cosa, mostrar como info

% actualizan el estado dinámico segun lo interpretado


aplicar_efecto(_, actualizar_mesa(Cartas)) :-
    !, retractall(mesa_actual(_)), assert(mesa_actual(Cartas)).

aplicar_efecto(_, inicio_turno) :-
    !,
    retractall(mi_mano(_)), assert(mi_mano([])),
    retractall(opciones_actuales(_)), assert(opciones_actuales([])),
    retractall(modo_actual(_)), assert(modo_actual(esperando)).

aplicar_efecto(_, mostrar_mano) :-
    !, retractall(contexto_lectura(_)), assert(contexto_lectura(mano)).

aplicar_efecto(_, sin_capturas) :-
    !,
    retractall(contexto_lectura(_)), assert(contexto_lectura(mano)),
    retractall(mi_mano(_)), assert(mi_mano([])),
    retractall(modo_actual(_)), assert(modo_actual(descartar)).

aplicar_efecto(Texto, opcion_captura) :-
    !,
    retractall(contexto_lectura(_)), assert(contexto_lectura(opciones)),
    opciones_actuales(Op),
    retractall(opciones_actuales(_)),
    append(Op, [Texto], Op1),
    assert(opciones_actuales(Op1)).

aplicar_efecto(_, linea_numerada(Carta)) :-
    !,
    contexto_lectura(Ctx),
    ( Ctx == mano ->
        mi_mano(M), retractall(mi_mano(_)), append(M, [Carta], M1), assert(mi_mano(M1))
    ; true
    ).

aplicar_efecto(_, pedir_jugada) :-
    !, retractall(modo_actual(_)), assert(modo_actual(capturar)).

aplicar_efecto(_, pedir_descarte) :-
    !, retractall(modo_actual(_)), assert(modo_actual(descartar)).

aplicar_efecto(_, fin_partida) :-
    !, retractall(modo_actual(_)), assert(modo_actual(terminado)).

aplicar_efecto(_, jugada_realizada) :-
    !, retractall(mi_mano(_)), assert(mi_mano([])).

aplicar_efecto(_, _).  % cualquier otro caso, no hay efecto extra


% parseo de listas de cartas en formato:  [7-oro,4-basto]


parsear_lista_cartas(Str, Cartas) :-
    atom_string(Atom, Str),
    atom_concat('[', Resto0, Atom),
    atom_concat(Inner, ']', Resto0),
    ( Inner == '' -> Cartas = []
    ; split_string(Inner, ",", " ", Partes),
      maplist(parsear_carta, Partes, Cartas)
    ).

parsear_carta(Str, Carta) :-
    term_to_atom(Carta, Str).



%%

obtener_mano(Mano) :- mi_mano(Mano).
obtener_mesa(Mesa) :- mesa_actual(Mesa).
obtener_opciones(Opciones) :- opciones_actuales(Opciones).
obtener_modo(Modo) :- modo_actual(Modo).


responder_indice(Indice, TextoRespuesta) :-
    number_string(Indice, TextoRespuesta).