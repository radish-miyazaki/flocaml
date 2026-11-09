The tokens cover the whole source, whitespace and comments included.

  $ cat > a.nix <<'EOF'
  > { x = "a${b}"; # c
  >   y = ./p/${q}; }
  > EOF
  $ flocaml tokens a.nix
  a.nix:1:1: Punctuation "{"
  a.nix:1:2: Whitespace " "
  a.nix:1:3: Identifier "x"
  a.nix:1:4: Whitespace " "
  a.nix:1:5: Punctuation "="
  a.nix:1:6: Whitespace " "
  a.nix:1:7: String_start "\""
  a.nix:1:8: String_text "a"
  a.nix:1:9: Interpolation_start "${"
  a.nix:1:11: Identifier "b"
  a.nix:1:12: Interpolation_end "}"
  a.nix:1:13: String_end "\""
  a.nix:1:14: Punctuation ";"
  a.nix:1:15: Whitespace " "
  a.nix:1:16: Comment "# c"
  a.nix:1:19: Whitespace "\n  "
  a.nix:2:3: Identifier "y"
  a.nix:2:4: Whitespace " "
  a.nix:2:5: Punctuation "="
  a.nix:2:6: Whitespace " "
  a.nix:2:7: Path "./p/"
  a.nix:2:11: Interpolation_start "${"
  a.nix:2:13: Identifier "q"
  a.nix:2:14: Interpolation_end "}"
  a.nix:2:15: Punctuation ";"
  a.nix:2:16: Whitespace " "
  a.nix:2:17: Punctuation "}"
  a.nix:2:18: Whitespace "\n"

Syntax errors do not stop the tokens, but errors of the lexer do.

  $ flocaml tokens -e 'in in'
  <string>:1:1: Keyword "in"
  <string>:1:3: Whitespace " "
  <string>:1:4: Keyword "in"
  $ flocaml tokens -e '"a'
  <string>:1:3: unterminated string
  [1]
