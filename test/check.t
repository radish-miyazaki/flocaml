The check command reports what Nix rejects after parsing.

  $ cat > dup.nix <<'EOF'
  > {
  >   a = 1;
  >   a = 2;
  >   b.c = 1;
  >   b = { c = 2; };
  > }
  > EOF
  $ nix-syntax check dup.nix
  dup.nix:3:3: attribute 'a' already defined at dup.nix:2:3
  dup.nix:5:9: attribute 'b.c' already defined at dup.nix:4:5
  [1]

Sets assigned to the same name are merged.

  $ echo '{ a.b = 1; a = { c = 2; }; a = { d.e = 3; }; }' > merge.nix
  $ nix-syntax check merge.nix

A merged set keeps whether the first one is recursive.

  $ echo '{ a = { x = 1; }; a = rec { y = x; }; }' > rec.nix
  $ nix-syntax check rec.nix
  rec.nix:1:33: undefined variable 'x'
  [1]

Names in inherit and in formals.

  $ echo '{ inherit a; a = 1; }' > inherit.nix
  $ nix-syntax check inherit.nix
  inherit.nix:1:11: undefined variable 'a'
  inherit.nix:1:14: attribute 'a' already defined at inherit.nix:1:11
  [1]
  $ echo '{ a, b ? a, a ? 1 } @ b: a' > formals.nix
  $ nix-syntax check formals.nix
  formals.nix:1:13: duplicate formal function argument 'a'
  formals.nix:1:23: duplicate formal function argument 'b'
  [1]

Let bindings cannot have names known only at evaluation.

  $ echo 'let ${"a"} = 1; ${b} = 2; in a' > let.nix
  $ nix-syntax check let.nix
  let.nix:1:1: dynamic attributes not allowed in let
  let.nix:1:19: undefined variable 'b'
  [1]

Any enclosing with may bind a variable. Other names can be added to the
builtins with --global.

  $ echo 'pkgs: with pkgs; [ hello ] ++ extra' > with.nix
  $ nix-syntax check with.nix
  $ echo '[ extra ]' > global.nix
  $ nix-syntax check global.nix
  global.nix:1:3: undefined variable 'extra'
  [1]
  $ nix-syntax check --global extra global.nix
