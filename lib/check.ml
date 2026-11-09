type kind =
  | Duplicate_attr of { path : string list; previous : Location.t }
  | Duplicate_formal of string
  | Dynamic_attr_in_let
  | Undefined_variable of string

type error = { kind : kind; loc : Location.t }

let message = function
  | Duplicate_attr { path; previous } ->
      Format.asprintf "attribute '%s' already defined at %a"
        (String.concat "." path) Location.pp previous
  | Duplicate_formal x ->
      Printf.sprintf "duplicate formal function argument '%s'" x
  | Dynamic_attr_in_let -> "dynamic attributes not allowed in let"
  | Undefined_variable x -> Printf.sprintf "undefined variable '%s'" x

let pp ppf { kind; loc } =
  Format.fprintf ppf "%a: %s" Location.pp loc (message kind)

(* Listed with [nix-instantiate --eval -E 'builtins.attrNames builtins'],
   keeping for each name [x] whichever of [x] and [__x] parses. *)
let default_globals =
  [
    "__add"; "__addDrvOutputDependencies"; "__addErrorContext"; "__all";
    "__any"; "__appendContext"; "__attrNames"; "__attrValues"; "__bitAnd";
    "__bitOr"; "__bitXor"; "__catAttrs"; "__ceil"; "__compareVersions";
    "__concatLists"; "__concatMap"; "__concatStringsSep"; "__convertHash";
    "__currentSystem"; "__currentTime"; "__deepSeq"; "__div"; "__elem";
    "__elemAt"; "__fetchurl"; "__filter"; "__filterSource"; "__findFile";
    "__flakeRefToString"; "__floor"; "__foldl'"; "__fromJSON";
    "__functionArgs"; "__genList"; "__genericClosure"; "__getAttr";
    "__getContext"; "__getEnv"; "__getFlake"; "__groupBy"; "__hasAttr";
    "__hasContext"; "__hashFile"; "__hashString"; "__head";
    "__intersectAttrs"; "__isAttrs"; "__isBool"; "__isFloat"; "__isFunction";
    "__isInt"; "__isList"; "__isPath"; "__isString"; "__langVersion";
    "__length"; "__lessThan"; "__listToAttrs"; "__mapAttrs"; "__match";
    "__mul"; "__nixPath"; "__nixVersion"; "__parseDrvName";
    "__parseFlakeRef"; "__partition"; "__path"; "__pathExists"; "__readDir";
    "__readFile"; "__readFileType"; "__replaceStrings"; "__seq"; "__sort";
    "__split"; "__splitVersion"; "__storeDir"; "__storePath";
    "__stringLength"; "__sub"; "__substring"; "__tail"; "__toFile";
    "__toJSON"; "__toPath"; "__toXML"; "__trace"; "__traceVerbose";
    "__tryEval"; "__typeOf"; "__unsafeDiscardOutputDependency";
    "__unsafeDiscardStringContext"; "__unsafeGetAttrPos"; "__warn";
    "__zipAttrsWith"; "abort"; "baseNameOf"; "break"; "builtins";
    "derivation"; "derivationStrict"; "dirOf"; "false"; "fetchGit";
    "fetchMercurial"; "fetchTarball"; "fromTOML"; "import"; "isNull"; "map";
    "null"; "placeholder"; "removeAttrs"; "scopedImport"; "throw";
    "toString"; "true";
  ]
[@@ocamlformat "disable"]

module Names = Set.Make (String)

(* The bindings of a set or a [let] after Nix has merged them, so that
   [a.b = 1; a.c = 2;] defines a single [a]. Values are checked once the
   whole set is known, since a value moved by a merge is scoped by the set it
   ends up in. *)
type set = {
  recursive : bool;
  defs : (string, def) Hashtbl.t;
  mutable names : string list;  (** In reverse order of definition. *)
  mutable dynamic : (Ast.attr Ast.loc * value) list;
  mutable inherit_from : Ast.expr list;
  mutable rejected : value list;
      (** Values of duplicate definitions, which are still checked. *)
}

and def = { loc : Location.t; value : value }

and value =
  | Expr of Ast.expr
  | Set of set
  | Inherited of string Ast.loc
  | Inherited_from

