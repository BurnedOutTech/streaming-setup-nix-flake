{ ... }:
{
  perSystem = { pkgs, ... }:
  {
    packages.yt-dl = pkgs.stdenv.mkDerivation {
      pname = "yt-dl";
      version = "1.0.0";

      src = ./yt-dl.pl;
      dontUnpack = true;

      nativeBuildInputs = [ pkgs.makeWrapper ];
      buildInputs = [ pkgs.perl ];

      installPhase = ''
        install -Dm755 $src $out/bin/yt-dl
        patchShebangs $out/bin/yt-dl
      '';

      postFixup = ''
        wrapProgram $out/bin/yt-dl \
          --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.yt-dlp pkgs.ffmpeg ]}
      '';
    };
  };
}
