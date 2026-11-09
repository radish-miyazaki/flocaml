open Ast

let fprintf = Format.fprintf
let invalid fmt = Printf.ksprintf (fun s -> invalid_arg ("Printer: " ^ s)) fmt

let is_keyword = function
  | "if" | "then" | "else" | "assert" | "with" | "let" | "in" | "rec"
  | "inherit" | "or" ->
      true
  | _ -> false

let is_identifier s =
  s <> ""
  && (match s.[0] with 'a' .. 'z' | 'A' .. 'Z' | '_' -> true | _ -> false)
  && String.for_all
       (function
         | 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_' | '\'' | '-' -> true
         | _ -> false)
       s

(* Precedence levels, from the loosest. They follow the grammar: a node may
   stand unparenthesized where the grammar asks for its level or a looser
   one. *)
let function_level = 0 (* lambda, let, with, assert *)
let if_level = 1
let pipe_level = 2
let op_level = 10 (* the loosest binary operator *)
let not_level = 16
let has_attr_level = 20
let negate_level = 21
let app_level = 30
let select_level = 31
let simple_level = 32

(* Where nothing that could extend an expression follows it. *)
let no_follower = -1

let binary_level = function
  | Pipe_into | Pipe_from -> pipe_level
  | Implies -> 10
  | Or -> 11
  | And -> 12
  | Eq | Neq -> 13
  | Lt | Le | Gt | Ge -> 14
  | Update -> 15
  | Add | Sub -> 17
  | Mul | Div -> 18
  | Concat -> 19

let binary_symbol = function
  | Concat -> "++"
  | Mul -> "*"
  | Div -> "/"
  | Add -> "+"
  | Sub -> "-"
  | Update -> "//"
  | Lt -> "<"
  | Le -> "<="
  | Gt -> ">"
  | Ge -> ">="
  | Eq -> "=="
  | Neq -> "!="
  | And -> "&&"
  | Or -> "||"
  | Implies -> "->"
  | Pipe_into -> "|>"
  | Pipe_from -> "<|"

(* Negative numbers have no literal; they print as a negation. *)
let is_prefix e =
  match e.desc with
  | Unary _ -> true
  | Int n -> n < 0L
  | Float f -> Float.sign_bit f
  | _ -> false

let level e =
  match e.desc with
  | Lambda _ | Let _ | With _ | Assert _ -> function_level
  | If _ -> if_level
  | Binary (op, _, _) -> binary_level op
  | Unary (Not, _) -> not_level
  | Has_attr _ -> has_attr_level
  | Apply (_, { desc = Var "or"; _ }) -> select_level
  | Apply _ -> app_level
  | Select _ -> select_level
  | _ when is_prefix e -> negate_level
  | _ -> simple_level

(* A prefix operator takes as its operand everything up to the first
   operator that binds more loosely than itself. So it needs parentheses
   when followed by an operator that binds more tightly, rather than when
   its own level is too loose for the place. *)
let needs_parens e ~level:required ~follower =
  if is_prefix e then required >= app_level || follower > level e
  else level e < required

let int_literal n =
  if n = Int64.min_int then invalid "integer %Ld has no literal" n;
  Int64.to_string (Int64.abs n)

(* Nix reads a float only with a dot, and [1e3] as [1] applied to [e3]. *)
let float_literal f =
  if not (Float.is_finite f) then invalid "float %h has no literal" f;
  let f = Float.abs f in
  let s =
    List.find
      (fun s -> float_of_string s = f)
      [
        Printf.sprintf "%.15g" f;
        Printf.sprintf "%.16g" f;
        Printf.sprintf "%.17g" f;
      ]
  in
  if String.contains s '.' then s
  else
    match String.index_opt s 'e' with
    | Some i -> String.sub s 0 i ^ ".0" ^ String.sub s i (String.length s - i)
    | None -> s ^ ".0"

(* What comes right after a character of literal text, to tell whether the
   character must be escaped. *)
type next = Char of char | Interpolation_start | Escape_start | End

let rec next_of_parts = function
  | [] -> End
  | Text "" :: rest -> next_of_parts rest
  | Text s :: _ -> Char s.[0]
  | Escape _ :: _ -> Escape_start
  | Interpolation _ :: _ -> Interpolation_start

