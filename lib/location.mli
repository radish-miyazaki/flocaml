(** Source locations. *)

type t = { start : Lexing.position; stop : Lexing.position }
(** The range of bytes from [start] (inclusive) to [stop] (exclusive). *)

val none : t
(** A location that does not point into any source. *)

val of_positions : Lexing.position * Lexing.position -> t

val merge : t -> t -> t
(** [merge a b] spans from the start of [a] to the end of [b]. *)

val pp : Format.formatter -> t -> unit
(** Prints [file:line:column] of the start, with a 1-based column. *)
