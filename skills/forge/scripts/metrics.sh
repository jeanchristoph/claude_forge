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
#   Avec un journal de mesure (celui de la branche, ou --parent-log) : en-tête **Actual:** du plan réécrit sans doublon,
#   sous **Estimate:**, à défaut sous **Date:** — « ≈ <a> min agent (incl. <c> min checks) · human <h> min (<n>
#   questions, <q> min) · fixed <f> min (delegate setup, merge) · delegates <d> min in parallel · total ≈ <a + h> min »,
#   poste sans mesure « — », « · partial (…) » quand la mesure est incomplète ; sans journal, plan intact. Seul
#   écrivain de la ligne : elle part avec le commit de la livraison et garde sa valeur jusqu'à la suivante
# Usage : metrics.sh --branch <name> --event engrave|closure --model <id> [--root <dir>] [--parent-log <file>] [--base <ref>]
# Sortie : 0 synthèse écrite · 1 usage, sans JSON

set -u

source "$(dirname "${BASH_SOURCE[0]}")/json.sh"
source "$(dirname "${BASH_SOURCE[0]}")/task-files.sh"

readonly EXIT_USAGE=1
readonly SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
readonly ESTIMATE_PATTERN='^\*\*Estimate:\*\*.*≈ ([0-9]+) min \(([0-9]+)-([0-9]+)\)'
readonly TIME_LOG_NAME="time-log.jsonl"
readonly NO_MEASURE="—"

# Nombre de tâches cochées mesurables sans réel chiffré (≈) : tâche-branche d'essaim et tâche déléguée à un projet
# lié écartées, leur réel venant du skill.
readonly UNMEASURED_TASKS_PROGRAM="$TASK_STATUS_AWK"'
  function flush() { if (in_task && status == "done" && !is_skipped && !is_measured) count++; in_task = 0 }
                                     { sub(/\r$/, "") }
  is_task_heading($0)                { flush(); in_task = 1; status = "open"; is_skipped = ($0 ~ / — Branch /); is_measured = 0; next }
  /^## /                             { flush(); next }
  in_task && /^\*\*Actual time:\*\*/ { is_measured = ($0 ~ /≈/) }
  in_task && is_status_line($0)      { status = status_of($0); if ($0 ~ /delegated to/) is_skipped = 1 }
  END { flush(); print count + 0 }'

# En-tête du plan : ancienne ligne **Actual:** retirée, nouvelle sous **Estimate:**, à défaut sous **Date:** ; sans
# l'un ni l'autre, plan recopié tel quel. Plan lu deux fois (repérage, puis écriture), fins de ligne gardées.
readonly ACTUAL_LINE_PROGRAM='
  function is_anchor(text) { return has_estimate ? (text ~ /^\*\*Estimate:\*\*/) : (text ~ /^\*\*Date:\*\*/) }
  { line = $0; eol = (line ~ /\r$/) ? "\r" : ""; sub(/\r$/, "", line) }
  FNR == NR { if (line ~ /^\*\*Estimate:\*\*/) has_estimate = 1; else if (line ~ /^\*\*Date:\*\*/) has_date = 1; next }
  (has_estimate || has_date) && line ~ /^\*\*Actual:\*\*/ { next }
  { print }
  !written && (has_estimate || has_date) && is_anchor(line) { print "**Actual:** " actual eol; written = 1 }'

ROOT="."
BRANCH=""
EVENT=""
MODEL=""
PARENT_LOG=""
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
      --parent-log) require_value "$1" $#; PARENT_LOG=$2; AGGREGATE_OPTIONS+=("$1" "$2"); shift 2 ;;
      --base)       require_value "$1" $#; AGGREGATE_OPTIONS+=("$1" "$2"); shift 2 ;;
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

# Somme de durées à une décimale dans REPLY, « null » comptant pour zéro ; null quand toutes le sont.
sum_minutes() {
  REPLY=$(awk 'BEGIN {
    for (i = 1; i < ARGC; i++) if (ARGV[i] != "null") { sum += ARGV[i]; is_measured = 1 }
    if (is_measured) printf "%.1f", sum; else printf "null"
  }' "$@")
}

