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

let parse features show_comments expr file =
  let filename, source =
    match (expr, file) with
    | Some e, _ -> ("", e)
    | None, Some path -> (path, read_file path)
    | None, None -> ("", read_file "-")
  in
  match Flocaml.parse_string ~filename ~features source with
  | Ok { expr; comments } ->
      Format.printf "%a@." Flocaml.Ast_printer.expr expr;
      if show_comments then
        List.iter (Format.printf "%a@." Flocaml.Ast_printer.comment) comments;
      0
  | Error e ->
      Format.eprintf "%a@." Flocaml.Syntax_error.pp e;
      1

let parse_cmd =
  let comments =
    Arg.(value & flag & info [ "comments" ] ~doc:"Also print the comments.")
  in
  let expr =
    Arg.(
      value
      & opt (some string) None
      & info [ "e"; "expr" ] ~docv:"EXPR"
          ~doc:"Parse $(docv) instead of a file.")
  in
  let file =
    Arg.(
      value
      & pos 0 (some string) None
      & info [] ~docv:"FILE" ~doc:"The file to parse, or $(b,-) for stdin.")
  in
  let doc = "print the syntax tree of a Nix expression" in
  Cmd.v (Cmd.info "parse" ~doc)
    Term.(const parse $ features $ comments $ expr $ file)

let check features files =
  List.fold_left
    (fun status path ->
      match Flocaml.parse_string ~filename:path ~features (read_file path) with
      | Ok _ -> status
      | Error e ->
          Format.printf "%a@." Flocaml.Syntax_error.pp e;
          1)
    0 files

let check_cmd =
  let files = Arg.(value & pos_all file [] & info [] ~docv:"FILE") in
  let doc = "report the syntax errors in Nix files" in
  Cmd.v (Cmd.info "check" ~doc) Term.(const check $ features $ files)

let () =
  let doc = "parser for the Nix expression language" in
  exit
    (Cmd.eval' (Cmd.group (Cmd.info "flocaml" ~doc) [ parse_cmd; check_cmd ]))
