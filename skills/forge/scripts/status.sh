#!/bin/bash
# État forge de la branche courante, lu au lancement par la « Détection d'état » de SKILL.md.
#   Lecture seule : aucune écriture, aucune commande git modifiant le dépôt
#   Rend compte en JSON sur une ligne — la mise en page revient au skill
#   Appelé à chaque lancement : lancer un processus coûte cher sous Git Bash, d'où le travail en variables
# Usage : status.sh [--root <dir>] [--branch <name>]
#   --branch : branche à évaluer à la place de la branche git courante (nom de code hors git)
# Sortie : 0 état écrit · 1 usage, sans JSON

set -u

source "$(dirname "${BASH_SOURCE[0]}")/json.sh"

readonly EXIT_USAGE=1
readonly STATE_PROJECT_INIT="project_init"
readonly STATE_CODING_STANDARDS_INIT="coding_standards_init"
readonly STATE_NO_BRANCH="no_branch"
readonly STATE_BRIEF="brief"
readonly STATE_PLAN="plan"
readonly STATE_ACTIVE="active"
readonly LOG_LINES_SCANNED=40
readonly LOG_ENTRIES_KEPT=10
readonly TAB=$'\t'
readonly CARRIAGE_RETURN=$'\r'

# Une ligne « fichier<TAB>statut<TAB>titre » par tâche : le statut est la ligne [ ] / [x] / [!] / [-] sous le titre,
# les micro-étapes [ ] T1.1 n'en sont pas. Tâche sans ligne de statut → ouverte.
readonly TASKS_PROGRAM='
  function flush() { if (title != "") printf "%s\t%s\t%s\n", plan, status, title; title = "" }
  FNR == 1       { flush(); plan = FILENAME }
                 { sub(/\r$/, "") }
  /^### T[0-9]+/ { flush(); title = substr($0, 5); status = "open"; next }
  /^## /         { flush(); next }
  title != "" && /^\[[ x!-]\]/ && !/^\[.\] T[0-9]+\.[0-9]+/ {
    mark = substr($0, 2, 1)
    status = (mark == "x") ? "done" : (mark == "!") ? "blocked" : (mark == "-") ? "dropped" : "open"
  }
  END { flush() }'

ROOT="."
BRANCH=""
BRANCH_DIR=""
STATE=""
DONE_COUNT=0
OPEN_COUNT=0
BLOCKED_COUNT=0
OPEN_TASKS_JSON=""
RECENT_LOG_JSON=""
RESUMABLE_JSON=""

# ── Arguments et gardes ───────────────────────────────────────────────────────

fail_usage() {
  echo "status: $1" >&2
  echo "usage: status.sh [--root <dir>] [--branch <name>]" >&2
  exit $EXIT_USAGE
}

require_value() {
  [ "$2" -ge 2 ] || fail_usage "$1 needs a value"
}

parse_arguments() {
  while [ $# -gt 0 ]; do
    case $1 in
      --root)   require_value "$1" $#; ROOT=$2; shift 2 ;;
      --branch) require_value "$1" $#; BRANCH=$2; shift 2 ;;
      *)        fail_usage "unknown argument $1" ;;
    esac
  done
}

validate_arguments() {
  [ -d "$ROOT" ] || fail_usage "not a directory: $ROOT"
}

# ── Rendu — données seules, la mise en page revient au skill (SKILL.md) ───────

# ── Lecture ───────────────────────────────────────────────────────────────────

resolve_branch() {
  [ -n "$BRANCH" ] || BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null)
  BRANCH_DIR="$ROOT/.forge/branch/$BRANCH"
}

resolve_state() {
  if [ ! -f "$ROOT/.forge/project.md" ]; then STATE=$STATE_PROJECT_INIT
  elif [ ! -f "$ROOT/.forge/coding-standards.md" ]; then STATE=$STATE_CODING_STANDARDS_INIT
  elif [ -z "$BRANCH" ]; then STATE=$STATE_NO_BRANCH
  elif [ ! -f "$BRANCH_DIR/brief.md" ]; then STATE=$STATE_BRIEF
  elif [ ! -f "$BRANCH_DIR/plan.md" ]; then STATE=$STATE_PLAN
  else STATE=$STATE_ACTIVE
  fi
}

