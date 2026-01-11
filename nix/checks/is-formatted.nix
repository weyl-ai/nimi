{
  nimi-fmt,
  stdenvNoCC,
  git,
}:
stdenvNoCC.mkDerivation {
  name = "nimi-fmt-check";
  src = ../..;

  nativeBuildInputs = [
    nimi-fmt
    git
  ];

  dontBuild = true;
  installPhase = "touch $out";

  doCheck = true;
  checkPhase = ''
    git init --quiet
    git add .

    treefmt --no-cache

    if ! git diff --exit-code; then
      echo "-------------------------------"
      echo "Aborting due to above changes ^"
      echo ""
      echo "Formatting check failed - try 'nix fmt'"
      exit 1
    fi
  '';
}
