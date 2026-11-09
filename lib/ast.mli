(** Syntax tree of Nix expressions.

    The tree follows the concrete syntax: nothing is desugared and parentheses
    are kept as {!Paren} nodes, so every node maps back to a range of the
    source. *)

type 'a loc = { txt : 'a; loc : Location.t }
type unary_op = Not  (** [!e] *) | Negate  (** [-e] *)

type binary_op =
  | Concat  (** [++] *)
  | Mul  (** [*] *)
  | Div  (** [/] *)
  | Add  (** [+] *)
  | Sub  (** [-] *)
  | Update  (** [//] *)
  | Lt  (** [<] *)
  | Le  (** [<=] *)
  | Gt  (** [>] *)
  | Ge  (** [>=] *)
  | Eq  (** [==] *)
  | Neq  (** [!=] *)
  | And  (** [&&] *)
  | Or  (** [||] *)
  | Implies  (** [->] *)
  | Pipe_into  (** [|>] *)
  | Pipe_from  (** [<|] *)

type expr = { desc : expr_desc; loc : Location.t }

and expr_desc =
  | Var of string
  | Int of int64
  | Float of float
  | String of string_part list  (** ["..."] *)
  | Indented_string of string_part list
      (** [''...''], with the indentation not yet stripped. *)
  | Path of string_part list
      (** [./a], [/a], [a/b] or [~/a], possibly with interpolations such as
          [./a/${b}]. The first part is the literal text before the first
          interpolation. *)
  | Search_path of string  (** [<nixpkgs/lib>], without the angle brackets. *)
  | Uri of string
  | Paren of expr
  | List of expr list
  | Attrs of { recursive : bool; bindings : binding loc list }
  | Legacy_let of binding loc list  (** The deprecated [let { ... }]. *)
  | Select of { expr : expr; path : attr_path; default : expr option }
      (** [e.a.b] or [e.a.b or d] *)
  | Has_attr of expr * attr_path  (** [e ? a.b] *)
  | Apply of expr * expr
  | Lambda of param * expr
  | Let of binding loc list * expr
  | With of expr * expr
  | Assert of expr * expr
  | If of expr * expr * expr
  | Unary of unary_op * expr
  | Binary of binary_op * expr * expr

and string_part =
  | Text of string  (** Literal text with escape sequences decoded. *)
  | Escape of string
      (** A decoded escape sequence in an indented string. Unlike {!Text}, it
          never counts as indentation. *)
  | Interpolation of expr  (** [${e}] *)

and attr =
  | Name of string  (** [a] *)
  | Quoted of string_part list  (** ["a"] or ["a${b}"] *)
  | Dynamic of expr  (** [${e}] *)

and attr_path = attr loc list

and binding =
  | Assign of attr_path * expr  (** [a.b = e;] *)
  | Inherit of expr option * attr loc list
      (** [inherit a b;] or [inherit (e) a b;] *)

and param =
  | Param_var of string loc  (** [x: body] *)
  | Param_pattern of pattern  (** [{ a, b ? 1, ... } @ x: body] *)

and pattern = {
  formals : formal list;
  ellipsis : bool;
  alias : string loc option;  (** The [x] of [{ ... } @ x] or [x @ { ... }]. *)
}

and formal = { name : string loc; default : expr option }

type comment_kind = Line  (** [# ...] *) | Block  (** [/* ... */] *)

type comment = { kind : comment_kind; text : string; loc : Location.t }
(** A comment, where [text] includes the delimiters. *)
