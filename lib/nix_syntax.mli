(** Parser for the Nix expression language.

    {[
    match Nix_syntax.parse_string "{ a = 1; }" with
    | Ok { expr; _ } -> Format.printf "%a@." Nix_syntax.Ast_printer.expr expr
    | Error e -> Format.eprintf "%a@." Nix_syntax.Syntax_error.pp e
    ]} *)

module Location = Location
module Ast = Ast
module Feature = Feature
module Syntax_error = Syntax_error
module Ast_printer = Ast_printer
module Ast_iterator = Ast_iterator
module Ast_mapper = Ast_mapper
module Literal = Literal
module Check = Check
module Printer = Printer
module Token = Token
module Locate = Locate
module Line_index = Line_index

type parsed = { expr : Ast.expr; comments : Ast.comment list }

val parse_string :
  ?filename:string ->
  ?features:Feature.t list ->
  string ->
  (parsed, Syntax_error.t) result
(** [parse_string source] parses a whole Nix expression. It accepts some
    expressions that Nix rejects after parsing, which {!Check.val-expr} finds.

    @param filename the file name recorded in locations.
    @param features the experimental features to accept. None by default. *)

val parse_channel :
  ?filename:string ->
  ?features:Feature.t list ->
  in_channel ->
  (parsed, Syntax_error.t) result
(** [parse_channel ic] parses everything left in [ic], as {!parse_string}. Open
    [ic] in binary mode, so that line breaks reach the parser unchanged. *)

val parse_file :
  ?features:Feature.t list -> string -> (parsed, Syntax_error.t) result
(** [parse_file path] parses the file at [path], recording [path] in locations.

    Raises [Sys_error] if the file cannot be read. *)
