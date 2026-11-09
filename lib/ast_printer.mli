(** Prints syntax trees as S-expressions, for debugging and tests. *)

val expr : Format.formatter -> Ast.expr -> unit
val comment : Format.formatter -> Ast.comment -> unit
