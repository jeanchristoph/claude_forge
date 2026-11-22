#!/bin/bash
# Marque du journal de mesure : seul chemin d'écriture des lignes que le skill ajoute au journal du hook.
#   start / done        : démarrage ou coche d'une tâche du plan, horodatés ; lus par time-aggregate.sh --task ;
#                         portent l'empreinte du dossier de la tâche (ROOT) : « chemin<TAB>hash » de chaque fichier
#                         modifié, nouveau ou supprimé (hash « - »), hors .forge — lecture seule, rien d'écrit dans
#                         le dépôt ni l'index ; champ absent hors dépôt git
#   delegate            : association d'un délégué à sa branche, sans horodatage — triée en tête du journal,
#                         elle précède ainsi le SubagentStart écrit avant que le skill connaisse l'identifiant
#   delegate_usage      : tokens rapportés au retour d'un délégué, sans horodatage
#   merge_start / merge_done : fusion d'une branche fille par le parent, horodatées ; lues par time-aggregate.sh
#   Appelé par le skill, jamais par un hook ; n'écrit rien sur la sortie standard, sortie 0 dans tous les cas
#   Journal absent (hook de mesure non installé) → rien n'est écrit, jamais de journal créé
#   Délégué : --time-log désigne le journal de la branche parente, où le hook range déjà ses événements ;
#   la marque de tâche porte alors la branche du délégué, qui la relie à sa mesure
# Usage : time-mark.sh --branch <name> --task T<n>[.<n>] --event start|done [--root <dir>] [--time-log <file>]
#         time-mark.sh --time-log <file> --event delegate --agent-id <id> --branch <name>
#         time-mark.sh --time-log <file> --event delegate_usage --agent-id <id> --tokens <n>
#         time-mark.sh --time-log <file> --event merge_start|merge_done --branch <branche fusionnée>
# Écrit : {"ts":<ms>,"event":"task_start"|"task_done","task":"T<n>"[,"branch":"<name>"][,"files":"<empreinte>"]}
#         {"event":"delegate","agent_id":"<id>","branch":"<name>"} · {"event":"delegate_usage","agent_id":"<id>","tokens":<n>}
#         {"ts":<ms>,"event":"merge_start"|"merge_done","branch":"<name>"}

exec 2>/dev/null

source "$(dirname "${BASH_SOURCE[0]}")/json.sh" || exit 0
source "$(dirname "${BASH_SOURCE[0]}")/task-marks.sh" || exit 0

readonly TIME_LOG_NAME="time-log.jsonl"
readonly TASK_PATTERN='^T[0-9]+(\.[0-9]+)?$'
readonly TOKENS_PATTERN='^[0-9]+$'

ROOT="."
BRANCH=""
TASK=""
EVENT=""
TIME_LOG=""
AGENT_ID=""
TOKENS=""

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
      --agent-id) AGENT_ID=$2 ;;
      --tokens)   TOKENS=$2 ;;
      *)          return 1 ;;
    esac
    shift 2
  done
  has_required_arguments
}

has_required_arguments() {
  case $EVENT in
    start|done)     [ -n "$BRANCH" ] && [[ $TASK =~ $TASK_PATTERN ]] ;;
    delegate)       [ -n "$TIME_LOG" ] && [ -n "$AGENT_ID" ] && [ -n "$BRANCH" ] ;;
    delegate_usage) [ -n "$TIME_LOG" ] && [ -n "$AGENT_ID" ] && [[ $TOKENS =~ $TOKENS_PATTERN ]] ;;
    merge_start|merge_done) [ -n "$TIME_LOG" ] && [ -n "$BRANCH" ] ;;
    *)              return 1 ;;
  esac
}

build_task_line() {
  local time files_json=""
  current_time_ms || return 1
  time=$REPLY
  if snapshot_files "$ROOT"; then
    json_escape "$REPLY"
    files_json=$REPLY
  fi
  task_mark_line "$time" "task_$EVENT" "$TASK" "${TIME_LOG:+$BRANCH}" "$files_json"
  LINE=$REPLY
}

build_delegate_line() {
  local agent_json
  json_escape "$AGENT_ID"; agent_json=$REPLY
  if [ "$EVENT" = "delegate" ]; then
    json_escape "$BRANCH"
    LINE="{\"event\":\"delegate\",\"agent_id\":$agent_json,\"branch\":$REPLY}"
  else
    LINE="{\"event\":\"delegate_usage\",\"agent_id\":$agent_json,\"tokens\":$((10#$TOKENS))}"
  fi
}

build_merge_line() {
  current_time_ms || return 1
  local time=$REPLY
  json_escape "$BRANCH"
  LINE="{\"ts\":$time,\"event\":\"$EVENT\",\"branch\":$REPLY}"
}

build_line() {
  case $EVENT in
    start|done)             build_task_line ;;
    merge_start|merge_done) build_merge_line ;;
    *)                      build_delegate_line ;;
  esac
}

main() {
  local target
  parse_arguments "$@" || exit 0
  target=${TIME_LOG:-"$ROOT/.forge/branch/$BRANCH/$TIME_LOG_NAME"}
  [ -f "$target" ] || exit 0
  build_line || exit 0
  printf '%s\n' "$LINE" >> "$target"
}

main "$@"
exit 0
