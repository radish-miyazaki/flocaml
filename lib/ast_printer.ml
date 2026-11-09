open Ast

let fprintf = Format.fprintf
let list pp ppf l = List.iter (fun x -> fprintf ppf "@ %a" pp x) l
let unary_op = function Not -> "Not" | Negate -> "Negate"

let binary_op = function
  | Concat -> "Concat"
  | Mul -> "Mul"
  | Div -> "Div"
  | Add -> "Add"
  | Sub -> "Sub"
  | Update -> "Update"
  | Lt -> "Lt"
  | Le -> "Le"
  | Gt -> "Gt"
  | Ge -> "Ge"
  | Eq -> "Eq"
  | Neq -> "Neq"
  | And -> "And"
  | Or -> "Or"
  | Implies -> "Implies"
  | Pipe_into -> "Pipe_into"
  | Pipe_from -> "Pipe_from"

let rec expr ppf e =
  match e.desc with
  | Var x -> fprintf ppf "(Var %s)" x
  | Int n -> fprintf ppf "(Int %Ld)" n
  | Float f -> fprintf ppf "(Float %s)" (Float.to_string f)
  | String parts -> fprintf ppf "@[<hv 2>(String%a)@]" (list string_part) parts
  | Indented_string parts ->
      fprintf ppf "@[<hv 2>(Indented_string%a)@]" (list string_part) parts
  | Path parts -> fprintf ppf "@[<hv 2>(Path%a)@]" (list string_part) parts
  | Search_path p -> fprintf ppf "(Search_path %S)" p
  | Uri u -> fprintf ppf "(Uri %S)" u
  | Paren e -> fprintf ppf "@[<hv 2>(Paren@ %a)@]" expr e
  | List es -> fprintf ppf "@[<hv 2>(List%a)@]" (list expr) es
  | Attrs { recursive; bindings } ->
      fprintf ppf "@[<hv 2>(%s%a)@]"
        (if recursive then "Rec_attrs" else "Attrs")
        (list binding) bindings
  | Legacy_let bindings ->
      fprintf ppf "@[<hv 2>(Legacy_let%a)@]" (list binding) bindings
  | Select { expr = e; path; default } ->
      fprintf ppf "@[<hv 2>(Select@ %a@ %a%a)@]" expr e attr_path path
        (list expr) (Option.to_list default)
  | Has_attr (e, path) ->
      fprintf ppf "@[<hv 2>(Has_attr@ %a@ %a)@]" expr e attr_path path
  | Apply (f, arg) -> fprintf ppf "@[<hv 2>(Apply@ %a@ %a)@]" expr f expr arg
  | Lambda (p, body) ->
      fprintf ppf "@[<hv 2>(Lambda@ %a@ %a)@]" param p expr body
  | Let (bindings, body) ->
      fprintf ppf "@[<hv 2>(Let@ @[<hv 2>(%a)@]@ %a)@]"
        (Format.pp_print_list ~pp_sep:Format.pp_print_space binding)
        bindings expr body
  | With (scope, body) ->
      fprintf ppf "@[<hv 2>(With@ %a@ %a)@]" expr scope expr body
  | Assert (cond, body) ->
      fprintf ppf "@[<hv 2>(Assert@ %a@ %a)@]" expr cond expr body
  | If (cond, then_, else_) ->
      fprintf ppf "@[<hv 2>(If@ %a@ %a@ %a)@]" expr cond expr then_ expr else_
  | Unary (op, e) -> fprintf ppf "@[<hv 2>(%s@ %a)@]" (unary_op op) expr e
  | Binary (op, l, r) ->
      fprintf ppf "@[<hv 2>(%s@ %a@ %a)@]" (binary_op op) expr l expr r

and string_part ppf = function
  | Text s -> fprintf ppf "%S" s
  | Escape s -> fprintf ppf "(Escape %S)" s
  | Interpolation e -> fprintf ppf "@[<hv 2>(Interpolation@ %a)@]" expr e

and attr ppf { txt; _ } =
  match txt with
  | Name x -> Format.pp_print_string ppf x
  | Quoted parts -> fprintf ppf "@[<hv 2>(Quoted%a)@]" (list string_part) parts
  | Dynamic e -> fprintf ppf "@[<hv 2>(Dynamic@ %a)@]" expr e

and attr_path ppf path =
  fprintf ppf "@[<hv 2>(%a)@]"
    (Format.pp_print_list ~pp_sep:Format.pp_print_space attr)
    path

and binding ppf { txt; _ } =
  match txt with
  | Assign (path, e) ->
      fprintf ppf "@[<hv 2>(Assign@ %a@ %a)@]" attr_path path expr e
  | Inherit (from, attrs) ->
      fprintf ppf "@[<hv 2>(Inherit%a%a)@]" (list expr) (Option.to_list from)
        (list attr) attrs

and param ppf = function
  | Param_var { txt; _ } -> fprintf ppf "(Param_var %s)" txt
  | Param_pattern { formals; ellipsis; alias } ->
      fprintf ppf "@[<hv 2>(Param_pattern%a%s%a)@]" (list formal) formals
        (if ellipsis then " ..." else "")
        (list (fun ppf { txt; _ } -> fprintf ppf "(Alias %s)" txt))
        (Option.to_list alias)

and formal ppf { name; default } =
  match default with
  | None -> Format.pp_print_string ppf name.txt
  | Some d -> fprintf ppf "@[<hv 2>(%s@ %a)@]" name.txt expr d

let comment ppf { kind; text; loc } =
  fprintf ppf "%a: %s %S" Location.pp loc
    (match kind with Line -> "Line" | Block -> "Block")
    text
