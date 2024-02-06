{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nix-ocaml/nix-overlays";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.appendOverlays [
          (self: super: {
            ocamlPackages = super.ocaml-ng.ocamlPackages_5_1.overrideScope'
              (oself: osuper: {
                pg_query = osuper.pg_query.overrideAttrs (prev: {
                  propagatedBuildInputs = prev.propagatedBuildInputs
                    ++ [ osuper.cmdliner ];
                });
              });
          })
        ];

        pkgs' = pkgs.pkgsCross.musl64;

        combattant = pkgs'.ocamlPackages.buildDunePackage {
          pname = "combattant";
          version = "0.0.1";
          src = ./.;
          buildInputs = with pkgs'.ocamlPackages; [
            ppx_rapper
            ppx_rapper_eio
            yojson
            eio_main
            piaf
            routes
            caqti-driver-postgresql
            ppx_expect

            logs
          ];
        };

      in {
        devShells.default = pkgs'.mkShell rec {
          nativeBuildInputs = with pkgs'.ocamlPackages; [
            dune_3
            findlib
            ocaml
            ocaml-lsp
            ocamlformat
            pkgs.openjdk17
          ];

          buildInputs = combattant.buildInputs
            ++ (with pkgs'.ocamlPackages; [ utop ]);
        };

        packages.default = combattant;

        packages.docker = pkgs.dockerTools.buildImage {
          name = "ghcr.io/molvrr/combattant";
          tag = "latest";
          copyToRoot = pkgs.buildEnv {
            name = "image-root";
            paths = [ pkgs.bashInteractive pkgs.coreutils pkgs.curl combattant ];
            pathsToLink = [ "/bin" ];
          };
          config = { Cmd = [ "combattant" ]; };
        };

        formatter = pkgs.nixfmt;
      });
}
