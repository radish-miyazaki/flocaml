Double-quoted strings.

  $ nix-syntax parse -e '"a\nb\"c\\d\e"'
  (String "a\nb\"c\\de")
  $ nix-syntax parse -e '"a${b}c"'
  (String "a" (Interpolation (Var b)) "c")
  $ nix-syntax parse -e '"a$" + "$${x}" + "$\${y}"'
  (Add (Add (String "a$") (String "$${x}")) (String "$${y}"))
  $ nix-syntax parse -e '"a${"b${c}"}"'
  (String "a" (Interpolation (String "b" (Interpolation (Var c)))))
  $ nix-syntax parse -e '"abc'
  <string>:1:5: unterminated string
  [1]

Indented strings keep their indentation in the syntax tree.

  $ cat > indented.nix <<'EOF'
  > ''
  >   a ''${b} ''' ''\t
  >    ${c} $d 'e'
  > ''
  > EOF
  $ nix-syntax parse indented.nix
  (Indented_string
    "  a "
    (Escape "$")
    "{b} "
    (Escape "''")
    " "
    (Escape "\t")
    "\n   "
    (Interpolation (Var c))
    " $d 'e'\n")

Paths, search paths and URIs.

  $ nix-syntax parse -e './a/b.nix'
  (Path "./a/b.nix")
  $ nix-syntax parse -e '/abs a/b ~/c'
  (Apply (Apply (Path "/abs") (Path "a/b")) (Path "~/c"))
  $ nix-syntax parse -e './a/${b}/c${d}'
  (Path "./a/" (Interpolation (Var b)) "/c" (Interpolation (Var d)))
  $ nix-syntax parse -e '~/${a}'
  (Path "~/" (Interpolation (Var a)))
  $ nix-syntax parse -e '1/2'
  (Path "1/2")
  $ nix-syntax parse -e './a/'
  <string>:1:5: path has a trailing slash
  [1]
  $ nix-syntax parse -e '<nixpkgs/lib>'
  (Search_path "nixpkgs/lib")
  $ nix-syntax parse -e 'x:x'
  (Uri "x:x")
  $ nix-syntax parse -e 'https://example.com/a?b=c'
  (Uri "https://example.com/a?b=c")

Comments are collected apart from the tree.

  $ cat > comments.nix <<'EOF'
  > # line
  > a /* block */ + b # trailing
  > EOF
  $ nix-syntax parse --comments comments.nix
  (Add (Var a) (Var b))
  comments.nix:1:1: Line "# line"
  comments.nix:2:3: Block "/* block */"
  comments.nix:2:19: Line "# trailing"
  $ nix-syntax parse -e 'a /* b'
  <string>:1:3: unterminated comment
  [1]
