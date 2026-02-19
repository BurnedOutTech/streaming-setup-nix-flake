{ inputs, ... }:
{
  perSystem = { system, config, pkgs, lib, ... }: 
  let
    # Import nixpkgs with allowUnfree for Reaper
    unfree-pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in
  {
    packages = rec {
      
      # 1. The Plugin Package (Adapted for "Portable" structure)
      drivenbymoss-reaper = pkgs.stdenv.mkDerivation rec {
        pname = "drivenbymoss-reaper";
        version = "26.5.1";

        src = pkgs.fetchurl {
          url = "https://www.mossgrabers.de/Software/Reaper/DrivenByMoss4Reaper-${version}-Linux.tar.gz";
          sha256 = "sha256-vqC5E6j/7t4pcsn/qegfR38m352rfxtrlwOBh8OI4SI=";
        };

        nativeBuildInputs = [ pkgs.autoPatchelfHook pkgs.patchelf ];
        
        # Dependencies for the bundled Java runtime
        buildInputs = with pkgs; [
          alsa-lib freetype stdenv.cc.cc.lib
          libX11 libXext libXi libXrender libXtst
        ];

        dontUnpack = true;

        # Install strictly into UserPlugins to allow easy injection later
        installPhase = ''
          mkdir -p $out/UserPlugins
          tar -xzf $src -C $out/UserPlugins
        '';

        # Fix RPATH so the plugin finds its sibling Java runtime
        postFixup = ''
          patchelf --add-rpath "$out/UserPlugins/java-runtime/lib:$out/UserPlugins/java-runtime/lib/server" \
            $out/UserPlugins/reaper_drivenbymoss.so
        '';
      };

      # 2. The Reaper Wrapper
      # This takes the base Reaper package and injects your plugins into its install dir
      reaper-wrapped = let 
        # Define which plugins you want to inject here
        myReaperPlugins = [ drivenbymoss-reaper ]; 
      in unfree-pkgs.reaper.overrideAttrs (old: {
        # NixOS Reaper installs to $out/opt/REAPER
        # We append a copy command to the install phase
        postInstall = (old.postInstall or "") + ''
          mkdir -p $out/opt/REAPER/UserPlugins
          
          ${lib.concatMapStrings (plugin: ''
            echo "Injecting plugin: ${plugin.name}"
            # Copy the contents of the plugin's UserPlugins folder into Reaper's
            cp -rn ${plugin}/UserPlugins/* $out/opt/REAPER/UserPlugins/
          '') myReaperPlugins}
        '';
      });
      
    };
  };
}
