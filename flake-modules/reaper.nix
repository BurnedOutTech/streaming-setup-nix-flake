# flake-modules/reaper.nix
{ inputs, ... }:
{
  perSystem = { pkgs, self', system, ... }: {
    packages = {
      reaper = 
        let
          # Import nixpkgs with allowUnfree for just this package
          unfree-pkgs = import inputs.nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        unfree-pkgs.reaper;

      audio-tools = pkgs.buildEnv {
        name = "audio-tools";
        paths = [
          pkgs.jack2
          pkgs.pipewire
          pkgs.pavucontrol
          pkgs.qpwgraph
          pkgs.alsa-utils
        ];
      };

      # yabridge-tools = pkgs.buildEnv {
      #   name = "yabridge-tools";
      #   paths = [
      #     pkgs.yabridge
      #     pkgs.wineWowPackages.yabridge
      #   ];
      # };
    };
  };
}
