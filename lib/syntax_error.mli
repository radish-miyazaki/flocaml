(** Errors reported while reading a Nix expression. *)

type kind =
  | Unexpected_token of { token : string; expected : string list }
      (** The description of the offending token, and of the tokens that could
          have been there. [expected] is empty when there are too many to be
          helpful. *)
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
