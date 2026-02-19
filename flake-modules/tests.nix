{ ... }:
{
  perSystem = { pkgs, self', ... }: {
    checks = {
      vm-smoke = pkgs.testers.runNixOSTest {
        name = "vm-smoke";
        nodes.machine = { ... }: {
          virtualisation.memorySize = 4096;
          environment.systemPackages = [
            self'.packages.obs
            self'.packages.reaper
          ];
        };
        testScript = ''
          start_all()
          machine.wait_for_unit("multi-user.target")
          machine.succeed("obs --version")
          machine.succeed("reaper --help >/tmp/reaper-help.log 2>&1 || reaper -h >/tmp/reaper-help.log 2>&1")
          machine.succeed("test -s /tmp/reaper-help.log")
        '';
      };

      raysession-pipewire = pkgs.testers.runNixOSTest {
        name = "raysession-pipewire";
        nodes.machine = { ... }: {
          virtualisation.memorySize = 2048;
          services.pipewire = {
            enable = true;
            jack.enable = true;
          };
          users.users.alice = {
            isNormalUser = true;
            extraGroups = [ "audio" ];
          };
          environment.systemPackages = [ pkgs.raysession ];
        };
        testScript = ''
          start_all()
          machine.wait_for_unit("multi-user.target")
          # Enable linger so alice gets a persistent user session (XDG_RUNTIME_DIR + user bus)
          machine.succeed("loginctl enable-linger alice")
          machine.wait_for_unit("user@1000.service")
          machine.wait_for_unit("pipewire.socket", user="alice")
          # Start ray-daemon (headless) as alice; connecting to JACK triggers PipeWire socket activation
          machine.succeed("su - alice -c 'XDG_RUNTIME_DIR=/run/user/1000 ray-daemon --osc-port 18271 --findfreeport >/tmp/ray.log 2>&1 &'")
          machine.sleep(2)
          machine.succeed("pgrep -f ray-daemon || (cat /tmp/ray.log >&2; false)")
          machine.execute("kill $(pgrep -f ray-daemon)")
          machine.shutdown()
        '';
      };
    };
  };
}
