{ pkgs ? import <nixpkgs> {} }:

let
  irisTheme = pkgs.fetchFromGitHub {
    owner = "slok";
    repo = "iris";
    rev = "34f8c50b92f62e31a5443c43cad422bdea4046e6"; # Dernière révision du dépôt
    sha256 = "sha256-h+uCYX69q+aidSQJi8hw9/+ESVtgBoRb1+PU6yCYECQ=";
  };
in

pkgs.stdenv.mkDerivation {
  name = "andrews-blog";
  src = ./.;

  buildInputs = with pkgs; [
    python3
    python3Packages.pelican
    python3Packages.markdown
  ];

  buildPhase = ''
    # Utiliser le thème Iris téléchargé via fetchFromGitHub
    mkdir -p iris
    cp -r ${irisTheme}/* iris/
    
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
  
  # Permettre la substitution pour accélérer les builds
  preferLocalBuild = false;
  allowSubstitutes = true;
}
