(** The checks that Nix makes on a syntax tree before evaluating it.

    Nix rejects these expressions when it parses them, although they are
    syntactically valid. {!Flocaml.parse_string} does not make these checks; run
    {!val-expr} on its result to accept exactly what Nix accepts. *)

type kind =
  | Duplicate_attr of { path : string list; previous : Location.t }
      (** [{ a = 1; a = 2; }]. [path] leads from the set of the binding to the
          name defined twice, through the sets that Nix merges, as in
          [{ a = { b = 1; }; a = { b = 2; }; }]. *)
  | Duplicate_formal of string  (** [{ a, a }: a] or [{ a } @ a: a] *)
  | Dynamic_attr_in_let  (** [let ${a} = 1; in b] *)
  | Undefined_variable of string
      (** A variable bound neither by the expression, nor in [globals], nor
          possibly by an enclosing [with]. *)

type error = { kind : kind; loc : Location.t }

val message : kind -> string

val pp : Format.formatter -> error -> unit
(** Prints [file:line:column: message]. *)

val default_globals : string list
(** The names that Nix 2.35 binds at the top level with no experimental features
    enabled, such as [true], [import] and [__add]. *)

val expr : ?globals:string list -> Ast.expr -> error list
(** [expr e] lists the errors in [e], ordered by location. Nix stops at the
    first one.

    @param globals the names bound around [e]. {!default_globals} by default. *)
