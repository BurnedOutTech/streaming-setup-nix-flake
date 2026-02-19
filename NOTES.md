
Free audio plugins:
https://lv2plug.in/pages/projects.html
https://github.com/alex-tee/lv2-plugins-ultimate-list
https://kx.studio/Repositories:Plugins
http://openavproductions.com/fabla2/
https://www.audiopluginsforfree.com/xenia/ - needs synth roms
https://dsp56300.wordpress.com/vavra/
https://hise.dev/


VCV-Rack wayland issue - https://github.com/NixOS/nixpkgs/issues/393113

Follow-up PR test plan proposal:
- Add separate NixOS VM checks that boot a graphical session and assert `obs` and `reaper` stay alive for a short period under Xvfb.
- Add package-specific smoke checks for `obs-cuda` and `reaper-wrapped`.
- Add negative tests for missing plugin/runtime dependencies (ensure clear failures).
- Add matrix testing for additional systems once outputs support them.
