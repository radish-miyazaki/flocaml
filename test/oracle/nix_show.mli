(** Prints a syntax tree in the format of [nix-instantiate --parse].

    The output of [nix-instantiate --parse] is the expression after Nix's own
    parser has desugared it, so this module repeats that desugaring: attribute
    paths are merged into nested sets, indentation is stripped from indented
    strings, relative paths are made absolute, and operators are turned into
    calls to builtins. Comparing the two outputs on many files tests flocaml
    against Nix itself. *)

type context = {
  base_dir : string;  (** The directory that relative paths are resolved in. *)
  home : string;  (** The value of [~] in home paths. *)
}

exception Unsupported of string
(** Raised for input that Nix rejects after parsing, such as an attribute
    defined twice. *)

val to_string : context -> Flocaml.Ast.expr -> string
