module Ast = Flocaml.Ast

type context = { base_dir : string; home : string }

exception Unsupported of string

(* Nix's expression tree after desugaring, reduced to what affects the
   output. *)
type t =
  | Verbatim of string
  | String of string
  | Concat of t list
  | List of t list
  | Attrs of attrs
  | Select of t * name list * t option
  | Has_attr of t * name list
  | Call of t * t list
  | Lambda of param * t
  | Let of attrs * t
  | With of t * t
  | Assert of t * t
  | If of t * t * t
  | Op of string * t * t
  | Not of t

and name = Static of string | Dynamic of t

and param =
  | Var_param of string
  | Pattern of {
      formals : (string * t option) list;  (** Sorted by name. *)
      ellipsis : bool;
      alias : string option;
    }

and attrs = {
  recursive : bool;
  defs : (string, def) Hashtbl.t;
  mutable dynamic : (t * t) list;  (** In reverse order. *)
  mutable inherit_from : t list;
      (** In order; [Inherited_from i] refers to the i-th. *)
}

and def = Plain of t | Inherited | Inherited_from of int

let new_attrs recursive =
  { recursive; defs = Hashtbl.create 8; dynamic = []; inherit_from = [] }

let duplicate name =
  raise (Unsupported ("attribute '" ^ name ^ "' already defined"))

let call f args =
  match f with Call (g, a) -> Call (g, a @ args) | f -> Call (f, args)

let builtin name args = Call (Verbatim name, args)

(* Nix's [canonPath]: resolves [.] and [..] without looking at the file
   system. *)
let canonical path =
  let segments =
    List.fold_left
      (fun acc s ->
        match s with
        | "" | "." -> acc
        | ".." -> ( match acc with [] -> [] | _ :: rest -> rest)
        | s -> s :: acc)
      []
      (String.split_on_char '/' path)
  in
  "/" ^ String.concat "/" (List.rev segments)

let path ctx head =
  if head.[0] = '~' then ctx.home ^ String.sub head 1 (String.length head - 1)
  else
    let absolute = if head.[0] = '/' then head else ctx.base_dir ^ "/" ^ head in
    let path = canonical absolute in
    if String.length head > 1 && String.ends_with ~suffix:"/" head then
      path ^ "/"
    else path

(* A string made of a single literal is a plain string; anything else, even a
   single interpolation, is a concatenation. *)
let concat = function
  | [] -> String ""
  | [ String s ] -> String s
  | parts -> Concat parts

