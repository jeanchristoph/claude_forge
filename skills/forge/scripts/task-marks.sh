#!/bin/bash
# Marques de tâche et points d'étape du journal de mesure, communs à time-mark.sh, plan-hook.sh et engrave.sh, chargés
# avec `source` après json.sh. Chaque fonction rend sa valeur dans REPLY ; seule append_checkpoint écrit, dans le journal.

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

# Dossier principal du dépôt de <dossier> dans REPLY, worktree compris ; rend 1 hors dépôt git.
main_worktree() {
  local listing
  REPLY=""
  listing=$(git -C "$1" worktree list --porcelain 2>/dev/null) || return 1
  listing=${listing%%$'\n'*}
  REPLY=${listing#worktree }
  [ -n "$REPLY" ]
}

# Chemin de <cible> relatif à <départ> dans REPLY, tous deux absolus ; nom du dossier seul entre deux lecteurs Windows.
relative_path() {
  local from=${1%/} to=${2%/} up=""
  [ "$from" = "$to" ] && { REPLY="."; return; }
  while [ -n "$from" ] && [[ "$to/" != "$from/"* ]]; do
    [ "$from" = "${from%/*}" ] && { REPLY=${to##*/}; return; }
    from=${from%/*}
    up+="../"
  done
  REPLY="$up${to#"$from"/}"
}

# Projet lié auquel appartient <dossier>, vu du dépôt parent <racine> : chemin relatif dans REPLY ; vide quand les deux
# sont le même dépôt (branche fille) ou hors dépôt git. Seul identifiant d'un projet lié dans le journal de mesure.
linked_project() {
  local top main parent_main
  main_worktree "$1" || return 0
  main=$REPLY
  main_worktree "$2" || return 0
  parent_main=$REPLY
  REPLY=""
  { [ "$main" = "$parent_main" ] || [ "$main" -ef "$parent_main" ]; } && return 0
  top=$(git -C "$2" rev-parse --show-toplevel 2>/dev/null) || return 0
  relative_path "$top" "$main"
}

# Ligne de marque de tâche : {"ts","event","task"[,"branch"][,"project"][,"files"]}.
# Usage : task_mark_line <ts> <task_start|task_done> <T<n>> <branche, vide → champ absent> <empreinte en chaîne JSON, vide → champ absent> [projet lié]
task_mark_line() {
  local line="{\"ts\":$1,\"event\":\"$2\",\"task\":\"$3\""
  if [ -n "$4" ]; then
    json_escape "$4"
    line+=",\"branch\":$REPLY"
  fi
  if [ -n "${6:-}" ]; then
    json_escape "$6"
    line+=",\"project\":$REPLY"
  fi
  [ -n "$5" ] && line+=",\"files\":$5"
  REPLY="$line}"
}

# Champs JSON « ,"branch":…[,"project":…] » dans REPLY, vides sans branche.
checkpoint_scope() {
  local scope=""
  if [ -n "$1" ]; then
    json_escape "$1"
    scope=",\"branch\":$REPLY"
  fi
  if [ -n "$2" ]; then
    json_escape "$2"
    scope+=",\"project\":$REPLY"
  fi
  REPLY=$scope
}

# Dernier point d'étape du journal : CHECKPOINT_TS, CHECKPOINT_DONE, CHECKPOINT_FILES (chaîne JSON, vide hors git) ;
# rend 1 sans point d'étape. Projet lié sans point d'étape à lui → celui de la branche sans projet (ancien journal).
# Usage : read_last_checkpoint <journal> <branche, vide → celle du journal> <projet lié, vide → même dépôt>
read_last_checkpoint() {
  local branch_key="" project_key="" line
  if [ -n "$2" ]; then
    json_escape "$2"
    branch_key="\"branch\":$REPLY"
  fi
  if [ -n "$3" ]; then
    json_escape "$3"
    project_key="\"project\":$REPLY"
  fi
  line=$(awk -v branch_key="$branch_key" -v project_key="$project_key" '
    !index($0, "\"event\":\"plan_checkpoint\"") { next }
    branch_key == "" { if (!index($0, "\"branch\":")) last = $0; next }
    !index($0, branch_key) { next }
    project_key != "" && index($0, project_key) { of_project = $0; next }
    !index($0, "\"project\":") { last = $0 }
    END { print (of_project != "") ? of_project : last }' "$1")
  [[ $line =~ \"ts\":([0-9]+) ]] || return 1
  CHECKPOINT_TS=${BASH_REMATCH[1]}
  CHECKPOINT_DONE=""
  [[ $line =~ \"done\":\"([^\"]*)\" ]] && CHECKPOINT_DONE=${BASH_REMATCH[1]}
  CHECKPOINT_FILES=""
  [[ $line =~ \"files\":(\"([^\"\\]|\\.)*\") ]] && CHECKPOINT_FILES=${BASH_REMATCH[1]}
  return 0
}

# Usage : append_checkpoint <journal> <ts> <tâches cochées> <empreinte en chaîne JSON, vide → absente> <branche> <projet lié>
append_checkpoint() {
  local files=""
  [ -n "$4" ] && files=",\"files\":$4"
  checkpoint_scope "$5" "$6"
  printf '%s\n' "{\"ts\":$2,\"event\":\"plan_checkpoint\"$REPLY,\"done\":\"$3\"$files}" >> "$1"
}
