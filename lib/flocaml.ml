module Location = Location
module Ast = Ast
module Feature = Feature
module Syntax_error = Syntax_error
module Ast_printer = Ast_printer
module Literal = Literal
module Check = Check
module I = Parser.MenhirInterpreter

type parsed = { expr : Ast.expr; comments : Ast.comment list }

(* One token of each kind, to ask the parser which kinds it would accept. *)
let all_tokens =
  Token.
    [
      ID "";
      INT 0L;
      FLOAT 0.;
      STR "";
      IND_STR "";
      IND_STR_ESCAPE "";
      PATH "";
      HOME_PATH "";
      SEARCH_PATH "";
      URI "";
      PATH_END;
      DQUOTE;
      IND_STRING_OPEN;
      IND_STRING_CLOSE;
      DOLLAR_CURLY;
      IF;
      THEN;
      ELSE;
      ASSERT;
      WITH;
      LET;
      IN;
      REC;
      INHERIT;
      OR_KW;
      ELLIPSIS;
      EQ;
      NEQ;
      LT;
      GT;
      LEQ;
      GEQ;
      AND;
      OR;
      IMPL;
      UPDATE;
      CONCAT;
      PIPE_INTO;
      PIPE_FROM;
      PLUS;
      MINUS;
      STAR;
      SLASH;
      NOT;
      QUESTION;
      LBRACE;
      RBRACE;
      LBRACKET;
      RBRACKET;
      LPAREN;
      RPAREN;
      COLON;
      SEMI;
      COMMA;
      DOT;
      AT;
      ASSIGN;
      EOF;
    ]

(* Like Bison, which Nix uses, list the expected tokens only when there are
   few of them. *)
let max_expected = 4

let expected ~features checkpoint position =
  let enabled = function
    | Token.PIPE_INTO | PIPE_FROM -> List.mem Feature.Pipe_operators features
    | _ -> true
  in
  let names =
    List.fold_left
      (fun names token ->
        if enabled token && I.acceptable checkpoint token position then
          let name = Lexer.name token in
          if List.mem name names then names else name :: names
        else names)
      [] all_tokens
  in
  if List.length names > max_expected then [] else List.rev names

(* [last] is the last token read together with the checkpoint that it was
   offered to, which is needed to tell what the parser would have
   accepted instead. *)
let rec run ~features lexer last checkpoint =
  match checkpoint with
  | I.InputNeeded _ ->
      let token = Lexer.token lexer in
      run ~features lexer (Some (checkpoint, token)) (I.offer checkpoint token)
  | I.Shifting _ | I.AboutToReduce _ ->
      run ~features lexer last (I.resume checkpoint)
  | I.HandlingError _ -> (
      match last with
      | None -> assert false
      | Some (offered, (token, start, stop)) ->
          let kind =
            Syntax_error.Unexpected_token
              {
                token = Lexer.describe token;
                expected = expected ~features offered start;
              }
          in
          Error { Syntax_error.kind; loc = Location.of_positions (start, stop) }
      )
  | I.Accepted expr -> Ok expr
  | I.Rejected -> assert false

let parse_string ?(filename = "") ?(features = []) source =
  let buf = Sedlexing.Latin1.from_string source in
  Sedlexing.set_filename buf filename;
  let lexer = Lexer.create ~features buf in
  let start, _ = Sedlexing.lexing_positions buf in
  match run ~features lexer None (Parser.Incremental.main start) with
  | Ok expr -> Ok { expr; comments = Lexer.comments lexer }
  | Error _ as e -> e
  | exception Lexer.Error e -> Error e
