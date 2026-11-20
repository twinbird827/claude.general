# Self-check for permission-extension.ps1; run: powershell.exe -NoProfile -File hooks/permission-extension.tests.ps1
$ErrorActionPreference = 'Stop'
$hook = Join-Path $PSScriptRoot 'permission-extension.ps1'
# No `mode` runs as `default` and `mode = ''` omits permission_mode; `want = ''` is no output (the permissions list decides).
$cases = @(
  @{ cmd = 'rm .tmp/probe'; want = 'allow' },
  @{ cmd = 'rm -rf .tmp/plans'; want = 'allow' },
  @{ cmd = 'rm .tmp/a.md .tmp/b.md'; want = 'allow' },
  @{ cmd = 'cd /c/Users/horie/.claude && rm .tmp/probe.md'; want = '' },
  @{ cmd = 'rm .tmp/../secret'; want = 'ask' },
  @{ cmd = 'rm -i .tmp/a.md'; want = 'ask' },
  @{ cmd = 'rm .tmp/a.md > /dev/null'; want = 'ask' },
  @{ cmd = 'git rm --cached x'; want = 'ask' },
  @{ cmd = 'glab api projects/:fullpath/merge_requests --method POST --raw-field title="t" --field description=@.tmp/b.md'; mode = 'auto'; want = '' },
  @{ cmd = 'glab api projects/:fullpath/merge_requests/1 --method PUT --field description=@.tmp/b.md > /dev/null'; mode = 'auto'; want = '' },
  @{ cmd = 'git push -u origin HEAD && glab api projects/:fullpath/merge_requests --method POST --raw-field title="t" --field description=@.tmp/b.md | jq -r ''.iid, .web_url'''; mode = 'auto'; want = '' },
  @{ cmd = 'glab api projects/:fullpath/issues --method POST --raw-field title="t" --field description=@.tmp/b.md | jq -r ''.iid, .web_url'''; mode = 'auto'; want = '' },
  @{ cmd = 'glab api projects/:fullpath/issues/1/notes --method POST --field body=@.tmp/b.md > /dev/null'; mode = 'auto'; want = '' },
  @{ cmd = 'glab api projects/:fullpath/x --method DELETE'; mode = 'auto'; want = 'ask' },
  @{ cmd = 'glab api projects/:fullpath/x -XDELETE'; mode = 'auto'; want = 'ask' },
  @{ cmd = 'glab api projects/:fullpath/x --method=delete'; mode = 'auto'; want = 'ask' },
  @{ cmd = 'rtk proxy glab api projects/:fullpath/x --method DELETE'; mode = 'auto'; want = 'ask' },
  @{ cmd = 'glab api projects/:fullpath/x'; mode = 'auto'; want = 'ask' },
  @{ cmd = 'glab api projects/:fullpath/x --raw-field note="a|b" --method DELETE'; mode = 'auto'; want = 'ask' },
  @{ cmd = 'glab api projects/:fullpath/x --method post'; mode = 'auto'; want = 'ask' },
  @{ cmd = "glab api projects/x --method POST --field description=@.tmp/a.md`nglab api projects/x/y --method DELETE"; mode = 'auto'; want = 'ask' },
  @{ cmd = 'glab api projects/x --method POST -f a=1 & glab api projects/x/y --method DELETE'; mode = 'auto'; want = 'ask' },
  @{ cmd = 'glab api projects/x/y --method DELETE --raw-field body="see --method POST"'; mode = 'auto'; want = 'ask' },
  @{ cmd = "rm .tmp/a.md`nrm .tmp/b.md"; want = 'allow' },
  @{ cmd = 'rm .tmp/a.md & git status'; want = '' },
  @{ cmd = '|||'; want = '' },
  @{ cmd = 'glab -R owner/repo api projects/x --method DELETE'; mode = 'auto'; want = 'ask' },
  @{ cmd = 'glab mr view 1'; want = '' },
  @{ cmd = 'glab api projects/x -F note="x --method POST|y" --method DELETE'; mode = 'auto'; want = '' },
  @{ cmd = 'glab -R "a&b" api projects/x --method DELETE'; mode = 'auto'; want = '' },
  @{ cmd = 'git push -u origin HEAD'; want = 'ask' },
  @{ cmd = 'git push -u origin HEAD'; mode = 'auto'; want = '' },
  @{ cmd = 'cd /c/x && git stash list'; want = 'ask' },
  @{ cmd = 'rtk proxy git push'; want = 'ask' },
  @{ cmd = 'git status'; want = '' },
  @{ cmd = 'git pushx'; want = '' },
  @{ cmd = 'git push'; mode = ''; want = 'ask' },
  @{ cmd = 'glab api projects/x --method POST'; want = 'ask' },
  @{ cmd = 'glab mr merge 1 -d -y --auto-merge=false'; mode = 'auto'; want = 'ask' },
  @{ cmd = 'rtk glab mr merge 1 -d -y --auto-merge=false'; mode = 'auto'; want = 'ask' },
  @{ cmd = 'gh pr merge 1 --merge --delete-branch'; mode = 'auto'; want = 'ask' },
  @{ cmd = 'glab mr merge 1'; want = 'ask' },
  @{ cmd = 'glab mr view 1 && glab mr merge 1'; mode = 'auto'; want = 'ask' },
  @{ cmd = 'glab mr mergex'; mode = 'auto'; want = '' },
  @{ cmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File x.ps1'; want = 'deny' },
  @{ cmd = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File x.ps1'; mode = 'auto'; want = 'deny' },
  @{ cmd = 'powershell -ep bypass -c x'; want = 'deny' },
  @{ cmd = 'pwsh -ExecutionPolicy:Bypass -File x.ps1'; want = 'deny' },
  @{ cmd = 'rtk proxy powershell.exe -ExecutionPolicy Bypass -File x.ps1'; want = 'deny' },
  @{ cmd = 'powershell.exe -NoProfile -File x.ps1'; want = '' },
  @{ cmd = 'powershell.exe -ExecutionPolicy RemoteSigned -File x.ps1'; want = '' },
  @{ cmd = 'git commit -m "drop -ExecutionPolicy Bypass"'; mode = 'auto'; want = '' },
  @{ cmd = 'MSYS_NO_PATHCONV=1 powershell.exe -ExecutionPolicy Bypass -File x.ps1'; want = 'deny' },
  @{ cmd = 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -ExecutionPolicy Bypass -File x.ps1'; want = 'deny' },
  @{ cmd = 'MSYS_NO_PATHCONV=1 powershell.exe /ExecutionPolicy Bypass -File x.ps1'; want = 'deny' },
  @{ cmd = 'powershell.exe -NoProfile -EncodedCommand ZQBjAGgAbwA= -ExecutionPolicy Bypass'; want = 'deny' },
  @{ cmd = 'powershell.exe -NoProfile -Command "Get-ChildItem -Exclude bypass"'; want = '' },
  @{ cmd = 'powershell.exe -NoProfile -File x.ps1 -ex bypass'; want = '' },
  @{ cmd = 'powershell.exe -NoProfile Get-ChildItem -Exclude bypass'; want = '' },
  @{ cmd = 'FOO=1 git push'; want = 'ask' },
  @{ cmd = '/usr/bin/git push'; want = 'ask' },
  @{ cmd = 'rtk proxy FOO=1 git push'; want = 'ask' },
  @{ cmd = 'FOO=1 rtk proxy git push'; want = 'ask' },
  @{ cmd = 'MSYS_NO_PATHCONV=1 rtk proxy powershell.exe -ExecutionPolicy Bypass -File x.ps1'; want = 'deny' }
)
function Decision($stdin) {
  $out = $stdin | powershell.exe -NoProfile -ExecutionPolicy Bypass -File $hook
  if ($LASTEXITCODE -ne 0) { throw "hook exited $LASTEXITCODE" }
  if (-not $out) { return '' }
  return ($out | ConvertFrom-Json).hookSpecificOutput.permissionDecision
}
$fail = 0
foreach ($c in $cases) {
  $in = @{ tool_input = @{ command = $c.cmd } }
  $mode = if ($c.ContainsKey('mode')) { $c.mode } else { 'default' }
  if ($mode) { $in.permission_mode = $mode }
  $got = Decision ($in | ConvertTo-Json -Compress)
  if ($got -ne $c.want) { Write-Host "FAIL: [$mode] $($c.cmd) -> '$got' (want '$($c.want)')"; $fail++ }
}
$got = Decision 'not json'
if ($got -ne 'ask') { Write-Host "FAIL: unreadable input -> '$got' (want 'ask')"; $fail++ }
if ($fail) { Write-Host "$fail case(s) failed"; exit 1 }
Write-Host "all $($cases.Count + 1) cases passed"
