#!/usr/bin/env bash
# PostToolUse hook: add a UTF-8 BOM to PowerShell files (.ps1/.psm1/.psd1)
# after Write/Edit.
#
# Windows PowerShell 5.1 reads BOM-less scripts as cp932: Japanese literals
# break, and with LF endings a line ending in a full-width char swallows the
# newline (the next line silently becomes part of a comment).
# Write drops an existing BOM unless the content starts with U+FEFF; Edit keeps it.
# Files starting with "#!" are skipped (a BOM breaks the shebang under pwsh on Linux).
# Files with a BOM (UTF-8 / UTF-16 LE / BE) pass through (Edit writes UTF-16LE back as is; prefixing gives EF BB BF FF FE, which PS 5.1 cannot run).
# BOM-less UTF-16LE (Write dropped the BOM) is not prefixed but reported via exit 2.
# Never fails the tool call.

input=$(cat)
[[ $input =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] || exit 0
file=${BASH_REMATCH[1]//\\\\/\\}

[[ ${file,,} =~ \.ps[dm]?1$ ]] || exit 0
[ -f "$file" ] || exit 0

head=$(head -c 3 "$file" | od -An -tx1 | tr -d ' \n')
[[ $head == efbbbf || $head == 2321* || $head == fffe* || $head == feff* ]] && exit 0
if [[ $head == ??00* ]]; then
  echo "ps1-utf8-bom: $file is UTF-16 without a BOM; PS 5.1 cannot run it. Rewrite it as UTF-8." >&2
  exit 2
fi

tmp=$(mktemp) || exit 0
{ printf '\357\273\277'; cat "$file"; } > "$tmp" || { rm -f "$tmp"; exit 0; }
if ! cat "$tmp" > "$file"; then
  echo "ps1-utf8-bom: failed to rewrite $file; BOM + original content kept in $tmp" >&2
  exit 2
fi
rm -f "$tmp"
exit 0
