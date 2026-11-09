type node =
  | Expr of Ast.expr
  | Attr of Ast.attr Ast.loc
  | Binding of Ast.binding Ast.loc
  | Name of string Ast.loc

let loc = function
  | Expr e -> e.loc
  | Attr { loc; _ } | Binding { loc; _ } | Name { loc; _ } -> loc

let contains (loc : Location.t) offset =
  loc.start.pos_cnum <= offset && offset < loc.stop.pos_cnum

(* Nodes are nested, so a node outside [offset] has no child inside it, and
   each node found is inside the ones found before. *)
let nodes_at e offset =
  let found = ref [] in
  let visit node default =
    if contains (loc node) offset then begin
      found := node :: !found;
      default ()
    end
  in
  let d = Ast_iterator.default_iterator in
  let it =
    {
      d with
      expr = (fun it e -> visit (Expr e) (fun () -> d.expr it e));
      attr = (fun it a -> visit (Attr a) (fun () -> d.attr it a));
      binding = (fun it b -> visit (Binding b) (fun () -> d.binding it b));
      name = (fun _ x -> visit (Name x) ignore);
    }
  in
  it.expr it e;
  !found
