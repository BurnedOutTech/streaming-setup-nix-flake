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
          echo "Run: test-all  # run all checks"
        '';

        packages = [
          (pkgs.writeShellScriptBin "test-all" ''
            set -e
            echo "Running flake checks..."
            nix flake check --print-build-logs "$@"
            echo ""
            echo "=== Logs ==="
            nix eval --json '.#checks.x86_64-linux' --apply builtins.attrNames \
              | ${pkgs.jq}/bin/jq -r '.[]' \
              | while read -r name; do
                  echo ""
                  echo "--- $name ---"
                  nix path-info --derivation ".#checks.x86_64-linux.$name" 2>/dev/null \
                    | xargs nix log 2>/dev/null || echo "(no log)"
                done
          '')
        ];
      };

      obs-only = pkgs.mkShell {
        buildInputs = [ self'.packages.obs pkgs.ffmpeg ];
      };

      reaper-only = pkgs.mkShell {
        buildInputs = [ self'.packages.reaper ];
      };
    };
  };
}

