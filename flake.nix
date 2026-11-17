{
  description = "va_args_iterators: C preprocessor __VA_ARGS__ counting and iteration macros";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        # mkShell (not mkShellNoCC): stdenv supplies the C/C++ compiler for the Catch tests.
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            cmake
            ruby # pp_iterators.rb header generator
          ];
        };
      });
}
