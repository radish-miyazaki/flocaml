Operator precedence and associativity follow Nix.

  $ flocaml parse -e 'a -> b -> c'
  (Implies (Var a) (Implies (Var b) (Var c)))
  $ flocaml parse -e 'a ++ b * c'
  (Mul (Concat (Var a) (Var b)) (Var c))
  $ flocaml parse -e 'a ++ b ++ c'
  (Concat (Var a) (Concat (Var b) (Var c)))
  $ flocaml parse -e '!a // b'
  (Update (Not (Var a)) (Var b))
  $ flocaml parse -e '!a ? b'
  (Not (Has_attr (Var a) (b)))
  $ flocaml parse --expr='- a ? b'
  (Has_attr (Negate (Var a)) (b))
  $ flocaml parse --expr='- a b'
  (Negate (Apply (Var a) (Var b)))
  $ flocaml parse -e 'a - -1'
  (Sub (Var a) (Negate (Int 1)))
  $ flocaml parse -e 'a + b ? c'
  (Add (Var a) (Has_attr (Var b) (c)))
  $ flocaml parse -e 'a && b || c'
  (Or (And (Var a) (Var b)) (Var c))
  $ flocaml parse -e 'a || b && c'
  (Or (Var a) (And (Var b) (Var c)))
  $ flocaml parse -e 'a < b == c'
  (Eq (Lt (Var a) (Var b)) (Var c))
  $ flocaml parse -e 'a // b // c'
  (Update (Var a) (Update (Var b) (Var c)))

Comparison and equality do not chain.

  $ flocaml parse -e 'a == b == c'
  <string>:1:8: unexpected '=='
  [1]
  $ flocaml parse -e 'a < b < c'
  <string>:1:7: unexpected '<'
  [1]

Pipe operators bind more loosely than any other operator, and must be enabled.

  $ flocaml parse --feature pipe-operators -e 'x |> f |> g'
  (Pipe_into (Pipe_into (Var x) (Var f)) (Var g))
  $ flocaml parse --feature pipe-operators -e 'f <| g <| x'
  (Pipe_from (Var f) (Pipe_from (Var g) (Var x)))
  $ flocaml parse --feature pipe-operators -e 'a |> b -> c'
  (Pipe_into (Var a) (Implies (Var b) (Var c)))
  $ flocaml parse --feature pipe-operators -e 'a |> b <| c'
  <string>:1:8: unexpected '<|'
  [1]
  $ flocaml parse -e 'x |> f'
  <string>:1:3: experimental feature 'pipe-operators' is disabled
  [1]
