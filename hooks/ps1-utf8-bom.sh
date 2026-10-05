#!/usr/bin/env bash
# PostToolUse hook: add a UTF-8 BOM to PowerShell files (.ps1/.psm1/.psd1)
# after Write/Edit.
#
# Windows PowerShell 5.1 reads BOM-less scripts as cp932: Japanese literals
# break, and with LF endings a line ending in a full-width char swallows the
# newline (the next line silently becomes part of a comment).
# Write drops an existing BOM unless the content starts with U+FEFF; Edit keeps it.
# Files starting with "#!" are skipped (a BOM breaks the shebang under pwsh on Linux).
# Never fails the tool call.

input=$(cat)
[[ $input =~ \"file_path\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] || exit 0
file=${BASH_REMATCH[1]//\\\\/\\}

shopt -s nocasematch
[[ $file == *.ps1 || $file == *.psm1 || $file == *.psd1 ]] || exit 0
shopt -u nocasematch
[ -f "$file" ] || exit 0

head=$(head -c 3 "$file" | od -An -tx1 | tr -d ' \n')
[[ $head == efbbbf || $head == 2321* ]] && exit 0

tmp=$(mktemp) || exit 0
{ printf '\357\273\277'; cat "$file"; } > "$tmp" && cat "$tmp" > "$file"
rm -f "$tmp"
exit 0
