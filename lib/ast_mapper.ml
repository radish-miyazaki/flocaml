open Ast

type mapper = {
  expr : mapper -> Ast.expr -> Ast.expr;
  string_part : mapper -> Ast.string_part -> Ast.string_part;
  attr : mapper -> Ast.attr Ast.loc -> Ast.attr Ast.loc;
  binding : mapper -> Ast.binding Ast.loc -> Ast.binding Ast.loc;
  param : mapper -> Ast.param -> Ast.param;
  formal : mapper -> Ast.formal -> Ast.formal;
  name : mapper -> string Ast.loc -> string Ast.loc;
}

let expr m e =
  let sub = m.expr m in
  let desc =
    match e.desc with
    | (Var _ | Int _ | Float _ | Search_path _ | Uri _) as d -> d
    | String parts -> String (List.map (m.string_part m) parts)
    | Indented_string parts ->
        Indented_string (List.map (m.string_part m) parts)
    | Path parts -> Path (List.map (m.string_part m) parts)
    | Paren e -> Paren (sub e)
    | List es -> List (List.map sub es)
    | Attrs { recursive; bindings } ->
        Attrs { recursive; bindings = List.map (m.binding m) bindings }
    | Legacy_let bindings -> Legacy_let (List.map (m.binding m) bindings)
    | Select { expr; path; default } ->
        let expr = sub expr in
        let path = List.map (m.attr m) path in
        Select { expr; path; default = Option.map sub default }
    | Has_attr (e, path) ->
        let e = sub e in
        Has_attr (e, List.map (m.attr m) path)
    | Apply (f, x) ->
        let f = sub f in
        Apply (f, sub x)
    | Lambda (p, body) ->
        let p = m.param m p in
        Lambda (p, sub body)
    | Let (bindings, body) ->
        let bindings = List.map (m.binding m) bindings in
        Let (bindings, sub body)
    | With (a, b) ->
        let a = sub a in
        With (a, sub b)
    | Assert (a, b) ->
        let a = sub a in
        Assert (a, sub b)
    | If (a, b, c) ->
        let a = sub a in
        let b = sub b in
        If (a, b, sub c)
    | Unary (op, e) -> Unary (op, sub e)
    | Binary (op, l, r) ->
        let l = sub l in
        Binary (op, l, sub r)
  in
  { e with desc }

let string_part m = function
  | (Text _ | Escape _) as p -> p
  | Interpolation e -> Interpolation (m.expr m e)

let attr m a =
  match a.txt with
  | Name _ -> a
  | Quoted parts -> { a with txt = Quoted (List.map (m.string_part m) parts) }
  | Dynamic e -> { a with txt = Dynamic (m.expr m e) }

let binding m b =
  match b.txt with
  | Assign (path, e) ->
      let path = List.map (m.attr m) path in
      { b with txt = Assign (path, m.expr m e) }
  | Inherit (from, attrs) ->
      let from = Option.map (m.expr m) from in
      { b with txt = Inherit (from, List.map (m.attr m) attrs) }

let param m = function
  | Param_var x -> Param_var (m.name m x)
  | Param_pattern { formals; ellipsis; alias } ->
      let formals = List.map (m.formal m) formals in
      Param_pattern { formals; ellipsis; alias = Option.map (m.name m) alias }

let formal m { name; default } =
  let name = m.name m name in
  { name; default = Option.map (m.expr m) default }

let name _ x = x
let default_mapper = { expr; string_part; attr; binding; param; formal; name }
