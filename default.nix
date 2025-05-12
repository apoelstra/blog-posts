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
    # Use the Iris theme downloaded via fetchFromGitHub
    mkdir -p iris
    cp -r ${irisTheme}/* iris/
    chmod +w -R iris/
    find iris -type f -name '*.html' -exec sed -i 's/http:/https:/g' {} \;
    sed -i 's/height: 165px;//' iris/static/css/main.css

    # Generate the site with Pelican
    ${pkgs.python3Packages.pelican}/bin/pelican content -o $out -s pelicanconf.py

    # Copy the theme to the output directory
    mkdir -p $out/theme
    cp -r iris/* $out/theme/
  '';

  installPhase = ''
    # Nothing to do here as buildPhase writes directly to $out
    echo "Site generated in $out"
  '';

  # Disable phases that are not necessary
  dontFixup = true;
  dontPatchELF = true;

  # Allow substitution to speed up builds
  preferLocalBuild = false;
  allowSubstitutes = true;
}
