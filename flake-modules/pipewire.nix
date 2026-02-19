{ ... }:
let
  patchedRaysession = pkgs: pkgs.raysession.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      sed -i '/from cgitb import text/d' src/gui/patchbay/patchcanvas/portgroup_widget.py
    '';
  });
in
{
  perSystem = { pkgs, ... }: {
    packages.raysession = patchedRaysession pkgs;
  };

  flake.nixosModules.pipewire = { config, lib, pkgs, ... }: {
    config = {
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        pulse.enable = true;
        jack.enable = true;
        socketActivation = false;
        extraConfig.pipewire.context.properties = {
          "default.clock.allowed-rates" = [ 48000 44100 ];
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 2048;
        };
      };
      systemd.user.services.wireplumber.wantedBy = [ "default.target" ];

      environment.systemPackages = with pkgs; [
        jack2
        pipewire
        wireplumber
        pavucontrol
        qpwgraph
        alsa-utils
        (patchedRaysession pkgs)
      ];
    };
  };
}
