(** Finding the nodes at a point of the source, as an editor does for the
    cursor. *)

type node =
  | Expr of Ast.expr
  | Attr of Ast.attr Ast.loc
  | Binding of Ast.binding Ast.loc
  | Name of string Ast.loc
      (** A name that a function binds: a parameter, a formal or an alias. *)

val loc : node -> Location.t

val nodes_at : Ast.expr -> int -> node list
(** [nodes_at e offset] lists the nodes of [e] whose location contains the byte
    at [offset], from the innermost to [e] itself. It is empty when [offset] is
    outside [e]. {!Line_index} converts an editor position to an offset. *)