load_current_plan() {
  [ -n "$BRANCH" ] && [ -f "$BRANCH_DIR/plan.md" ] || return 0
  local plan task_status title
  while IFS=$TAB read -r plan task_status title; do
    case $task_status in
      done)    DONE_COUNT=$((DONE_COUNT + 1)) ;;
      blocked) BLOCKED_COUNT=$((BLOCKED_COUNT + 1)) ;;
      open)
        OPEN_COUNT=$((OPEN_COUNT + 1))
        json_escape "$title"
        OPEN_TASKS_JSON+="${OPEN_TASKS_JSON:+,}$REPLY"
        ;;
    esac
  done < <(awk "$TASKS_PROGRAM" "$BRANCH_DIR/plan.md")
}

# Entrées les plus récentes, en tête de log.md : lecture bornée, jamais le fichier entier.
load_recent_log() {
  local log_file="$BRANCH_DIR/log.md" line scanned=0 kept=0
  [ -n "$BRANCH" ] && [ -f "$log_file" ] || return 0
  while [ "$scanned" -lt "$LOG_LINES_SCANNED" ] && [ "$kept" -lt "$LOG_ENTRIES_KEPT" ] && IFS= read -r line; do
    scanned=$((scanned + 1))
    line=${line%"$CARRIAGE_RETURN"}
    case $line in
      "- ["*)
        kept=$((kept + 1))
        json_escape "$line"
        RECENT_LOG_JSON+="${RECENT_LOG_JSON:+,}$REPLY"
        ;;
    esac
  done < "$log_file"
}

branch_exists() {
  git -C "$ROOT" show-ref --verify --quiet "refs/heads/$1"
}

# Une ligne « fichier<TAB>nombre » par plan gardant des tâches ouvertes, tous plans lus en un seul passage.
plans_with_open_tasks() {
  find "$1" -name plan.md -exec awk "$TASKS_PROGRAM" {} + \
    | awk -F '\t' '$2 == "open" { open[$1]++ } END { for (plan in open) printf "%s\t%s\n", plan, open[plan] }' \
    | sort
}

# Branches locales autres que la courante dont le plan garde des tâches ouvertes.
load_resumable_branches() {
  local base="$ROOT/.forge/branch" plan open branch
  [ -d "$base" ] || return 0
  while IFS=$TAB read -r plan open; do
    branch=${plan#"$base"/}
    branch=${branch%/plan.md}
    [ "$branch" = "$BRANCH" ] && continue
    branch_exists "$branch" || continue
    json_escape "$branch"
    RESUMABLE_JSON+="${RESUMABLE_JSON:+,}{\"branch\":$REPLY,\"open\":$open}"
  done < <(plans_with_open_tasks "$base")
}

render_status() {
  local branch_json=null state_json
  if [ -n "$BRANCH" ]; then
    json_escape "$BRANCH"
    branch_json=$REPLY
  fi
  json_escape "$STATE"
  state_json=$REPLY
  printf '{"branch":%s,"state":%s,' "$branch_json" "$state_json"
  printf '"tasks":{"done":%s,"open":%s,"blocked":%s,"total":%s},' \
    "$DONE_COUNT" "$OPEN_COUNT" "$BLOCKED_COUNT" "$((DONE_COUNT + OPEN_COUNT + BLOCKED_COUNT))"
  printf '"open_tasks":[%s],"recent_log":[%s],"resumable":[%s]}\n' \
    "$OPEN_TASKS_JSON" "$RECENT_LOG_JSON" "$RESUMABLE_JSON"
}

main() {
  parse_arguments "$@"
  validate_arguments
  resolve_branch
  resolve_state
  load_current_plan
  load_recent_log
  load_resumable_branches
  render_status
}

main "$@"
