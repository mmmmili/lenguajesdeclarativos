
es_carta(Numero-Palo) :- 
    member(Palo, [oro, espada, basto, copa]),
    member(Numero, [rey, caballo, sota, 7, 6, 5, 4, 3, 2, ancho]).

% valor de las cartas

valor_carta(Numero-Palo,N) :-
    es_carta(Numero-Palo),
    valor_aux(Numero,N).
valor_aux(rey,10).
valor_aux(caballo,9).
valor_aux(sota,8).
valor_aux(N,N) :- member(N,[2,3,4,5,6,7]).
valor_aux(ancho,1).     

% suma de cartas tail recursive

suma_cartas(Cartas,S):-
    suma_cartas_(Cartas,0,S).

suma_cartas_([],S,S).
suma_cartas_([Carta|Resto],Cont,Suma) :-
    valor_carta(Carta,Valor),
    Cont1 is Cont + Valor,
    suma_cartas_(Resto,Cont1,Suma).

% suma de cartas que suman 15

suma_15(Cartas):-
    suma_cartas(Cartas,15).





%escoba :- phrase(escoba,[_],[_]).

%escoba -->
%    resetear,
%    mezclar_cartas,
%    crear_jugadores([]),
%    jugar,
%    mostrar_puntajes.

%resetear -->
%    state(_,[stock(Cartas)]),
%    {
%        
%    }.