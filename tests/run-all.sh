#!/bin/bash
# Suite complète : lance chaque fichier *.test.sh du dossier, l'un après l'autre. Une ligne par fichier vert,
# la sortie entière d'un fichier rouge. Sort en échec si un fichier est rouge.
# Usage : bash tests/run-all.sh

FOLDER="$(cd "$(dirname "$0")" && pwd)"
failed_files=0
for test_file in "$FOLDER"/*.test.sh; do
  if output=$(bash "$test_file" 2>&1); then
    echo "ok   $(basename "$test_file") — ${output##*$'\n'}"
  else
    failed_files=$((failed_files + 1))
    printf '%s\nFAIL %s\n' "$output" "$(basename "$test_file")"
  fi
done
[ "$failed_files" -eq 0 ]
