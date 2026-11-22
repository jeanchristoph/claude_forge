#!/bin/bash
# Marques de tâche du journal de mesure, communes à time-mark.sh et plan-hook.sh, chargées avec `source`
# après json.sh. Aucune écriture : chaque fonction rend sa valeur dans REPLY.

# Millisecondes depuis l'epoch, sans sous-processus ; le séparateur décimal suit la locale.
# Rend 1 sans EPOCHREALTIME (bash < 5) : aucune heure fiable, rien ne s'écrit.
current_time_ms() {
  local microseconds=${EPOCHREALTIME/[.,]/}
  [ ${#microseconds} -gt 3 ] || return 1
  REPLY=${microseconds:0:${#microseconds}-3}
}

# Empreinte du dossier <root>, une ligne « chemin<TAB>hash » par fichier modifié, nouveau ou supprimé (hash « - »),
# hors .forge ; rend 1 hors dépôt git. Lecture seule : rien d'écrit dans le dépôt ni l'index.
# Hash limité à 12 caractères : il ne sert qu'à voir qu'un contenu a changé.
snapshot_files() {
  local root=$1 entry path lines="" index=0 paths=() hashes=()
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  while IFS= read -r -d '' entry; do
    path=${entry:3}
    if [[ ${entry:0:2} == *D* ]]; then lines+="$path"$'\t'"-"$'\n'; else paths+=("$path"); fi
  done < <(git -C "$root" status --porcelain -z --no-renames --untracked-files=all -- . ':(exclude).forge')
  if [ ${#paths[@]} -gt 0 ]; then
    mapfile -t hashes < <(cd "$root" && printf '%s\n' "${paths[@]}" | git hash-object --stdin-paths)
    for path in "${paths[@]}"; do
      lines+="$path"$'\t'"${hashes[index]:0:12}"$'\n'
      index=$((index + 1))
    done
  fi
  REPLY=${lines%$'\n'}
}

# Ligne de marque de tâche : {"ts","event","task"[,"branch"][,"files"]}.
# Usage : task_mark_line <ts> <task_start|task_done> <T<n>> <branche, vide → champ absent> <empreinte en chaîne JSON, vide → champ absent>
task_mark_line() {
  local line="{\"ts\":$1,\"event\":\"$2\",\"task\":\"$3\""
  if [ -n "$4" ]; then
    json_escape "$4"
    line+=",\"branch\":$REPLY"
  fi
  [ -n "$5" ] && line+=",\"files\":$5"
  REPLY="$line}"
}
