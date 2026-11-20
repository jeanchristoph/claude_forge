#!/bin/bash
# Marque de tâche : ajoute une ligne horodatée au journal de mesure au démarrage ou à la coche d'une tâche du plan.
#   Appelé par le skill, jamais par un hook ; lu par time-aggregate.sh --task
#   N'écrit rien sur la sortie standard, ne bloque jamais : sortie 0 dans tous les cas
#   Journal absent (hook de mesure non installé) → rien n'est écrit, jamais de journal créé
#   Délégué : --time-log désigne le journal de la branche parente, où le hook range déjà ses événements ;
#   la ligne porte alors la branche du délégué, qui la relie à sa mesure
# Usage : time-mark.sh --branch <name> --task T<n> --event start|done [--root <dir>] [--time-log <file>]
# Écrit : {"ts":<ms>,"event":"task_start"|"task_done","task":"T<n>"[,"branch":"<name>"]}

exec 2>/dev/null

source "$(dirname "${BASH_SOURCE[0]}")/json.sh" || exit 0

readonly TIME_LOG_NAME="time-log.jsonl"
readonly TASK_PATTERN='^T[0-9]+$'

ROOT="."
BRANCH=""
TASK=""
EVENT=""
TIME_LOG=""

# Arguments lus sans échec bruyant : une valeur manquante ou un argument inconnu rend 1, le script sort sans écrire.
parse_arguments() {
  while [ $# -gt 0 ]; do
    [ $# -ge 2 ] || return 1
    case $1 in
      --root)     ROOT=$2 ;;
      --branch)   BRANCH=$2 ;;
      --task)     TASK=$2 ;;
      --event)    EVENT=$2 ;;
      --time-log) TIME_LOG=$2 ;;
      *)          return 1 ;;
    esac
    shift 2
  done
  [ -n "$BRANCH" ] && [[ $TASK =~ $TASK_PATTERN ]] || return 1
  case $EVENT in
    start|done) return 0 ;;
    *)          return 1 ;;
  esac
}

# Millisecondes depuis l'epoch, sans sous-processus ; le séparateur décimal suit la locale.
current_time_ms() {
  local microseconds=${EPOCHREALTIME/[.,]/}
  REPLY=${microseconds:0:${#microseconds}-3}
}

build_line() {
  current_time_ms
  LINE="{\"ts\":$REPLY,\"event\":\"task_$EVENT\",\"task\":\"$TASK\""
  if [ -n "$TIME_LOG" ]; then
    json_escape "$BRANCH"
    LINE+=",\"branch\":$REPLY"
  fi
  LINE+="}"
}

main() {
  local target
  parse_arguments "$@" || exit 0
  target=${TIME_LOG:-"$ROOT/.forge/branch/$BRANCH/$TIME_LOG_NAME"}
  [ -f "$target" ] || exit 0
  build_line
  printf '%s\n' "$LINE" >> "$target"
}

main "$@"
exit 0
