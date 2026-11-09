## unreleased

First release.

- Parse Nix expressions into a syntax tree that keeps parentheses, comments
  and the location of every node. On every file of nixpkgs, the tree is the
  same as that of `nix-instantiate --parse`.
- `Check`: the errors that Nix reports after parsing, such as an attribute
  defined twice or an undefined variable.
- `Printer`: print a tree as Nix source, adding the parentheses it needs.
- `Token`: a lossless list of tokens, whitespace and comments included.
- `Ast_iterator`, `Ast_mapper` and `Locate`: visit and rewrite trees, and find
  the nodes at a point of the source.
- `Line_index`: convert byte offsets to lines and columns in UTF-8, UTF-16 or
  code points.
- The `flocaml` command, with `parse`, `print`, `tokens` and `check`.
