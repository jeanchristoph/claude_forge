#!/bin/bash
# État de l'essaim d'une branche parente : branches filles en cours, lançables, en attente, et tâches ordinaires
# que le parent peut prendre. Lu par « Délégation — essaim de branches filles » (commands/swarm.md) et la reprise.
#   Lecture seule : aucune écriture, aucune commande git modifiant le dépôt (merge-tree simule en mémoire)
#   Rend compte en JSON sur une ligne — la mise en page revient au skill
#   Tâche-branche : titre « ### Tn — Branch <x> » ; dépendances : ligne « **Depends on:** <x>, T3 » ou « none »,
#   une dépendance désignant une branche ou un numéro de tâche
#   Unité d'essaim : branche fille (type child) ou branche liée (type linked) — tâches ouvertes au même champ
#   « **Linked branch:** <dossier relatif à ROOT> @ <branche> », réunies en une unité, jamais prises par le parent ;
#   en cours quand une de ses tâches porte la note « delegated to … ». Projet lié non forgé (.forge/project.md absent
#   de master / main) → une seule de ses unités à la fois, les autres attendent celle-là
#   N : ligne « **N:** <n> » de swarm.md, 3 à défaut
#   now : heure locale « AAAA-MM-JJ HH:MM », seule source de la colonne Since et des dates de swarm.md
#   Statut d'une tâche : sa première ligne « [ ] / [x] / [!] / [-] », jamais une note qui suit
#   invalid : tâche ouverte jamais lançable telle quelle — dépendance inconnue (texte libre compris), bloquée,
#   abandonnée, cycle de dépendances, nom de branche refusé par git ; absente des autres listes
#   blocked : tâches-branches [!] · stale : worktree supprimé à la main (git worktree prune le retire)
#   conflict : true conflit simulé, null simulation impossible
# Usage : swarm-status.sh [--root <dir>] [--branch <parent>] [--plan <fichier>] [--assume-done <Tn|branche>[,…]]
#   --plan : plan rédigé lu à la place de .forge/branch/<parent>/plan.md — plan pas encore écrit (phases/p4-plan.md)
#   --assume-done : tâches comptées faites, pour calculer la suite d'une fusion avant de la faire
# Sortie : 0 JSON écrit · 1 usage, sans JSON

set -u

source "$(dirname "${BASH_SOURCE[0]}")/json.sh"

readonly EXIT_USAGE=1
readonly DEFAULT_SWARM_SIZE=3

# Séparateur de champs non blanc : read garde les champs vides, qu'une tabulation ferait fusionner.
readonly FIELD_SEPARATOR=$'\x1f'

