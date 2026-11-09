{
  description = "Parser for the Nix expression language";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        default = pkgs.ocamlPackages.buildDunePackage {
          pname = "flocaml";
          version = "0.1.0";
          src = ./.;
          nativeBuildInputs = [ pkgs.ocamlPackages.menhir ];
          buildInputs = with pkgs.ocamlPackages; [
            menhirLib
            sedlex
            cmdliner
          ];
          doCheck = true;
          nativeCheckInputs = [
            pkgs.ocamlformat_0_29_0
            pkgs.ocamlPackages.odoc
          ];
          checkPhase = ''
            runHook preCheck
            dune build --root . --profile release @fmt @doc -j $NIX_BUILD_CORES
            dune test --root . --profile release -j $NIX_BUILD_CORES
            runHook postCheck
          '';
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          inputsFrom = [ self.packages.${pkgs.stdenv.hostPlatform.system}.default ];
          packages = [
            pkgs.ocamlPackages.ocaml-lsp
            pkgs.ocamlPackages.utop
            # Keep in sync with the version in .ocamlformat.
            pkgs.ocamlformat_0_29_0
          ];
        };
      });
    };
}
