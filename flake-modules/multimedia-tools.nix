{ ... }:
{
  perSystem = { pkgs, ... }: {
    packages.multimedia-tools = pkgs.symlinkJoin {
      name = "multimedia-tools";
      paths = with pkgs; [
        # Image tools
        metadata-cleaner          # View and strip file metadata (uses mat2)
        font-manager              # GTK font manager
        eyedropper                # Color picker
        upscaler                  # Image upscaling
        curtail                   # Image compression
        inkscape                  # Vector graphics editor

        # Audio tools
        easyeffects               # Audio effects for PipeWire
        helvum                    # PipeWire patchbay
        carla                     # Audio plugin host
        raysession
        zrythm                    # Digital audio workstation
        kmidimon                  # MIDI monitor (Drumstick)

        # Video tools
        handbrake                 # Video transcoder / DVD ripper
        kdePackages.kdenlive      # Non-linear video editor
        vlc                       # Media player
        peek                      # Animated GIF/screen recorder
      ];
    };
  };
}
