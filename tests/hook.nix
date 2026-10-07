{ runCommand, nushell }:

# Runs the script directly, so the check needs neither whisper nor its model.
runCommand "dicta-hook-test" { nativeBuildInputs = [ nushell ]; } ''
  export HOME="$TMPDIR"
  nu ${./hook.nu} ${../dicta.nu}
  touch "$out"
''
