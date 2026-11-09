Functions.

  $ flocaml parse -e 'x: y: x'
  (Lambda (Param_var x) (Lambda (Param_var y) (Var x)))
  $ flocaml parse -e '{ a, b ? 1, ... }: a'
  (Lambda (Param_pattern a (b (Int 1)) ...) (Var a))
  $ flocaml parse -e '{ a, }: a'
  (Lambda (Param_pattern a) (Var a))
  $ flocaml parse -e '{}: 1'
  (Lambda (Param_pattern) (Int 1))
  $ flocaml parse -e '{ ... } @ args: args'
  (Lambda (Param_pattern ... (Alias args)) (Var args))
  $ flocaml parse -e 'args @ { a }: a'
  (Lambda (Param_pattern a (Alias args)) (Var a))

Attribute sets and bindings.

  $ flocaml parse -e '{}'
  (Attrs)
  $ flocaml parse -e 'rec { a = 1; b = a; }'
  (Rec_attrs (Assign (a) (Int 1)) (Assign (b) (Var a)))
  $ flocaml parse -e '{ a.b.c = 1; ${d} = 2; "e${f}" = 3; or = 4; }'
  (Attrs
    (Assign (a b c) (Int 1))
    (Assign ((Dynamic (Var d))) (Int 2))
    (Assign ((Quoted "e" (Interpolation (Var f)))) (Int 3))
    (Assign (or) (Int 4)))
  $ flocaml parse -e '{ inherit a "b"; inherit (c) d; }'
  (Attrs (Inherit a (Quoted "b")) (Inherit (Var c) d))
  $ flocaml parse -e 'let a = 1; in a'
  (Let ((Assign (a) (Int 1))) (Var a))
  $ flocaml parse -e 'let in 1'
  (Let () (Int 1))
  $ flocaml parse -e 'let { a = 1; body = a; }'
  (Legacy_let (Assign (a) (Int 1)) (Assign (body) (Var a)))

Selection and application.

  $ flocaml parse -e 'a.b.c 1 (f x)'
  (Apply
    (Apply (Select (Var a) (b c)) (Int 1))
    (Paren (Apply (Var f) (Var x))))
  $ flocaml parse -e 'a.b or c.d or e'
  (Select (Var a) (b) (Select (Var c) (d) (Var e)))
  $ flocaml parse -e 'a.${b}."c"'
  (Select (Var a) ((Dynamic (Var b)) (Quoted "c")))
  $ flocaml parse -e '[ f or ]'
  (List (Apply (Var f) (Var or)))
  $ flocaml parse -e '[ 1 a.b (f x) ]'
  (List (Int 1) (Select (Var a) (b)) (Paren (Apply (Var f) (Var x))))

Control flow.

  $ flocaml parse -e 'if a then b else c'
  (If (Var a) (Var b) (Var c))
  $ flocaml parse -e 'with a; assert b; c'
  (With (Var a) (Assert (Var b) (Var c)))

Numbers follow the lexical rules of Nix, so "00.5" is an integer and a float.

  $ flocaml parse -e '1 2.5 .5 1.5e3 1. 00.5'
  (Apply
    (Apply
      (Apply
        (Apply (Apply (Apply (Int 1) (Float 2.5)) (Float 0.5)) (Float 1500.))
        (Float 1.))
      (Int 0))
    (Float 0.5))
  $ flocaml parse -e '9223372036854775807'
  (Int 9223372036854775807)
  $ flocaml parse -e '9223372036854775808'
  <string>:1:1: invalid integer 9223372036854775808
  [1]
