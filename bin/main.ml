open Cmdliner

let read_file = function
  | "-" -> In_channel.input_all stdin
  | path -> In_channel.with_open_bin path In_channel.input_all

let features =
  let feature =
    Arg.enum
      (List.map (fun f -> (Flocaml.Feature.to_string f, f)) Flocaml.Feature.all)
  in
  let doc = "Accept the experimental language feature $(docv)." in
  Arg.(value & opt_all feature [] & info [ "feature" ] ~docv:"NAME" ~doc)

(* The file name and the source of the expression to read. *)
let input =
  let expr =
    Arg.(
      value
      & opt (some string) None
      & info [ "e"; "expr" ] ~docv:"EXPR" ~doc:"Read $(docv) instead of a file.")
  in
  let file =
    Arg.(
      value
      & pos 0 (some string) None
      & info [] ~docv:"FILE" ~doc:"The file to read, or $(b,-) for stdin.")
  in
  let input expr file =
    match (expr, file) with
    | Some e, _ -> ("", e)
    | None, Some path -> (path, read_file path)
    | None, None -> ("", read_file "-")
  in
  Term.(const input $ expr $ file)

let with_tree features (filename, source) f =
  match Flocaml.parse_string ~filename ~features source with
  | Ok parsed ->
      f parsed;
      0
  | Error e ->
      Format.eprintf "%a@." Flocaml.Syntax_error.pp e;
      1

let parse features show_comments input =
  with_tree features input (fun { expr; comments } ->
      Format.printf "%a@." Flocaml.Ast_printer.expr expr;
      if show_comments then
        List.iter (Format.printf "%a@." Flocaml.Ast_printer.comment) comments)

let parse_cmd =
  let comments =
    Arg.(value & flag & info [ "comments" ] ~doc:"Also print the comments.")
  in
  let doc = "print the syntax tree of a Nix expression" in
  Cmd.v (Cmd.info "parse" ~doc) Term.(const parse $ features $ comments $ input)

let print features input =
  with_tree features input (fun { expr; _ } ->
      Format.printf "%a@." Flocaml.Printer.expr expr)

let print_cmd =
  let doc = "print a Nix expression again from its syntax tree" in
  let man =
    [
      `S Manpage.s_description;
      `P
        "Prints the expression as $(b,Flocaml.Printer) does: comments and the \
         original layout are lost.";
    ]
  in
  Cmd.v (Cmd.info "print" ~doc ~man) Term.(const print $ features $ input)

let token_kind : Flocaml.Token.kind -> string = function
  | Whitespace -> "Whitespace"
  | Comment -> "Comment"
  | Keyword -> "Keyword"
  | Identifier -> "Identifier"
  | Integer -> "Integer"
  | Float -> "Float"
  | String_start -> "String_start"
  | String_end -> "String_end"
  | String_text -> "String_text"
  | Interpolation_start -> "Interpolation_start"
  | Interpolation_end -> "Interpolation_end"
  | Path -> "Path"
  | Search_path -> "Search_path"
  | Uri -> "Uri"
  | Operator -> "Operator"
  | Punctuation -> "Punctuation"

let tokens features (filename, source) =
  match Flocaml.Token.tokenize ~filename ~features source with
  | Ok tokens ->
      List.iter
        (fun (t : Flocaml.Token.t) ->
          Format.printf "%a: %s %S@." Flocaml.Location.pp t.loc
            (token_kind t.kind) t.text)
        tokens;
      0
  | Error e ->
      Format.eprintf "%a@." Flocaml.Syntax_error.pp e;
      1

let tokens_cmd =
  let doc = "list the tokens of a Nix expression, whitespace included" in
  Cmd.v (Cmd.info "tokens" ~doc) Term.(const tokens $ features $ input)

let check features globals files =
  let globals = Flocaml.Check.default_globals @ globals in
  List.fold_left
    (fun status path ->
      match Flocaml.parse_string ~filename:path ~features (read_file path) with
      | Ok { expr; _ } -> (
          match Flocaml.Check.expr ~globals expr with
          | [] -> status
          | errors ->
              List.iter (Format.printf "%a@." Flocaml.Check.pp) errors;
              1)
      | Error e ->
          Format.printf "%a@." Flocaml.Syntax_error.pp e;
          1)
    0 files

let check_cmd =
  let globals =
    let doc =
      "Treat $(docv) as bound at the top level, in addition to the builtins."
    in
    Arg.(value & opt_all string [] & info [ "global" ] ~docv:"NAME" ~doc)
  in
  let files = Arg.(value & pos_all file [] & info [] ~docv:"FILE") in
  let doc = "report the errors that Nix finds in files before evaluation" in
  Cmd.v (Cmd.info "check" ~doc) Term.(const check $ features $ globals $ files)

let () =
  (* On Windows, text mode would turn CRLF into LF on input and LF into CRLF
     on output, which changes the locations and the printed strings. *)
  set_binary_mode_in stdin true;
  set_binary_mode_out stdout true;
  let doc = "parser for the Nix expression language" in
  exit
    (Cmd.eval'
       (Cmd.group (Cmd.info "flocaml" ~doc)
          [ parse_cmd; print_cmd; tokens_cmd; check_cmd ]))