# Une ligne par tâche, champs séparés par \x1f : numéro, statut, branche ou vide, dépendances séparées par des virgules,
# branche liée « <dossier> @ <branche> » ou vide, 1 si déléguée sinon 0, titre.
readonly PLAN_PROGRAM='
  function flush() {
    if (task != "") printf "%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n", task, status, branch, depends, linked, delegated, title
    task = ""
  }
  { sub(/\r$/, "") }
  /^### T[0-9]+/ {
    flush()
    task = $2; title = $0; sub(/^### T[0-9]+ [^ ]+ /, "", title)
    status = "open"; depends = ""; branch = ""; linked = ""; delegated = 0; status_read = 0
    if (title ~ /^Branch /) { branch = title; sub(/^Branch /, "", branch); gsub(/`/, "", branch); sub(/ .*/, "", branch) }
    next
  }
  /^## / { flush(); next }
  task != "" && /^\*\*Depends on:\*\*/ {
    depends = $0; sub(/^\*\*Depends on:\*\* */, "", depends); gsub(/`/, "", depends); gsub(/ /, "", depends)
    if (depends == "none") depends = ""
  }
  task != "" && /^\*\*Linked branch:\*\*/ {
    linked = $0; sub(/^\*\*Linked branch:\*\* */, "", linked); gsub(/`/, "", linked); sub(/ +$/, "", linked)
  }
  task != "" && !/^\*\*/ && /delegated to / { delegated = 1 }
  task != "" && !status_read && /^\[[ x!-]\]/ && !/^\[.\] T[0-9]+\.[0-9]+/ {
    mark = substr($0, 2, 1); status_read = 1
    status = (mark == "x") ? "done" : (mark == "!") ? "blocked" : (mark == "-") ? "dropped" : "open"
  }
  END { flush() }'

# Avancement d'un plan de branche fille : « faites totales ».
readonly PROGRESS_PROGRAM='
  { sub(/\r$/, "") }
  /^### T[0-9]+/ { total++; open_task = 1; next }
  /^## / { open_task = 0 }
  open_task && /^\[x\]/ { done++; open_task = 0 }
  END { printf "%d %d", done, total }'

ROOT="."
PLAN_FILE=""
PARENT=""
SWARM_SIZE=$DEFAULT_SWARM_SIZE
ASSUME_DONE=""
declare -A DONE_KEYS=()
declare -A WORKTREES=()
declare -A PRUNABLE=()
declare -A TASK_STATUS=()
declare -A TASK_OF_BRANCH=()
declare -A TASK_DEPENDS=()
declare -A ASSUMED=()
declare -A UNIT_TASKS=()
declare -A UNIT_DEPENDS=()
declare -A UNIT_FIRST=()
declare -A UNIT_DELEGATED=()
declare -A FORGED=()
declare -A UNFORGED_HOLDER=()
TASK_LINES=()
RUNNING_JSON=""
LAUNCHABLE_JSON=""
WAITING_JSON=""
ORDINARY_JSON=""
INVALID_JSON=""
BLOCKED_JSON=""
STALE_JSON=""
RUNNING_COUNT=0
OPEN_BRANCH_COUNT=0
MAIN_WORKTREE=""

# ── Arguments et gardes ───────────────────────────────────────────────────────

fail_usage() {
  echo "swarm-status: $1" >&2
  echo "usage: swarm-status.sh [--root <dir>] [--branch <parent>] [--plan <file>] [--assume-done <Tn|branch>[,…]]" >&2
  exit $EXIT_USAGE
}

parse_arguments() {
  while [ $# -gt 0 ]; do
    case $1 in
      --root)   [ $# -ge 2 ] || fail_usage "$1 needs a value"; ROOT=$2; shift 2 ;;
      --branch) [ $# -ge 2 ] || fail_usage "$1 needs a value"; PARENT=$2; shift 2 ;;
      --plan)   [ $# -ge 2 ] || fail_usage "$1 needs a value"; PLAN_FILE=$2; shift 2 ;;
      --assume-done) [ $# -ge 2 ] || fail_usage "$1 needs a value"; ASSUME_DONE=$2; shift 2 ;;
      *)        fail_usage "unknown argument $1" ;;
    esac
  done
  [ -d "$ROOT" ] || fail_usage "not a directory: $ROOT"
  [ -n "$PARENT" ] || PARENT=$(git -C "$ROOT" branch --show-current 2>/dev/null)
  [ -n "$PARENT" ] || fail_usage "no current branch: pass --branch"
  [ -n "$PLAN_FILE" ] || PLAN_FILE="$ROOT/.forge/branch/$PARENT/plan.md"
  [ -f "$PLAN_FILE" ] || fail_usage "no plan for $PARENT"
  git -C "$ROOT" show-ref --verify --quiet "refs/heads/$PARENT" || fail_usage "no git branch $PARENT"
}

# ── Lecture ───────────────────────────────────────────────────────────────────

read_swarm_size() {
  local file="$ROOT/.forge/branch/$PARENT/swarm.md" line
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    [[ $line =~ ^\*\*N:\*\*\ *([0-9]+) ]] && { SWARM_SIZE=${BASH_REMATCH[1]}; return 0; }
  done < "$file"
}

load_tasks() {
  local line task task_status branch depends
  mapfile -t TASK_LINES < <(awk "$PLAN_PROGRAM" "$PLAN_FILE")
  for line in "${TASK_LINES[@]}"; do
    IFS=$FIELD_SEPARATOR read -r task task_status branch depends _ <<< "$line"
    TASK_STATUS[$task]=$task_status
    TASK_DEPENDS[$task]=$depends
    [ -n "$branch" ] && TASK_OF_BRANCH[$branch]=$task
  done
  for task in "${!TASK_STATUS[@]}"; do
    [ "${TASK_STATUS[$task]}" = "done" ] && mark_done "$task"
  done
  load_assumed_done
}

# Tâche faite : son numéro et sa branche lèvent les dépendances qui les citent.
mark_done() {
  local task=$1 branch
  DONE_KEYS[$task]=1
  for branch in "${!TASK_OF_BRANCH[@]}"; do
    [ "${TASK_OF_BRANCH[$branch]}" = "$task" ] && DONE_KEYS[$branch]=1
  done
}

load_assumed_done() {
  local key task
  local IFS=,
  for key in $ASSUME_DONE; do
    resolve_dependency "$key"; task=$REPLY
    [ -n "$task" ] || continue
    ASSUMED[$task]=1
    mark_done "$task"
  done
}

# Numéro de la tâche désignée par une dépendance (numéro ou branche) dans REPLY, vide si inconnue.
resolve_dependency() {
  REPLY=""
  if [[ $1 =~ ^T[0-9]+$ ]] && [ -n "${TASK_STATUS[$1]:-}" ]; then REPLY=$1; return; fi
  REPLY=${TASK_OF_BRANCH[$1]:-}
}

is_open() {
  [ "${TASK_STATUS[$1]:-}" = "open" ] && [ -z "${ASSUMED[$1]:-}" ]
}

# La tâche se retrouve-t-elle parmi ses propres dépendances ouvertes, de proche en proche ?
is_in_cycle() {
  local origin=$1 current dependency task queue=("$1")
  local -A visited=()
  while [ ${#queue[@]} -gt 0 ]; do
    current=${queue[0]}; queue=("${queue[@]:1}")
    local IFS=,
    for dependency in ${TASK_DEPENDS[$current]:-}; do
      resolve_dependency "$dependency"; task=$REPLY
      [ -n "$task" ] && is_open "$task" || continue
      [ "$task" = "$origin" ] && return 0
      [ -n "${visited[$task]:-}" ] && continue
      visited[$task]=1; queue+=("$task")
    done
  done
  return 1
}

# Première dépendance qui rend la tâche impossible, « dépendance raison » dans REPLY, vide sinon.
find_invalid_dependency() {
  local task=$1 dependency target
  local IFS=,
  for dependency in ${TASK_DEPENDS[$task]:-}; do
    resolve_dependency "$dependency"; target=$REPLY
    [ -n "$target" ] || { REPLY="$dependency unknown"; return; }
    case ${TASK_STATUS[$target]} in
      blocked) REPLY="$dependency blocked"; return ;;
      dropped) REPLY="$dependency dropped"; return ;;
    esac
  done
  if is_in_cycle "$task"; then REPLY="$task cycle"; else REPLY=""; fi
}

# Branche extraite → chemin de son worktree, le dépôt principal compris.
# Worktree supprimé à la main : marqué « prunable » par git, ou dossier absent.
load_worktrees() {
  local line path="" branch=""
  MAIN_WORKTREE=$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)
  while IFS= read -r line; do
    case $line in
      "worktree "*) path=${line#worktree }; branch="" ;;
      "branch refs/heads/"*)
        branch=${line#branch refs/heads/}; WORKTREES[$branch]=$path
        [ -d "$path" ] || PRUNABLE[$branch]=1 ;;
      "prunable"*) [ -n "$branch" ] && PRUNABLE[$branch]=1 ;;
    esac
  done < <(git -C "$ROOT" worktree list --porcelain 2>/dev/null)
}

# Dépendances non faites, séparées par des virgules, dans REPLY — sans doublon, hors des tâches de $2 (unité liée).
missing_dependencies() {
  local depends=$1 members=",${2:-},"  dependency missing=""
  local IFS=,
  for dependency in $depends; do
    [ -n "$dependency" ] && [ -z "${DONE_KEYS[$dependency]:-}" ] || continue
    [[ $members == *",$dependency,"* || ",$missing," == *",$dependency,"* ]] && continue
    missing+="${missing:+,}$dependency"
  done
  REPLY=$missing
}

# ── Branches liées ────────────────────────────────────────────────────────────

# Tâches ouvertes au même « **Linked branch:** » réunies en une unité, nommée par sa première tâche dans l'ordre du plan.
# Projet non forgé déjà tenu par une unité déléguée → UNFORGED_HOLDER, que les autres unités attendent.
load_linked_units() {
  local line task task_status branch depends linked delegated
  for line in "${TASK_LINES[@]}"; do
    IFS=$FIELD_SEPARATOR read -r task task_status branch depends linked delegated _ <<< "$line"
    [ -z "$branch" ] && [ -n "$linked" ] && is_open "$task" || continue
    [ -n "${UNIT_FIRST[$linked]:-}" ] || UNIT_FIRST[$linked]=$task
    UNIT_TASKS[$linked]+="${UNIT_TASKS[$linked]:+,}$task"
    [ -n "$depends" ] && UNIT_DEPENDS[$linked]+="${UNIT_DEPENDS[$linked]:+,}$depends"
    [ "$delegated" = "1" ] && UNIT_DELEGATED[$linked]=1
  done
  for linked in "${!UNIT_DELEGATED[@]}"; do
    linked_project_state "${linked% @ *}"
    [ "$REPLY" = "unforged" ] && UNFORGED_HOLDER[${linked% @ *}]=$linked
  done
}

# État du projet lié, dans REPLY : forged, unforged (.forge/project.md absent de master / main, à défaut de HEAD)
# ou missing (aucun dépôt git). Mis en cache par dossier.
linked_project_state() {
  local project=$1 directory="$ROOT/$1" default=HEAD candidate
  [ -z "${FORGED[$project]:-}" ] || { REPLY=${FORGED[$project]}; return; }
  REPLY=missing
  if git -C "$directory" rev-parse --git-dir >/dev/null 2>&1; then
    for candidate in master main; do
      git -C "$directory" show-ref --verify --quiet "refs/heads/$candidate" && { default=$candidate; break; }
    done
    REPLY=unforged
    git -C "$directory" cat-file -e "$default:.forge/project.md" 2>/dev/null && REPLY=forged
  fi
  FORGED[$project]=$REPLY
}

json_array_of_csv() {
  local csv=$1 item array=""
  local IFS=,
  for item in $csv; do
    json_escape "$item"
    array+="${array:+,}$REPLY"
  done
  REPLY="[$array]"
}

# ── Classement ────────────────────────────────────────────────────────────────

add_running() {
  local task=$1 branch=$2 worktree=$3 progress="0 0" plan="$3/.forge/branch/$2/plan.md"
  [ -f "$plan" ] && progress=$(awk "$PROGRESS_PROGRAM" "$plan")
  set -- "$task" "$branch" "$worktree" $progress
  json_escape "$2"; local branch_json=$REPLY
  json_escape "$3"; local worktree_json=$REPLY
  RUNNING_JSON+="${RUNNING_JSON:+,}{\"task\":\"$1\",\"type\":\"child\",\"branch\":$branch_json,\"worktree\":$worktree_json,\"done\":$4,\"total\":$5}"
  RUNNING_COUNT=$((RUNNING_COUNT + 1))
}

# Branche lançable : existence, puis fusion simulée de la parente dans la branche.
add_launchable() {
  local task=$1 branch=$2 exists=false conflict=false files="" output
  json_escape "$branch"; local branch_json=$REPLY
  if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
    exists=true
    output=$(git -C "$ROOT" merge-tree --write-tree --name-only "$branch" "$PARENT" 2>/dev/null)
    case $? in
      0) ;;
      1) conflict=true
         files=$(printf '%s\n' "$output" | awk 'NR == 1 { next } /^$/ { exit } { printf "%s%s", (n++ ? "," : ""), $0 }') ;;
      *) conflict=null ;;
    esac
  fi
  json_array_of_csv "$files"
  LAUNCHABLE_JSON+="${LAUNCHABLE_JSON:+,}{\"task\":\"$task\",\"type\":\"child\",\"branch\":$branch_json,\"exists\":$exists,\"conflict\":$conflict,\"conflict_files\":$REPLY}"
}

add_waiting() {
  local task=$1 branch=$2 missing=$3
  json_escape "$branch"; local branch_json=$REPLY
  json_array_of_csv "$missing"
  WAITING_JSON+="${WAITING_JSON:+,}{\"task\":\"$task\",\"type\":\"child\",\"branch\":$branch_json,\"waiting_for\":$REPLY}"
}

# Tâche jamais lançable telle quelle : « dépendance raison » éclaté en deux champs.
add_invalid() {
  local task=$1 branch=$2 dependency=$3 reason=$4 branch_json=null
  [ -n "$branch" ] && { json_escape "$branch"; branch_json=$REPLY; }
  json_escape "$dependency"
  INVALID_JSON+="${INVALID_JSON:+,}{\"task\":\"$task\",\"branch\":$branch_json,\"dependency\":$REPLY,\"reason\":\"$reason\"}"
}

add_blocked() {
  json_escape "$2"
  BLOCKED_JSON+="${BLOCKED_JSON:+,}{\"task\":\"$1\",\"branch\":$REPLY}"
}

add_stale() {
  json_escape "$2"; local branch_json=$REPLY
  json_escape "$3"
  STALE_JSON+="${STALE_JSON:+,}{\"task\":\"$1\",\"branch\":$branch_json,\"worktree\":$REPLY}"
}

classify_branch_task() {
  local task=$1 branch=$2 depends=$3 worktree=${WORKTREES[$2]:-}
  OPEN_BRANCH_COUNT=$((OPEN_BRANCH_COUNT + 1))
  git check-ref-format --branch "$branch" >/dev/null 2>&1 || { add_invalid "$task" "$branch" "$branch" branch_name; return; }
  if [ -n "$worktree" ] && [ "$worktree" != "$MAIN_WORKTREE" ]; then
    if [ -n "${PRUNABLE[$branch]:-}" ]; then add_stale "$task" "$branch" "$worktree"; else add_running "$task" "$branch" "$worktree"; fi
    return
  fi
  find_invalid_dependency "$task"
  # shellcheck disable=SC2086 — « dépendance raison » éclaté volontairement
  [ -z "$REPLY" ] || { add_invalid "$task" "$branch" $REPLY; return; }
  missing_dependencies "$depends"
  if [ -n "$REPLY" ]; then add_waiting "$task" "$branch" "$REPLY"; else add_launchable "$task" "$branch"; fi
}

# Tâche ordinaire : prenable par le parent quand ses dépendances sont faites ; la dernière tâche du plan
# (vérification d'ensemble) attend toutes les branches.
classify_ordinary_task() {
  local task=$1 depends=$2 title=$3 is_last=$4 waiting_for=""
  find_invalid_dependency "$task"
  # shellcheck disable=SC2086 — « dépendance raison » éclaté volontairement
  [ -z "$REPLY" ] || { add_invalid "$task" "" $REPLY; return; }
  missing_dependencies "$depends"
  waiting_for=$REPLY
  json_escape "$title"; local title_json=$REPLY
  json_array_of_csv "$waiting_for"
  ORDINARY_JSON+="${ORDINARY_JSON:+,}{\"task\":\"$task\",\"title\":$title_json,\"waiting_for\":$REPLY,\"is_last\":$is_last}"
}

# Début de l'entrée JSON d'une unité liée, accolade non fermée, dans REPLY : la liste y ajoute son champ propre.
linked_entry() {
  local task=$1 unit=$2
  json_escape "${unit##* @ }"; local branch_json=$REPLY
  json_escape "${unit% @ *}"; local project_json=$REPLY
  json_array_of_csv "${UNIT_TASKS[$unit]}"
  REPLY="{\"task\":\"$task\",\"type\":\"linked\",\"branch\":$branch_json,\"linked\":$project_json,\"tasks\":$REPLY"
}

# Unité liée : en cours (déléguée), invalide, en attente (dépendance, ou projet non forgé tenu par une autre unité),
# sinon lançable — jamais de fusion simulée : le parent ne fusionne pas une branche liée.
classify_linked_unit() {
  local unit=$1 task=${UNIT_FIRST[$1]} project=${1% @ *} branch=${1##* @ } member state holder entry
  local -a members
  OPEN_BRANCH_COUNT=$((OPEN_BRANCH_COUNT + 1))
  [[ $unit == *" @ "* ]] && [ -n "$branch" ] || { add_invalid "$task" "" "$unit" linked_field; return; }
  linked_entry "$task" "$unit"; entry=$REPLY
  if [ -n "${UNIT_DELEGATED[$unit]:-}" ]; then
    RUNNING_JSON+="${RUNNING_JSON:+,}$entry}"; RUNNING_COUNT=$((RUNNING_COUNT + 1)); return
  fi
  linked_project_state "$project"; state=$REPLY
  [ "$state" != "missing" ] || { add_invalid "$task" "$branch" "$project" linked_missing; return; }
  IFS=, read -ra members <<< "${UNIT_TASKS[$unit]}"
  for member in "${members[@]}"; do
    find_invalid_dependency "$member"
    # shellcheck disable=SC2086 — « dépendance raison » éclaté volontairement
    [ -z "$REPLY" ] || { add_invalid "$task" "$branch" $REPLY; return; }
  done
  missing_dependencies "${UNIT_DEPENDS[$unit]:-}" "${UNIT_TASKS[$unit]}"
  if [ -z "$REPLY" ] && [ "$state" = "unforged" ]; then
    holder=${UNFORGED_HOLDER[$project]:-$unit}
    UNFORGED_HOLDER[$project]=$holder
    [ "$holder" = "$unit" ] || REPLY=${holder##* @ }
  fi
  if [ -n "$REPLY" ]; then
    json_array_of_csv "$REPLY"; WAITING_JSON+="${WAITING_JSON:+,}$entry,\"waiting_for\":$REPLY}"; return
  fi
  LAUNCHABLE_JSON+="${LAUNCHABLE_JSON:+,}$entry,\"forged\":$([ "$state" = "forged" ] && echo true || echo false)}"
}

classify_tasks() {
  local index last=$((${#TASK_LINES[@]} - 1)) task task_status branch depends linked delegated title is_last
  for index in "${!TASK_LINES[@]}"; do
    IFS=$FIELD_SEPARATOR read -r task task_status branch depends linked delegated title <<< "${TASK_LINES[$index]}"
    [ "$task_status" = "blocked" ] && [ -n "$branch" ] && add_blocked "$task" "$branch"
    is_open "$task" || continue
    if [ -n "$branch" ]; then classify_branch_task "$task" "$branch" "$depends"; continue; fi
    if [ -n "$linked" ]; then [ "${UNIT_FIRST[$linked]}" = "$task" ] && classify_linked_unit "$linked"; continue; fi
    is_last=false
    [ "$index" -eq "$last" ] && is_last=true
    classify_ordinary_task "$task" "$depends" "$title" "$is_last"
  done
}

render() {
  local slots=$((SWARM_SIZE - RUNNING_COUNT)) now
  [ "$slots" -lt 0 ] && slots=0
  printf -v now '%(%Y-%m-%d %H:%M)T' -1
  json_escape "$PARENT"
  printf '{"parent":%s,"n":%s,"slots":%s,"open_branches":%s,' "$REPLY" "$SWARM_SIZE" "$slots" "$OPEN_BRANCH_COUNT"
  printf '"running":[%s],"launchable":[%s],"waiting":[%s],"ordinary":[%s],' \
    "$RUNNING_JSON" "$LAUNCHABLE_JSON" "$WAITING_JSON" "$ORDINARY_JSON"
  printf '"invalid":[%s],"blocked":[%s],"stale":[%s],"now":"%s"}\n' "$INVALID_JSON" "$BLOCKED_JSON" "$STALE_JSON" "$now"
}

main() {
  parse_arguments "$@"
  read_swarm_size
  load_tasks
  load_linked_units
  load_worktrees
  classify_tasks
  render
}

main "$@"
