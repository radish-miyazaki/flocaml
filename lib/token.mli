(** A lossless view of the source as a list of tokens.

    {!tokenize} splits the source into tokens that cover every byte, whitespace
    and comments included, so that concatenating their texts gives back the
    source. Tools that must keep the layout, such as formatters, syntax
    highlighters and refactoring tools, work on these tokens and use the syntax
    tree to know what they mean.

    Tokenizing does not parse, so it succeeds on sources with syntax errors, and
    fails only where the lexer itself does, such as in an unterminated string.
*)

type kind =
  | Whitespace
  | Comment
  | Keyword  (** [if], [let], [or], ... *)
  | Identifier
  | Integer
  | Float
  | String_start
      (** A double quote, or the two single quotes that open an indented string
          together with the rest of their line if it is blank. *)
  | String_end
  | String_text
      (** Literal text and escape sequences inside a string, as written. *)
  | Interpolation_start  (** [${] *)
  | Interpolation_end  (** The [}] that closes [${]. *)
  | Path  (** A path, or a part of one between interpolations. *)
  | Search_path  (** [<nixpkgs>] *)
  | Uri
  | Operator  (** [==], [++], [!], [?], ... *)
  | Punctuation  (** [{], [;], [=], [...], ... *)

type t = { kind : kind; text : string; loc : Location.t }

val tokenize :
  ?filename:string ->
  ?features:Feature.t list ->
  string ->
  (t list, Syntax_error.t) result
(** [tokenize source] lists the tokens of [source] in order. Their texts
    concatenate to [source]. *)
