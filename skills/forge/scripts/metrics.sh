#!/bin/bash
# Synthèse de mesure d'une branche : écrit .forge/branch/<branche>/metrics.json, sans le modèle.
#   Appelé par engrave.sh run (avant git add), par la clôture et par la fusion d'une branche fille d'essaim
#   Durées et volume tirés de time-aggregate.sh ; fichiers prévus et réels comptés de la même façon des deux côtés :
#   par tâche dès qu'une tâche est mesurée (task_planned_files / task_files), sinon prévus null et réels = fichiers
#   de la branche selon git
#   metrics.json : un objet sur une ligne, réécrit à chaque passage, champs dans l'ordre figé ci-dessous, valeurs
#   cumulées depuis le début de la branche — l'historique reste dans git
#   Rend compte en JSON sur une ligne : chemin écrit et valeurs de la ligne « Estimated … actual … », estimé lu dans
#   l'en-tête **Estimate:** du plan (null sans en-tête) — la mise en page revient au skill
# Usage : metrics.sh --branch <name> --event engrave|closure --model <id> [--root <dir>] [--parent-log <file>] [--base <ref>]
# Sortie : 0 synthèse écrite · 1 usage, sans JSON

set -u

source "$(dirname "${BASH_SOURCE[0]}")/json.sh"

readonly EXIT_USAGE=1
readonly SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
readonly ESTIMATE_PATTERN='^\*\*Estimate:\*\*.*≈ ([0-9]+) min \(([0-9]+)-([0-9]+)\)'

ROOT="."
BRANCH=""
EVENT=""
MODEL=""
AGGREGATE_OPTIONS=()

fail_usage() {
  echo "metrics: $1" >&2
  echo "usage: metrics.sh --branch <name> --event engrave|closure --model <id> [--root <dir>] [--parent-log <file>] [--base <ref>]" >&2
  exit $EXIT_USAGE
}

require_value() {
  [ "$2" -ge 2 ] || fail_usage "$1 needs a value"
}

parse_arguments() {
  while [ $# -gt 0 ]; do
    case $1 in
      --root)       require_value "$1" $#; ROOT=$2; shift 2 ;;
      --branch)     require_value "$1" $#; BRANCH=$2; shift 2 ;;
      --event)      require_value "$1" $#; EVENT=$2; shift 2 ;;
      --model)      require_value "$1" $#; MODEL=$2; shift 2 ;;
      --parent-log|--base) require_value "$1" $#; AGGREGATE_OPTIONS+=("$1" "$2"); shift 2 ;;
      *)            fail_usage "unknown argument $1" ;;
    esac
  done
  [ -n "$BRANCH" ] || fail_usage "--branch is required"
  [ -n "$MODEL" ] || fail_usage "--model is required"
  [[ $EVENT == engrave || $EVENT == closure ]] || fail_usage "--event needs engrave or closure"
  [ -d "$ROOT/.forge/branch/$BRANCH" ] || fail_usage "no forge branch folder: $ROOT/.forge/branch/$BRANCH"
}

# Valeur brute (nombre, null, true, false ou chaîne JSON) du champ <name> de AGGREGATE, dans REPLY ; null si absent.
aggregate_field() {
  local pattern="\"$1\":(\"([^\"\\\\]|\\\\.)*\"|[^,}]+)"
  REPLY=null
  [[ $AGGREGATE =~ $pattern ]] && REPLY=${BASH_REMATCH[1]}
}

# Minutes d'agent : parent + délégués, une décimale ; null quand les deux le sont.
agent_minutes() {
  local parent delegated
  aggregate_field parent_minutes; parent=$REPLY
  aggregate_field delegated_minutes; delegated=$REPLY
  REPLY=null
  [ "$parent" = null ] && [ "$delegated" = null ] && return
  REPLY=$(awk -v a="$parent" -v b="$delegated" 'BEGIN { printf "%.1f", (a == "null" ? 0 : a) + (b == "null" ? 0 : b) }')
}

# Fichiers prévus et réels dans PLANNED_FILES / ACTUAL_FILES — par tâche dès qu'une tâche est mesurée.
compared_files() {
  local measured_tasks
  aggregate_field measured_tasks; measured_tasks=$REPLY
  if [ "$measured_tasks" != null ] && [ "$measured_tasks" -gt 0 ]; then
    aggregate_field task_planned_files; PLANNED_FILES=$REPLY
    aggregate_field task_files; ACTUAL_FILES=$REPLY
  else
    PLANNED_FILES=null
    aggregate_field files; ACTUAL_FILES=$REPLY
  fi
}

# Ligne de metrics.json dans REPLY, champs dans l'ordre figé.
build_metrics_line() {
  local date field line
  printf -v date '%(%Y-%m-%d)T' -1
  line="{\"event\":\"$EVENT\",\"date\":\"$date\""
  json_escape "$BRANCH"; line+=",\"branch\":$REPLY"
  aggregate_field mode; line+=",\"mode\":$REPLY"
  json_escape "$MODEL"; line+=",\"model\":$REPLY"
  line+=",\"planned_files\":$PLANNED_FILES,\"actual_files\":$ACTUAL_FILES"
  aggregate_field files; line+=",\"branch_files\":$REPLY"
  for field in lines_added lines_deleted; do aggregate_field "$field"; line+=",\"$field\":$REPLY"; done
  line+=",\"agent_minutes\":$AGENT_MINUTES"
  for field in human_minutes questions check_minutes tokens partial delegate_setup_minutes merge_minutes; do
    aggregate_field "$field"; line+=",\"$field\":$REPLY"
  done
  REPLY="$line}"
}

# Estimé de l'en-tête **Estimate:** du plan : « minutes bas haut », ou « null null null ».
read_plan_estimate() {
  local plan="$ROOT/.forge/branch/$BRANCH/plan.md" line
  REPLY="null null null"
  [ -f "$plan" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    [[ $line =~ $ESTIMATE_PATTERN ]] || continue
    REPLY="${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]}"
    return 0
  done < "$plan"
}

render_report() {
  local metrics_file=$1 minutes low high partial
  read -r minutes low high <<< "$(read_plan_estimate; echo "$REPLY")"
  aggregate_field partial; partial=$REPLY
  json_escape "$metrics_file"
  printf '{"metrics_file":%s,"planned_files":%s,"estimated_minutes":%s,"estimated_low":%s,"estimated_high":%s,' \
    "$REPLY" "$PLANNED_FILES" "$minutes" "$low" "$high"
  printf '"actual_files":%s,"agent_minutes":%s,"partial":%s}\n' "$ACTUAL_FILES" "$AGENT_MINUTES" "$partial"
}

main() {
  local metrics_file
  parse_arguments "$@"
  AGGREGATE=$(bash "$SCRIPT_DIR/time-aggregate.sh" --root "$ROOT" --branch "$BRANCH" ${AGGREGATE_OPTIONS[@]+"${AGGREGATE_OPTIONS[@]}"}) \
    || fail_usage "time-aggregate.sh failed"
  agent_minutes; AGENT_MINUTES=$REPLY
  compared_files
  build_metrics_line
  metrics_file="$ROOT/.forge/branch/$BRANCH/metrics.json"
  printf '%s\n' "$REPLY" > "$metrics_file"
  render_report "$metrics_file"
}

main "$@"
