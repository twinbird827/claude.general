# PreToolUse hook: split a Bash call into segments and return allow / ask / deny where a permissions-list rule cannot express the condition.
# Segments split on the set the permissions list splits on
# (knowhow/pipe-stage-hook-removal.md), so the hook and the list judge the
# same units.
# Bypass: denied in every mode because the auto-mode classifier blocks it with
# no ask fallback, so the reason tells Claude to drop the flag. Bypass is not
# needed where SETUP.md was followed: Step 4 runs `npm --version`, which fails
# on a Restricted PC and sends the user to the troubleshooting entry for npm's
# security error, which sets CurrentUser to RemoteSigned.
# Bypass: the scan stops at -File / -Command because powershell.exe passes
# what follows to the script or command, not to its own parameters. Only the
# first word of each segment is checked, so a commit message or grep argument
# mentioning Bypass stays out of scope. The split ignores quotes, so a
# `powershell ... -ExecutionPolicy Bypass` placed after a ; | & or newline
# inside quotes is still denied.
# `glab api`: the two words are not matched as adjacent tokens, so a
# persistent flag between them (`glab -R owner/repo api ...`) cannot hide the
# call.
# ask prefixes: moved out of settings `permissions.ask`, which is skipped when
# rtk rewrites the call and prompts even in auto mode when rtk does not. Merge
# prefixes ask in every mode: in auto mode the classifier blocks them as Merge
# Without Review with no ask fallback, while the user decides each merge in
# the conversation.
# `rm`: any other rm form asks so the call never falls through to the
# auto-mode classifier, whose block has no ask fallback. Safe rm segments
# mixed with other segments stay silent because `allow` covers the whole call
# and would wave through the others; the permissions list judges them per
# segment.
# ASCII only (PowerShell 5.1 stdout encoding). Unreadable input falls into the
# 'ask' branch: no output would mean "no decision" and reach the classifier.
# Re-run hooks/permission-extension.tests.ps1 after changing a pattern: its
# $cases are the specification of what each pattern must match.
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
$stripped = @($parts | ForEach-Object { $_ -creplace '^(rtk (proxy )?|[A-Za-z_][A-Za-z0-9_]*=\S*\s+)*', '' -creplace '^(?![''"])\S*[/\\]', '' })
$epFlag = (2..15 | ForEach-Object { 'executionpolicy'.Substring(0, $_) }) -join '|'
$stopFlag = (@(1..4 | ForEach-Object { 'file'.Substring(0, $_) }) + @(1..7 | ForEach-Object { 'command'.Substring(0, $_) })) -join '|'
$bypass = '(?i)^(powershell|pwsh)(\.exe)?(\s+(?![-/](' + $stopFlag + ')(\s|:|\z))\S+)*?\s+[-/](' + $epFlag + '|ep)(\s+|:)[''"]?bypass([''"]|\s|\z)'
if (@($stripped | Where-Object { $_ -match $bypass }).Count) {
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"-ExecutionPolicy Bypass is not needed here. Drop it and run again. If the execution policy blocks the script, ask the user to run Set-ExecutionPolicy RemoteSigned -Scope CurrentUser as in the SETUP.md troubleshooting entry for npm failing with a security error (linked from Step 4)."}}'
  exit 0
}
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
