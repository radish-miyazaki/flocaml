(** Printing syntax trees as Nix source.

    The output is valid Nix that reads back as the same tree, apart from
    locations, for any tree that {!Nix_syntax.parse_string} returns. Comments
    and the original layout are not kept; see {!Token} for a lossless view of
    the source.

    Trees built by hand may lack the {!Ast.Paren} nodes that their structure
    needs, as in [Binary (Mul, Binary (Add, a, b), c)]. The printer adds the
    parentheses itself, so such a tree reads back with {!Ast.Paren} nodes in
    those places. *)

val expr : Format.formatter -> Ast.expr -> unit
(** [expr ppf e] prints [e], breaking lines to fit the margin of [ppf].

    Raises [Invalid_argument] if the tree has no Nix syntax, such as a variable
    whose name is not an identifier, or a float that is not finite. *)

val to_string : Ast.expr -> string
(** As {!val-expr}, into a string. *)
