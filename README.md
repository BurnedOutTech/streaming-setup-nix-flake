# streaming-setup

A Nix flake ([flake-parts](https://flake.parts)) that packages OBS, Reaper, and related audio/streaming tools for `x86_64-linux`. Each module is also re-exported so other flakes can import only what they need.

## Binary cache

Packages are built on CI and pushed to Cachix. Add the cache to avoid rebuilding locally:

```bash
cachix use burnedouttech
```

Or in your NixOS config:
```nix
nix.settings = {
  substituters = [ "https://burnedouttech.cachix.org" ];
  trusted-public-keys = [ "burnedouttech.cachix.org-1:..." ]; # fill in from cachix dashboard
};
```

## Packages

| Package | Description |
|---|---|
| `obs` | OBS Studio with plugins (CPU, Wayland-ready) |
| `obs-cuda` | OBS Studio with CUDA support |
| `reaper` | Reaper DAW + plugins as a `symlinkJoin` with runtime libs wired up |
| `reaper-wrapped` | Reaper with DrivenByMoss MIDI controller plugin injected |
| `drivenbymoss-reaper` | DrivenByMoss plugin package (standalone) |
| `yt-dl` | CLI wrapper: downloads via `yt-dlp` → transcodes to DaVinci Resolve-compatible DNxHR/PCM `.mov` |
| `multimedia-tools` | Collection of multimedia utilities: Metadata Cleaner, Font Manager, Eyedropper, Upscaler, Curtail, Inkscape, EasyEffects, Helvum, Carla, Zrythm, MIDI Monitor (kmidimon), Handbrake, Kdenlive, VLC, Peek |
| `open-llm-vtuber` | Open LLM VTuber server — voice LLM chat with Live2D avatar, served on port 12393 |

## OBS Plugins included

`wlrobs`, `obs-pipewire-audio-capture`, `obs-source-switcher`, `input-overlay`, `obs-advanced-masks`, `obs-gstreamer`, `obs-vnc`, `obs-vkcapture`, `droidcam-obs`, `obs-source-record`, `advanced-scene-switcher`, `obs-text-pthread`

## Reaper Plugins / Tools included

VCV Rack, yabridge (Windows VST bridge), Surge XT, GeonKick, Cardinal, Calf, LSP Plugins, Neural Amp Modeler LV2, DrumGizmo, QSynth, FluidSynth

## Building

```bash
nix build .#obs           # OBS (CPU)
nix build .#obs-cuda      # OBS with CUDA
nix build .#reaper        # Reaper suite
nix build .#reaper-wrapped  # Reaper with DrivenByMoss injected
nix build .#yt-dl         # yt-dl helper
nix build .#open-llm-vtuber  # Open LLM VTuber server
```

## Dev Shell

```bash
nix develop               # obs-cuda + reaper + ffmpeg + sox
```

## yt-dl

Downloads a URL via `yt-dlp` and transcodes to DNxHR LB / PCM audio `.mov` for DaVinci Resolve. Requires `yt-dlp` and `ffmpeg` in `PATH` (provided automatically via the Nix package).

```bash
yt-dl <url>
```

## NixOS Modules

### PipeWire

A PipeWire NixOS module is available at `nixosModules.pipewire`. It enables ALSA, PulseAudio, and JACK compatibility, sets low-latency clock rates (32–2048 quantum, 44100/48000 Hz), and installs common audio utilities.

```nix
imports = [ inputs.streaming-setup.nixosModules.pipewire ];
```

### Open LLM VTuber

A systemd service module for the Open LLM VTuber server is available at `nixosModules.open-llm-vtuber`. The service:

- Runs as a dedicated system user
- Stores mutable state (conf.yaml, model cache, logs) in `/var/lib/open-llm-vtuber`
- Symlinks read-only assets (frontend, live2d-models, backgrounds, …) from the Nix store and updates them automatically on package upgrades

```nix
imports = [ inputs.streaming-setup.nixosModules.open-llm-vtuber ];

services.open-llm-vtuber = {
  enable  = true;
  package = inputs.streaming-setup.packages.x86_64-linux.open-llm-vtuber;
  # host = "0.0.0.0";   # expose to LAN
  # port = 12393;
  # openFirewall = true;
  extraEnvironment = {
    OLLAMA_HOST = "http://127.0.0.1:11434";
  };
};
```

The server is reachable at `http://localhost:12393` after activation. Edit `/var/lib/open-llm-vtuber/conf.yaml` to configure LLM backends, ASR/TTS providers, and Live2D models.

## Using individual modules in another flake

Every module is re-exported under `flakeModules.*`:

```nix
inputs.streaming-setup.flakeModules.obs             # OBS only
inputs.streaming-setup.flakeModules.reaper          # Reaper only
inputs.streaming-setup.flakeModules.yt-dl           # yt-dl only
inputs.streaming-setup.flakeModules.multimedia-tools  # multimedia utilities
inputs.streaming-setup.flakeModules.open-llm-vtuber # Open LLM VTuber package + service
inputs.streaming-setup.flakeModules.default         # everything
```

## Updating inputs

```bash
nix flake update
```

## Versioning and releases

This repository uses [Conventional Commits](https://www.conventionalcommits.org/) with automated releases:

- Pull requests are checked to ensure PR titles follow conventional format (for example: `feat: add obs plugin`, `fix: correct reaper wrapper`).
- On every push to `master`, Release Please analyzes merged commits and directly versions/releases from `master` without opening a release PR.
- A Git tag and GitHub release are created automatically when releasable changes are detected.

> **Note:** Only `x86_64-linux` is supported. Unfree packages (`reaper`, `vcv-rack`) are handled inside individual modules via a scoped `allowUnfree` nixpkgs instance — the top-level flake does not set it globally.
