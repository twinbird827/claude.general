# Self-check for permission-extension.ps1: feed each command through the hook
# and compare the permissionDecision ('' = no output = the permissions list
# decides). Run after changing any pattern in the hook:
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File hooks/permission-extension.tests.ps1
$ErrorActionPreference = 'Stop'
$hook = Join-Path $PSScriptRoot 'permission-extension.ps1'
$cases = @(
  @{ cmd = 'rm .tmp/keep-turn'; want = 'allow' },
  @{ cmd = 'rm -rf .tmp/plans'; want = 'allow' },
  @{ cmd = 'rm .tmp/a.md .tmp/b.md'; want = 'allow' },
  @{ cmd = 'cd /c/Users/horie/.claude && rm .tmp/keep-turn'; want = '' },
  @{ cmd = 'rm .tmp/../secret'; want = 'ask' },
  @{ cmd = 'rm -i .tmp/a.md'; want = 'ask' },
  @{ cmd = 'rm .tmp/a.md > /dev/null'; want = 'ask' },
  @{ cmd = 'git rm --cached x'; want = 'ask' },
  @{ cmd = 'glab api projects/:fullpath/merge_requests --method POST --raw-field title="t" --field description=@.tmp/b.md'; want = '' },
  @{ cmd = 'glab api projects/:fullpath/merge_requests/1 --method PUT --field description=@.tmp/b.md > /dev/null'; want = '' },
  @{ cmd = 'git push -u origin HEAD && glab api projects/:fullpath/merge_requests --method POST --raw-field title="t" --field description=@.tmp/b.md | jq -r ''.iid, .web_url'''; want = '' },
  @{ cmd = 'glab api projects/:fullpath/issues --method POST --raw-field title="t" --field description=@.tmp/b.md | jq -r ''.iid, .web_url'''; want = '' },
  @{ cmd = 'glab api projects/:fullpath/issues/1/notes --method POST --field body=@.tmp/b.md > /dev/null'; want = '' },
  @{ cmd = 'glab api projects/:fullpath/x --method DELETE'; want = 'ask' },
  @{ cmd = 'glab api projects/:fullpath/x -XDELETE'; want = 'ask' },
  @{ cmd = 'glab api projects/:fullpath/x --method=delete'; want = 'ask' },
  @{ cmd = 'rtk proxy glab api projects/:fullpath/x --method DELETE'; want = 'ask' },
  @{ cmd = 'glab api projects/:fullpath/x'; want = 'ask' },
  @{ cmd = 'glab api projects/:fullpath/x --raw-field note="a|b" --method DELETE'; want = 'ask' },
  @{ cmd = 'glab api projects/:fullpath/x --method post'; want = 'ask' },
  @{ cmd = "glab api projects/x --method POST --field description=@.tmp/a.md`nglab api projects/x/y --method DELETE"; want = 'ask' },
  @{ cmd = 'glab api projects/x --method POST -f a=1 & glab api projects/x/y --method DELETE'; want = 'ask' },
  @{ cmd = 'glab api projects/x/y --method DELETE --raw-field body="see --method POST"'; want = 'ask' },
  @{ cmd = "rm .tmp/a.md`nrm .tmp/b.md"; want = 'allow' },
  @{ cmd = 'rm .tmp/a.md & git status'; want = '' },
  @{ cmd = '|||'; want = '' },
  @{ cmd = 'glab -R owner/repo api projects/x --method DELETE'; want = 'ask' },
  @{ cmd = 'glab mr view 1'; want = '' },
  @{ cmd = 'glab api projects/x -F note="x --method POST|y" --method DELETE'; want = '' },
  @{ cmd = 'glab -R "a&b" api projects/x --method DELETE'; want = '' }
)
function Decision($stdin) {
  $out = $stdin | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook
  if ($LASTEXITCODE -ne 0) { throw "hook exited $LASTEXITCODE" }
  if (-not $out) { return '' }
  return ($out | ConvertFrom-Json).hookSpecificOutput.permissionDecision
}
$fail = 0
foreach ($c in $cases) {
  $got = Decision (@{ tool_input = @{ command = $c.cmd } } | ConvertTo-Json -Compress)
  if ($got -ne $c.want) { Write-Host "FAIL: $($c.cmd) -> '$got' (want '$($c.want)')"; $fail++ }
}
$got = Decision 'not json'
if ($got -ne 'ask') { Write-Host "FAIL: unreadable input -> '$got' (want 'ask')"; $fail++ }
if ($fail) { Write-Host "$fail case(s) failed"; exit 1 }
Write-Host "all $($cases.Count + 1) cases passed"
