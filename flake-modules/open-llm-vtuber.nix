# flake-modules/open-llm-vtuber.nix
#
# Packages the Open LLM VTuber server (https://github.com/Open-LLM-VTuber/Open-LLM-VTuber)
# using uv2nix (reads uv.lock directly — no manual dep declarations needed).
# Exposes a NixOS systemd service module.
#
# Exposes:
#   packages.open-llm-vtuber          — the server application
#   nixosModules.open-llm-vtuber      — systemd service module
#
# Usage in a NixOS host:
#   imports = [ inputs.streaming-setup.nixosModules.open-llm-vtuber ];
#   services.open-llm-vtuber = {
#     enable  = true;
#     package = inputs.streaming-setup.packages.x86_64-linux.open-llm-vtuber;
#   };
#
# Notes for upstreaming to nixpkgs:
#   - uv2nix is not yet an acceptable pattern in nixpkgs; a proper PR would
#     need to switch to buildPythonApplication with all deps declared explicitly.
#   - sherpa-onnx, cartesia, letta-client, and duckduckgo-mcp-server would each
#     need their own nixpkgs package derivation.
{ inputs, ... }:
{
  perSystem = { pkgs, lib, ... }:
    let
      python = pkgs.python311;

      # -----------------------------------------------------------------------
      # Upstream source (fixed-output — required for uv2nix workspace loading)
      # -----------------------------------------------------------------------
      src = pkgs.fetchFromGitHub {
        owner = "Open-LLM-VTuber";
        repo  = "Open-LLM-VTuber";
        rev   = "v1.2.1";
        hash  = "sha256-NUUu5aKhjrSpVZDG5kC44V4RRfR+VAyrq1zokFvy15w=";
      };

      # Pre-built frontend (separate git submodule in the upstream repo)
      frontend = pkgs.fetchFromGitHub {
        owner = "Open-LLM-VTuber";
        repo  = "Open-LLM-VTuber-Web";
        rev   = "ac7de8e880d803e4bda64aadda88208708d081ef";
        hash  = "sha256-Y8hMHrWV3dGVCvWvq/wadukRvMg+/xXkqlT2N6VQ5DM=";
      };

      # -----------------------------------------------------------------------
      # Python virtual environment via uv2nix
      #
      # uv2nix reads uv.lock from the workspace root (must be a fixed store
      # path so Nix can evaluate it at evaluation time).  All 310+ dependencies
      # are resolved from the lockfile — no manual declarations needed.
      # -----------------------------------------------------------------------
      workspace = inputs.uv2nix.lib.workspace.loadWorkspace {
        workspaceRoot = src;
      };

      # Prefer pre-built wheels; fall back to sdist when no wheel exists.
      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };

      # Overrides for wheels that bundle native .so files requiring extra libs,
      # and for sdists with missing build-system declarations.
      nativeOverlay = final: prev:
        # nvidia-*-cu12 wheels cross-reference each other's .so files.  They
        # will all be co-located in the same venv at runtime, so we skip strict
        # dependency resolution during the build phase.
        let
          nvidiaPackages = [
            "nvidia-cublas-cu12"      "nvidia-cuda-cupti-cu12"  "nvidia-cuda-nvrtc-cu12"
            "nvidia-cuda-runtime-cu12" "nvidia-cudnn-cu12"       "nvidia-cufft-cu12"
            "nvidia-cufile-cu12"      "nvidia-curand-cu12"      "nvidia-cusolver-cu12"
            "nvidia-cusparse-cu12"    "nvidia-cusparselt-cu12"  "nvidia-nccl-cu12"
            "nvidia-nvjitlink-cu12"   "nvidia-nvshmem-cu12"     "nvidia-nvtx-cu12"
          ];
          ignoreMissingDeps = name:
            if prev ? ${name}
            then { ${name} = prev.${name}.overrideAttrs (_: { autoPatchelfIgnoreMissingDeps = true; }); }
            else { };
        in
        lib.foldl' lib.mergeAttrs {} (map ignoreMissingDeps nvidiaPackages)
        // {
          # azure-cognitiveservices-speech bundles GStreamer + ALSA extensions.
          azure-cognitiveservices-speech = prev.azure-cognitiveservices-speech.overrideAttrs (old: {
            buildInputs = (old.buildInputs or []) ++ [
              pkgs.alsa-lib
              pkgs.gst_all_1.gstreamer
              pkgs.gst_all_1.gst-plugins-base
            ];
          });

          # torch bundles .so files that reference the co-installed nvidia-*-cu12 libs.
          torch = prev.torch.overrideAttrs (_: { autoPatchelfIgnoreMissingDeps = true; });

          # fastapi and fastapi-cli both install bin/fastapi — keep fastapi-cli's copy.
          fastapi = prev.fastapi.overrideAttrs (old: {
            postInstall = (old.postInstall or "") + ''
              rm -f "$out/bin/fastapi"
            '';
          });

          # langdetect and srt have no [build-system] table; need setuptools injected.
          langdetect = prev.langdetect.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.setuptools ];
          });
          srt = prev.srt.overrideAttrs (old: {
            nativeBuildInputs = (old.nativeBuildInputs or []) ++ [ final.setuptools ];
          });
        };

      pythonSet = (pkgs.callPackage inputs.pyproject-nix.build.packages {
        inherit python;
      }).overrideScope (
        lib.composeManyExtensions [
          inputs.pyproject-build-systems.overlays.default
          overlay
          nativeOverlay
        ]
      );

      # The virtual environment containing all runtime dependencies.
      # (The root workspace package is "virtual" — not installed — so we only
      # get its deps here; the source is added to sys.path via the wrapper.)
      venv = pythonSet.mkVirtualEnv "open-llm-vtuber-env" workspace.deps.default;

      # Package derivation extracted as a let-binding so devShells can reference it.
      pkg = pkgs.runCommand "open-llm-vtuber-1.2.1" {
        nativeBuildInputs = [ pkgs.python3 pkgs.makeWrapper ];
        meta = with pkgs.lib; {
          description = "Hands-free LLM voice chat with a Live2D VTuber avatar";
          longDescription = ''
            Open LLM VTuber lets you converse with any LLM backend using voice
            input, voice interruption, and a Live2D animated avatar.  The server
            exposes a WebSocket API and serves a web frontend on port 12393.
          '';
          homepage    = "https://github.com/Open-LLM-VTuber/Open-LLM-VTuber";
          license     = licenses.mit;
          maintainers = [ ];
          platforms   = [ "x86_64-linux" ];
          mainProgram = "open-llm-vtuber";
        };
      } ''
        shareDir="$out/share/open-llm-vtuber"
        mkdir -p "$out/bin" "$shareDir"

        # ---- Python source (run_server.py imports from src/ and upgrade_codes/) ----
        # When Python executes run_server.py as a script, it adds $shareDir to
        # sys.path.  src/ and upgrade_codes/ sit inside $shareDir, so all
        # "from src.open_llm_vtuber.*" and "from upgrade_codes.*" imports resolve.
        cp -r ${src}/src           "$shareDir/"
        cp -r ${src}/upgrade_codes "$shareDir/"

        # ---- Patch and install the entry script ----
        cp ${src}/run_server.py "$shareDir/"
        chmod u+w "$shareDir/run_server.py"

        # Use setdefault so the systemd service (or user env) overrides HF_HOME
        sed -i \
          's|os\.environ\["HF_HOME"\] = str(Path(__file__)\.parent / "models")|os.environ.setdefault("HF_HOME", str(Path.cwd() / "models"))|' \
          "$shareDir/run_server.py"
        sed -i \
          's|os\.environ\["MODELSCOPE_CACHE"\] = str(Path(__file__)\.parent / "models")|os.environ.setdefault("MODELSCOPE_CACHE", str(Path.cwd() / "models"))|' \
          "$shareDir/run_server.py"

        # Hardcode version (pyproject.toml is not present in the state dir at runtime)
        python3 - <<PYEOF
        import re, pathlib
        p = pathlib.Path("$shareDir/run_server.py")
        t = p.read_text()
        t = re.sub(
            r'def get_version\(\) -> str:\n    with open\("pyproject\.toml", "rb"\) as f:.*?return pyproject\["project"\]\["version"\]',
            'def get_version() -> str:\n    return "1.2.1"',
            t, flags=re.DOTALL,
        )
        p.write_text(t)
        PYEOF

        # Frontend is provided by the Nix package (not a git submodule)
        sed -i 's/check_frontend_submodule(lang)/pass  # frontend provided by Nix/' \
          "$shareDir/run_server.py"

        # ---- Static assets ----
        cp -r ${frontend}             "$shareDir/frontend"
        cp -r ${src}/live2d-models    "$shareDir/live2d-models"
        cp -r ${src}/backgrounds      "$shareDir/backgrounds"
        cp -r ${src}/avatars          "$shareDir/avatars"
        cp -r ${src}/web_tool         "$shareDir/web_tool"
        cp -r ${src}/characters       "$shareDir/characters"
        cp -r ${src}/prompts          "$shareDir/prompts"
        cp    ${src}/model_dict.json  "$shareDir/model_dict.json"
        cp    ${src}/mcp_servers.json "$shareDir/mcp_servers.json"
        cp    ${src}/config_templates/conf.default.yaml "$shareDir/conf.default.yaml"

        # ---- Wrapper ----
        # Runs the venv's Python with run_server.py as a script.
        # Python adds $shareDir to sys.path automatically (script directory rule),
        # making "from src.open_llm_vtuber.*" and "from upgrade_codes.*" work.
        makeWrapper ${venv}/bin/python "$out/bin/open-llm-vtuber" \
          --add-flags "$shareDir/run_server.py"
      '';

    in
    {
      packages.open-llm-vtuber = pkg;

      # -----------------------------------------------------------------------
      # Dev shell — run the server directly from source for testing
      #
      # Usage:
      #   nix develop .#open-llm-vtuber
      #   cp conf.yaml.example conf.yaml   # or edit as needed
      #   open-llm-vtuber                  # starts on http://localhost:12393
      # -----------------------------------------------------------------------
      devShells.open-llm-vtuber = pkgs.mkShell {
        name = "open-llm-vtuber-dev";
        packages = [
          pkg                               # puts open-llm-vtuber on PATH
          venv                              # direct python access for dev
          pkgs.ffmpeg                       # pydub runtime dep
          pkgs.uv                           # for updating deps from source
        ];
        shellHook = ''
          echo "🎭 Open LLM VTuber dev shell"
          echo ""
          echo "  open-llm-vtuber is on PATH. To start:"
          echo "    mkdir -p /tmp/olv-test && cd /tmp/olv-test"
          echo "    cp \$(open-llm-vtuber --print-share-dir 2>/dev/null || echo /dev/null)/conf.default.yaml conf.yaml 2>/dev/null || true"
          echo "    # edit conf.yaml: change asr_model to groq_whisper_asr to skip 1 GB download"
          echo "    open-llm-vtuber"
          echo ""
          echo "  Then open http://localhost:12393 in a browser."
        '';
      };
    };

  # ---------------------------------------------------------------------------
  # NixOS service module
  # ---------------------------------------------------------------------------
  flake.nixosModules.open-llm-vtuber = { config, lib, pkgs, ... }:
    with lib;
    let
      cfg      = config.services.open-llm-vtuber;
      shareDir = "${cfg.package}/share/open-llm-vtuber";

      # Read-only asset directories that are symlinked into the state dir.
      readOnlyDirs = [
        "frontend" "live2d-models" "backgrounds"
        "avatars" "web_tool" "characters" "prompts"
      ];
    in
    {
      options.services.open-llm-vtuber = {
        enable = mkEnableOption "Open LLM VTuber server";

        package = mkOption {
          type        = types.package;
          description = ''
            The open-llm-vtuber package to use.  Obtain it from the
            streaming-setup flake:

              package = inputs.streaming-setup.packages.x86_64-linux.open-llm-vtuber;
          '';
        };

        host = mkOption {
          type        = types.str;
          default     = "127.0.0.1";
          description = "Host address the HTTP/WebSocket server listens on.";
        };

        port = mkOption {
          type        = types.port;
          default     = 12393;
          description = "TCP port the HTTP/WebSocket server listens on.";
        };

        dataDir = mkOption {
          type        = types.path;
          default     = "/var/lib/open-llm-vtuber";
          description = ''
            Directory for mutable state: conf.yaml, model cache, logs, and
            uploaded avatars.  Read-only assets (frontend, live2d-models,
            backgrounds, etc.) are symlinked in from the Nix store on first
            start and updated automatically when the package changes.
          '';
        };

        user = mkOption {
          type        = types.str;
          default     = "open-llm-vtuber";
          description = "System user the service runs as.";
        };

        group = mkOption {
          type        = types.str;
          default     = "open-llm-vtuber";
          description = "System group the service runs as.";
        };

        openFirewall = mkOption {
          type        = types.bool;
          default     = false;
          description = "Open {option}`services.open-llm-vtuber.port` in the firewall.";
        };

        extraEnvironment = mkOption {
          type        = types.attrsOf types.str;
          default     = { };
          example     = literalExpression ''{ OLLAMA_HOST = "http://127.0.0.1:11434"; }'';
          description = "Extra environment variables passed to the server process.";
        };
      };

      config = mkIf cfg.enable {
        users.users.${cfg.user} = {
          isSystemUser = true;
          group        = cfg.group;
          home         = cfg.dataDir;
          description  = "Open LLM VTuber daemon user";
        };

        users.groups.${cfg.group} = { };

        networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

        systemd.services.open-llm-vtuber = {
          description = "Open LLM VTuber server";
          wantedBy    = [ "multi-user.target" ];
          after       = [ "network.target" ];

          # Seed the state directory and maintain store-path symlinks.
          preStart = ''
            # Writable subdirectories
            mkdir -p "${cfg.dataDir}"/{models,cache,logs}

            # Seed conf.yaml from package default on first run
            if [ ! -f "${cfg.dataDir}/conf.yaml" ]; then
              install -m 644 \
                "${shareDir}/conf.default.yaml" \
                "${cfg.dataDir}/conf.yaml"
            fi

            # Seed model_dict.json (users may customise this file)
            if [ ! -f "${cfg.dataDir}/model_dict.json" ]; then
              install -m 644 \
                "${shareDir}/model_dict.json" \
                "${cfg.dataDir}/model_dict.json"
            fi

            # Seed mcp_servers.json (users may customise MCP server list)
            if [ ! -f "${cfg.dataDir}/mcp_servers.json" ]; then
              install -m 644 \
                "${shareDir}/mcp_servers.json" \
                "${cfg.dataDir}/mcp_servers.json"
            fi

            # Symlink read-only assets; replace dangling symlinks after upgrades.
            ${concatMapStrings (dir: ''
              if [ -L "${cfg.dataDir}/${dir}" ] && [ ! -e "${cfg.dataDir}/${dir}" ]; then
                rm "${cfg.dataDir}/${dir}"
              fi
              if [ ! -e "${cfg.dataDir}/${dir}" ]; then
                ln -s "${shareDir}/${dir}" "${cfg.dataDir}/${dir}"
              fi
            '') readOnlyDirs}
          '';

          serviceConfig = {
            User              = cfg.user;
            Group             = cfg.group;
            WorkingDirectory  = cfg.dataDir;
            StateDirectory    = "open-llm-vtuber";
            StateDirectoryMode = "0750";

            ExecStart = "${cfg.package}/bin/open-llm-vtuber";

            Environment = mapAttrsToList (k: v: "${k}=${v}") ({
              HF_HOME          = "${cfg.dataDir}/models";
              MODELSCOPE_CACHE = "${cfg.dataDir}/models";
            } // cfg.extraEnvironment);

            Restart    = "on-failure";
            RestartSec = "5s";

            # Basic hardening
            PrivateTmp        = true;
            NoNewPrivileges   = true;
            ProtectSystem     = "strict";
            ReadWritePaths    = [ cfg.dataDir ];
          };
        };
      };
    };
}
