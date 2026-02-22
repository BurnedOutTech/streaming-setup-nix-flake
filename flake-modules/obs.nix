{ ... }:
{
  perSystem = { pkgs, self', ... }: 
    let
      obsPlugins = with pkgs.obs-studio-plugins; [
          wlrobs                      # Wayland screen capture
          obs-pipewire-audio-capture  # Audio from PipeWire
          # obs-backgroundremoval       # ML background removal
          obs-source-switcher         # Scene automation

          input-overlay
          obs-advanced-masks
          #obs-vertical-canvas
          obs-gstreamer                                                                     
          obs-vnc
          obs-vkcapture
          droidcam-obs
          obs-source-record
          advanced-scene-switcher    
          obs-text-pthread
      ];

      obsDependencies = with pkgs; [
        android-tools
        usbmuxd 
      ];

      obsPackages = [
        obsPlugins
        obsDependencies
      ];
      
      # Create a wrapOBS function with CUDA obs-studio
      wrapOBSWithCuda = pkgs.wrapOBS.override {
        obs-studio = pkgs.obs-studio.override { cudaSupport = true; };
      };
    in
    {
      packages = {
        obs = pkgs.wrapOBS {
          plugins = obsPackages;
        };

        obs-cuda = wrapOBSWithCuda {
          plugins = obsPackages;
        };
      };
    };

  # Firewall rules for obs-websocket-monitor
  flake.nixosModules.obs = { ... }: {
    config = {
      networking.firewall.allowedTCPPorts = [ 4455 ];
      networking.firewall.allowedUDPPorts = [ 5353 ];
    };
  };
}
