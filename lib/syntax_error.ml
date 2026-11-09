type kind =
  | Unexpected_token of { token : string; expected : string list }
  | Unexpected_character of string
  | Unterminated_string
  | Unterminated_comment
  | Trailing_slash_in_path
  | Invalid_integer of string
  | Disabled_feature of Feature.t

type t = { kind : kind; loc : Location.t }

let message = function
  | Unexpected_token { token; expected = [] } ->
      Printf.sprintf "unexpected %s" token
  | Unexpected_token { token; expected } ->
      Printf.sprintf "unexpected %s, expecting %s" token
        (String.concat " or " expected)
  | Unexpected_character c -> Printf.sprintf "unexpected character %S" c
  | Unterminated_string -> "unterminated string"
  | Unterminated_comment -> "unterminated comment"
  | Trailing_slash_in_path -> "path has a trailing slash"
  | Invalid_integer s -> Printf.sprintf "invalid integer %s" s
  | Disabled_feature feature ->
      Printf.sprintf "experimental feature '%s' is disabled"
        (Feature.to_string feature)

let pp ppf { kind; loc } =
  Format.fprintf ppf "%a: %s" Location.pp loc (message kind)
