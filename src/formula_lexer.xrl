Definitions.

DIGIT       = [0-9]
LETTER      = [a-zA-Z]
IDENTIFIER  = [a-zA-Z_][a-zA-Z_0-9]*
WHITESPACE  = [\s\t\n\r]
EQUALS      = \=
PAREN_OPEN  = \(
PAREN_CLOSE = \)
PERIOD      = \.
COMMA       = ,

Rules.
{LETTER}{DIGIT}+         : {token, {coord, TokenLine, to_coord(TokenChars)}}.
{IDENTIFIER}             : {token, {ident, TokenLine, string:to_upper(TokenChars)}}.
{DIGIT}+{PERIOD}{DIGIT}+ : {token, {float, TokenLine, list_to_float(TokenChars)}}.
{DIGIT}+                 : {token, {int, TokenLine, list_to_integer(TokenChars)}}.
{EQUALS}                 : {token, {equals, TokenLine}}.
{PAREN_OPEN}             : {token, {paren_open, TokenLine}}.
{PAREN_CLOSE}            : {token, {paren_close, TokenLine}}.
{COMMA}                  : {token, {comma, TokenLine}}.
{WHITESPACE}+            : skip_token.

Erlang code.

to_coord([Column | Row]) ->
    {
        % Convert columns and rows into relative offsets
        string:to_upper(Column) - $A,
        list_to_integer(Row) - 1
    }.
