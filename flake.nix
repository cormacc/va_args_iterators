{
  description = "va_args_iterators: C preprocessor __VA_ARGS__ counting and iteration macros";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        # Only clang and clang++: the full clang wrapper also provides cc and c++, which would
        # replace GCC's on PATH.
        clangOnly = pkgs.runCommand "clang-only" { } ''
          mkdir -p $out/bin
          ln -s ${pkgs.clang}/bin/clang ${pkgs.clang}/bin/clang++ $out/bin/
        '';
      in {
        # mkShell (not mkShellNoCC): stdenv supplies GCC, the default compiler (CC=gcc, CXX=g++).
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            cmake
            ruby # pp_iterators.rb header generator
            clangOnly # second compiler, for the clang CMake presets
          ];
        };
      });
}
