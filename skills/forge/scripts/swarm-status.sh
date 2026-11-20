#!/bin/bash
# État de l'essaim d'une branche parente : branches filles en cours, lançables, en attente, et tâches ordinaires
# que le parent peut prendre. Lu par « Délégation — essaim de branches filles » (commands/swarm.md) et la reprise.
#   Lecture seule : aucune écriture, aucune commande git modifiant le dépôt (merge-tree simule en mémoire)
#   Rend compte en JSON sur une ligne — la mise en page revient au skill
#   Tâche-branche : titre « ### Tn — Branch <x> » ; dépendances : ligne « **Depends on:** <x>, T3 » ou « none »,
#   une dépendance désignant une branche ou un numéro de tâche
#   N : ligne « **N:** <n> » de swarm.md, 3 à défaut
#   now : heure locale « AAAA-MM-JJ HH:MM », seule source de la colonne Since et des dates de swarm.md
# Usage : swarm-status.sh [--root <dir>] [--branch <parent>]
# Sortie : 0 JSON écrit · 1 usage, sans JSON

set -u

source "$(dirname "${BASH_SOURCE[0]}")/json.sh"

readonly EXIT_USAGE=1
readonly DEFAULT_SWARM_SIZE=3

# Séparateur de champs non blanc : read garde les champs vides, qu'une tabulation ferait fusionner.
readonly FIELD_SEPARATOR=$'\x1f'

