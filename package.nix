{
  lib,
  coreutils,
  fetchurl,
  libnotify,
  makeWrapper,
  nushell,
  pipewire,
  replaceVars,
  runCommand,
  symlinkJoin,
  whisper-cpp,
  wl-clipboard-rs,
  writeTextFile,
  writers,
}:

let
  # `--stdin` exposes the hook payload as `$in`; writeNuScriptBin omits it.
  script = writeTextFile {
    name = "dicta";
    destination = "/bin/dicta";
    executable = true;
    text = "#!${nushell}/bin/nu --stdin\n" + builtins.readFile ./dicta.nu;
  };

  # English base model: quick enough on a laptop CPU for short spoken notes.
  # Point DICTA_MODEL at another ggml model to trade speed for accuracy.
  model = fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin";
    hash = "sha256-oDd5yG3zMjB19eeWyyzlAp8A7Ihp7uP9+4l6/jbG0AI=";
  };

  dicta = symlinkJoin {
    name = "dicta";
    paths = [ script ];
    nativeBuildInputs = [ makeWrapper ];
    # niri and systemctl come from the session, which must match the running
    # compositor and user manager.
    postBuild = ''
      wrapProgram "$out/bin/dicta" \
        --set DICTA_SELF "$out/bin/dicta" \
        --set-default DICTA_MODEL ${model} \
        --prefix PATH : ${
          lib.makeBinPath [
            coreutils
            libnotify
            pipewire
            whisper-cpp
            wl-clipboard-rs
          ]
        }
    '';
    meta = {
      description = "A reporter's tape recorder for reviewing what coding agents did";
      homepage = "https://github.com/schlich/dicta";
      license = lib.licenses.mit;
      mainProgram = "dicta";
      platforms = lib.platforms.linux;
    };
  };

  # A Noctalia `path` plugin source: one directory per plugin.
  noctaliaPlugins = runCommand "dicta-noctalia-plugins" { } ''
    install -Dm644 ${./noctalia/plugin.toml} $out/dicta/plugin.toml
    install -Dm644 ${
      replaceVars ./noctalia/widget.luau { dicta = "${dicta}/bin/dicta"; }
    } $out/dicta/widget.luau
  '';

  # A Claude Code plugin whose UserPromptSubmit hook attaches pending takes.
  claudeCodePlugin = runCommand "dicta-claude-code-plugin" { } ''
    install -Dm644 ${
      writers.writeJSON "plugin.json" {
        name = "dicta";
        description = "Attach spoken review notes recorded with dicta to the next prompt.";
      }
    } $out/.claude-plugin/plugin.json
    install -Dm644 ${
      writers.writeJSON "hooks.json" {
        hooks.UserPromptSubmit = [
          {
            hooks = [
              {
                type = "command";
                command = "${dicta}/bin/dicta hook";
                timeout = 10;
              }
            ];
          }
        ];
      }
    } $out/hooks/hooks.json
  '';
in
dicta.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    inherit model noctaliaPlugins claudeCodePlugin;
  };
})
