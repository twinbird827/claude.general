#!/usr/bin/env bash
# Self-check for ps1-utf8-bom.sh. Exits non-zero if any case fails.
# Usage: bash hooks/ps1-utf8-bom.tests.sh

hook=$(dirname "$0")/ps1-utf8-bom.sh
dir=$(cd "$(dirname "$0")/.." && pwd)/.tmp/ps1-utf8-bom-tests
rm -rf "$dir"; mkdir -p "$dir"
trap 'chmod -R u+w "$dir"; rm -rf "$dir"' EXIT
fail=0

hex() { od -An -tx1 "$1" | tr -d ' \n'; }

# Feed the hook a PostToolUse payload with the Windows path; sets rc and err.
run() {
  local w; w=$(cygpath -w "$1"); w=${w//\\/\\\\}
  err=$(printf '{"tool_input":{"file_path":"%s"}}' "$w" | bash "$hook" 2>&1 >/dev/null); rc=$?
}

# report <name> <status of the preceding test> <detail on failure>
report() { if [ "$2" -eq 0 ]; then echo "ok   $1"; else echo "FAIL $1: ${3}"; fail=1; fi; }

# t <name> <content (printf format)> <expected hex> [expected rc]
t() {
  local f=$dir/$1
  printf "$2" > "$f"
  run "$f"
  local got; got=$(hex "$f")
  [[ $got == "$3" && $rc == "${4:-0}" ]]; report "$1" $? "got $got rc=$rc"
}

t plain.ps1    'ab'                 efbbbf6162
t bom.ps1      '\xef\xbb\xbfab'     efbbbf6162
t shebang.ps1  '#!x'                232178
t u16le.ps1    '\xff\xfeW\x00'      fffe5700
t u16be.ps1    '\xfe\xff\x00W'      feff0057
t u16nobom.ps1 'W\x00r\x00'         57007200 2
t upper.PS1    'ab'                 efbbbf6162
t data.psd1    'ab'                 efbbbf6162
t x.ps11       'ab'                 6162
t x.txt        'ab'                 6162
t crlf.ps1     'a\r\nb\r\n'         efbbbf610d0a620d0a
t empty.ps1    ''                   efbbbf

# Write-back failure: file untouched, exit 2, temp file named on stderr keeps BOM + original.
f=$dir/readonly.ps1
printf 'ab' > "$f"; chmod 444 "$f"
run "$f"
got=$(hex "$f")
tmp=$([[ $err =~ kept\ in\ (.*)$ ]] && echo "${BASH_REMATCH[1]}")
kept=$([ -f "$tmp" ] && hex "$tmp")
[[ $got == 6162 && $rc == 2 && $kept == efbbbf6162 ]]; report readonly.ps1 $? "got $got rc=$rc kept=$kept err=$err"
[ -f "$tmp" ] && rm -f "$tmp"

exit $fail