# Une ligne par tâche, champs séparés par \x1f : numéro, statut, branche ou vide, dépendances séparées par des virgules, titre.
readonly PLAN_PROGRAM='
  function flush() { if (task != "") printf "%s\x1f%s\x1f%s\x1f%s\x1f%s\n", task, status, branch, depends, title; task = "" }
  { sub(/\r$/, "") }
  /^### T[0-9]+/ {
    flush()
    task = $2; title = $0; sub(/^### T[0-9]+ [^ ]+ /, "", title)
    status = "open"; depends = ""; branch = ""
    if (title ~ /^Branch /) { branch = title; sub(/^Branch /, "", branch); gsub(/`/, "", branch); sub(/ .*/, "", branch) }
    next
  }
  /^## / { flush(); next }
  task != "" && /^\*\*Depends on:\*\*/ {
    depends = $0; sub(/^\*\*Depends on:\*\* */, "", depends); gsub(/`/, "", depends); gsub(/ /, "", depends)
    if (depends == "none") depends = ""
  }
  task != "" && /^\[[ x!-]\]/ && !/^\[.\] T[0-9]+\.[0-9]+/ {
    mark = substr($0, 2, 1)
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
PARENT=""
SWARM_SIZE=$DEFAULT_SWARM_SIZE
declare -A DONE_KEYS=()
declare -A WORKTREES=()
TASK_LINES=()
RUNNING_JSON=""
LAUNCHABLE_JSON=""
WAITING_JSON=""
ORDINARY_JSON=""
RUNNING_COUNT=0
OPEN_BRANCH_COUNT=0
MAIN_WORKTREE=""

# ── Arguments et gardes ───────────────────────────────────────────────────────

fail_usage() {
  echo "swarm-status: $1" >&2
  echo "usage: swarm-status.sh [--root <dir>] [--branch <parent>]" >&2
  exit $EXIT_USAGE
}

parse_arguments() {
  while [ $# -gt 0 ]; do
    case $1 in
      --root)   [ $# -ge 2 ] || fail_usage "$1 needs a value"; ROOT=$2; shift 2 ;;
      --branch) [ $# -ge 2 ] || fail_usage "$1 needs a value"; PARENT=$2; shift 2 ;;
      *)        fail_usage "unknown argument $1" ;;
    esac
  done
  [ -d "$ROOT" ] || fail_usage "not a directory: $ROOT"
  [ -n "$PARENT" ] || PARENT=$(git -C "$ROOT" branch --show-current 2>/dev/null)
  [ -n "$PARENT" ] || fail_usage "no current branch: pass --branch"
  [ -f "$ROOT/.forge/branch/$PARENT/plan.md" ] || fail_usage "no plan for $PARENT"
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
  local task task_status branch
  mapfile -t TASK_LINES < <(awk "$PLAN_PROGRAM" "$ROOT/.forge/branch/$PARENT/plan.md")
  for line in "${TASK_LINES[@]}"; do
    IFS=$FIELD_SEPARATOR read -r task task_status branch _ <<< "$line"
    [ "$task_status" = "done" ] || continue
    DONE_KEYS[$task]=1
    [ -n "$branch" ] && DONE_KEYS[$branch]=1
  done
}

# Branche extraite → chemin de son worktree, le dépôt principal compris.
load_worktrees() {
  local line path=""
  MAIN_WORKTREE=$(git -C "$ROOT" rev-parse --show-toplevel 2>/dev/null)
  while IFS= read -r line; do
    case $line in
      "worktree "*) path=${line#worktree } ;;
      "branch refs/heads/"*) WORKTREES[${line#branch refs/heads/}]=$path ;;
    esac
  done < <(git -C "$ROOT" worktree list --porcelain 2>/dev/null)
}

# Dépendances non faites, séparées par des virgules, dans REPLY.
missing_dependencies() {
  local depends=$1 dependency missing=""
  local IFS=,
  for dependency in $depends; do
    [ -n "$dependency" ] && [ -z "${DONE_KEYS[$dependency]:-}" ] && missing+="${missing:+,}$dependency"
  done
  REPLY=$missing
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
  RUNNING_JSON+="${RUNNING_JSON:+,}{\"task\":\"$1\",\"branch\":$branch_json,\"worktree\":$worktree_json,\"done\":$4,\"total\":$5}"
  RUNNING_COUNT=$((RUNNING_COUNT + 1))
}

# Branche lançable : existence, puis fusion simulée de la parente dans la branche.
add_launchable() {
  local task=$1 branch=$2 exists=false conflict=false files="" output
  json_escape "$branch"; local branch_json=$REPLY
  if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$branch"; then
    exists=true
    if ! output=$(git -C "$ROOT" merge-tree --write-tree --name-only "$branch" "$PARENT" 2>/dev/null); then
      conflict=true
      files=$(printf '%s\n' "$output" | awk 'NR == 1 { next } /^$/ { exit } { printf "%s%s", (n++ ? "," : ""), $0 }')
    fi
  fi
  json_array_of_csv "$files"
  LAUNCHABLE_JSON+="${LAUNCHABLE_JSON:+,}{\"task\":\"$task\",\"branch\":$branch_json,\"exists\":$exists,\"conflict\":$conflict,\"conflict_files\":$REPLY}"
}

add_waiting() {
  local task=$1 branch=$2 missing=$3
  json_escape "$branch"; local branch_json=$REPLY
  json_array_of_csv "$missing"
  WAITING_JSON+="${WAITING_JSON:+,}{\"task\":\"$task\",\"branch\":$branch_json,\"waiting_for\":$REPLY}"
}

classify_branch_task() {
  local task=$1 branch=$2 depends=$3
  OPEN_BRANCH_COUNT=$((OPEN_BRANCH_COUNT + 1))
  if [ -n "${WORKTREES[$branch]:-}" ] && [ "${WORKTREES[$branch]}" != "$MAIN_WORKTREE" ]; then
    add_running "$task" "$branch" "${WORKTREES[$branch]}"
    return
  fi
  missing_dependencies "$depends"
  if [ -n "$REPLY" ]; then add_waiting "$task" "$branch" "$REPLY"; else add_launchable "$task" "$branch"; fi
}

# Tâche ordinaire : prenable par le parent quand ses dépendances sont faites ; la dernière tâche du plan
# (vérification d'ensemble) attend toutes les branches.
classify_ordinary_task() {
  local task=$1 depends=$2 title=$3 is_last=$4 waiting_for=""
  missing_dependencies "$depends"
  waiting_for=$REPLY
  json_escape "$title"; local title_json=$REPLY
  json_array_of_csv "$waiting_for"
  ORDINARY_JSON+="${ORDINARY_JSON:+,}{\"task\":\"$task\",\"title\":$title_json,\"waiting_for\":$REPLY,\"is_last\":$is_last}"
}

classify_tasks() {
  local index last=$((${#TASK_LINES[@]} - 1)) task task_status branch depends title is_last
  for index in "${!TASK_LINES[@]}"; do
    IFS=$FIELD_SEPARATOR read -r task task_status branch depends title <<< "${TASK_LINES[$index]}"
    [ "$task_status" = "open" ] || continue
    if [ -n "$branch" ]; then classify_branch_task "$task" "$branch" "$depends"; continue; fi
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
  printf '"running":[%s],"launchable":[%s],"waiting":[%s],"ordinary":[%s],"now":"%s"}\n' \
    "$RUNNING_JSON" "$LAUNCHABLE_JSON" "$WAITING_JSON" "$ORDINARY_JSON" "$now"
}

main() {
  parse_arguments "$@"
  read_swarm_size
  load_tasks
  load_worktrees
  classify_tasks
  render
}

main "$@"
