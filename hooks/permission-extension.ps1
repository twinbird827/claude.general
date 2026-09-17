# PreToolUse hook: extend the permission list where a Bash rule cannot express
# the condition. Judges the whole Bash command once, split into segments on
# && || ; | & and newlines -- the set the permissions list splits on
# (knowhow/pipe-stage-hook-removal.md).
# Two rules:
# 1. `glab api`: a segment is in scope when it carries both the words `glab`
#    and `api`, in any order -- not as adjacent tokens, so a persistent flag
#    between them (`glab -R owner/repo api ...`) cannot hide the call. An
#    in-scope segment is left silent (the permissions list decides) only when
#    it carries an explicit POST or PUT method (upper case) AND carries no
#    other method token. Anything else -> `ask`: DELETE, a lower-case method,
#    a method-less GET, and a segment that lost its method because a
#    separator inside an argument value split the call. Two forms stay silent:
#    a segment that ends with a POST token (`-F note="x --method POST|y"
#    --method DELETE`) leaves the real DELETE in the next segment, and a split
#    before `api` (`glab -R "a&b" api x --method DELETE`) puts the two words
#    in separate segments, so neither is in scope.
# 2. `rm`: a segment is safe when it carries at most one flag made of one or
#    two of the letters `r`/`f` (`-r`, `-f`, `-rf`, `-fr`), ends with its
#    last target, and every target is a plain relative path under ./.tmp/
#    (no `..`, no glob, no quoting, no expansion, no shell metacharacters).
#    - a segment that mentions `rm` in any other form -> `ask`, so the call
#      never falls through to the auto-mode classifier (a blocked classifier
#      verdict has no ask fallback).
#    - all rm segments safe and nothing else in the call -> `allow`
#    - all rm segments safe but other segments present (a `cd` prefix, a
#      pipe) -> stay silent, because `allow` covers the whole call and would
#      wave through those other segments. The permissions list judges them
#      per segment.
# ASCII only (PowerShell 5.1 stdout encoding). Unreadable input falls into the
# 'ask' branch: no output would mean "no decision" and reach the classifier.
# Self-check: hooks/permission-extension.tests.ps1 (re-run after changing a pattern).
$ErrorActionPreference = 'Stop'
try {
  # Read stdin via the raw handle: [Console]::In is empty when the harness runs
  # powershell.exe with -WindowStyle Hidden (no console attached).
  $raw = (New-Object IO.StreamReader([Console]::OpenStandardInput())).ReadToEnd()
  $cmd = ($raw | ConvertFrom-Json).tool_input.command
} catch { $cmd = $null }
function Ask($why) { '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"' + $why + '"}}' }
if (-not $cmd) { Ask 'the command could not be read or parsed'; exit 0 }
$parts = @([regex]::Split($cmd, '&&|\|\||;|\||&|\r?\n') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$glabWord = '(^|[^A-Za-z0-9_-])glab([^A-Za-z0-9_-]|\z)'
$apiWord = '(^|[^A-Za-z0-9_-])api([^A-Za-z0-9_-]|\z)'
$writeOk = '(^|\s)(-X|--method)[\s=]*[''"]?(POST|PUT)([''"]|\s|\z)'
$otherMethod = '(^|\s)(-X|--method)(?![\s=]*[''"]?(POST|PUT)([''"]|\s|\z))'
if (@($parts | Where-Object { $_ -cmatch $glabWord -and $_ -cmatch $apiWord -and ($_ -cnotmatch $writeOk -or $_ -cmatch $otherMethod) }).Count) { Ask 'glab api without an explicit POST or PUT method in the same segment, or with another method token alongside it'; exit 0 }
$safe = "^rm( -[rf]{1,2})?( \.tmp(/[A-Za-z0-9_-][A-Za-z0-9._-]*)+)+\z"
$rmSafe = @($parts | Where-Object { $_ -cmatch $safe })
$rmRisky = @($parts | Where-Object { $_ -cmatch '(^|[^A-Za-z0-9_-])rm([^A-Za-z0-9_-]|\z)' -and $_ -cnotmatch $safe })
if ($rmRisky.Count) { Ask 'an rm target is not a plain path under .tmp/'; exit 0 }
if ($parts.Count -and $rmSafe.Count -eq $parts.Count) {
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"every rm target is a plain path under .tmp/"}}'
}
exit 0