let next_in s i rest =
  if i + 1 < String.length s then Char s.[i + 1] else next_of_parts rest

(* A [$] must not start [${], nor make [$$] with the [$] of an
   interpolation. In both kinds of strings, the lexer reads [$$] as a pair,
   so the [{] after it is literal and [$$] is written as it is. *)
let dollar_needs_escape = function
  | Char '{' | Interpolation_start -> true
  | Char _ | Escape_start | End -> false

(* Calls [f i c next] on each character of [s] that is not the second half
   of a [$$] pair, which [pair] writes. *)
let scan s rest ~pair f =
  let n = String.length s in
  let rec go i =
    if i < n then
      let next = next_in s i rest in
      match (s.[i], next) with
      | '$', Char '$' ->
          pair ();
          go (i + 2)
      | c, next ->
          f c next;
          go (i + 1)
  in
  go 0

let string_text b s rest =
  scan s rest
    ~pair:(fun () -> Buffer.add_string b "$$")
    (fun c next ->
      match c with
      | '"' -> Buffer.add_string b "\\\""
      | '\\' -> Buffer.add_string b "\\\\"
      | '\n' -> Buffer.add_string b "\\n"
      | '\r' -> Buffer.add_string b "\\r"
      | '\t' -> Buffer.add_string b "\\t"
      | '$' when dollar_needs_escape next -> Buffer.add_string b "\\$"
      | c -> Buffer.add_char b c)

let indented_escape b = function
  | "$" -> Buffer.add_string b "''$"
  | "''" -> Buffer.add_string b "'''"
  | "\n" -> Buffer.add_string b "''\\n"
  | "\r" -> Buffer.add_string b "''\\r"
  | "\t" -> Buffer.add_string b "''\\t"
  | s -> String.iter (fun c -> Buffer.add_string b ("''\\" ^ String.make 1 c)) s

(* Text in an indented string is raw. A ['] before another ['] would make
   [''], which ends the string or starts an escape; the closing [''] counts
   too. *)
let indented_text b s rest =
  scan s rest
    ~pair:(fun () -> Buffer.add_string b "$$")
    (fun c next ->
      match (c, next) with
      | '\'', (Char '\'' | Escape_start | End) -> Buffer.add_string b "''\\'"
      | '$', next when dollar_needs_escape next -> Buffer.add_string b "''$"
      | c, _ -> Buffer.add_char b c)

let rec expr_at ~level:required ~follower ppf e =
  if needs_parens e ~level:required ~follower then
    fprintf ppf "@[<hv 1>(%a)@]" (desc ~follower:no_follower) e
  else desc ~follower ppf e

and top ppf e = expr_at ~level:function_level ~follower:no_follower ppf e

and desc ~follower ppf e =
  match e.desc with
  | Var x ->
      if is_identifier x && not (is_keyword x) then Format.pp_print_string ppf x
      else invalid "%S is not a variable name" x
  | Int n -> fprintf ppf "%s%s" (if n < 0L then "-" else "") (int_literal n)
  | Float f ->
      fprintf ppf "%s%s"
        (if Float.sign_bit f then "-" else "")
        (float_literal f)
  | String parts -> Format.pp_print_string ppf (string_literal parts)
  | Indented_string parts ->
      Format.pp_print_string ppf (indented_string_literal parts)
  | Path parts -> Format.pp_print_string ppf (path_literal parts)
  | Search_path p -> fprintf ppf "<%s>" p
  | Uri u -> Format.pp_print_string ppf u
  | Paren e -> fprintf ppf "@[<hv 1>(%a)@]" top e
  | List [] -> Format.pp_print_string ppf "[ ]"
  | List es ->
      fprintf ppf "@[<hv 2>[%a@;<1 -2>]@]"
        (fun ppf ->
          List.iter
            (fprintf ppf "@ %a"
               (expr_at ~level:select_level ~follower:no_follower)))
        es
  | Attrs { recursive; bindings } ->
      fprintf ppf "%s%a"
        (if recursive then "rec " else "")
        bindings_block bindings
  | Legacy_let bindings -> fprintf ppf "let %a" bindings_block bindings
  | Select { expr = e; path; default } -> (
      (* Without a space, [1 .a] would read as the float [1.] and [./a .b]
         as the path [./a.b]. *)
      let space =
        match e.desc with Int _ | Float _ | Path _ | Uri _ -> " " | _ -> ""
      in
      fprintf ppf "%a%s.%a"
        (expr_at ~level:simple_level ~follower:no_follower)
        e space attr_path path;
      match default with
      | None -> ()
      | Some d ->
          fprintf ppf " or %a"
            (expr_at ~level:select_level ~follower:no_follower)
            d)
  | Has_attr (e, path) ->
      fprintf ppf "@[<hv 2>%a@ ? %a@]"
        (expr_at ~level:(has_attr_level + 1) ~follower:has_attr_level)
        e attr_path path
  | Apply (f, { desc = Var "or"; _ }) ->
      fprintf ppf "%a or" (expr_at ~level:simple_level ~follower:no_follower) f
  | Apply (f, x) ->
      fprintf ppf "@[<hv 2>%a@ %a@]"
        (expr_at ~level:app_level ~follower:no_follower)
        f
        (expr_at ~level:select_level ~follower:no_follower)
        x
  | Lambda (p, body) -> fprintf ppf "@[<hv>%a:@ %a@]" param p top body
  | Let (bindings, body) ->
      fprintf ppf "@[<hv>@[<hv 2>let%a@]@ in@ %a@]" bindings_list bindings top
        body
  | With (scope, body) ->
      fprintf ppf "@[<hv>@[<hv 2>with@ %a;@]@ %a@]" top scope top body
  | Assert (cond, body) ->
      fprintf ppf "@[<hv>@[<hv 2>assert@ %a;@]@ %a@]" top cond top body
  | If (c, a, b) ->
      fprintf ppf
        "@[<hv>@[<hv 2>if@ %a@]@ @[<hv 2>then@ %a@]@ @[<hv 2>else@ %a@]@]" top c
        top a top b
  | Unary (Not, x) -> fprintf ppf "!%a" (expr_at ~level:not_level ~follower) x
  | Unary (Negate, x) ->
      fprintf ppf "-%s%a" (negate_space x)
        (expr_at ~level:negate_level ~follower)
        x
  | Binary (op, l, r) ->
      let p = binary_level op in
      let is op' (e : expr) =
        match e.desc with Binary (o, _, _) -> o = op' | _ -> false
      in
      (* Mixing [|>] and [<|] needs parentheses, so a pipe takes only the
         same pipe as its operand. *)
      let left, right =
        match op with
        | Pipe_into -> ((if is Pipe_into l then p else op_level), op_level)
        | Pipe_from -> (op_level, if is Pipe_from r then p else op_level)
        | Implies | Update | Concat -> (p + 1, p)
        | Or | And | Add | Sub | Mul | Div -> (p, p + 1)
        | Eq | Neq | Lt | Le | Gt | Ge -> (p + 1, p + 1)
      in
      fprintf ppf "@[<hv 2>%a@ %s %a@]"
        (expr_at ~level:left ~follower:p)
        l (binary_symbol op)
        (expr_at ~level:right ~follower)
        r

(* [-./a] would read as a path, so a space separates them; [- -a] is only
   easier to read. *)
and negate_space x =
  let rec leftmost (e : expr) =
    match e.desc with
    | Apply (f, _) -> leftmost f
    | Select { expr; _ } -> leftmost expr
    | Has_attr (e, _) | Binary (_, e, _) -> leftmost e
    | _ -> e
  in
  let x = leftmost x in
  match x.desc with
  | Path _ -> " "
  | Unary (Negate, _) -> " "
  | Int n when n < 0L -> " "
  | Float f when Float.sign_bit f -> " "
  | _ -> ""

and string_literal parts =
  let b = Buffer.create 16 in
  Buffer.add_char b '"';
  let rec go = function
    | [] -> ()
    | (Text s | Escape s) :: rest ->
        string_text b s rest;
        go rest
    | Interpolation e :: rest ->
        Buffer.add_string b (interpolation e);
        go rest
  in
  go parts;
  Buffer.add_char b '"';
  Buffer.contents b

and indented_string_literal parts =
  let b = Buffer.create 16 in
  Buffer.add_string b "''";
  (* The opening [''] takes the line break that follows it, so one can start
     the content on its own line. It must, when the content starts with a
     line of spaces, which the opening would take otherwise. *)
  if
    List.exists (function Text s -> String.contains s '\n' | _ -> false) parts
  then Buffer.add_char b '\n';
  let rec go = function
    | [] -> ()
    | Text s :: rest ->
        indented_text b s rest;
        go rest
    | Escape s :: rest ->
        indented_escape b s;
        go rest
    | Interpolation e :: rest ->
        Buffer.add_string b (interpolation e);
        go rest
  in
  go parts;
  Buffer.add_string b "''";
  Buffer.contents b

and path_literal parts =
  match parts with
  | Text _ :: _ ->
      String.concat ""
        (List.map
           (function
             | Text s | Escape s -> s | Interpolation e -> interpolation e)
           parts)
  | _ -> invalid "a path must start with text"

and interpolation e = Format.asprintf "${%a}" top e

and attr ppf ({ txt; _ } : attr Ast.loc) =
  match txt with
  | Name x when is_identifier x && (x = "or" || not (is_keyword x)) ->
      Format.pp_print_string ppf x
  | Name x -> Format.pp_print_string ppf (string_literal [ Text x ])
  | Quoted parts -> Format.pp_print_string ppf (string_literal parts)
  | Dynamic e -> Format.pp_print_string ppf (interpolation e)

and attr_path ppf path =
  Format.pp_print_list
    ~pp_sep:(fun ppf () -> Format.pp_print_char ppf '.')
    attr ppf path

and binding ppf ({ txt; _ } : binding Ast.loc) =
  match txt with
  | Assign (path, e) -> fprintf ppf "@[<hv 2>%a =@ %a;@]" attr_path path top e
  | Inherit (from, attrs) ->
      let inherited ppf (a : attr Ast.loc) =
        match a.txt with
        | Name _ -> attr ppf a
        | Quoted parts
          when List.for_all (function Text _ -> true | _ -> false) parts ->
            attr ppf a
        | Quoted _ | Dynamic _ -> invalid "inherit takes only static names"
      in
      fprintf ppf "@[<hv 2>inherit%a%a;@]"
        (fun ppf -> Option.iter (fprintf ppf "@ (%a)" top))
        from
        (fun ppf -> List.iter (fprintf ppf "@ %a" inherited))
        attrs

and bindings_list ppf bindings = List.iter (fprintf ppf "@ %a" binding) bindings

and bindings_block ppf = function
  | [] -> Format.pp_print_string ppf "{ }"
  | bindings -> fprintf ppf "@[<hv 2>{%a@;<1 -2>}@]" bindings_list bindings

and name ppf ({ txt; _ } : string Ast.loc) =
  if is_identifier txt && not (is_keyword txt) then
    Format.pp_print_string ppf txt
  else invalid "%S is not a parameter name" txt

and param ppf = function
  | Param_var x -> name ppf x
  | Param_pattern { formals; ellipsis; alias } ->
      let formal ppf { name = n; default } =
        match default with
        | None -> name ppf n
        | Some d -> fprintf ppf "@[<hv 2>%a ?@ %a@]" name n top d
      in
      let items =
        List.map (fun f ppf -> formal ppf f) formals
        @
        if ellipsis then [ (fun ppf -> Format.pp_print_string ppf "...") ]
        else []
      in
      (match items with
      | [] -> Format.pp_print_string ppf "{ }"
      | items ->
          fprintf ppf "@[<hv 2>{ %a@;<1 -2>}@]"
            (Format.pp_print_list
               ~pp_sep:(fun ppf () -> fprintf ppf ",@ ")
               (fun ppf item -> item ppf))
            items);
      Option.iter (fprintf ppf " @@ %a" name) alias

let expr ppf e = top ppf e
let to_string e = Format.asprintf "%a" expr e
