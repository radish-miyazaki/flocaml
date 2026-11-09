# Contributing to flocaml

Thank you for your interest in flocaml. Bug reports, especially expressions
that flocaml reads differently from Nix, are the most useful contributions.

For a change larger than a bug fix, please open an issue first to discuss it.

## Setting up

With Nix, `nix develop` gives a shell with OCaml, the dependencies, ocamlformat
and ocaml-lsp:

```sh
nix develop
dune build
dune test
```

With opam:

```sh
opam install . --deps-only --with-test --with-doc
dune build
dune test
```

## Tests

- `test/*.t` are [cram tests](https://dune.readthedocs.io/en/stable/tests.html#cram-tests)
  that run the `flocaml` command. After a change in the output, review it with
  `dune test` and accept it with `dune promote`.
- `test/unit` tests the parts of the library that the command does not reach.
- `test/oracle` compares flocaml with `nix-instantiate --parse`. It needs Nix,
  so it is not part of `dune test`. Run it when changing the lexer, the parser
  or `Check`:

  ```sh
  test/oracle/cases.sh
  test/oracle/compare.sh /path/to/nixpkgs
  ```

  `compare.sh` takes a while on all of nixpkgs; `JOBS` sets how many processes
  it runs at a time.
- `test/roundtrip` checks that printing a tree and reading the tokens lose
  nothing, on any set of files.

A weekly workflow runs the last two on the nixpkgs pinned in `flake.lock`.

## Style

- Format the code with `dune fmt`. The version of ocamlformat is the one in
  `.ocamlformat`.
- Write comments in English. A comment explains why the code is as it is, or
  which behavior of Nix it follows; the code itself shows what it does.
- Document every value of a `.mli` file. `dune build @doc` fails on broken
  references.
- Keep to the standard library of OCaml 4.14.

## Changes

Add an entry to the `unreleased` section of `CHANGES.md` for any change that
users can notice.
