type t = { start : Lexing.position; stop : Lexing.position }

let none = { start = Lexing.dummy_pos; stop = Lexing.dummy_pos }
let of_positions (start, stop) = { start; stop }
let merge a b = { start = a.start; stop = b.stop }

let pp ppf { start; _ } =
  let file = if start.pos_fname = "" then "<string>" else start.pos_fname in
  Format.fprintf ppf "%s:%d:%d" file start.pos_lnum
    (start.pos_cnum - start.pos_bol + 1)