let rec expr ctx (e : Ast.expr) =
  match e.desc with
  | Var x -> Verbatim x
  | Int n -> Verbatim (Int64.to_string n)
  | Float f -> Verbatim (Printf.sprintf "%g" f)
  | String parts -> concat (List.map (string_part ctx) parts)
  | Indented_string parts -> concat (strip_indentation ctx parts)
  | Path [] -> assert false
  | Path (head :: rest) -> (
      let head =
        match head with Text s -> Verbatim (path ctx s) | _ -> assert false
      in
      match rest with
      | [] -> head
      | rest -> Concat (head :: List.map (string_part ctx) rest))
  | Search_path p -> builtin "__findFile" [ Verbatim "__nixPath"; String p ]
  | Uri u -> String u
  | Paren e -> expr ctx e
  | List es -> List (List.map (expr ctx) es)
  | Attrs { recursive; bindings } -> Attrs (attrs ctx recursive bindings)
  | Legacy_let bindings ->
      Select (Attrs (attrs ctx true bindings), [ Static "body" ], None)
  | Select { expr = e; path; default } ->
      Select
        (expr ctx e, List.map (name ctx) path, Option.map (expr ctx) default)
  | Has_attr (e, path) -> Has_attr (expr ctx e, List.map (name ctx) path)
  | Apply (f, arg) -> call (expr ctx f) [ expr ctx arg ]
  | Binary (((Pipe_into | Pipe_from) as op), l, r) ->
      let f, arg = if op = Pipe_into then (r, l) else (l, r) in
      call (expr ctx f) [ expr ctx arg ]
  | Lambda (Param_var x, body) -> Lambda (Var_param x.txt, expr ctx body)
  | Lambda (Param_pattern { formals; ellipsis; alias }, body) ->
      let formals =
        List.map
          (fun ({ name; default } : Ast.formal) ->
            (name.txt, Option.map (expr ctx) default))
          formals
        |> List.sort (fun (x, _) (y, _) -> String.compare x y)
      in
      let alias = Option.map (fun (x : string Ast.loc) -> x.txt) alias in
      Lambda (Pattern { formals; ellipsis; alias }, expr ctx body)
  | Let (bindings, body) -> Let (attrs ctx false bindings, expr ctx body)
  | With (scope, body) -> With (expr ctx scope, expr ctx body)
  | Assert (cond, body) -> Assert (expr ctx cond, expr ctx body)
  | If (c, a, b) -> If (expr ctx c, expr ctx a, expr ctx b)
  | Unary (Not, e) -> Not (expr ctx e)
  | Unary (Negate, e) -> builtin "__sub" [ Verbatim "0"; expr ctx e ]
  | Binary (op, l, r) -> (
      let l = expr ctx l and r = expr ctx r in
      match op with
      | Concat -> Op ("++", l, r)
      | Mul -> builtin "__mul" [ l; r ]
      | Div -> builtin "__div" [ l; r ]
      | Add -> Op ("+", l, r)
      | Sub -> builtin "__sub" [ l; r ]
      | Update -> Op ("//", l, r)
      | Lt -> builtin "__lessThan" [ l; r ]
      | Gt -> builtin "__lessThan" [ r; l ]
      | Le -> Not (builtin "__lessThan" [ r; l ])
      | Ge -> Not (builtin "__lessThan" [ l; r ])
      | Eq -> Op ("==", l, r)
      | Neq -> Op ("!=", l, r)
      | And -> Op ("&&", l, r)
      | Or -> Op ("||", l, r)
      | Implies -> Op ("->", l, r)
      | Pipe_into | Pipe_from -> assert false)

and string_part ctx = function
  | Ast.Text s | Escape s -> String s
  | Interpolation e -> expr ctx e

(* A name that desugars to a plain string is static, whether it is written
   [a], ["a"] or [${"a"}]. *)
and name ctx ({ txt; _ } : Ast.attr Ast.loc) =
  let of_expr = function String s -> Static s | e -> Dynamic e in
  match txt with
  | Name x -> Static x
  | Quoted parts -> of_expr (concat (List.map (string_part ctx) parts))
  | Dynamic e -> of_expr (expr ctx e)

and attrs ctx recursive bindings =
  let attrs = new_attrs recursive in
  List.iter
    (fun ({ txt; _ } : Ast.binding Ast.loc) ->
      match txt with
      | Assign (path, e) ->
          add_attr attrs (List.map (name ctx) path) (expr ctx e)
      | Inherit (from, names) ->
          let def =
            match from with
            | None -> Inherited
            | Some from ->
                attrs.inherit_from <- attrs.inherit_from @ [ expr ctx from ];
                Inherited_from (List.length attrs.inherit_from - 1)
          in
          List.iter
            (fun n ->
              match name ctx n with
              | Static s ->
                  if Hashtbl.mem attrs.defs s then duplicate s;
                  Hashtbl.replace attrs.defs s def
              | Dynamic _ ->
                  raise
                    (Unsupported "dynamic attributes not allowed in inherit"))
            names)
    bindings;
  attrs

(* Follows Nix's [addAttr]: intermediate names create or reuse nested sets,
   and a set assigned to an existing set is merged into it. *)
and add_attr attrs path value =
  match path with
  | [] -> assert false
  | [ Static s ] -> (
      match (Hashtbl.find_opt attrs.defs s, value) with
      | None, _ -> Hashtbl.replace attrs.defs s (Plain value)
      | Some (Plain (Attrs existing)), Attrs added -> merge existing added
      | Some _, _ -> duplicate s)
  | [ Dynamic n ] -> attrs.dynamic <- (n, value) :: attrs.dynamic
  | Static s :: rest -> (
      match Hashtbl.find_opt attrs.defs s with
      | Some (Plain (Attrs nested)) -> add_attr nested rest value
      | Some _ -> duplicate s
      | None ->
          let nested = new_attrs false in
          Hashtbl.replace attrs.defs s (Plain (Attrs nested));
          add_attr nested rest value)
  | Dynamic n :: rest ->
      let nested = new_attrs false in
      attrs.dynamic <- (n, Attrs nested) :: attrs.dynamic;
      add_attr nested rest value