let new_set recursive =
  {
    recursive;
    defs = Hashtbl.create 8;
    names = [];
    dynamic = [];
    inherit_from = [];
    rejected = [];
  }

let define set name def =
  Hashtbl.replace set.defs name def;
  set.names <- name :: set.names

let rec strip_parens (e : Ast.expr) =
  match e.desc with Paren e -> strip_parens e | _ -> e

(* [report] receives each error as it is found. *)
let rec value report e =
  match (strip_parens e).desc with
  | Attrs { recursive; bindings } -> Set (set report recursive bindings)
  | _ -> Expr e

and set report recursive bindings =
  let set = new_set recursive in
  List.iter
    (fun ({ txt; _ } : Ast.binding Ast.loc) ->
      match txt with
      | Assign (path, e) -> add report set ~prefix:[] path (value report e)
      | Inherit (from, names) ->
          Option.iter (fun e -> set.inherit_from <- e :: set.inherit_from) from;
          List.iter
            (fun ({ txt; loc } : Ast.attr Ast.loc) ->
              (* The parser accepts only static names in [inherit]. *)
              Option.iter
                (fun name ->
                  let value =
                    if Option.is_some from then Inherited_from
                    else Inherited { txt = name; loc }
                  in
                  match Hashtbl.find_opt set.defs name with
                  | Some previous ->
                      duplicate report set [ name ] ~previous ~loc value
                  | None -> define set name { loc; value })
                (Literal.attr_name txt))
            names)
    bindings;
  set

and duplicate report set path ~previous ~loc value =
  report { kind = Duplicate_attr { path; previous = previous.loc }; loc };
  set.rejected <- value :: set.rejected

(* Follows Nix's [addAttr]: the names before the last one create or reuse
   nested sets, and a set assigned to an existing set is merged into it. *)
and add report set ~prefix path value =
  match path with
  | [] -> assert false
  | ({ txt; loc } as attr) :: rest -> (
      let nested () =
        let nested = new_set false in
        add report nested ~prefix:[] rest value;
        Set nested
      in
      match (Literal.attr_name txt, rest) with
      | None, [] -> set.dynamic <- (attr, value) :: set.dynamic
      | None, _ -> set.dynamic <- (attr, nested ()) :: set.dynamic
      | Some name, [] -> (
          match (Hashtbl.find_opt set.defs name, value) with
          | None, _ -> define set name { loc; value }
          | Some { value = Set existing; _ }, Set added ->
              merge report existing added ~prefix:(prefix @ [ name ])
          | Some previous, _ ->
              duplicate report set (prefix @ [ name ]) ~previous ~loc value)
      | Some name, _ -> (
          match Hashtbl.find_opt set.defs name with
          | Some { value = Set existing; _ } ->
              add report existing ~prefix:(prefix @ [ name ]) rest value
          | Some previous ->
              duplicate report set (prefix @ [ name ]) ~previous ~loc value
          | None ->
              let nested = new_set false in
              define set name { loc; value = Set nested };
              add report nested ~prefix:(prefix @ [ name ]) rest value))

(* The merged set keeps whether [existing] is recursive. *)
and merge report existing added ~prefix =
  List.iter
    (fun name ->
      let def = Hashtbl.find added.defs name in
      match (Hashtbl.find_opt existing.defs name, def.value) with
      | None, _ -> define existing name def
      | Some { value = Set e; _ }, Set a ->
          merge report e a ~prefix:(prefix @ [ name ])
      | Some previous, value ->
          duplicate report existing (prefix @ [ name ]) ~previous ~loc:def.loc
            value)
    (List.rev added.names);
  existing.dynamic <- added.dynamic @ existing.dynamic;
  existing.inherit_from <- added.inherit_from @ existing.inherit_from;
  existing.rejected <- added.rejected @ existing.rejected

type frame = Static of Names.t | With

(* Any enclosing [with] may bind a variable, so Nix leaves it to evaluation. *)
let bound env x =
  List.exists (function Static names -> Names.mem x names | With -> true) env

let lookup report env x loc =
  if not (bound env x) then report { kind = Undefined_variable x; loc }

