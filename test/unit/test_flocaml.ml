(* Tests of the library functions that the cram tests do not reach through
   the command line. Prints each failure and exits with 1 if there is any. *)

open Flocaml

let failures = ref 0

let check name ~expected actual show =
  if expected <> actual then begin
    incr failures;
    Printf.printf "FAIL %s\n  expected: %s\n  actual:   %s\n" name
      (show expected) (show actual)
  end

let parse source =
  match parse_string source with
  | Ok { expr; _ } -> expr
  | Error e -> failwith (Format.asprintf "%a" Syntax_error.pp e)

let id x = x
let mk desc : Ast.expr = { desc; loc = Location.none }
let var x = mk (Var x)
let binary op l r = mk (Binary (op, l, r))

(* Trees built without Paren nodes get the parentheses they need. *)
let printer () =
  let cases =
    [
      ( "mul of add",
        binary Mul (binary Add (var "a") (var "b")) (var "c"),
        "(a + b) * c" );
      ( "add of mul",
        binary Add (binary Mul (var "a") (var "b")) (var "c"),
        "a * b + c" );
      ( "sub right",
        binary Sub (var "a") (binary Sub (var "b") (var "c")),
        "a - (b - c)" );
      ("not left", binary Mul (mk (Unary (Not, var "a"))) (var "b"), "(!a) * b");
      ( "not inside",
        binary Add (binary Mul (var "a") (mk (Unary (Not, var "b")))) (var "c"),
        "a * (!b) + c" );
      ( "apply arg",
        mk (Apply (var "f", mk (Apply (var "g", var "x")))),
        "f (g x)" );
      ( "lambda operand",
        binary Add
          (mk (Lambda (Param_var { txt = "x"; loc = Location.none }, var "x")))
          (var "y"),
        "(x: x) + y" );
      ("negative int", mk (Apply (var "f", mk (Int (-1L)))), "f (-1)");
      ("float exponent", mk (Float 1e300), "1.0e+300");
      ( "mixed pipes",
        binary Pipe_into (binary Pipe_from (var "f") (var "a")) (var "g"),
        "(f <| a) |> g" );
      ( "keyword attribute",
        mk
          (Select
             {
               expr = var "a";
               path = [ { txt = Name "if"; loc = Location.none } ];
               default = None;
             }),
        "a.\"if\"" );
    ]
  in
  List.iter
    (fun (name, e, expected) ->
      check ("printer: " ^ name) ~expected (Printer.to_string e) id;
      (* The output must parse. *)
      match parse_string ~features:Feature.all (Printer.to_string e) with
      | Ok _ -> ()
      | Error err ->
          incr failures;
          Format.printf "FAIL printer: %s does not parse: %a@." name
            Syntax_error.pp err)
    cases;
  match Printer.to_string (var "a b") with
  | _ ->
      incr failures;
      print_endline "FAIL printer: accepted an invalid variable name"
  | exception Invalid_argument _ -> ()

let line_index () =
  (* "é" is 2 bytes and 1 UTF-16 unit; "😀" is 4 bytes and 2 units. *)
  let source = "a\r\né😀x\ry" in
  let index = Line_index.of_string source in
  let show { Line_index.line; column } = Printf.sprintf "%d:%d" line column in
  check "line_index: count" ~expected:3
    (Line_index.line_count index)
    string_of_int;
  let x = String.index source 'x' in
  List.iter
    (fun (encoding, name, column) ->
      check
        ("line_index: position " ^ name)
        ~expected:{ Line_index.line = 1; column }
        (Line_index.position index encoding x)
        show;
      check
        ("line_index: offset " ^ name)
        ~expected:x
        (Line_index.offset index encoding { line = 1; column })
        string_of_int)
    [ (Utf8, "utf8", 6); (Utf16, "utf16", 3); (Utf32, "utf32", 2) ];
  check "line_index: after CR"
    ~expected:{ Line_index.line = 2; column = 0 }
    (Line_index.position index Utf16 (String.index source 'y'))
    show;
  check "line_index: column past the end" ~expected:1
    (Line_index.offset index Utf16 { line = 0; column = 10 })
    string_of_int;
  check "line_index: inside a character"
    ~expected:{ Line_index.line = 1; column = 1 }
    (Line_index.position index Utf16 (String.index source 'x' - 1))
    show

let locate () =
  let source = "{ a = f x; }" in
  let e = parse source in
  let describe = function
    | Locate.Expr { desc = Var x; _ } -> "Var " ^ x
    | Expr { desc = Apply _; _ } -> "Apply"
    | Expr { desc = Attrs _; _ } -> "Attrs"
    | Expr _ -> "Expr"
    | Attr _ -> "Attr"
    | Binding _ -> "Binding"
    | Name _ -> "Name"
  in
  let at offset = List.map describe (Locate.nodes_at e offset) in
  let show = String.concat ", " in
  check "locate: argument"
    ~expected:[ "Var x"; "Apply"; "Binding"; "Attrs" ]
    (at (String.index source 'x'))
    show;
  check "locate: attribute name"
    ~expected:[ "Attr"; "Binding"; "Attrs" ]
    (at (String.index source 'a'))
    show;
  check "locate: outside" ~expected:[] (at 100) show

let iterator () =
  let e = parse "{ a, b ? c }: let d = a; in [ b d ]" in
  let found = ref [] in
  let d = Ast_iterator.default_iterator in
  let it =
    {
      d with
      expr =
        (fun it (e : Ast.expr) ->
          (match e.desc with Var x -> found := x :: !found | _ -> ());
          d.expr it e);
      name =
        (fun _ (x : string Ast.loc) -> found := ("name " ^ x.txt) :: !found);
    }
  in
  it.expr it e;
  check "iterator: order"
    ~expected:[ "name a"; "name b"; "c"; "a"; "b"; "d" ]
    (List.rev !found) (String.concat ", ")

let parse_file () =
  let path = Filename.temp_file "flocaml" ".nix" in
  Out_channel.with_open_bin path (fun oc -> output_string oc "1 +");
  let result = Flocaml.parse_file path in
  Sys.remove path;
  match result with
  | Error { loc; _ } ->
      check "parse_file: file name" ~expected:path loc.start.pos_fname id
  | Ok _ ->
      incr failures;
      print_endline "FAIL parse_file: accepted an incomplete expression"

let () =
  printer ();
  line_index ();
  locate ();
  iterator ();
  parse_file ();
  if !failures > 0 then exit 1
