# flocaml

A parser for the [Nix](https://nixos.org) expression language, written in OCaml.

The name comes from *flocon*, French for snowflake, and Caml.

flocaml reads Nix expressions into a syntax tree that follows the concrete syntax. Nothing is desugared, parentheses are kept, and every node carries its source location. Comments are collected alongside the tree, and the source can also be read as a lossless list of tokens. This makes it suitable for tools that inspect or rewrite Nix files.

## Status

flocaml is in early development, and its API may still change.

On every `.nix` file in nixpkgs, flocaml produces the same expressions as `nix-instantiate --parse`. `test/oracle/compare.sh DIR` runs this comparison on the files under `DIR`, and `test/oracle/cases.sh` runs it on expressions that Nix rejects after parsing. `test/roundtrip` checks on the same files that printing a tree gives it back, and that the tokens give back the source.

## Usage

```ocaml
match Flocaml.parse_file "default.nix" with
| Ok { expr; comments } -> Format.printf "%a@." Flocaml.Printer.expr expr
| Error e -> Format.eprintf "%a@." Flocaml.Syntax_error.pp e
```

Besides the parser, the library has the following modules.

| Module | Purpose |
|---|---|
| `Ast` | The syntax tree |
| `Check` | Finds the errors that Nix reports after parsing, such as an attribute defined twice, a duplicate function argument or an unbound variable |
| `Printer` | Prints a tree as Nix source, with the parentheses it needs |
| `Token` | Splits the source into tokens that cover every byte, whitespace and comments included |
| `Ast_iterator`, `Ast_mapper` | Visit and rewrite trees, in the style of OCaml's compiler-libs |
| `Locate` | Finds the nodes at a point of the source |
| `Line_index` | Converts byte offsets to lines and columns in bytes, UTF-16 or code points, for editors |
| `Literal` | Computes the values of string literals and attribute names as Nix does |
| `Ast_printer` | Dumps a tree for debugging |

The `flocaml` command gives access to most of them.

```console
$ flocaml parse -e '{ a ? 1 }: a + 1'
(Lambda (Param_pattern (a (Int 1))) (Add (Var a) (Int 1)))
$ flocaml print -e '{a=1;}'
{ a = 1; }
$ flocaml tokens default.nix
$ flocaml check default.nix
```

Experimental syntax such as the pipe operators `|>` and `<|` is rejected unless enabled with `--feature pipe-operators`, or with `~features` in the API.

## Building

flocaml needs OCaml 4.14 or later and dune 3.0 or later.

With Nix, `nix build` builds the package and runs the tests, and `nix develop` gives a shell for working on it.

```sh
nix build
nix develop -c dune test
```

With opam, install the dependencies and build with dune.

```sh
opam install . --deps-only --with-test
dune build
```

## License

ISC
