#!/usr/bin/env bash
# Daily plugin updater: refresh every marketplace, then update every installed
# plugin. Plugin list is discovered dynamically from `claude plugin list`, so a
# newly added plugin is picked up with no edit here.
# Invoked by the Task Scheduler task "claude-plugin-update".
# ponytail: no set -e / no pipefail on purpose — one plugin failing must not
# abort the rest. An empty plugin list means no update ran at all, so it is a failure.

fail=0
claude plugin marketplace update || fail=1

# ponytail: list into a variable, not a pipe — `| while` runs in a subshell and
# the failure flag set inside it would be lost.
plugins=$(claude plugin list | grep -oE '[[:alnum:]._-]+@[[:alnum:]._-]+')
[ -n "$plugins" ] || fail=1

for p in $plugins; do
  claude plugin update "$p" || { echo "update failed: $p"; fail=1; }
done

exit $fail
