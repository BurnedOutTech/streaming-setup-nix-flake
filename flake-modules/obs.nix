# flake-modules/obs.nix
{ ... }:
{
  perSystem = { pkgs, self', ... }: 
    let
      obsPlugins = with pkgs.obs-studio-plugins; [
          wlrobs                      # Wayland screen capture
          obs-pipewire-audio-capture  # Audio from PipeWire
          # obs-backgroundremoval       # ML background removal
          obs-source-switcher         # Scene automation

          # validate ones below
          input-overlay
          obs-advanced-masks
          #obs-vertical-canvas
          obs-gstreamer                                                                     
          obs-vkcapture
          droidcam-obs
          obs-source-record
          advanced-scene-switcher    # Temporarily disabled - build issue with CUDA toolkit
          obs-text-pthread
      ];
      
      # Create a wrapOBS function with CUDA obs-studio
      wrapOBSWithCuda = pkgs.wrapOBS.override {
        obs-studio = pkgs.obs-studio.override { cudaSupport = true; };
      };
    in
    {
      packages = {
        obs-streaming = pkgs.wrapOBS {
          plugins = obsPlugins;
        };

        obs-streaming-cuda = wrapOBSWithCuda {
          plugins = obsPlugins;
        };

        obs = self'.packages.obs-streaming;
        obs-cuda = self'.packages.obs-streaming-cuda;
      };
    };
}
