open Token

type mode =
  | Default
  | String
  | Indented_string
  | In_path  (** After a path segment, where an interpolation may follow. *)
  | In_path_slash  (** As [In_path], but the segment ended with [/]. *)

type t = {
  buf : Sedlexing.lexbuf;
  features : Feature.t list;
  mutable modes : mode list;
  mutable comments : Ast.comment list;
}

exception Error of Syntax_error.t

let create ?(features = []) buf =
  { buf; features; modes = [ Default ]; comments = [] }

let comments t = List.rev t.comments
let push t mode = t.modes <- mode :: t.modes

(* An unbalanced [}] leaves the bottom mode in place and lets the parser
   report the error. *)
let pop t = match t.modes with [] | [ _ ] -> () | _ :: rest -> t.modes <- rest

let replace t mode =
  pop t;
  push t mode

let lexeme t = Sedlexing.Latin1.lexeme t.buf

let emit t token =
  let start, stop = Sedlexing.lexing_positions t.buf in
  (token, start, stop)

let error t kind =
  let loc = Location.of_positions (Sedlexing.lexing_positions t.buf) in
  raise (Error { kind; loc })

let after_path t s =
  push t (if String.ends_with ~suffix:"/" s then In_path_slash else In_path)

let decode_escape = function 'n' -> '\n' | 'r' -> '\r' | 't' -> '\t' | c -> c

(* Decodes backslash escapes and turns CR and CRLF into LF, as Nix does for
   double-quoted strings. *)
let unescape s =
  let n = String.length s in
  let b = Buffer.create n in
  let rec go i =
    if i < n then
      match s.[i] with
      | '\\' when i + 1 < n ->
          Buffer.add_char b (decode_escape s.[i + 1]);
          go (i + 2)
      | '\r' ->
          Buffer.add_char b '\n';
          go (if i + 1 < n && s.[i + 1] = '\n' then i + 2 else i + 1)
      | c ->
          Buffer.add_char b c;
          go (i + 1)
  in
  go 0;
  Buffer.contents b

let digit = [%sedlex.regexp? '0' .. '9']
let alpha = [%sedlex.regexp? 'a' .. 'z' | 'A' .. 'Z']

let ident =
  [%sedlex.regexp? (alpha | '_'), Star (alpha | digit | '_' | '\'' | '-')]

let int = [%sedlex.regexp? Plus digit]

let float =
  [%sedlex.regexp?
    ( ('1' .. '9', Star digit, '.', Star digit | Opt '0', '.', Plus digit),
      Opt (('e' | 'E'), Opt ('+' | '-'), Plus digit) )]

let path_char = [%sedlex.regexp? alpha | digit | '.' | '_' | '-' | '+']
let path = [%sedlex.regexp? Star path_char, Plus ('/', Plus path_char), Opt '/']
let path_segment = [%sedlex.regexp? Star path_char, '/']
let home_path = [%sedlex.regexp? '~', Plus ('/', Plus path_char), Opt '/']
let home_path_start = [%sedlex.regexp? "~/"]

let search_path =
  [%sedlex.regexp? '<', Plus path_char, Star ('/', Plus path_char), '>']

let uri =
  [%sedlex.regexp?
    ( alpha,
      Star (alpha | digit | '+' | '-' | '.'),
      ':',
      Plus
        ( alpha | digit | '%' | '/' | '?' | ':' | '@' | '&' | '=' | '+' | '$'
        | ',' | '-' | '_' | '.' | '!' | '~' | '*' | '\'' ) )]

let whitespace = [%sedlex.regexp? Plus (' ' | '\t' | '\r' | '\n')]
let line_comment = [%sedlex.regexp? '#', Star (Compl ('\r' | '\n'))]

let block_comment =
  [%sedlex.regexp?
    "/*", Star (Compl '*' | Plus '*', Compl ('*' | '/')), Plus '*', '/']

