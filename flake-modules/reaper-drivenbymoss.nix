{ ... }:
{
  perSystem = { pkgs, self', ... }: {
    packages = {
      drivenbymoss-reaper = pkgs.stdenv.mkDerivation {
       pname = "drivenbymoss-reaper";
        version = "26.5.1";

        src = pkgs.fetchurl {
          url = "https://www.mossgrabers.de/Software/Reaper/DrivenByMoss4Reaper-26.5.1-Linux.tar.gz";
          sha256 = "sha256-vqC5E6j/7t4pcsn/qegfR38m352rfxtrlwOBh8OI4SI=";
        };

        nativeBuildInputs = [ pkgs.patchelf ];

        unpackPhase = ''tar -xzf $src'';

        installPhase = ''
          mkdir -p $out/lib/reaper

          # Copy everything
          cp reaper_drivenbymoss.so $out/lib/reaper/
          cp -r drivenbymoss-libs $out/lib/reaper/
          cp -r java-runtime $out/lib/reaper/
          cp -r resources $out/lib/reaper/

          # Patchelf to find bundled runtime
          patchelf \
            --set-rpath "$out/lib/reaper/java-runtime/lib:$out/lib/reaper/java-runtime/lib/server:$out/lib/reaper" \
            $out/lib/reaper/reaper_drivenbymoss.so
        '';

        meta = {
          description = "DrivenByMoss 4 Reaper Extension";
          platforms = [ "x86_64-linux" ];
        };
      };
    };
  };
}
