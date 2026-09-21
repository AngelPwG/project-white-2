{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  packages = with pkgs; [
    odin
    pkg-config
  ];

  buildInputs = with pkgs; [
    alsa-lib
    libGL
    libx11
    libxcursor
    libxi
    libxinerama
    libxrandr
    raylib
  ];

  shellHook = ''
    echo "WHITEOUT development shell"
    echo "Odin: $(odin version)"
    echo "Run the game with: odin run ."
  '';
}
