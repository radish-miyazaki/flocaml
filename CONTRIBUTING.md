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

To see which parts of the code your tests reach, measure the coverage with [bisect_ppx](https://github.com/aantron/bisect_ppx), which the Nix shell provides, and open `_coverage/html/index.html`. CI does the same and sends the result to [Coveralls](https://coveralls.io/github/radish-miyazaki/nix-syntax).

```sh
rm -rf _coverage && mkdir -p _coverage/data
BISECT_FILE=$PWD/_coverage/data/bisect dune runtest --instrument-with bisect_ppx --build-dir "$PWD/_coverage/build" --cache=disabled
bisect-ppx-report html --coverage-path _coverage/data --source-path _coverage/build/default -o _coverage/html
```

## Style

Format the code with `dune fmt`, which uses the version of ocamlformat given in `.ocamlformat`.

Write comments in English. A comment explains why the code is as it is, or which behavior of Nix it follows, since the code itself shows what it does.

Document every value in a `.mli` file. `dune build @doc` fails on broken references.

Use only what the standard library of OCaml 4.14 provides.

## Changes

Add an entry to the `unreleased` section of `CHANGES.md` for any change that users can notice.

## Releasing

A release follows these steps, with `X.Y.Z` the new version.

1. Open a pull request that renames `## unreleased` in `CHANGES.md` to `## X.Y.Z (YYYY-MM-DD)` and sets `version` in `flake.nix` to `X.Y.Z`. Merge it with a merge commit once CI passes.

2. Tag the merge commit on `main` and push the tag.

   ```sh
   git switch main
   git pull
   git tag -a vX.Y.Z -m "nix-syntax X.Y.Z"
   git push origin vX.Y.Z
   ```

3. The tag starts the release workflow (`.github/workflows/release.yml`). It checks that `flake.nix` has the version of the tag and that `CHANGES.md` has a section for it, builds `nix-syntax-X.Y.Z.tbz` from the tag with `git archive`, and builds and tests the tarball as opam-repository would. It then creates the GitHub Release with the tarball and the section of `CHANGES.md` as notes. The summary of the run gives the `url` section for the opam file, with the sha256 and sha512 checksums.

4. In a fork of [ocaml/opam-repository](https://github.com/ocaml/opam-repository), add `packages/nix-syntax/nix-syntax.X.Y.Z/opam`. Its content is `nix-syntax.opam` of the tag without its first line, the comment that dune generated it, followed by the `url` section from the summary. `x-maintenance-intent` already comes from `nix-syntax.opam.template`. Check the file with `opam lint`.

5. Open the pull request with the title `[new release] nix-syntax (X.Y.Z)`. Its body gives the synopsis, the project page, and the changes of that version.

   ```markdown
   Parser for the Nix expression language

   - Project page: https://github.com/radish-miyazaki/nix-syntax

   ##### CHANGES:

   (the section of CHANGES.md for X.Y.Z)
   ```

   The pull request is left to a person, since the maintainers of opam-repository expect one behind it.
