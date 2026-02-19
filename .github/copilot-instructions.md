# Copilot Instructions

## Project Overview

A Nix flake using [flake-parts](https://flake.parts) that packages OBS, Reaper, and related audio/streaming tools for `x86_64-linux`. The flake also exposes each module individually so other flakes can import only what they need.

## Build Commands

```bash
nix build .#obs           # OBS with plugins (CPU)
nix build .#obs-cuda      # OBS with CUDA-enabled obs-studio
nix build .#reaper        # Reaper DAW + plugins as a symlinkJoin
nix develop               # Enter the default dev shell (obs-cuda + reaper + ffmpeg + sox)
nix flake update          # Update all inputs (what the updater agent does)
```

There are no tests or linters.

## Architecture

### flake-parts module structure

All configuration lives in `flake-modules/`. Each file is a flake-parts module imported by `flake.nix`. There are two patterns in use:

- **`perSystem` modules** (`obs.nix`, `reaper.nix`, `reaper-drivenbymoss.nix`, `devshells.nix`): Produce per-system `packages` or `devShells` attributes.
- **`flake.nixosModules` modules** (`pipewire.nix`): Produce NixOS system modules, not packages.

### Unfree packages

Both `reaper.nix` and `reaper-drivenbymoss.nix` instantiate a second nixpkgs with `config.allowUnfree = true` (called `unfree-pkgs`) to access `reaper` and `vcv-rack`. This is intentional — the top-level flake does not set `allowUnfree` globally.

### Plugin injection pattern

`reaper-drivenbymoss.nix` shows the pattern for injecting plugins into Reaper:
1. Build the plugin as a derivation that installs to `$out/UserPlugins/`.
2. Use `overrideAttrs` on the Reaper package to `cp -rn` those files into `$out/opt/REAPER/UserPlugins/` in `postInstall`.

### Module re-exports

`flake.nix` re-exposes every module under `flake.flakeModules.*` so downstream flakes can do `inputs.streaming-setup.flakeModules.obs` to pull in only OBS.

## Key Conventions

- `self'.packages.<name>` is used inside `perSystem` to reference sibling packages (e.g., `devshells.nix` references `self'.packages.obs-cuda`).
- Runtime library paths for plugins are set via `wrapProgram --prefix LD_LIBRARY_PATH` in `reaper.nix`.
- Only `x86_64-linux` is in `systems`; do not add other systems without testing plugin availability.

## yt-dl.pl

A Perl helper script that downloads a URL via `yt-dlp` and immediately transcodes the result to a DaVinci Resolve-compatible format (DNxHR LB video + PCM audio, `.mov` container). Requires `yt-dlp` and `ffmpeg` in `PATH`.

```bash
perl yt-dl.pl <url>
```
