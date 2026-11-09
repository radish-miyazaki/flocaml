(* Follows Nix's [stripIndentation]. Escapes and interpolations end the leading
   whitespace of a line without counting as indentation, and only the last
   token may lose a trailing line of spaces. *)
let strip_indentation parts =
  let at_line_start = ref true
  and current = ref 0
  and min_indent = ref max_int in
  let end_of_indent () =
    if !at_line_start then begin
      at_line_start := false;
      min_indent := min !min_indent !current
    end
  in
  List.iter
    (function
      | Ast.Text s ->
          String.iter
            (fun c ->
              if !at_line_start then
                match c with
                | ' ' -> incr current
                | '\n' -> current := 0
                | _ -> end_of_indent ()
              else if c = '\n' then begin
                at_line_start := true;
                current := 0
              end)
            s
      | Escape _ | Interpolation _ -> end_of_indent ())
    parts;
  let min_indent = !min_indent in
  let at_line_start = ref true and dropped = ref 0 in
  let trim ~last s =
    let b = Buffer.create (String.length s) in
    String.iter
      (fun c ->
        if !at_line_start then (
          match c with
          | ' ' ->
              if !dropped >= min_indent then Buffer.add_char b c;
              incr dropped
          | '\n' ->
              dropped := 0;
              Buffer.add_char b c
          | c ->
              at_line_start := false;
              dropped := 0;
              Buffer.add_char b c)
        else begin
          Buffer.add_char b c;
          if c = '\n' then at_line_start := true
        end)
      s;
    let s = Buffer.contents b in
    if not last then s
    else
      match String.rindex_opt s '\n' with
      | Some i
        when String.for_all (( = ) ' ')
               (String.sub s (i + 1) (String.length s - i - 1)) ->
          String.sub s 0 (i + 1)
      | _ -> s
  in
  let rec go = function
    | [] -> []
    | (Ast.Interpolation _ as part) :: rest ->
        at_line_start := false;
        dropped := 0;
        part :: go rest
    | (Text s | Escape s) :: rest ->
        let s = trim ~last:(rest = []) s in
        if s = "" then go rest else Text s :: go rest
  in
  go parts

(* A string with an interpolation is a concatenation in Nix, even when the
   interpolated expression is itself a plain string. *)
let rec static_string (e : Ast.expr) =
  match e.desc with
  | Paren e -> static_string e
  | String [] -> Some ""
  | String [ Text s ] -> Some s
  | Indented_string parts -> (
      match strip_indentation parts with
      | [] -> Some ""
      | [ Text s ] -> Some s
      | _ -> None)
  | _ -> None

let attr_name = function
  | Ast.Name x -> Some x
  | Quoted [] -> Some ""
  | Quoted [ Text s ] -> Some s
  | Quoted _ -> None
  | Dynamic e -> static_string e
