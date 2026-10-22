{
  description = "Update your cabal.project's source-repository-packages";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";
  };

  outputs = inputs: {
    packages = builtins.mapAttrs (system: pkgs: {
      cabal-source-repo-update = pkgs.haskellPackages.callCabal2nix "cabal-source-repo-update" ./. {};
      static = pkgs.pkgsStatic.haskellPackages.callCabal2nix "cabal-source-repo-update" ./. {};

      default = inputs.self.packages.${system}.cabal-source-repo-update;
    }) inputs.nixpkgs.legacyPackages;
  };
}
