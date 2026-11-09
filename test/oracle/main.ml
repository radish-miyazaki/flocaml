(* Prints each file in the format of [nix-instantiate --parse], one line per
   file, or a line starting with "error:" when the file cannot be read. *)

let absolute path =
  if Filename.is_relative path then Filename.concat (Sys.getcwd ()) path
  else path

let show home path =
  let ctx = { Nix_show.base_dir = Filename.dirname (absolute path); home } in
  let source = In_channel.with_open_bin path In_channel.input_all in
  match Flocaml.parse_string ~filename:path source with
  | Ok { expr; _ } -> (
      try Nix_show.to_string ctx expr
      with Nix_show.Unsupported msg -> "error: " ^ msg)
  | Error e -> Format.asprintf "error: %a" Flocaml.Syntax_error.pp e

let () =
  let home = Option.value (Sys.getenv_opt "HOME") ~default:"" in
  Array.iteri
    (fun i path -> if i > 0 then print_endline (show home path))
    Sys.argv