and merge existing added =
  let offset = List.length existing.inherit_from in
  Hashtbl.iter
    (fun s def ->
      if Hashtbl.mem existing.defs s then duplicate s;
      let def =
        match def with
        | Inherited_from i -> Inherited_from (i + offset)
        | d -> d
      in
      Hashtbl.replace existing.defs s def)
    added.defs;
  existing.inherit_from <- existing.inherit_from @ added.inherit_from;
  existing.dynamic <- added.dynamic @ existing.dynamic

(* Nix's [stripIndentation]. Escapes and interpolations end the leading
   whitespace of a line without counting as indentation, and only the last
   token may lose a trailing line of spaces. *)
and strip_indentation ctx parts =
  let at_line_start = ref true
  and current = ref 0
  and min_indent = ref max_int in
  let end_of_indent () =
    if !at_line_start then begin
      at_line_start := false;
      min_indent := min !min_indent !current
    end
  in
  List.iter
    (function
      | Ast.Text s ->
          String.iter
            (fun c ->
              if !at_line_start then
                match c with
                | ' ' -> incr current
                | '\n' -> current := 0
                | _ -> end_of_indent ()
              else if c = '\n' then begin
                at_line_start := true;
                current := 0
              end)
            s
      | Escape _ | Interpolation _ -> end_of_indent ())
    parts;
  let min_indent = !min_indent in
  let at_line_start = ref true and dropped = ref 0 in
  let trim ~last s =
    let b = Buffer.create (String.length s) in
    String.iter
      (fun c ->
        if !at_line_start then (
          match c with
          | ' ' ->
              if !dropped >= min_indent then Buffer.add_char b c;
              incr dropped
          | '\n' ->
              dropped := 0;
              Buffer.add_char b c
          | c ->
              at_line_start := false;
              dropped := 0;
              Buffer.add_char b c)
        else begin
          Buffer.add_char b c;
          if c = '\n' then at_line_start := true
        end)
      s;
    let s = Buffer.contents b in
    if not last then s
    else
      match String.rindex_opt s '\n' with
      | Some i
        when String.for_all (( = ) ' ')
               (String.sub s (i + 1) (String.length s - i - 1)) ->
          String.sub s 0 (i + 1)
      | _ -> s
  in
  let rec go = function
    | [] -> []
    | part :: rest -> (
        match part with
        | Ast.Interpolation e ->
            at_line_start := false;
            dropped := 0;
            let e = expr ctx e in
            e :: go rest
        | Text s | Escape s ->
            let s = trim ~last:(rest = []) s in
            if s = "" then go rest else String s :: go rest)
  in
  go parts

let is_keyword = function
  | "if" | "then" | "else" | "assert" | "with" | "let" | "in" | "rec"
  | "inherit" ->
      true
  | _ -> false

let add_literal b s =
  Buffer.add_char b '"';
  String.iteri
    (fun i c ->
      match c with
      | '"' | '\\' ->
          Buffer.add_char b '\\';
          Buffer.add_char b c
      | '\n' -> Buffer.add_string b "\\n"
      | '\r' -> Buffer.add_string b "\\r"
      | '\t' -> Buffer.add_string b "\\t"
      | '$' when i + 1 < String.length s && s.[i + 1] = '{' ->
          Buffer.add_string b "\\$"
      | c -> Buffer.add_char b c)
    s;
  Buffer.add_char b '"'

let add_identifier b s =
  let is_alpha = function
    | 'a' .. 'z' | 'A' .. 'Z' | '_' -> true
    | _ -> false
  in
  let is_rest c =
    is_alpha c || match c with '0' .. '9' | '\'' | '-' -> true | _ -> false
  in
  if
    s = "" || is_keyword s
    || (not (is_alpha s.[0]))
    || not (String.for_all is_rest s)
  then add_literal b s
  else Buffer.add_string b s

