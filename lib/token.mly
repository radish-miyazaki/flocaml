/* Tokens are kept apart from the grammar so that the lexer depends only on
   this module and not on the parser. */

%token <string> ID
%token <int64> INT
%token <float> FLOAT

/* Literal text inside strings and paths. */
%token <string> STR
%token <string> IND_STR
%token <string> IND_STR_ESCAPE

%token <string> PATH
%token <string> HOME_PATH
%token <string> SEARCH_PATH
%token <string> URI
/* Zero-width token that closes a path, so that interpolations can follow
   the start of a path without whitespace in between. */
%token PATH_END

%token DQUOTE IND_STRING_OPEN IND_STRING_CLOSE DOLLAR_CURLY

%token IF THEN ELSE ASSERT WITH LET IN REC INHERIT OR_KW
%token ELLIPSIS

%token EQ NEQ LT GT LEQ GEQ AND OR IMPL UPDATE CONCAT
%token PIPE_INTO PIPE_FROM
%token PLUS MINUS STAR SLASH NOT QUESTION

%token LBRACE RBRACE LBRACKET RBRACKET LPAREN RPAREN
%token COLON SEMI COMMA DOT AT ASSIGN

%token EOF

%%
