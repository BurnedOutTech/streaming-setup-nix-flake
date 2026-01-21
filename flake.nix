{
  description = "OBS + Reaper streaming setup using flake.parts";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs = inputs@{ flake-parts, ... }:
    let
      # Define the list of modules once to avoid duplication
      modules = [
        ./flake-modules/obs.nix
        ./flake-modules/reaper.nix
        ./flake-modules/devshells.nix
        ./flake-modules/reaper-drivenbymoss.nix
      ];
    in
      # https://flake.parts/module-arguments.html
      flake-parts.lib.mkFlake { inherit inputs; } {
      imports = modules;
      flake = {
        # Expose flake modules to be used by other flakes
        flakeModules = {
          obs = ./flake-modules/obs.nix;
          reaper = ./flake-modules/reaper.nix;
          reaper-drivenbymoss = ./flake-modules/reaper-drivenbymoss.nix;
          devshells = ./flake-modules/devshells.nix;
          default = {
            imports = modules;
          };
        };
      };
      systems = [
        # systems for which you want to build the `perSystem` attributes
        "x86_64-linux"
      ];
    };
}
