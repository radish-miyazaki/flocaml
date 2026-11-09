(** Experimental language features that must be enabled explicitly, as with
    Nix's [experimental-features] setting. *)

type t = Pipe_operators  (** The [|>] and [<|] operators. *)

val all : t list

val to_string : t -> string
(** The name Nix uses for the feature, such as ["pipe-operators"]. *)

val of_string : string -> t option
