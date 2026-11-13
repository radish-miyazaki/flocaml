## 0.2.0 (2026-11-13)

- Rename the project from flocaml to nix-syntax, following the naming policy of opam-repository. The package, the library and the command are now `nix-syntax`, and the module is `Nix_syntax`.
- Declare in the opam file that only the latest version is maintained.

## 0.1.2 (2026-11-12)

- Keep MSYS2 from rewriting the paths given to the tests, which made them fail on Windows.

## 0.1.1 (2026-11-11)

- Print the exponent of a float without leading zeros, as `1.0e+20` and not `1.0e+020` on Windows.
- Read and write the standard channels of the `flocaml` command in binary mode, so that it keeps CRLF on Windows.

## 0.1.0 (2026-11-09)

First release.

- Parse Nix expressions into a syntax tree that keeps parentheses, comments and the location of every node. On every file of nixpkgs, the tree matches that of `nix-instantiate --parse`.
- Add `Check`, which finds the errors that Nix reports after parsing, such as an attribute defined twice or an undefined variable.
- Add `Printer`, which prints a tree as Nix source and adds the parentheses it needs.
- Add `Token`, a lossless list of tokens that includes whitespace and comments.
- Add `Ast_iterator` and `Ast_mapper` to visit and rewrite trees, and `Locate` to find the nodes at a point of the source.
- Add `Line_index`, which converts byte offsets to lines and columns in UTF-8, UTF-16 or code points.
- Add the `flocaml` command, with `parse`, `print`, `tokens` and `check`.
