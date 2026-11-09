(** Traversal of syntax trees, in the style of OCaml's [Ast_iterator].

    An iterator is a record with one function per kind of node. Each function
    receives the iterator itself, through which it reaches the children, so
    overriding a field changes how that kind of node is visited everywhere:

    {[
    (* Lists the variables of [e], outermost first. *)
    let variables e =
      let found = ref [] in
      let expr it (e : Ast.expr) =
        (match e.desc with Var x -> found := x :: !found | _ -> ());
        Ast_iterator.default_iterator.expr it e
      in
      let it = { Ast_iterator.default_iterator with expr } in
      it.expr it e;
      List.rev !found
    ]}

    Children are visited in source order, except that the alias of a pattern
    always comes after the formals, as the tree does not record where it was
    written. *)

type iterator = {
  expr : iterator -> Ast.expr -> unit;
  string_part : iterator -> Ast.string_part -> unit;
  attr : iterator -> Ast.attr Ast.loc -> unit;
  binding : iterator -> Ast.binding Ast.loc -> unit;
  param : iterator -> Ast.param -> unit;
  formal : iterator -> Ast.formal -> unit;
  name : iterator -> string Ast.loc -> unit;
      (** A name that a function binds: a parameter, a formal or an alias. *)
}

val default_iterator : iterator
(** Visits every child and does nothing else. *)
