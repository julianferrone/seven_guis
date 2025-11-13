Nonterminals formula number arguments expr application.
Terminals paren_open paren_close comma equals float int coord ident.
Rootsymbol formula.

number -> float : remove_line('$1').
number -> int   : remove_line('$1').

arguments -> expr                 : ['$1'].
arguments -> expr comma arguments : ['$1' | '$3'].

application -> ident paren_open paren_close           : {appl, remove_line('$1'), []}.
application -> ident paren_open arguments paren_close : {appl, remove_line('$1'), '$3'}.

expr -> coord       : remove_line('$1').
expr -> number      : '$1'.
expr -> application : '$1'.

formula -> number      : '$1'.
formula -> equals expr : {expr, '$2'}.

Erlang code.

remove_line({Atom, _Line, Value})  -> {Atom, Value}.