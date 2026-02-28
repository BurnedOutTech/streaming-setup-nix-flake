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

      open-llm-vtuber-service = pkgs.testers.runNixOSTest {
        name = "open-llm-vtuber-service";

        nodes.machine = { lib, pkgs, ... }:
          let
            pkg      = self'.packages.open-llm-vtuber;
            shareDir = "${pkg}/share/open-llm-vtuber";

            # Build-time: copy the bundled default conf (valid pydantic config)
            # and patch two settings that would block startup in a headless VM:
            #  - asr_model: groq_whisper_asr — API-based ASR, no model download at init
            #  - host: 0.0.0.0 — so curl inside the VM can reach the server
            testConf = pkgs.runCommand "conf.test.yaml" { } (''
              sed \
                -e "s|asr_model: 'sherpa_onnx_asr'|asr_model: 'groq_whisper_asr'|" \
                -e "s|host: 'localhost'|host: '0.0.0.0'|" \
                '' + shareDir + ''/conf.default.yaml > $out
            '');
          in
          {
            virtualisation.memorySize = 2048;

            users.users.vtuber = { isSystemUser = true; group = "vtuber"; };
            users.groups.vtuber = { };

            systemd.services.open-llm-vtuber = {
              description = "Open LLM VTuber";
              wantedBy    = [ "multi-user.target" ];
              after       = [ "network.target" ];

              preStart = ''
                mkdir -p /var/lib/open-llm-vtuber/{models,cache,logs}

                # Use the test conf (no model downloads)
                install -m 644 ${testConf} /var/lib/open-llm-vtuber/conf.yaml

                # Seed model_dict.json so Live2D init doesn't CRITICAL-error
                [ -f /var/lib/open-llm-vtuber/model_dict.json ] || \
                  install -m 644 ${shareDir}/model_dict.json \
                                  /var/lib/open-llm-vtuber/model_dict.json

                # Seed mcp_servers.json so MCP server registry initialises without error
                [ -f /var/lib/open-llm-vtuber/mcp_servers.json ] || \
                  install -m 644 ${shareDir}/mcp_servers.json \
                                  /var/lib/open-llm-vtuber/mcp_servers.json

                for d in frontend live2d-models backgrounds avatars web_tool characters prompts; do
                  [ -e /var/lib/open-llm-vtuber/$d ] || \
                    ln -s ${shareDir}/$d /var/lib/open-llm-vtuber/$d
                done
              '';

              serviceConfig = {
                User             = "vtuber";
                Group            = "vtuber";
                WorkingDirectory = "/var/lib/open-llm-vtuber";
                StateDirectory   = "open-llm-vtuber";
                ExecStart        = "${pkg}/bin/open-llm-vtuber";
                Environment      = [
                  "HF_HOME=/var/lib/open-llm-vtuber/models"
                  "MODELSCOPE_CACHE=/var/lib/open-llm-vtuber/models"
                ];
              };
            };
          };

        testScript = ''
          start_all()
          machine.wait_for_unit("open-llm-vtuber.service")
          # Wait up to 60s for uvicorn to bind (init runs before binding port)
          machine.wait_for_open_port(12393, timeout=60)
          # HTTP frontend must respond (proves uvicorn started — init completed without model downloads)
          machine.succeed("curl -sf http://127.0.0.1:12393/ >/dev/null")
          # State directory populated correctly
          machine.succeed("test -f /var/lib/open-llm-vtuber/conf.yaml")
          machine.succeed("test -f /var/lib/open-llm-vtuber/model_dict.json")
          machine.succeed("test -L /var/lib/open-llm-vtuber/frontend")
          machine.succeed("test -L /var/lib/open-llm-vtuber/live2d-models")
        '';
      };
    };
  };
}
