# Contributing to nix-syntax

Thank you for your interest in nix-syntax. Bug reports are the most useful contributions, especially expressions that nix-syntax reads differently from Nix.

For a change larger than a bug fix, please open an issue first to discuss it.

## Setting up

With Nix, `nix develop` gives a shell with OCaml, the dependencies, ocamlformat and ocaml-lsp.

```sh
nix develop
dune build
dune test
```

With opam, install the dependencies first.

```sh
opam install . --deps-only --with-test --with-doc
dune build
dune test
```

## Tests

The files `test/*.t` are [cram tests](https://dune.readthedocs.io/en/stable/tests.html#cram-tests) that run the `nix-syntax` command. When the output changes, review the difference that `dune test` shows and accept it with `dune promote`.

`test/unit` tests the parts of the library that the command does not reach.

`test/oracle` compares nix-syntax with `nix-instantiate --parse`. It needs Nix, so it is not part of `dune test`. Run it when you change the lexer, the parser or `Check`.

```sh
test/oracle/cases.sh
test/oracle/compare.sh /path/to/nixpkgs
```

`compare.sh` takes a while on all of nixpkgs. `JOBS` sets how many processes it runs at a time.

`test/roundtrip` checks on any set of files that printing a tree and reading the tokens lose nothing.

A weekly workflow runs the last two on the nixpkgs pinned in `flake.lock`.

## Style

Format the code with `dune fmt`, which uses the version of ocamlformat given in `.ocamlformat`.

Write comments in English. A comment explains why the code is as it is, or which behavior of Nix it follows, since the code itself shows what it does.

Document every value in a `.mli` file. `dune build @doc` fails on broken references.

Use only what the standard library of OCaml 4.14 provides.

## Changes

Add an entry to the `unreleased` section of `CHANGES.md` for any change that users can notice.
