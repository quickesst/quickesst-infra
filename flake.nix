{
  description = "Quickesst Infra";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
		pkgs = import nixpkgs {
		  inherit system;
		  config.allowUnfree = true;
		};
  in {
   devShells.${system}.default = pkgs.mkShell {
      packages = [ pkgs.k3d pkgs.kubectl pkgs.kubernetes-helm pkgs.git pkgs.terraform pkgs.docker pkgs.go-task pkgs.pre-commit pkgs.gitleaks ];
      shellHook = ''
        if [ -d .git ]; then
          pre-commit install --install-hooks --hook-type pre-commit --hook-type commit-msg > /dev/null
        fi
        if ! k3d cluster list | grep -q quickesst; then
          echo "Création du cluster k3d..."
          k3d cluster create quickesst
        else
          echo "Cluster k3d déjà taskprésent."
          k3d cluster start quickesst 2>/dev/null || true
        fi
      '';
    };
  };
}