(* Operators that Nix turns into calls of these builtins. *)
let builtin_of_binary : Ast.binary_op -> string option = function
  | Sub -> Some "__sub"
  | Mul -> Some "__mul"
  | Div -> Some "__div"
  | Lt | Gt | Le | Ge -> Some "__lessThan"
  | Concat | Add | Update | Eq | Neq | And | Or | Implies | Pipe_into
  | Pipe_from ->
      None

let rec expr report env (e : Ast.expr) =
  let check = expr report env in
  match e.desc with
  | Var "__curPos" -> (* Nix reads it as the current position. *) ()
  | Var x -> lookup report env x e.loc
  | Int _ | Float _ | Uri _ -> ()
  | Search_path _ ->
      lookup report env "__findFile" e.loc;
      lookup report env "__nixPath" e.loc
  | String parts | Indented_string parts | Path parts ->
      List.iter (string_part report env) parts
  | Paren e -> check e
  | List es -> List.iter check es
  | Attrs { recursive; bindings } ->
      ignore (check_set report env (set report recursive bindings))
  | Legacy_let bindings ->
      ignore (check_set report env (set report true bindings))
  | Let (bindings, body) ->
      let set = set report true bindings in
      if set.dynamic <> [] then
        report { kind = Dynamic_attr_in_let; loc = e.loc };
      expr report (check_set report env set) body
  | Select { expr = e; path; default } ->
      check e;
      List.iter (attr report env) path;
      Option.iter check default
  | Has_attr (e, path) ->
      check e;
      List.iter (attr report env) path
  | Apply (f, x) ->
      check f;
      check x
  | Lambda (Param_var x, body) ->
      expr report (Static (Names.singleton x.txt) :: env) body
  | Lambda (Param_pattern { formals; alias; _ }, body) ->
      let add names ({ txt; loc } : string Ast.loc) =
        if Names.mem txt names then report { kind = Duplicate_formal txt; loc };
        Names.add txt names
      in
      let names =
        List.fold_left
          (fun names ({ name; _ } : Ast.formal) -> add names name)
          Names.empty formals
      in
      let names = Option.fold ~none:names ~some:(add names) alias in
      let env = Static names :: env in
      List.iter
        (fun ({ default; _ } : Ast.formal) ->
          Option.iter (expr report env) default)
        formals;
      expr report env body
  | With (scope, body) ->
      check scope;
      expr report (With :: env) body
  | Assert (cond, body) ->
      check cond;
      check body
  | If (cond, a, b) ->
      check cond;
      check a;
      check b
  | Unary (Not, x) -> check x
  | Unary (Negate, x) ->
      lookup report env "__sub" e.loc;
      check x
  | Binary (op, l, r) ->
      Option.iter
        (fun name -> lookup report env name e.loc)
        (builtin_of_binary op);
      check l;
      check r

and string_part report env = function
  | Ast.Text _ | Escape _ -> ()
  | Interpolation e -> expr report env e

and attr report env ({ txt; _ } : Ast.attr Ast.loc) =
  match txt with
  | Name _ -> ()
  | Quoted parts -> List.iter (string_part report env) parts
  | Dynamic e -> expr report env e

(* Returns the scope of the values, which is also the scope of the body of a
   [let]. A plain [inherit] reads the enclosing scope even in a recursive
   set. *)
and check_set report env set =
  let inner =
    if set.recursive then Static (Names.of_list set.names) :: env else env
  in
  let value = function
    | Expr e -> expr report inner e
    | Set s -> ignore (check_set report inner s)
    | Inherited { txt; loc } -> lookup report env txt loc
    | Inherited_from -> ()
  in
  List.iter (fun name -> value (Hashtbl.find set.defs name).value) set.names;
  List.iter (expr report inner) set.inherit_from;
  List.iter
    (fun (name, v) ->
      attr report inner name;
      value v)
    set.dynamic;
  List.iter value set.rejected;
  inner

let expr ?(globals = default_globals) e =
  let errors = ref [] in
  expr
    (fun error -> errors := error :: !errors)
    [ Static (Names.of_list globals) ]
    e;
  List.stable_sort
    (fun (a : error) (b : error) ->
      Int.compare a.loc.Location.start.pos_cnum b.loc.Location.start.pos_cnum)
    (List.rev !errors)
