#!/usr/bin/env bash
# PostToolUse hook: convert LF line endings to CRLF for text files
# after Write/Edit/MultiEdit/NotebookEdit.

set -e

input=$(cat)
file=$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null || true)

[ -z "$file" ] && exit 0
[ -f "$file" ] || exit 0

# Target text extensions (case-insensitive)
shopt -s nocasematch
case "$file" in
  *.md|*.markdown|*.txt|*.json|*.jsonc|*.json5|*.xml|*.yml|*.yaml|*.toml|*.ini|*.cfg|*.conf|*.env|*.properties|\
  *.cs|*.csproj|*.sln|*.vb|*.vbproj|*.fs|*.fsproj|*.razor|*.cshtml|*.xaml|\
  *.js|*.mjs|*.cjs|*.ts|*.tsx|*.jsx|*.vue|*.svelte|\
  *.py|*.rb|*.php|*.go|*.rs|*.java|*.kt|*.kts|*.scala|*.swift|*.lua|*.pl|*.r|\
  *.c|*.h|*.cc|*.cpp|*.hpp|*.hh|*.cxx|*.m|*.mm|\
  *.sh|*.bash|*.zsh|*.fish|*.ps1|*.psm1|*.psd1|*.bat|*.cmd|\
  *.html|*.htm|*.css|*.scss|*.sass|*.less|*.styl|\
  *.sql|*.graphql|*.gql|*.proto|\
  *.csv|*.tsv|*.log|*.diff|*.patch|*.svg|\
  *.ipynb|\
  *.gitignore|*.gitattributes|*.editorconfig|*.dockerignore|\
  *Dockerfile|*Makefile|*CMakeLists.txt) ;;
  *) exit 0 ;;
esac
shopt -u nocasematch

# Normalize to CRLF: strip any trailing \r, then append \r on every line.
# Uses a tmp file to avoid partial writes.
tmp="${file}.crlf.tmp"
sed -e 's/\r$//' -e 's/$/\r/' "$file" > "$tmp" && mv -f "$tmp" "$file"

exit 0
