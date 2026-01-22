# flake-modules/reaper.nix
{ inputs, ... }:
{
  perSystem = { pkgs, self', system, ... }: 
  let
    # Import nixpkgs with allowUnfree for Reaper
    unfree-pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in
  {
    packages = {
      reaper = pkgs.buildEnv {
        name = "reaper-suite";
        paths = [
          unfree-pkgs.reaper
          
          # VST bridges for Windows plugins
          pkgs.yabridge
          pkgs.yabridgectl
          pkgs.wineWowPackages.yabridge
          
          # Synths and instruments
          #pkgs.vital
          pkgs.surge-XT
          pkgs.geonkick
          pkgs.cardinal
          
          # Audio effects
          pkgs.calf
          pkgs.lsp-plugins
          pkgs.neural-amp-modeler-lv2
          
          # MIDI tools
          pkgs.qsynth
          pkgs.fluidsynth
          pkgs.soundfont-fluid
          
          # Utilities
          pkgs.audacity
        ];
      };
    };
  };
}
