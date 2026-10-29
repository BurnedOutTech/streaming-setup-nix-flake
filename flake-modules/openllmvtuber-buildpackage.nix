# flake-modules/open-llm-vtuber.nix
#
# Packages the Open LLM VTuber server (https://github.com/Open-LLM-VTuber/Open-LLM-VTuber)
# and exposes a NixOS systemd service module.
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
#   - sherpa-onnx ships pre-built wheels; a proper nixpkgs PR would need a
#     source build (cmake + C++ extensions).  The wheel approach used here is
#     only viable for x86_64-linux.
#   - cartesia, letta-client, and duckduckgo-mcp-server should each get their
#     own nixpkgs package derivation before the main package is submitted.
{ inputs, ... }:
{
  perSystem = { pkgs, system, lib, ... }:
    let
      python = pkgs.python311;

      # -----------------------------------------------------------------------
      # Python packages not yet in nixpkgs
      # -----------------------------------------------------------------------

      # sherpa-onnx distributes pre-built wheels that bundle the C++ runtime.
      # autoPatchelfHook rewrites the rpath so the bundled .so files are found
      # on NixOS.  Only x86_64-linux cp311 wheel is provided here; add more
      # fetchurl stanzas + system guards when upstreaming to nixpkgs.
      sherpa-onnx = python.pkgs.buildPythonPackage {
        pname = "sherpa-onnx";
        version = "1.12.27";
        format = "wheel";

        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/5f/0d/86b3f06542ffbd6f4c96bab56a1628fdbbadfc8a94bbb44159157514d690/sherpa_onnx-1.12.27-cp311-cp311-manylinux2014_x86_64.manylinux_2_17_x86_64.whl";
          hash = "sha256-1rUxDGkWwDyZsUo2CgHP6A3bbeHm+LJxVGJ+8YDfgjs=";
        };

        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = [ pkgs.stdenv.cc.cc.lib pkgs.onnxruntime ];
        propagatedBuildInputs = with python.pkgs; [ numpy ];

        pythonImportsCheck = [ "sherpa_onnx" ];

        meta = {
          description = "Speech recognition / TTS toolkit with ONNX Runtime";
          homepage = "https://github.com/k2-fsa/sherpa-onnx";
          license = pkgs.lib.licenses.asl20;
          platforms = [ "x86_64-linux" ];
        };
      };

      cartesia = python.pkgs.buildPythonPackage {
        pname = "cartesia";
        version = "3.0.2";
        pyproject = true;

        src = pkgs.fetchPypi {
          pname = "cartesia";
          version = "3.0.2";
          hash = "sha256-vu/xbNWjbTDZCJhOhFkebnwgQp5UxYIvylwWvybdgFo=";
        };

        postPatch = ''
          # Remove exact version pin on hatchling so nixpkgs' version is accepted
          substituteInPlace pyproject.toml \
            --replace-fail 'hatchling==1.26.3' 'hatchling'
        '';

        build-system = with python.pkgs; [ hatchling hatch-fancy-pypi-readme ];

        propagatedBuildInputs = with python.pkgs; [
          anyio
          distro
          httpx
          pydantic
          sniffio
          typing-extensions
        ];

        doCheck = false;
        pythonImportsCheck = [ "cartesia" ];

        meta = {
          description = "Cartesia TTS Python client";
          homepage = "https://cartesia.ai";
          license = pkgs.lib.licenses.asl20;
        };
      };

      letta-client = python.pkgs.buildPythonPackage {
        pname = "letta-client";
        version = "1.7.9";
        pyproject = true;

        src = pkgs.fetchPypi {
          pname = "letta_client";
          version = "1.7.9";
          hash = "sha256-1vvJ/BbCVN87IWIACedD1FtU9I/QVMcHktPI1tbgvVk=";
        };

        postPatch = ''
          substituteInPlace pyproject.toml \
            --replace-fail 'hatchling==1.26.3' 'hatchling'
        '';

        build-system = with python.pkgs; [ hatchling hatch-fancy-pypi-readme ];

        propagatedBuildInputs = with python.pkgs; [
          anyio
          distro
          httpx
          pydantic
          sniffio
        ];

        doCheck = false;

        meta = {
          description = "Python client for the Letta agent framework";
          homepage = "https://github.com/letta-ai/letta";
          license = pkgs.lib.licenses.asl20;
        };
      };

      duckduckgo-mcp-server = python.pkgs.buildPythonPackage {
        pname = "duckduckgo-mcp-server";
        version = "0.1.1";
        pyproject = true;

        src = pkgs.fetchPypi {
          pname = "duckduckgo_mcp_server";
          version = "0.1.1";
          hash = "sha256-1vSPTLQjTennFuh/fUmqVGN+vEo3AOz9BfJgaWRjwOw=";
        };

        build-system = with python.pkgs; [ hatchling ];

        propagatedBuildInputs = with python.pkgs; [
          beautifulsoup4
          httpx
          mcp
        ];

        doCheck = false;

        meta = {
          description = "DuckDuckGo search MCP server";
          homepage = "https://github.com/nickclyde/duckduckgo-mcp-server";
          license = pkgs.lib.licenses.mit;
        };
      };

      # edge-tts is a pure-Python wheel — no native deps needed.
      edge-tts = python.pkgs.buildPythonPackage {
        pname = "edge-tts";
        version = "7.2.7";
        format = "wheel";

        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/bf/89/92ac6b154ab87d236c15e5e0c73cb99be58efb1ea3eb9318c266bf9a36bf/edge_tts-7.2.7-py3-none-any.whl";
          hash = "sha256-rBHZ6DQ0fl7mLL5y6KVv/WXTxOeVvhSx5ZO3LPZIDdk=";
        };

        propagatedBuildInputs = with python.pkgs; [
          aiohttp
          certifi
          tabulate
          typing-extensions
        ];

        doCheck = false;
        pythonImportsCheck = [ "edge_tts" ];

        meta = {
          description = "Unofficial Microsoft Edge TTS for Python";
          homepage = "https://github.com/rany2/edge-tts";
          license = pkgs.lib.licenses.gpl3Only;
        };
      };

      # azure-cognitiveservices-speech ships a manylinux wheel bundling native
      # libs.  autoPatchelfHook + the three native packages below satisfy all
      # RPATH requirements (GStreamer codec/audio + ALSA).
      azure-cognitiveservices-speech = python.pkgs.buildPythonPackage {
        pname = "azure-cognitiveservices-speech";
        version = "1.47.0";
        format = "wheel";

        src = pkgs.fetchurl {
          url = "https://files.pythonhosted.org/packages/6b/d6/b8f55421b8cb40b478f4fb793c52b1bb0ed794263a5475ae2a6490a4cd53/azure_cognitiveservices_speech-1.47.0-py3-none-manylinux1_x86_64.whl";
          hash = "sha256-V3twLuMNNezFgefirCP0OHeC+TwkHX+PPIb3K7iD0C0=";
        };

        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        buildInputs = with pkgs; [
          stdenv.cc.cc.lib
          alsa-lib
          gst_all_1.gstreamer
          gst_all_1.gst-plugins-base
        ];

        propagatedBuildInputs = with python.pkgs; [ azure-core ];

        doCheck = false;
        pythonImportsCheck = [ "azure.cognitiveservices.speech" ];

        meta = {
          description = "Microsoft Azure Cognitive Services Speech SDK";
          homepage = "https://aka.ms/csspeech";
          license = pkgs.lib.licenses.mit;
          platforms = [ "x86_64-linux" ];
        };
      };

      # Frontend is a separate git submodule (pre-built static assets)
      frontend = pkgs.fetchFromGitHub {
        owner = "Open-LLM-VTuber";
        repo  = "Open-LLM-VTuber-Web";
        rev   = "ac7de8e880d803e4bda64aadda88208708d081ef";
        hash  = "sha256-Y8hMHrWV3dGVCvWvq/wadukRvMg+/xXkqlT2N6VQ5DM=";
      };

    in
    {
      packages.open-llm-vtuber = python.pkgs.buildPythonApplication {
        pname   = "open-llm-vtuber";
        version = "1.2.1";
        pyproject = true;

        src = pkgs.fetchFromGitHub {
          owner = "Open-LLM-VTuber";
          repo  = "Open-LLM-VTuber";
          rev   = "v1.2.1";
          hash  = "sha256-NUUu5aKhjrSpVZDG5kC44V4RRfR+VAyrq1zokFvy15w=";
        };

        # The upstream repo has no [build-system] table; we add setuptools.
        build-system = with python.pkgs; [ setuptools ];

        postPatch = ''
          # ---- Fix src-layout import in the entry script and upgrade_codes ----
          find . -name "*.py" -exec sed -i 's/from src\.open_llm_vtuber\./from open_llm_vtuber./g' {} +

          # ---- Disable git submodule frontend check ----
          # The frontend is provided via the Nix package share directory.
          sed -i 's/check_frontend_submodule(lang)/pass  # frontend provided by Nix package/' \
            run_server.py

          # ---- Fix HF_HOME / MODELSCOPE_CACHE ----
          # Use setdefault so the service (or the user's environment) can override.
          sed -i \
            's|os\.environ\["HF_HOME"\] = str(Path(__file__).parent / "models")|os.environ.setdefault("HF_HOME", str(Path.cwd() / "models"))|' \
            run_server.py
          sed -i \
            's|os\.environ\["MODELSCOPE_CACHE"\] = str(Path(__file__).parent / "models")|os.environ.setdefault("MODELSCOPE_CACHE", str(Path.cwd() / "models"))|' \
            run_server.py

          # ---- Relax numpy upper bound and drop dev-only deps from pyproject.toml ----
          # nixpkgs ships numpy 2.x; pre-commit and ruff are dev tools, not runtime deps.
          substituteInPlace pyproject.toml \
            --replace-fail '"numpy>=1.26.4,<2",' '"numpy>=1.26.4",'
          sed -i '/"pre-commit>=/d; /"ruff>=/d' pyproject.toml

          # ---- Use importlib.metadata for version (avoid reading pyproject.toml from CWD) ----
          python3 - <<'PYEOF'
          import re, pathlib
          p = pathlib.Path("run_server.py")
          t = p.read_text()
          t = re.sub(
              r'def get_version\(\) -> str:\n    with open\("pyproject\.toml", "rb"\) as f:.*?return pyproject\["project"\]\["version"\]',
              'def get_version() -> str:\n    try:\n        from importlib.metadata import version as _v\n        return _v("open-llm-vtuber")\n    except Exception:\n        return "1.2.1"',
              t, flags=re.DOTALL,
          )
          p.write_text(t)
          PYEOF

          # ---- Add a callable main() entry point ----
          cat >> run_server.py <<'EOF'


          def main() -> None:
              """Console-script entry point (used by the Nix wrapper)."""
              args = parse_args()
              console_log_level = "DEBUG" if args.verbose else "INFO"
              if args.hf_mirror:
                  os.environ["HF_ENDPOINT"] = "https://hf-mirror.com"
              run(console_log_level=console_log_level)
          EOF

          # ---- Restructure for proper packaging ----
          # Move the entry script into the package so setuptools installs it.
          mv run_server.py src/open_llm_vtuber/_run.py

          # Move upgrade_codes and prompts (top-level packages) into src/ so setuptools discovers them.
          mv upgrade_codes src/
          mv prompts src/

          # Add [build-system], package discovery, and console script to pyproject.toml.
          cat >> pyproject.toml <<'EOF'

          [build-system]
          requires = ["setuptools>=61"]
          build-backend = "setuptools.build_meta"

          [tool.setuptools.packages.find]
          where = ["src"]

          [project.scripts]
          open-llm-vtuber = "open_llm_vtuber._run:main"
          EOF
        '';

        # Place read-only assets (frontend, models, backgrounds, …) under
        # $out/share/open-llm-vtuber/ so the NixOS service can symlink them.
        # Note: prompts/ is installed as a Python package (moved to src/ in postPatch).
        postInstall = ''
          share="$out/share/open-llm-vtuber"
          mkdir -p "$share"
          cp -r ${frontend}                    "$share/frontend"
          cp -r live2d-models                  "$share/live2d-models"
          cp -r backgrounds                    "$share/backgrounds"
          cp -r avatars                        "$share/avatars"
          cp -r web_tool                       "$share/web_tool"
          cp -r characters                     "$share/characters"
          cp    model_dict.json                "$share/model_dict.json"
          cp    config_templates/conf.default.yaml "$share/conf.default.yaml"
        '';

        propagatedBuildInputs = with python.pkgs; [
          anthropic
          azure-cognitiveservices-speech
          cartesia
          chardet
          edge-tts
          elevenlabs
          fastapi
          groq
          httpx
          langdetect
          loguru
          mcp
          numpy
          onnxruntime
          openai
          pydub
          pysbd
          pyttsx3
          pyyaml
          requests
          ruamel-yaml
          scipy
          sherpa-onnx
          soundfile
          srt
          tomli
          torch
          tqdm
          uvicorn
          websocket-client
          letta-client
          duckduckgo-mcp-server
        ];

        pythonImportsCheck = [ "open_llm_vtuber" "upgrade_codes" "prompts" ];

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
