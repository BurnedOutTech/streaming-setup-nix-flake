# 
#  TODO: For obs-websocket-monitor we need to open those ports  
# sudo iptables -I INPUT -p tcp --dport 4455 -j ACCEPT
# sudo iptables -I INPUT -p udp --dport 5353 -j ACCEPT
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
}
