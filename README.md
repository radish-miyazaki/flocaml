# flocaml

A parser for the [Nix](https://nixos.org) expression language, written in OCaml.

The name comes from *flocon*, French for snowflake, and Caml.

flocaml reads Nix expressions into a syntax tree that follows the concrete
syntax: nothing is desugared, parentheses are kept, and every node carries its
source location. Comments are collected alongside the tree. This makes it
suitable for tools that inspect or rewrite Nix files.

## Status

Early development. The parser reads every `.nix` file in nixpkgs, but the API
is not stable yet.

## Usage

```ocaml
match Flocaml.parse_string ~filename:"default.nix" source with
| Ok { expr; comments } -> Format.printf "%a@." Flocaml.Ast_printer.expr expr
| Error e -> Format.eprintf "%a@." Flocaml.Syntax_error.pp e
```

The `flocaml` command prints the syntax tree of a file, or checks files for
syntax errors:

```console
$ flocaml parse -e '{ a ? 1 }: a + 1'
(Lambda (Param_pattern (a (Int 1))) (Add (Var a) (Int 1)))
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
`dune build`.

## License

ISC
