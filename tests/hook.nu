# The script parses cleanly, and its UserPromptSubmit hook attaches the
# pending takes recorded in a window the session runs under (an ancestor
# process) while leaving every other take pending.
use std/assert

def take [id: string, pid: int, transcript: string] {
  {
    id: $id
    at: (date now | format date '%+')
    status: "pending"
    app: "test"
    title: "test"
    pid: $pid
    workspace: "test"
    directory: null
    quote: "the passage"
    audio: "/nonexistent.wav"
    transcript: $transcript
  }
}

def main [script: path] {
  let diagnostics = (
    ^nu --ide-check 100 $script
    | lines
    | each { from json }
    | where type == "diagnostic"
  )
  assert equal $diagnostics [] "dicta.nu has diagnostics"

  let root = (mktemp --directory)
  let environment = { DICTA_DIR: $"($root)/data", XDG_RUNTIME_DIR: $"($root)/run" }
  mkdir $"($root)/data/takes" $"($root)/run"
  # This process is an ancestor of the hook; no process has the other pid.
  take "20260101T000001" $nu.pid "Ours." | to json | save $"($root)/data/takes/20260101T000001.json"
  take "20260101T000002" 999999999 "Someone else's." | to json | save $"($root)/data/takes/20260101T000002.json"

  let hook = (with-env $environment { '{"session_id":"test"}' | ^nu --stdin $script hook | complete })
  assert equal $hook.exit_code 0 $hook.stderr
  assert ($hook.stdout | is-not-empty) $"the hook attached nothing: ($hook.stderr)"
  let output = ($hook.stdout | from json)
  assert equal $output.hookSpecificOutput.hookEventName "UserPromptSubmit"
  assert str contains $output.hookSpecificOutput.additionalContext "> the passage"
  assert str contains $output.hookSpecificOutput.additionalContext "Ours."
  assert not ($output.hookSpecificOutput.additionalContext | str contains "Someone else's.")

  let statuses = (
    glob $"($root)/data/takes/*.json" | each { open } | sort-by id | get status
  )
  assert equal $statuses ["delivered" "pending"]

  # Nothing left to attach: the hook prints nothing.
  let again = (with-env $environment { '{"session_id":"test"}' | ^nu --stdin $script hook | complete })
  assert equal ($again.stdout | str trim) ""
  print "dicta hook test passed"
}
