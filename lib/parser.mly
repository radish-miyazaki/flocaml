%{
open Ast

let mk loc desc = { desc; loc = Location.of_positions loc }
let mkloc loc txt = { txt; loc = Location.of_positions loc }

(* The lexer may split one run of literal text into several tokens, for
   instance around a lone [$]. *)
let rec merge_text = function
  | Text a :: Text b :: rest -> merge_text (Text (a ^ b) :: rest)
  | part :: rest -> part :: merge_text rest
  | [] -> []
%}

%start <Ast.expr> main

/* From the loosest to the tightest. The pipe operators are handled by the
   grammar instead, because mixing them without parentheses is an error. */
%right IMPL
%left OR
%left AND
%nonassoc EQ NEQ
%nonassoc LT GT LEQ GEQ
%right UPDATE
%left NOT
%left PLUS MINUS
%left STAR SLASH
%right CONCAT
%nonassoc QUESTION
%nonassoc NEGATE

%%

main:
  | e = expr EOF { e }

expr:
  | e = expr_function { e }

expr_function:
  | x = ident COLON body = expr_function
    { mk $loc (Lambda (Param_var x, body)) }
  | p = pattern COLON body = expr_function
    { mk $loc (Lambda (Param_pattern p, body)) }
  | ASSERT cond = expr SEMI body = expr_function
    { mk $loc (Assert (cond, body)) }
  | WITH scope = expr SEMI body = expr_function
    { mk $loc (With (scope, body)) }
  | LET bindings = binding* IN body = expr_function
    { mk $loc (Let (bindings, body)) }
  | e = expr_if { e }

pattern:
  | f = formals
    { let formals, ellipsis = f in { formals; ellipsis; alias = None } }
  | f = formals AT x = ident
    { let formals, ellipsis = f in { formals; ellipsis; alias = Some x } }
  | x = ident AT f = formals
    { let formals, ellipsis = f in { formals; ellipsis; alias = Some x } }

formals:
  | LBRACE RBRACE { ([], false) }
  | LBRACE f = formal_list RBRACE { f }

formal_list:
  | ELLIPSIS { ([], true) }
  | f = formal ioption(COMMA) { ([ f ], false) }
  | f = formal COMMA rest = formal_list
    { let formals, ellipsis = rest in (f :: formals, ellipsis) }

formal:
  | name = ident { { name; default = None } }
  | name = ident QUESTION default = expr { { name; default = Some default } }

ident:
  | x = ID { mkloc $loc x }

expr_if:
  | IF cond = expr THEN then_ = expr ELSE else_ = expr
    { mk $loc (If (cond, then_, else_)) }
  | e = expr_pipe { e }

expr_pipe:
  | e = expr_op | e = pipe_into | e = pipe_from { e }

pipe_into:
  | l = expr_op PIPE_INTO r = expr_op
  | l = pipe_into PIPE_INTO r = expr_op
    { mk $loc (Binary (Pipe_into, l, r)) }

pipe_from:
  | l = expr_op PIPE_FROM r = expr_op
  | l = expr_op PIPE_FROM r = pipe_from
    { mk $loc (Binary (Pipe_from, l, r)) }

expr_op:
  | NOT e = expr_op %prec NOT { mk $loc (Unary (Not, e)) }
  | MINUS e = expr_op %prec NEGATE { mk $loc (Unary (Negate, e)) }
  | l = expr_op op = binary_op r = expr_op { mk $loc (Binary (op, l, r)) }
  | e = expr_op QUESTION path = attr_path { mk $loc (Has_attr (e, path)) }
  | e = expr_app { e }

%inline binary_op:
  | CONCAT { Concat }
  | STAR { Mul }
  | SLASH { Div }
  | PLUS { Add }
  | MINUS { Sub }
  | UPDATE { Update }
  | LT { Lt }
  | LEQ { Le }
  | GT { Gt }
  | GEQ { Ge }
  | EQ { Eq }
  | NEQ { Neq }
  | AND { And }
  | OR { Or }
  | IMPL { Implies }

