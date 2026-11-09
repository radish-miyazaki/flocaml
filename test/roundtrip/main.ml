(* Checks on each file that the printer, the tokens and the default mapper
   lose nothing, and prints a line for each file that fails:

   - "print: FILE" when printing the tree and parsing it again gives another
     tree;
   - "tokens: FILE" when the texts of the tokens do not concatenate to the
     source;
   - "map: FILE" when the default mapper changes the tree.

   Files that do not parse are skipped. Exits with 1 if any line was
   printed. *)

let show e = Format.asprintf "%a" Flocaml.Ast_printer.expr e

let check path =
  let source = In_channel.with_open_bin path In_channel.input_all in
  match Flocaml.parse_string ~filename:path source with
  | Error _ -> []
  | Ok { expr; _ } ->
      let print =
        match Flocaml.parse_string (Flocaml.Printer.to_string expr) with
        | Ok { expr = again; _ } -> show again = show expr
        | Error _ -> false
        | exception Invalid_argument _ -> false
      in
      let tokens =
        match Flocaml.Token.tokenize source with
        | Ok tokens ->
            String.concat ""
              (List.map (fun (t : Flocaml.Token.t) -> t.text) tokens)
            = source
        | Error _ -> false
      in
      let map =
        let m = Flocaml.Ast_mapper.default_mapper in
        m.expr m expr = expr
      in
      List.filter_map
        (fun (ok, name) -> if ok then None else Some name)
        [ (print, "print"); (tokens, "tokens"); (map, "map") ]

let () =
  let failed = ref false in
  Array.iteri
    (fun i path ->
      if i > 0 then
        List.iter
          (fun name ->
            failed := true;
            Printf.printf "%s: %s\n%!" name path)
          (check path))
    Sys.argv;
  if !failed then exit 1
