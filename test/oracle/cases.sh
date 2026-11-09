#!/bin/sh
# Parses each line of test/oracle/cases.txt with both `nix-instantiate --parse`
# and flocaml, and prints the lines on which they disagree.
#
# Usage: test/oracle/cases.sh
#
# The cases are mostly expressions that Nix rejects after parsing, which
# files in nixpkgs never contain. Prints "differ: EXPR" when both accept the
# expression with different results, and "rejected: EXPR" when only one side
# accepts it. Exits with 1 if any line was printed.
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
dune build --root "$root" ./test/oracle/main.exe 2>/dev/null
show=$root/_build/default/test/oracle/main.exe
file=$(mktemp "${TMPDIR:-/tmp}/case.XXXXXX")
trap 'rm -f "$file"' EXIT

while IFS= read -r expr; do
  printf '%s\n' "$expr" >"$file"
  # Experimental features such as fetch-tree add builtins.
  expected=$(nix-instantiate --option experimental-features '' \
    --parse "$file" 2>/dev/null) && ok=1 || ok=0
  actual=$("$show" "$file")
  case $actual in error:*) mine=0 ;; *) mine=1 ;; esac
  if [ "$ok" = 1 ] && [ "$mine" = 1 ]; then
    [ "$expected" = "$actual" ] || echo "differ: $expr"
  elif [ "$ok" != "$mine" ]; then
    echo "rejected: $expr"
  fi
done <"$root/test/oracle/cases.txt" |
  awk '{ print } END { exit NR > 0 }'
