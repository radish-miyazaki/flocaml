(lang dune 3.23)

(using menhir 3.0)

(name flocaml)

(generate_opam_files true)

(source
 (github radish-miyazaki/flocaml))

(license ISC)

(authors "Yoshiki Hidaka")

(maintainers "Yoshiki Hidaka")

(package
 (name flocaml)
 (synopsis "Parser for the Nix expression language")
 (description
  "flocaml parses Nix expressions into a syntax tree that keeps the source locations of every node and the comments, so tools can inspect and rewrite Nix files without losing their layout.")
 (tags
  (nix parser))
 (depends
  (ocaml
   (>= 5.1))
  (menhir
   (and
    :build
    (>= 20230608)))
  (menhirLib
   (>= 20230608))
  (sedlex
   (>= 3.2))
  (cmdliner
   (>= 1.3))))
