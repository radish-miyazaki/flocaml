(** Lexer for Nix expressions.

    Nix needs a stateful lexer: inside strings and paths, [${] starts an
    expression and the matching [}] returns to the string or path. The lexer
    keeps a stack of modes to track this. *)

type t

exception Error of Syntax_error.t

val create : ?features:Feature.t list -> Sedlexing.lexbuf -> t
(** The buffer must decode the source as Latin-1 (see {!Sedlexing.Latin1}), so
    that positions count bytes and any byte sequence can be read, as Nix does.
*)

val token : t -> Tokens.token * Lexing.position * Lexing.position
(** Returns the next token, skipping whitespace and comments.

    @raise Error on malformed input. *)

val comments : t -> Ast.comment list
(** The comments read so far, in source order. *)

val name : Tokens.token -> string
(** The kind of the token for error messages, such as ["'=='"] or
    ["identifier"]. *)

val describe : Tokens.token -> string
(** As {!name}, but with the text of the token when it varies, such as
    ["identifier 'foo'"]. *)

val in_path : t -> bool
(** Whether the last token read continues a path, as the [b] of [./a/${x}b]
    does. *)

val in_string : t -> bool
(** Whether the lexer is inside a string, outside of any interpolation. *)