let rec add b t =
  let str = Buffer.add_string b in
  match t with
  | Verbatim s -> str s
  | String s -> add_literal b s
  | Concat parts ->
      str "(";
      List.iteri
        (fun i p ->
          if i > 0 then str " + ";
          add b p)
        parts;
      str ")"
  | List es ->
      str "[ ";
      List.iter
        (fun e ->
          str "(";
          add b e;
          str ") ")
        es;
      str "]"
  | Attrs attrs ->
      if attrs.recursive then str "rec ";
      str "{ ";
      add_bindings b attrs;
      str "}"
  | Select (e, path, default) ->
      str "(";
      add b e;
      str ").";
      add_path b path;
      Option.iter
        (fun d ->
          str " or (";
          add b d;
          str ")")
        default
  | Has_attr (e, path) ->
      str "((";
      add b e;
      str ") ? ";
      add_path b path;
      str ")"
  | Call (f, args) ->
      str "(";
      add b f;
      List.iter
        (fun a ->
          str " ";
          add b a)
        args;
      str ")"
  | Lambda (param, body) ->
      str "(";
      add_param b param;
      str ": ";
      add b body;
      str ")"
  | Let (attrs, body) ->
      str "(let ";
      add_bindings b attrs;
      str "in ";
      add b body;
      str ")"
  | With (scope, body) ->
      str "(with ";
      add b scope;
      str "; ";
      add b body;
      str ")"
  | Assert (cond, body) ->
      str "assert ";
      add b cond;
      str "; ";
      add b body
  | If (c, x, y) ->
      str "(if ";
      add b c;
      str " then ";
      add b x;
      str " else ";
      add b y;
      str ")"
  | Op (op, l, r) ->
      str "(";
      add b l;
      str (" " ^ op ^ " ");
      add b r;
      str ")"
  | Not e ->
      str "(! ";
      add b e;
      str ")"

and add_path b path =
  List.iteri
    (fun i n ->
      if i > 0 then Buffer.add_char b '.';
      match n with
      | Static s -> add_identifier b s
      | Dynamic e ->
          Buffer.add_string b "\"${";
          add b e;
          Buffer.add_string b "}\"")
    path

and add_param b = function
  | Var_param x -> Buffer.add_string b x
  | Pattern { formals; ellipsis; alias } ->
      Buffer.add_string b "{ ";
      List.iteri
        (fun i (name, default) ->
          if i > 0 then Buffer.add_string b ", ";
          Buffer.add_string b name;
          Option.iter
            (fun d ->
              Buffer.add_string b " ? ";
              add b d)
            default)
        formals;
      if ellipsis then
        Buffer.add_string b (if formals = [] then "..." else ", ...");
      Buffer.add_string b " }";
      Option.iter (fun x -> Buffer.add_string b (" @ " ^ x)) alias

and add_bindings b attrs =
  let defs =
    Hashtbl.to_seq attrs.defs |> List.of_seq
    |> List.sort (fun (x, _) (y, _) -> String.compare x y)
  in
  let names keep =
    List.filter_map (fun (s, d) -> if keep d then Some s else None) defs
  in
  let add_inherit names =
    List.iter
      (fun s ->
        Buffer.add_char b ' ';
        add_identifier b s)
      names;
    Buffer.add_string b "; "
  in
  (match names (function Inherited -> true | _ -> false) with
  | [] -> ()
  | names ->
      Buffer.add_string b "inherit";
      add_inherit names);
  List.iteri
    (fun i from ->
      match names (function Inherited_from j -> i = j | _ -> false) with
      | [] -> ()
      | names ->
          Buffer.add_string b "inherit (";
          add b from;
          Buffer.add_char b ')';
          add_inherit names)
    attrs.inherit_from;
  List.iter
    (fun (s, d) ->
      match d with
      | Plain e ->
          add_identifier b s;
          Buffer.add_string b " = ";
          add b e;
          Buffer.add_string b "; "
      | Inherited | Inherited_from _ -> ())
    defs;
  List.iter
    (fun (n, v) ->
      Buffer.add_string b "\"${";
      add b n;
      Buffer.add_string b "}\" = ";
      add b v;
      Buffer.add_string b "; ")
    (List.rev attrs.dynamic)

let to_string ctx e =
  let b = Buffer.create 1024 in
  add b (expr ctx e);
  Buffer.contents b
