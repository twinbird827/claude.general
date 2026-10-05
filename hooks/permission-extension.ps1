# PreToolUse hook: extend the permission list where a Bash rule cannot express
# the condition. Judges the whole Bash command once, split into segments on
# && || ; | & and newlines -- the set the permissions list splits on
# (knowhow/pipe-stage-hook-removal.md).
# Three rules:
# 1. `glab api`: a segment is in scope when it carries both the words `glab`
#    and `api`, in any order -- not as adjacent tokens, so a persistent flag
#    between them (`glab -R owner/repo api ...`) cannot hide the call. An
#    in-scope segment is left silent by this rule (rule 2 then asks outside
#    auto mode, since `glab api` is an ask prefix; the permissions list
#    decides the rest) only when it carries an explicit POST or PUT method
#    (upper case) AND carries no other method token. Anything else -> `ask`:
#    DELETE, a lower-case method, a method-less GET, and a segment that lost
#    its method because a separator inside an argument value split the call.
#    Two forms stay silent:
#    a segment that ends with a POST token (`-F note="x --method POST|y"
#    --method DELETE`) leaves the real DELETE in the next segment, and a split
#    before `api` (`glab -R "a&b" api x --method DELETE`) puts the two words
#    in separate segments, so neither is in scope.
# 2. ask prefixes (moved out of settings `permissions.ask`): a segment, after
#    stripping a leading `rtk proxy ` or `rtk `, that equals a prefix or starts
#    with the prefix plus a space -> `ask` outside auto mode (an unreadable mode
#    counts as outside); silent in auto mode, so the classifier judges. Settings
#    ask cannot do this: it is skipped when rtk rewrites the call, and prompts
#    even in auto mode when rtk does not.
#    Merge prefixes (`gh pr merge`, `glab mr merge`) -> `ask` in every mode:
#    in auto mode the classifier blocks them as Merge Without Review with no
#    ask fallback, while the user decides each merge in the conversation.
# 3. `rm`: a segment is safe when it carries at most one flag made of one or
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
  $in = $raw | ConvertFrom-Json
  $cmd = $in.tool_input.command
  $mode = $in.permission_mode
} catch { $cmd = $null }
function Ask($why) { '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"' + $why + '"}}' }
if (-not $cmd) { Ask 'the command could not be read or parsed'; exit 0 }
$parts = @([regex]::Split($cmd, '&&|\|\||;|\||&|\r?\n') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$glabWord = '(^|[^A-Za-z0-9_-])glab([^A-Za-z0-9_-]|\z)'
$apiWord = '(^|[^A-Za-z0-9_-])api([^A-Za-z0-9_-]|\z)'
$writeOk = '(^|\s)(-X|--method)[\s=]*[''"]?(POST|PUT)([''"]|\s|\z)'
$otherMethod = '(^|\s)(-X|--method)(?![\s=]*[''"]?(POST|PUT)([''"]|\s|\z))'
if (@($parts | Where-Object { $_ -cmatch $glabWord -and $_ -cmatch $apiWord -and ($_ -cnotmatch $writeOk -or $_ -cmatch $otherMethod) }).Count) { Ask 'glab api without an explicit POST or PUT method in the same segment, or with another method token alongside it'; exit 0 }
$askPrefixes = @(
  'dotnet run', 'dotnet publish', 'dotnet add package', 'dotnet remove package', 'dotnet tool install',
  'git add', 'git commit', 'git stash', 'git clone', 'git restore --staged', 'git push', 'git pull',
  'git reset', 'git checkout', 'git switch',
  'gh pr checkout', 'gh pr create', 'gh pr edit', 'gh issue close',
  'glab mr checkout', 'glab api', 'glab issue close',
  'mv', 'curl', 'wget'
)
$alwaysAskPrefixes = @('gh pr merge', 'glab mr merge')
$stripped = @($parts | ForEach-Object { $_ -creplace '^rtk (proxy )?', '' })
function PrefixHit($prefixes) { @($stripped | Where-Object { $s = $_; @($prefixes | Where-Object { $s -ceq $_ -or $s.StartsWith("$_ ", [StringComparison]::Ordinal) }).Count }).Count }
if (PrefixHit $alwaysAskPrefixes) { Ask 'the command merges a merge request'; exit 0 }
if ((PrefixHit $askPrefixes) -and $mode -ne 'auto') { Ask 'the command matches an ask prefix outside auto mode'; exit 0 }
$safe = "^rm( -[rf]{1,2})?( \.tmp(/[A-Za-z0-9_-][A-Za-z0-9._-]*)+)+\z"
$rmSafe = @($parts | Where-Object { $_ -cmatch $safe })
$rmRisky = @($parts | Where-Object { $_ -cmatch '(^|[^A-Za-z0-9_-])rm([^A-Za-z0-9_-]|\z)' -and $_ -cnotmatch $safe })
if ($rmRisky.Count) { Ask 'an rm target is not a plain path under .tmp/'; exit 0 }
if ($parts.Count -and $rmSafe.Count -eq $parts.Count) {
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"every rm target is a plain path under .tmp/"}}'
}
exit 0