(* A [$] is literal unless it starts [${]; [$$] keeps the second [$]
   literal too, so ["$${x}"] contains no interpolation. *)
let string_char =
  [%sedlex.regexp?
    ( Compl ('$' | '"' | '\\')
    | '$', Compl ('{' | '"' | '\\')
    | '\\', any
    | '$', '\\', any )]

let indented_char =
  [%sedlex.regexp?
    Compl ('$' | '\'') | '$', Compl ('{' | '\'') | '\'', Compl ('\'' | '$')]

let add_comment t kind =
  let loc = Location.of_positions (Sedlexing.lexing_positions t.buf) in
  t.comments <- { Ast.kind; text = lexeme t; loc } :: t.comments

let feature t feature token =
  if List.mem feature t.features then emit t token
  else error t (Disabled_feature feature)

let rec token t =
  match t.modes with
  | Default :: _ | [] -> default t
  | String :: _ -> string t
  | Indented_string :: _ -> indented_string t
  | ((In_path | In_path_slash) as mode) :: _ -> in_path t mode

and default t =
  let buf = t.buf in
  match%sedlex buf with
  | whitespace -> default t
  | line_comment ->
      add_comment t Line;
      default t
  | block_comment ->
      add_comment t Block;
      default t
  | "/*" -> error t Unterminated_comment
  | "if" -> emit t IF
  | "then" -> emit t THEN
  | "else" -> emit t ELSE
  | "assert" -> emit t ASSERT
  | "with" -> emit t WITH
  | "let" -> emit t LET
  | "in" -> emit t IN
  | "rec" -> emit t REC
  | "inherit" -> emit t INHERIT
  | "or" -> emit t OR_KW
  | "..." -> emit t ELLIPSIS
  | "==" -> emit t EQ
  | "!=" -> emit t NEQ
  | "<=" -> emit t LEQ
  | ">=" -> emit t GEQ
  | "&&" -> emit t AND
  | "||" -> emit t OR
  | "->" -> emit t IMPL
  | "//" -> emit t UPDATE
  | "++" -> emit t CONCAT
  | "|>" -> feature t Pipe_operators PIPE_INTO
  | "<|" -> feature t Pipe_operators PIPE_FROM
  | ident -> emit t (ID (lexeme t))
  | int -> (
      let s = lexeme t in
      match Int64.of_string_opt s with
      | Some n -> emit t (INT n)
      | None -> error t (Invalid_integer s))
  | float -> emit t (FLOAT (float_of_string (lexeme t)))
  | "${" ->
      push t Default;
      emit t DOLLAR_CURLY
  | '{' ->
      push t Default;
      emit t LBRACE
  | '}' ->
      pop t;
      emit t RBRACE
  | '"' ->
      push t String;
      emit t DQUOTE
  | "''", Opt (Star ' ', '\n') ->
      push t Indented_string;
      emit t IND_STRING_OPEN
  (* Only the head of the path belongs to this token; read it again without
     the [${]. *)
  | (path_segment | home_path_start), "${" ->
      Sedlexing.rollback buf;
      path_head t
  | path ->
      let s = lexeme t in
      after_path t s;
      emit t (PATH s)
  | home_path ->
      let s = lexeme t in
      after_path t s;
      emit t (HOME_PATH s)
  | search_path ->
      let s = lexeme t in
      emit t (SEARCH_PATH (String.sub s 1 (String.length s - 2)))
  | uri -> emit t (URI (lexeme t))
  | '(' -> emit t LPAREN
  | ')' -> emit t RPAREN
  | '[' -> emit t LBRACKET
  | ']' -> emit t RBRACKET
  | ';' -> emit t SEMI
  | ':' -> emit t COLON
  | ',' -> emit t COMMA
  | '.' -> emit t DOT
  | '@' -> emit t AT
  | '=' -> emit t ASSIGN
  | '<' -> emit t LT
  | '>' -> emit t GT
  | '+' -> emit t PLUS
  | '-' -> emit t MINUS
  | '*' -> emit t STAR
  | '/' -> emit t SLASH
  | '!' -> emit t NOT
  | '?' -> emit t QUESTION
  | eof -> emit t EOF
  | any -> error t (Unexpected_character (lexeme t))
  | _ -> assert false

and path_head t =
  let buf = t.buf in
  match%sedlex buf with
  | path_segment ->
      push t In_path_slash;
      emit t (PATH (lexeme t))
  | home_path_start ->
      push t In_path_slash;
      emit t (HOME_PATH (lexeme t))
  | _ -> assert false

and string t =
  let buf = t.buf in
  match%sedlex buf with
  | "${" ->
      push t Default;
      emit t DOLLAR_CURLY
  | '"' ->
      pop t;
      emit t DQUOTE
  | Plus string_char -> emit t (STR (unescape (lexeme t)))
  | '$' -> emit t (STR "$")
  | '\\' | eof -> error t Unterminated_string
  | _ -> assert false

and indented_string t =
  let buf = t.buf in
  match%sedlex buf with
  | Plus indented_char -> emit t (IND_STR (lexeme t))
  | "''$" -> emit t (IND_STR_ESCAPE "$")
  | "'''" -> emit t (IND_STR_ESCAPE "''")
  | "''\\", any ->
      let s = lexeme t in
      emit t (IND_STR_ESCAPE (unescape (String.sub s 2 (String.length s - 2))))
  | "${" ->
      push t Default;
      emit t DOLLAR_CURLY
  | "''" ->
      pop t;
      emit t IND_STRING_CLOSE
  | '$' -> emit t (IND_STR "$")
  | '\'' -> emit t (IND_STR "'")
  | eof -> error t Unterminated_string
  | _ -> assert false

and in_path t mode =
  let buf = t.buf in
  match%sedlex buf with
  | "${" ->
      replace t In_path;
      push t Default;
      emit t DOLLAR_CURLY
  | path | path_segment | Plus path_char ->
      let s = lexeme t in
      pop t;
      after_path t s;
      emit t (STR s)
  | any | eof -> (
      match mode with
      | In_path_slash -> error t Trailing_slash_in_path
      | _ ->
          let start, _ = Sedlexing.lexing_positions buf in
          Sedlexing.rollback buf;
          pop t;
          (PATH_END, start, start))
  | _ -> assert false

let name = function
  | ID _ -> "identifier"
  | INT _ -> "integer"
  | FLOAT _ -> "float"
  | STR _ | IND_STR _ | IND_STR_ESCAPE _ -> "string content"
  | PATH _ | HOME_PATH _ | SEARCH_PATH _ -> "path"
  | URI _ -> "URI"
  | PATH_END -> "end of path"
  | DQUOTE -> "'\"'"
  | IND_STRING_OPEN | IND_STRING_CLOSE -> "''''"
  | DOLLAR_CURLY -> "'${'"
  | IF -> "'if'"
  | THEN -> "'then'"
  | ELSE -> "'else'"
  | ASSERT -> "'assert'"
  | WITH -> "'with'"
  | LET -> "'let'"
  | IN -> "'in'"
  | REC -> "'rec'"
  | INHERIT -> "'inherit'"
  | OR_KW -> "'or'"
  | ELLIPSIS -> "'...'"
  | EQ -> "'=='"
  | NEQ -> "'!='"
  | LT -> "'<'"
  | GT -> "'>'"
  | LEQ -> "'<='"
  | GEQ -> "'>='"
  | AND -> "'&&'"
  | OR -> "'||'"
  | IMPL -> "'->'"
  | UPDATE -> "'//'"
  | CONCAT -> "'++'"
  | PIPE_INTO -> "'|>'"
  | PIPE_FROM -> "'<|'"
  | PLUS -> "'+'"
  | MINUS -> "'-'"
  | STAR -> "'*'"
  | SLASH -> "'/'"
  | NOT -> "'!'"
  | QUESTION -> "'?'"
  | LBRACE -> "'{'"
  | RBRACE -> "'}'"
  | LBRACKET -> "'['"
  | RBRACKET -> "']'"
  | LPAREN -> "'('"
  | RPAREN -> "')'"
  | COLON -> "':'"
  | SEMI -> "';'"
  | COMMA -> "','"
  | DOT -> "'.'"
  | AT -> "'@'"
  | ASSIGN -> "'='"
  | EOF -> "end of input"

let describe = function
  | ID x -> Printf.sprintf "identifier '%s'" x
  | INT n -> Printf.sprintf "integer %Ld" n
  | FLOAT f -> Printf.sprintf "float %g" f
  | PATH p | HOME_PATH p -> Printf.sprintf "path '%s'" p
  | SEARCH_PATH p -> Printf.sprintf "path '<%s>'" p
  | URI u -> Printf.sprintf "URI '%s'" u
  | token -> name token
