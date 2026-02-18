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
        '';
      };
    };
  };
}
