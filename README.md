# flocaml

A parser for the [Nix](https://nixos.org) expression language, written in OCaml.

The name comes from *flocon*, French for snowflake, and Caml.

flocaml reads Nix expressions into a syntax tree that follows the concrete
syntax: nothing is desugared, parentheses are kept, and every node carries its
source location. Comments are collected alongside the tree, and the source can
also be read as a lossless list of tokens. This makes it suitable for tools
that inspect or rewrite Nix files.

## Status

Early development. The API is not stable yet.

On every `.nix` file in nixpkgs, flocaml produces the same expressions as
`nix-instantiate --parse`. `test/oracle/compare.sh DIR` runs this comparison
on the files under `DIR`, and `test/oracle/cases.sh` runs it on expressions
that Nix rejects after parsing. `test/roundtrip` checks on the same files that
printing a tree gives it back, and that the tokens give back the source.

## Usage

```ocaml
match Flocaml.parse_file "default.nix" with
| Ok { expr; comments } -> Format.printf "%a@." Flocaml.Printer.expr expr
| Error e -> Format.eprintf "%a@." Flocaml.Syntax_error.pp e
```

The library provides:

| Module | Purpose |
|---|---|
| `Ast` | The syntax tree |
| `Check` | The errors that Nix finds after parsing: an attribute defined twice, a duplicate function argument, or a variable that is not bound |
| `Printer` | Printing a tree as Nix source, with the parentheses it needs |
| `Token` | The source as tokens that cover every byte, whitespace and comments included |
| `Ast_iterator`, `Ast_mapper` | Visiting and rewriting trees, in the style of OCaml's compiler-libs |
| `Locate` | The nodes at a point of the source |
| `Line_index` | Line and column positions in bytes, UTF-16 or code points, for editors |
| `Literal` | The values of string literals and attribute names, as Nix computes them |
| `Ast_printer` | A dump of the tree for debugging |

The `flocaml` command exposes most of these:

```console
$ flocaml parse -e '{ a ? 1 }: a + 1'
(Lambda (Param_pattern (a (Int 1))) (Add (Var a) (Int 1)))
$ flocaml print -e '{a=1;}'
{ a = 1; }
$ flocaml tokens default.nix
$ flocaml check default.nix
```

Experimental syntax such as the pipe operators `|>` and `<|` is rejected
unless enabled with `--feature pipe-operators` (or `~features` in the API).

## Building

With Nix:

```sh
nix build
nix develop -c dune test
```

With opam, install `menhir`, `menhirLib`, `sedlex` and `cmdliner`, then run
`dune build`. flocaml needs OCaml 4.14 or later and dune 3.0 or later.

## License

ISC
