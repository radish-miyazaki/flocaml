(** The values of literals, as Nix computes them while parsing. *)

val strip_indentation : Ast.string_part list -> Ast.string_part list
(** [strip_indentation parts] removes the common indentation from the parts of
    an {!Ast.Indented_string}, along with a last line made only of spaces.

    Each literal token stays a separate {!Ast.Text} part, as it does in Nix, and
    literals left empty are dropped. {!Ast.Escape} parts become {!Ast.Text}
    parts. *)

val static_string : Ast.expr -> string option
(** [static_string e] is the value of [e] if Nix reads it as a plain string
    without evaluation: a string without interpolations, an indented string that
    is a single literal after stripping, or either in parentheses. *)

val attr_name : Ast.attr -> string option
(** [attr_name a] is the name of [a] if it is known without evaluation, as in
    [a], ["a"] or [${"a"}]. *)
