open Ast

type iterator = {
  expr : iterator -> Ast.expr -> unit;
  string_part : iterator -> Ast.string_part -> unit;
  attr : iterator -> Ast.attr Ast.loc -> unit;
  binding : iterator -> Ast.binding Ast.loc -> unit;
  param : iterator -> Ast.param -> unit;
  formal : iterator -> Ast.formal -> unit;
  name : iterator -> string Ast.loc -> unit;
}

let expr it e =
  match e.desc with
  | Var _ | Int _ | Float _ | Search_path _ | Uri _ -> ()
  | String parts | Indented_string parts | Path parts ->
      List.iter (it.string_part it) parts
  | Paren e -> it.expr it e
  | List es -> List.iter (it.expr it) es
  | Attrs { bindings; _ } | Legacy_let bindings ->
      List.iter (it.binding it) bindings
  | Select { expr; path; default } ->
      it.expr it expr;
      List.iter (it.attr it) path;
      Option.iter (it.expr it) default
  | Has_attr (e, path) ->
      it.expr it e;
      List.iter (it.attr it) path
  | Apply (a, b) | With (a, b) | Assert (a, b) | Binary (_, a, b) ->
      it.expr it a;
      it.expr it b
  | Lambda (p, body) ->
      it.param it p;
      it.expr it body
  | Let (bindings, body) ->
      List.iter (it.binding it) bindings;
      it.expr it body
  | If (a, b, c) ->
      it.expr it a;
      it.expr it b;
      it.expr it c
  | Unary (_, e) -> it.expr it e

let string_part it = function
  | Text _ | Escape _ -> ()
  | Interpolation e -> it.expr it e

let attr it { txt; _ } =
  match txt with
  | Name _ -> ()
  | Quoted parts -> List.iter (it.string_part it) parts
  | Dynamic e -> it.expr it e

let binding it { txt; _ } =
  match txt with
  | Assign (path, e) ->
      List.iter (it.attr it) path;
      it.expr it e
  | Inherit (from, attrs) ->
      Option.iter (it.expr it) from;
      List.iter (it.attr it) attrs

(* The alias comes first or last in the source; it is visited after the
   formals, as the tree does not tell. *)
let param it = function
  | Param_var x -> it.name it x
  | Param_pattern { formals; alias; _ } ->
      List.iter (it.formal it) formals;
      Option.iter (it.name it) alias

let formal it { name; default } =
  it.name it name;
  Option.iter (it.expr it) default

let name _ _ = ()
let default_iterator = { expr; string_part; attr; binding; param; formal; name }
