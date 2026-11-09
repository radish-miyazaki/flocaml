(** Errors reported while reading a Nix expression. *)

type kind =
  | Unexpected_token of string  (** The description of the offending token. *)
  | Unexpected_character of string
  | Unterminated_string
  | Unterminated_comment
  | Trailing_slash_in_path
  | Invalid_integer of string
  | Disabled_feature of Feature.t

type t = { kind : kind; loc : Location.t }

val message : kind -> string

val pp : Format.formatter -> t -> unit
(** Prints [file:line:column: message]. *)
