(** Conversion between byte offsets and line-column positions.

    {!Location.t} counts columns in bytes. Editors count them in other units:
    the Language Server Protocol uses UTF-16 code units by default. An index is
    built once per source and answers in any of these units.

    Lines end at LF, CRLF or a lone CR, as in the Language Server Protocol.
    Bytes that are not valid UTF-8 count as one character each. *)

type t

(** The unit of columns. *)
type encoding =
  | Utf8  (** Bytes, as in {!Location.t}. *)
  | Utf16
      (** UTF-16 code units, the default of the Language Server Protocol. *)
  | Utf32  (** Unicode code points. *)

type position = { line : int; column : int }
(** Both count from 0. *)

val of_string : string -> t
(** [of_string source] indexes the lines of [source]. *)

val line_count : t -> int

val position : t -> encoding -> int -> position
(** [position index encoding offset] is the position of the byte at [offset]. An
    offset inside a character is taken as the start of that character, and an
    offset past the end of the source as the end.

    Raises [Invalid_argument] if [offset] is negative. *)

val offset : t -> encoding -> position -> int
(** [offset index encoding position] is the byte offset of [position], the
    inverse of {!val-position}. A column past the end of its line is taken as
    the end of the line, and a line past the last as the end of the source.

    Raises [Invalid_argument] if [position] has a negative component. *)
