type kind =
  | Whitespace
  | Comment
  | Keyword
  | Identifier
  | Integer
  | Float
  | String_start
  | String_end
  | String_text
  | Interpolation_start
  | Interpolation_end
  | Path
  | Search_path
  | Uri
  | Operator
  | Punctuation

type t = { kind : kind; text : string; loc : Location.t }

(* [lexer] is in the state after [token]; it tells an opening quote from a
   closing one, and the [}] of an interpolation from that of a set. Tokens
   of no width have no kind. *)
let classify lexer (token : Tokens.token) =
  match token with
  | IF | THEN | ELSE | ASSERT | WITH | LET | IN | REC | INHERIT | OR_KW ->
      Some Keyword
  | ID _ -> Some Identifier
  | INT _ -> Some Integer
  | FLOAT _ -> Some Float
  | DQUOTE -> Some (if Lexer.in_string lexer then String_start else String_end)
  | IND_STRING_OPEN -> Some String_start
  | IND_STRING_CLOSE -> Some String_end
  | STR _ -> Some (if Lexer.in_path lexer then Path else String_text)
  | IND_STR _ | IND_STR_ESCAPE _ -> Some String_text
  | PATH _ | HOME_PATH _ -> Some Path
  | SEARCH_PATH _ -> Some Search_path
  | URI _ -> Some Uri
  | DOLLAR_CURLY -> Some Interpolation_start
  | RBRACE ->
      Some
        (if Lexer.in_string lexer || Lexer.in_path lexer then Interpolation_end
         else Punctuation)
  | EQ | NEQ | LT | GT | LEQ | GEQ | AND | OR | IMPL | UPDATE | CONCAT
  | PIPE_INTO | PIPE_FROM | PLUS | MINUS | STAR | SLASH | NOT | QUESTION ->
      Some Operator
  | LBRACE | LBRACKET | RBRACKET | LPAREN | RPAREN | COLON | SEMI | COMMA | DOT
  | AT | ASSIGN | ELLIPSIS ->
      Some Punctuation
  | PATH_END | EOF -> None

let make source kind (start : Lexing.position) (stop : Lexing.position) =
  {
    kind;
    text = String.sub source start.pos_cnum (stop.pos_cnum - start.pos_cnum);
    loc = { start; stop };
  }

(* The lexer skips only whitespace and comments, so these fill the gaps
   between its tokens. *)
let gap source (comments : Ast.comment list) (start : Lexing.position) stop =
  let whitespace (a : Lexing.position) (b : Lexing.position) acc =
    if a.pos_cnum < b.pos_cnum then make source Whitespace a b :: acc else acc
  in
  let rec go pos comments acc =
    match comments with
    | (c : Ast.comment) :: rest when c.loc.start.pos_cnum < stop.Lexing.pos_cnum
      ->
        let acc = whitespace pos c.loc.start acc in
        go c.loc.stop rest (make source Comment c.loc.start c.loc.stop :: acc)
    | _ -> (whitespace pos stop acc, comments)
  in
  go start comments []

let tokenize ?(filename = "") ?(features = []) source =
  let buf = Sedlexing.Latin1.from_string source in
  Sedlexing.set_filename buf filename;
  let lexer = Lexer.create ~features buf in
  let rec read acc =
    let token, start, stop = Lexer.token lexer in
    match (token, classify lexer token) with
    | EOF, _ -> (List.rev acc, start)
    | _, Some kind -> read ((kind, start, stop) :: acc)
    | _, None -> read acc
  in
  match read [] with
  | exception Lexer.Error e -> Error e
  | tokens, eof ->
      let start =
        { Lexing.pos_fname = filename; pos_lnum = 1; pos_bol = 0; pos_cnum = 0 }
      in
      let rec fill pos comments tokens acc =
        match tokens with
        | [] ->
            let trivia, _ = gap source comments pos eof in
            List.rev_append acc (List.rev trivia)
        | (kind, a, b) :: rest ->
            let trivia, comments = gap source comments pos a in
            fill b comments rest (make source kind a b :: (trivia @ acc))
      in
      Ok (fill start (Lexer.comments lexer) tokens [])