expr_app:
  | f = expr_app arg = expr_select { mk $loc (Apply (f, arg)) }
  | e = expr_select { e }

expr_select:
  | e = expr_simple DOT path = attr_path
    { mk $loc (Select { expr = e; path; default = None }) }
  | e = expr_simple DOT path = attr_path OR_KW default = expr_select
    { mk $loc (Select { expr = e; path; default = Some default }) }
  (* [f or] applies [f] to a variable named [or], which Nix still accepts
     for backward compatibility. *)
  | f = expr_simple arg = or_var { mk $loc (Apply (f, arg)) }
  | e = expr_simple { e }

or_var:
  | OR_KW { mk $loc (Var "or") }

expr_simple:
  | x = ID { mk $loc (Var x) }
  | n = INT { mk $loc (Int n) }
  | n = FLOAT { mk $loc (Float n) }
  | DQUOTE parts = string_part* DQUOTE { mk $loc (String (merge_text parts)) }
  | IND_STRING_OPEN parts = indented_string_part* IND_STRING_CLOSE
    { mk $loc (Indented_string parts) }
  | head = path_head PATH_END { mk $loc (Path [ Text head ]) }
  | head = path_head tail = path_tail PATH_END
    { mk $loc (Path (Text head :: tail)) }
  | p = SEARCH_PATH { mk $loc (Search_path p) }
  | u = URI { mk $loc (Uri u) }
  | LPAREN e = expr RPAREN { mk $loc (Paren e) }
  | LET LBRACE bindings = binding* RBRACE { mk $loc (Legacy_let bindings) }
  | REC LBRACE bindings = binding* RBRACE
    { mk $loc (Attrs { recursive = true; bindings }) }
  | LBRACE bindings = binding+ RBRACE
    { mk $loc (Attrs { recursive = false; bindings }) }
  | LBRACE RBRACE { mk $loc (Attrs { recursive = false; bindings = [] }) }
  | LBRACKET elements = expr_select* RBRACKET { mk $loc (List elements) }

path_head:
  | p = PATH | p = HOME_PATH { p }

(* Text may follow the head of a path only after an interpolation, so
   [/a//b] is an error, as in Nix. *)
path_tail:
  | texts = text* i = interpolation rest = string_part*
    { texts @ (i :: rest) }

text:
  | s = STR { Text s }

interpolation:
  | DOLLAR_CURLY e = expr RBRACE { Interpolation e }

string_part:
  | p = text | p = interpolation { p }

indented_string_part:
  | s = IND_STR { Text s }
  | s = IND_STR_ESCAPE { Escape s }
  | p = interpolation { p }

binding:
  | path = attr_path ASSIGN e = expr SEMI { mkloc $loc (Assign (path, e)) }
  | INHERIT attrs = inherited_attr* SEMI { mkloc $loc (Inherit (None, attrs)) }
  | INHERIT LPAREN from = expr RPAREN attrs = inherited_attr* SEMI
    { mkloc $loc (Inherit (Some from, attrs)) }

attr_path:
  | path = separated_nonempty_list(DOT, attr) { path }

attr:
  | a = static_attr { a }
  | DOLLAR_CURLY e = expr RBRACE { mkloc $loc (Dynamic e) }

(* [inherit] takes no interpolation, as the attribute names must be known
   before evaluation. *)
inherited_attr:
  | a = name_attr { a }
  | DQUOTE parts = text* DQUOTE { mkloc $loc (Quoted (merge_text parts)) }

static_attr:
  | a = name_attr { a }
  | DQUOTE parts = string_part* DQUOTE { mkloc $loc (Quoted (merge_text parts)) }

name_attr:
  | x = ID { mkloc $loc (Name x) }
  | OR_KW { mkloc $loc (Name "or") }
