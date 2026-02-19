# streaming-setup

A Nix flake ([flake-parts](https://flake.parts)) that packages OBS, Reaper, and related audio/streaming tools for `x86_64-linux`. Each module is also re-exported so other flakes can import only what they need.

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

## NixOS Module

A PipeWire NixOS module is available at `nixosModules.pipewire`. It enables ALSA, PulseAudio, and JACK compatibility, sets low-latency clock rates (32–2048 quantum, 44100/48000 Hz), and installs common audio utilities.

```nix
# In your NixOS configuration:
imports = [ inputs.streaming-setup.nixosModules.pipewire ];
```

## Using individual modules in another flake

Every module is re-exported under `flakeModules.*`:

```nix
inputs.streaming-setup.flakeModules.obs      # OBS only
inputs.streaming-setup.flakeModules.reaper   # Reaper only
inputs.streaming-setup.flakeModules.yt-dl    # yt-dl only
inputs.streaming-setup.flakeModules.multimedia-tools  # multimedia utilities
inputs.streaming-setup.flakeModules.default  # everything
```

## Updating inputs

```bash
nix flake update
```

> **Note:** Only `x86_64-linux` is supported. Unfree packages (`reaper`, `vcv-rack`) are handled inside individual modules via a scoped `allowUnfree` nixpkgs instance — the top-level flake does not set it globally.
