{
  description = "OBS + Reaper streaming setup using flake.parts";

  inputs = {
    #nixpkgs.url = "github:nixos/nixpkgs/146b74e1d3917da07c69c8a26cf8a4323b5bd900";
    nixpkgs.url = "github:nixos/nixpkgs/146b74e1d3917da07c69c8a26cf8a4323b5bd900";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
  };

  outputs = inputs@{ flake-parts, ... }:
      # https://flake.parts/module-arguments.html
      flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        # Optional: use external flake logic, e.g.
        # inputs.foo.flakeModules.default
        ./flake-modules/obs.nix
        ./flake-modules/reaper.nix
        ./flake-modules/devshells.nix
        ./flake-modules/reaper-drivenbymoss.nix
      ];
      flake = {
        # Put your original flake attributes here.
        # Defines outputs that don't depend on the system (like NixOS modules, overlays, or templates).
      };
      systems = [
        # systems for which you want to build the `perSystem` attributes
        "x86_64-linux"
        # ...
      ];
    };
}
