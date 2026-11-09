#!/bin/sh
# Parses every .nix file under DIR with both `nix-instantiate --parse` and
# flocaml, and prints the files on which they disagree.
#
# Usage: test/oracle/compare.sh DIR
#
# Runs JOBS processes at a time (2 by default) at low priority, as nixpkgs
# has tens of thousands of files.
#
# Prints "differ: FILE" when both parse the file with different results, and
# "rejected: FILE" when only one side accepts it. Exits with 1 if any line
# was printed.
set -eu

dir=${1:?usage: compare.sh DIR}
root=$(cd "$(dirname "$0")/../.." && pwd)
dune build --root "$root" ./test/oracle/main.exe 2>/dev/null
show=$root/_build/default/test/oracle/main.exe
jobs=${JOBS:-2}

find "$dir" -name '*.nix' -type f -print0 |
  nice -n 19 xargs -0 -n 100 -P "$jobs" sh -c '
    show=$1
    shift
    for f do
      expected=$(nix-instantiate --parse "$f" 2>/dev/null) && ok=1 || ok=0
      actual=$("$show" "$f")
      case $actual in error:*) mine=0 ;; *) mine=1 ;; esac
      if [ "$ok" = 1 ] && [ "$mine" = 1 ]; then
        [ "$expected" = "$actual" ] || echo "differ: $f"
      elif [ "$ok" != "$mine" ]; then
        echo "rejected: $f"
      fi
    done
  ' sh "$show" |
  sort |
  awk '{ print } END { exit NR > 0 }'
