default: format check

pull:
  git pull

update:
  npins update

format:
  shopt -s globstar && nix fmt *.nix **/*.nix

check:
  nix-build -A checks.x86_64-linux
