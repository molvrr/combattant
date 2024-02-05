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
                  propagatedBuildInputs = prev.propagatedBuildInputs ++ [ osuper.cmdliner ];
                });
              });
          })
        ];

        pkgs' = pkgs.pkgsCross.musl64;

        rinhadebackend = pkgs'.ocamlPackages.buildDunePackage {
          pname = "rinhadebackend";
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
          ];

          buildInputs = rinhadebackend.buildInputs
            ++ (with pkgs'.ocamlPackages; [ utop ]);
        };

        packages.default = rinhadebackend;

        packages.docker = pkgs'.dockerTools.buildImage {
          name = "ghcr.io/molvrr/rinhadebackend";
          tag = "latest";
          copyToRoot = pkgs'.buildEnv {
            name = "image-root";
            paths = [ pkgs'.bashInteractive pkgs'.coreutils pkgs'.curl rinhadebackend ];
            pathsToLink = [ "/bin" ];
          };
          config = { Cmd = [ "rinhadebackend" ]; };
        };

        formatter = pkgs.nixfmt;
      });
}
