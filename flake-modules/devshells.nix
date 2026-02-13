{
  # PerSystem Key Arguments
  # pkgs: nixpkgs for current system
  # system: "x86_64-linux", etc.
  # self': your flake outputs (system pre-selected)
  # inputs': input flakes (system pre-selected)
  # config: merged configuration from all modules (read-only)
  # lib: nixpkgs library utilities
  perSystem = { pkgs, self', ... }: {
    devShells = {
      default = pkgs.mkShell {
        name = "streaming-env";
        buildInputs = [
          self'.packages.obs-cuda
          self'.packages.reaper
          pkgs.ffmpeg
          pkgs.sox
        ];

        shellHook = ''
          echo "🎬 Streaming environment ready"
          echo "Run: obs &"
          echo "Run: reaper &"
        '';
      };

      obs-only = pkgs.mkShell {
        buildInputs = [ self'.packages.obs-streaming pkgs.ffmpeg ];
      };

      reaper-only = pkgs.mkShell {
        buildInputs = [ self'.packages.reaper self'.packages.audio-tools ];
      };
    };
  };
}

