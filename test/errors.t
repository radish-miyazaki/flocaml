A short list of expected tokens follows the unexpected one.

  $ flocaml parse -e '{ a = 1 }'
  <string>:1:9: unexpected '}'
  [1]
  $ flocaml parse -e 'a.'
  <string>:1:3: unexpected end of input, expecting identifier or '"' or '${' or 'or'
  [1]
  $ flocaml parse -e 'if a then b'
  <string>:1:12: unexpected end of input
  [1]
  $ flocaml parse -e '(a'
  <string>:1:3: unexpected end of input
  [1]
  $ flocaml parse -e 'a +'
  <string>:1:4: unexpected end of input
  [1]

Text cannot follow the head of a path without an interpolation in between.

  $ flocaml parse -e '/a//b'
  <string>:1:6: unexpected end of path, expecting string content or '${'
  [1]
  $ flocaml parse -e '/a/${b}/c'
  (Path "/a/" (Interpolation (Var b)) "/c")

The names in inherit must be known without evaluation.

  $ flocaml parse -e '{ inherit "a"; }'
  (Attrs (Inherit (Quoted "a")))
  $ flocaml parse -e '{ inherit "${a}"; }'
  <string>:1:12: unexpected '${', expecting string content or '"'
  [1]
  $ flocaml parse -e '{ inherit ${a}; }'
  <string>:1:11: unexpected '${'
  [1]

Errors from the lexer.

  $ flocaml parse -e 'a ` b'
  <string>:1:3: unexpected character "`"
  [1]
  $ flocaml parse -e "''abc"
  <string>:1:6: unterminated string
  [1]
