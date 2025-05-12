{ pkgs ? import <nixpkgs> {} }:

pkgs.stdenv.mkDerivation {
  name = "andrews-blog";
  src = ./.;

  buildInputs = with pkgs; [
    python3
    python3Packages.pelican
    python3Packages.markdown
    git
  ];

  buildPhase = ''
    # Créer un répertoire temporaire pour le thème
    mkdir -p iris
    
    # Cloner le thème Iris depuis GitHub
    ${pkgs.git}/bin/git clone https://github.com/slok/iris.git iris
    
    # Générer le site avec Pelican
    ${pkgs.python3Packages.pelican}/bin/pelican content -o $out -s pelicanconf.py
    
    # Copier le thème dans le répertoire de sortie
    mkdir -p $out/theme
    cp -r iris/* $out/theme/
  '';

  installPhase = ''
    # Rien à faire ici car buildPhase écrit directement dans $out
    echo "Site généré dans $out"
  '';

  # Désactiver certaines phases qui ne sont pas nécessaires
  dontFixup = true;
  dontPatchELF = true;
}
