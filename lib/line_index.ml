type encoding = Utf8 | Utf16 | Utf32
type position = { line : int; column : int }

type t = {
  source : string;
  starts : int array;  (** The offset at which each line starts. *)
}

let of_string source =
  let n = String.length source in
  let starts = ref [ 0 ] in
  let i = ref 0 in
  while !i < n do
    (match source.[!i] with
    | '\n' -> starts := (!i + 1) :: !starts
    | '\r' ->
        if !i + 1 < n && source.[!i + 1] = '\n' then incr i;
        starts := (!i + 1) :: !starts
    | _ -> ());
    incr i
  done;
  { source; starts = Array.of_list (List.rev !starts) }

let line_count t = Array.length t.starts

(* The end of line [l], before its line break. *)
let line_end t l =
  if l + 1 < Array.length t.starts then
    let next = t.starts.(l + 1) in
    if next >= 2 && String.sub t.source (next - 2) 2 = "\r\n" then next - 2
    else next - 1
  else String.length t.source

(* The length in bytes of the UTF-8 sequence starting at [i], or 1 if it is
   not a valid one. *)
let char_length s i =
  let d = String.get_utf_8_uchar s i in
  if Uchar.utf_decode_is_valid d then Uchar.utf_decode_length d else 1

(* The number of units that the character at [i] counts for. *)
let units encoding s i =
  match encoding with
  | Utf8 -> char_length s i
  | Utf32 -> 1
  | Utf16 ->
      let d = String.get_utf_8_uchar s i in
      if
        Uchar.utf_decode_is_valid d
        && Uchar.to_int (Uchar.utf_decode_uchar d) >= 0x10000
      then 2
      else 1

(* The last line starting at or before [offset]. *)
let line_of_offset t offset =
  let rec search lo hi =
    if lo >= hi then lo
    else
      let mid = (lo + hi + 1) / 2 in
      if t.starts.(mid) <= offset then search mid hi else search lo (mid - 1)
  in
  search 0 (Array.length t.starts - 1)

let position t encoding offset =
  if offset < 0 then invalid_arg "Line_index.position";
  let offset = min offset (String.length t.source) in
  let line = line_of_offset t offset in
  let rec count i column =
    if i >= offset then column
    else
      let next = i + char_length t.source i in
      if next > offset then column
      else count next (column + units encoding t.source i)
  in
  { line; column = count t.starts.(line) 0 }

let offset t encoding { line; column } =
  if line < 0 || column < 0 then invalid_arg "Line_index.offset";
  if line >= Array.length t.starts then String.length t.source
  else
    let stop = line_end t line in
    let rec walk i remaining =
      if remaining <= 0 || i >= stop then i
      else
        let u = units encoding t.source i in
        (* A column inside a character stays at its start. *)
        if u > remaining then i
        else walk (i + char_length t.source i) (remaining - u)
    in
    walk t.starts.(line) column
