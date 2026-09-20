{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    hjem = {
      url = "github:feel-co/hjem";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    with import ./lib { inherit (nixpkgs) lib; };
      mkFlake inputs {
        systems  = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
        hosts    = mapHosts   ./hosts;

        modules  = mapModules ./modules  id;
        profiles = mapModules ./profiles id;
        packages = mapModules ./packages id;
        overlays = mapModules ./overlays import;
      };
}