# Minutes d'agent : parent + délégués, une décimale ; null quand les deux le sont.
agent_minutes() {
  local parent
  aggregate_field parent_minutes; parent=$REPLY
  aggregate_field delegated_minutes
  sum_minutes "$parent" "$REPLY"
}

# Durée d'un poste dans REPLY : « <m> min », ou « — » sans mesure.
shown_minutes() {
  REPLY="$1 min"
  [ "$1" = null ] && REPLY=$NO_MEASURE
}

# Durée chiffrée d'un poste dans REPLY : « ≈ <m> min », ou « — » sans mesure.
approximate_minutes() {
  REPLY="≈ $1 min"
  [ "$1" = null ] && REPLY=$NO_MEASURE
}

# Raisons d'une mesure incomplète dans REPLY, « · partial (…) » ou vide : journal commencé après la branche (partial de
# time-aggregate.sh), tâches cochées mesurables sans réel chiffré.
partial_suffix() {
  local reasons="" unmeasured
  aggregate_field partial
  [ "$REPLY" = true ] && reasons="log started after the branch"
  unmeasured=$(awk "$UNMEASURED_TASKS_PROGRAM" "$1")
  [ "$unmeasured" -gt 0 ] && reasons+="${reasons:+, }$unmeasured unmeasured tasks"
  REPLY=""
  [ -n "$reasons" ] && REPLY=" · partial ($reasons)"
}

# Valeur de l'en-tête **Actual:** du plan <plan> dans REPLY, même forme que la ligne de tâche, total à la fin.
# BUSINESS_RULE: total = agent + humain — vérifications et fusion sont des parts du temps d'agent, la mise en route une
# part du temps des délégués ; les délégués, simultanés, sont affichés à part et hors total
build_actual_line() {
  local field line
  local -A value
  for field in parent_minutes human_minutes questions question_minutes check_minutes delegate_setup_minutes \
    merge_minutes delegated_minutes; do
    aggregate_field "$field"; value[$field]=$REPLY
  done
  approximate_minutes "${value[parent_minutes]}"; line="$REPLY agent"
  shown_minutes "${value[check_minutes]}"; line+=" (incl. $REPLY checks)"
  shown_minutes "${value[human_minutes]}"; line+=" · human $REPLY"
  shown_minutes "${value[question_minutes]}"; line+=" (${value[questions]/null/$NO_MEASURE} questions, $REPLY)"
  sum_minutes "${value[delegate_setup_minutes]}" "${value[merge_minutes]}"; shown_minutes "$REPLY"
  line+=" · fixed $REPLY (delegate setup, merge)"
  shown_minutes "${value[delegated_minutes]}"; line+=" · delegates $REPLY in parallel"
  sum_minutes "${value[parent_minutes]}" "${value[human_minutes]}"; approximate_minutes "$REPLY"; line+=" · total $REPLY"
  partial_suffix "$1"
  REPLY="$line$REPLY"
}

has_measure_log() {
  [ -f "$ROOT/.forge/branch/$BRANCH/$TIME_LOG_NAME" ] || { [ -n "$PARENT_LOG" ] && [ -f "$PARENT_LOG" ]; }
}

# En-tête **Actual:** du plan réécrit ; plan intact sans plan ni journal de mesure.
write_actual_line() {
  local plan="$ROOT/.forge/branch/$BRANCH/plan.md" content
  [ -f "$plan" ] && has_measure_log || return 0
  build_actual_line "$plan"
  content=$(awk -v actual="$REPLY" "$ACTUAL_LINE_PROGRAM" "$plan" "$plan") || return 0
  [ -n "$content" ] && printf '%s\n' "$content" > "$plan"
  return 0
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
  write_actual_line
  render_report "$metrics_file"
}

main "$@"
