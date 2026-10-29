# flake-modules

Each file is a [flake-parts](https://flake.parts) module. They can be used
individually or all together via the `default` flakeModule.

---

## Modules overview

| File | Packages | NixOS module | devShell |
|---|---|---|---|
| `obs.nix` | `obs`, `obs-cuda` | `obs` (firewall) | — |
| `reaper.nix` | `reaper` | — | — |
| `reaper-drivenbymoss.nix` | — | — | — |
| `pipewire.nix` | `raysession` (patched) | `pipewire` | — |
| `multimedia-tools.nix` | `multimedia-tools` | — | — |
| `yt-dl/yt-dl.nix` | `yt-dl` | — | — |
| `devshells.nix` | — | — | `default`, `obs-only`, `reaper-only` |
| `open-llm-vtuber.nix` | `open-llm-vtuber` | `open-llm-vtuber` | `open-llm-vtuber` |
| `tests.nix` | — | — | — |
| `openllmvtuber-buildpackage.nix` | `open-llm-vtuber` | — | — (not imported) |

---

## Building packages

```bash
# All examples run from the repo root
cd /path/to/streaming-setup

nix build .#obs
nix build .#obs-cuda           # OBS with CUDA support
nix build .#reaper
nix build .#multimedia-tools   # bundle: inkscape, kdenlive, vlc, easyeffects, …
nix build .#raysession         # patched RaySession (PipeWire patchbay)
nix build .#yt-dl              # Perl wrapper around yt-dlp
nix build .#open-llm-vtuber    # LLM VTuber server (uv2nix, see below)
```

---

## Running

### Dev shells

```bash
nix develop                    # default: OBS + Reaper + ffmpeg + sox
nix develop .#obs-only         # just OBS + ffmpeg
nix develop .#reaper-only      # just Reaper
nix develop .#open-llm-vtuber  # open-llm-vtuber binary + venv + ffmpeg + uv
```

### open-llm-vtuber manual start

The server requires several asset files in the working directory.  The package
ships them all under `$out/share/open-llm-vtuber/`.

```bash
# 1. Build the package and grab the share path
PKG=$(nix build .#open-llm-vtuber --no-link --print-out-paths)
SHARE=$PKG/share/open-llm-vtuber

# 2. Set up a working directory
mkdir -p /tmp/olv && cd /tmp/olv

# 3. Seed required files
cp $SHARE/conf.default.yaml  conf.yaml
cp $SHARE/model_dict.json    .
cp $SHARE/mcp_servers.json   .
for d in frontend live2d-models backgrounds avatars web_tool characters prompts; do
  ln -sf $SHARE/$d .
done

# 4. Avoid the ~1 GB sherpa-onnx model download on first run.
#    Switch ASR to groq_whisper_asr (API-based, no local model needed).
#    You still need a Groq API key in conf.yaml → groq_whisper_asr.api_key.
sed -i "s|asr_model: 'sherpa_onnx_asr'|asr_model: 'groq_whisper_asr'|" conf.yaml
sed -i "s|host: 'localhost'|host: '0.0.0.0'|" conf.yaml

# 5. Start the server
$PKG/bin/open-llm-vtuber
# or, if you're inside nix develop .#open-llm-vtuber:
open-llm-vtuber
```

Open **http://localhost:12393** in a browser.

---

## NixOS service modules

Import a module into your NixOS configuration:

```nix
# flake.nix of your host
{
  inputs.streaming-setup.url = "github:youruser/streaming-setup";

  outputs = { nixpkgs, streaming-setup, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        streaming-setup.nixosModules.open-llm-vtuber
        streaming-setup.nixosModules.obs       # optional: opens websocket firewall port
        streaming-setup.nixosModules.pipewire  # optional: low-latency PipeWire config
        {
          services.open-llm-vtuber = {
            enable  = true;
            package = streaming-setup.packages.x86_64-linux.open-llm-vtuber;
          };
        }
      ];
    };
  };
}
```

### open-llm-vtuber service options

| Option | Type | Default | Description |
|---|---|---|---|
| `enable` | bool | `false` | Enable the systemd service |
| `package` | package | — | The `open-llm-vtuber` package to use |
| `dataDir` | path | `/var/lib/open-llm-vtuber` | State directory (conf.yaml, models, cache) |
| `user` | string | `open-llm-vtuber` | User to run the service as |
| `group` | string | `open-llm-vtuber` | Group to run the service as |

On first start `preStart` will:
- Copy `conf.default.yaml` → `$dataDir/conf.yaml` (if not already present)
- Seed `model_dict.json` and `mcp_servers.json`
- Symlink read-only assets (`frontend/`, `live2d-models/`, etc.) from the package store path

### pipewire module

Configures PipeWire with ALSA/PulseAudio/JACK compatibility, low-latency
quantum settings (32–2048), and installs `pavucontrol`, `qpwgraph`,
`jack2`, `wireplumber`, and `raysession`.

### obs module

Opens TCP port `4455` (obs-websocket) and UDP port `5353` (mDNS) in the
firewall.

---

## Tests

### Automated NixOS VM test

```bash
# Run (boots a QEMU VM, ~2 min first run; cached on repeat)
nix build .#checks.x86_64-linux.open-llm-vtuber-service -L

# Force re-run even if cached
nix build .#checks.x86_64-linux.open-llm-vtuber-service -L --rebuild
```

The test:
1. Boots a NixOS VM with the service enabled
2. Waits for the unit to start and TCP port 12393 to open
3. `curl`s the frontend HTTP endpoint
4. Checks state files (`conf.yaml`, `model_dict.json`) and asset symlinks exist

Uses `groq_whisper_asr` in the test conf to avoid downloading the ~1 GB
sherpa-onnx model inside the VM.

### Interactive VM (for manual poking)

```bash
DRIVER=$(nix build .#checks.x86_64-linux.open-llm-vtuber-service.driver \
           --no-link --print-out-paths)
$DRIVER/bin/nixos-test-driver
# Python REPL — machine is available:
# >>> machine.start()
# >>> machine.wait_for_unit("open-llm-vtuber.service")
# >>> machine.wait_for_open_port(12393)
# >>> machine.shell_interact()   # drops you into a shell inside the VM
```

---

## open-llm-vtuber: two packaging approaches

Two implementations exist side by side:

### `open-llm-vtuber.nix` (active, uv2nix)

Reads `uv.lock` from upstream directly via
[uv2nix](https://github.com/adisbladis/uv2nix).  All 200+ transitive
dependencies are resolved from the lock file — no manual dep declarations.

- ✅ Easy to maintain: just update `uv.lock` when upstream bumps deps
- ✅ Exact reproducibility (lock file pins every transitive dep)
- ✅ NixOS VM test passes
- ❌ Not acceptable for nixpkgs (uv2nix pattern not yet allowed upstream)
- Requires 3 extra flake inputs: `uv2nix`, `pyproject-nix`, `pyproject-build-systems`

### `openllmvtuber-buildpackage.nix` (backup, nixpkgs style)

Uses `buildPythonApplication` with every dep declared explicitly.
Six packages not in nixpkgs are declared inline as wheel derivations:
`sherpa-onnx`, `cartesia`, `azure-cognitiveservices-speech`, `edge-tts`,
`letta-client`, `duckduckgo-mcp-server`.

- ✅ No extra flake inputs
- ✅ Closest to nixpkgs PR style
- ❌ Not imported by `flake.nix` (standalone file, test manually)
- ❌ Fragile: each inline wheel derivation needs manual hash + build-input updates on version bumps

**Test the buildPythonApplication version:**
```bash
nix build --impure --expr '
  let
    f = builtins.getFlake (toString ./.);
    pkgs = f.inputs.nixpkgs.legacyPackages.x86_64-linux;
    mod = import ./flake-modules/openllmvtuber-buildpackage.nix { inputs = f.inputs; };
  in (mod.perSystem { inherit pkgs; system = "x86_64-linux"; lib = pkgs.lib; }).packages.open-llm-vtuber
'
./result/bin/open-llm-vtuber --help
```
