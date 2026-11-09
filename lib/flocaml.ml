module Location = Location
module Ast = Ast
module Feature = Feature
module Syntax_error = Syntax_error
module Ast_printer = Ast_printer
module I = Parser.MenhirInterpreter

type parsed = { expr : Ast.expr; comments : Ast.comment list }

(* The incremental API lets us remember the last token read, which is the one
   the parser rejects. *)
let rec run lexer last checkpoint =
  match checkpoint with
  | I.InputNeeded _ ->
      let token = Lexer.token lexer in
      run lexer token (I.offer checkpoint token)
  | I.Shifting _ | I.AboutToReduce _ -> run lexer last (I.resume checkpoint)
  | I.HandlingError _ ->
      let token, start, stop = last in
      let kind = Syntax_error.Unexpected_token (Lexer.describe token) in
      Error { Syntax_error.kind; loc = Location.of_positions (start, stop) }
  | I.Accepted expr -> Ok expr
  | I.Rejected -> assert false

let parse_string ?(filename = "") ?(features = []) source =
  let buf = Sedlexing.Latin1.from_string source in
  Sedlexing.set_filename buf filename;
  let lexer = Lexer.create ~features buf in
  let start, _ = Sedlexing.lexing_positions buf in
  match run lexer (Token.EOF, start, start) (Parser.Incremental.main start) with
  | Ok expr -> Ok { expr; comments = Lexer.comments lexer }
  | Error _ as e -> e
  | exception Lexer.Error e -> Error e
