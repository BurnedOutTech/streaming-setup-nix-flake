# flake-modules/reaper.nix
{ inputs, ... }:
{
  perSystem = { pkgs, self', system, ... }: 
  let
    # Import nixpkgs with allowUnfree for Reaper
    unfree-pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    reaper-patched = unfree-pkgs.reaper.overrideAttrs (old: {
      # Reaper uses 2 MiB-aligned ELF segments; the default page size causes
      # autoPatchelfHook to create overlapping mappings and crash at startup.
      # Remove this once nixpkgs preserves Reaper's native page alignment.
      patchelfFlags = (old.patchelfFlags or []) ++ [
        "--page-size"
        "2097152"
      ];
    });
    
    # Define dependencies list to use in both paths and library path
    # (Removed libraries that are usually implicitly handled or should be in LD_LIBRARY_PATH)
    plugin-deps = [
      unfree-pkgs.vcv-rack
      
      # VST bridges for Windows plugins
      pkgs.yabridge
      pkgs.yabridgectl
      pkgs.wineWow64Packages.yabridge
      
      # Synths and instruments
      #pkgs.vital
      pkgs.surge-xt
      pkgs.geonkick
      pkgs.cardinal
      
      # Audio effects
      pkgs.calf

      pkgs.lsp-plugins # needs manual copying
      pkgs.neural-amp-modeler-lv2 # needs manual copying
      pkgs.drumgizmo # needs manual copying
      pkgs.sfizz #idk how it works
      
      # MIDI tools
      pkgs.qsynth
      pkgs.fluidsynth
      pkgs.soundfont-fluid
      
      # Utilities
      pkgs.audacity
    ];

    # Runtime libs often needed by plugins
    runtime-libs = with pkgs; [
      libxcb
      libxkbfile
      libx11
      libxkbcommon
      ftgl
      cairo
      pango
      fontconfig
      libpng
      zlib
    ];

  in
  {
    packages = {
      reaper = pkgs.symlinkJoin {
        name = "reaper-suite";
        paths = [ reaper-patched ] ++ plugin-deps ++ runtime-libs;
        
        nativeBuildInputs = [ pkgs.makeWrapper ];

        postBuild = ''
          wrapProgram $out/bin/reaper \
            --set PIPEWIRE_LATENCY "256/48000" \
            --prefix LD_LIBRARY_PATH : "${pkgs.lib.makeLibraryPath (plugin-deps ++ runtime-libs)}"
        '';
      };
    };
  };
}
