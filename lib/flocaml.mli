(** Parser for the Nix expression language.

    {[
    match Flocaml.parse_string "{ a = 1; }" with
    | Ok { expr; _ } -> Format.printf "%a@." Flocaml.Ast_printer.expr expr
    | Error e -> Format.eprintf "%a@." Flocaml.Syntax_error.pp e
    ]} *)

module Location = Location
module Ast = Ast
module Feature = Feature
module Syntax_error = Syntax_error
module Ast_printer = Ast_printer

type parsed = { expr : Ast.expr; comments : Ast.comment list }

val parse_string :
  ?filename:string ->
  ?features:Feature.t list ->
  string ->
  (parsed, Syntax_error.t) result
(** [parse_string source] parses a whole Nix expression.

    @param filename the file name recorded in locations.
    @param features the experimental features to accept. None by default. *)
