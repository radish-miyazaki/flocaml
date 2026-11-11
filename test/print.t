The printer gives back an expression that parses to the same tree. This
helper prints an expression and says if the tree changes.

  $ roundtrip () {
  >   flocaml parse --expr="$1" > before
  >   flocaml print --expr="$1" > printed.nix
  >   cat printed.nix
  >   flocaml parse printed.nix > after
  >   cmp -s before after || echo "TREE CHANGED"
  > }

Prefix operators take everything that binds more tightly than themselves.

  $ roundtrip '!a + b'
  !a + b
  $ roundtrip '(!a) + b'
  (!a) + b
  $ roundtrip 'a * !b'
  a * !b
  $ roundtrip '(a * !b) + c'
  (a * !b) + c
  $ roundtrip '- -a'
  - -a
  $ roundtrip '-!a'
  -!a
  $ roundtrip '- ./a'
  - ./a
  $ roundtrip '-a ? b'
  -a ? b
  $ roundtrip '!a ? b'
  !a ? b

Associativity, and the operators that Nix does not chain.

  $ roundtrip 'a - b - c'
  a - b - c
  $ roundtrip 'a - (b - c)'
  a - (b - c)
  $ roundtrip 'a ++ b ++ c'
  a ++ b ++ c
  $ roundtrip 'a -> b -> c'
  a -> b -> c
  $ roundtrip '(a == b) == c'
  (a == b) == c
  $ roundtrip 'f x y'
  f x y
  $ roundtrip 'f (x y)'
  f (x y)

Tokens that would run together without a space.

  $ roundtrip '1 .a'
  1 .a
  $ roundtrip './a .b'
  ./a .b
  $ roundtrip 'x: x'
  x: x
  $ roundtrip 'f or'
  f or
  $ roundtrip 'a.b or c'
  a.b or c
  $ roundtrip '{ or = 1; "if" = 2; "a b" = 3; }.or'
  { or = 1; "if" = 2; "a b" = 3; }.or

Numbers.

  $ roundtrip '[ 1.5 1.0e+20 1.0e-05 0.1 100.0 ]'
  [ 1.5 1.0e+20 1.0e-5 0.1 100.0 ]

Strings are escaped only where needed. A pair of dollars keeps the brace
after it literal.

  $ roundtrip '"a\"b\\c\n$x ${y} \${z} $${w}"'
  "a\"b\\c\n$x ${y} \${z} $${w}"
  $ roundtrip "''a ''\${b} \${c} \$\${d} '''x ''\\n''"
  ''a ''${b} ${c} $${d} '''x ''\n''
  $ roundtrip "''
  >   a
  >     b
  > ''"
  ''
    a
      b
  ''

Layout follows the width of the line.

  $ flocaml print -e '{ pkgs, lib, ... }: { environment.systemPackages = with pkgs; [ git ripgrep fd jq ]; programs.zsh.enable = true; }'
  { pkgs, lib, ... }:
  {
    environment.systemPackages = with pkgs; [ git ripgrep fd jq ];
    programs.zsh.enable = true;
  }
