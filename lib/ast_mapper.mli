(** Rewriting of syntax trees, in the style of OCaml's [Ast_mapper].

    As with {!Ast_iterator}, each function receives the mapper itself to rewrite
    the children:

    {[
    (* Renames the variable [a] to [b]. *)
    let rename e =
      let expr m (e : Ast.expr) =
        match e.desc with
        | Var "a" -> { e with desc = Var "b" }
        | _ -> Ast_mapper.default_mapper.expr m e
      in
      let m = { Ast_mapper.default_mapper with expr } in
      m.expr m e
    ]}

    Locations are kept as they are, so a rewritten node still points to the
    source of the node it replaces. *)

type mapper = {
  expr : mapper -> Ast.expr -> Ast.expr;
  string_part : mapper -> Ast.string_part -> Ast.string_part;
  attr : mapper -> Ast.attr Ast.loc -> Ast.attr Ast.loc;
  binding : mapper -> Ast.binding Ast.loc -> Ast.binding Ast.loc;
  param : mapper -> Ast.param -> Ast.param;
  formal : mapper -> Ast.formal -> Ast.formal;
  name : mapper -> string Ast.loc -> string Ast.loc;
      (** A name that a function binds: a parameter, a formal or an alias. *)
}

val default_mapper : mapper
(** Rewrites every child and rebuilds the node around them. *)
