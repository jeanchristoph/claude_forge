#!/bin/bash
# Hook de mesure du temps : ajoute une ligne horodatée au journal de la branche extraite dans le cwd de l'événement.
#   Déclaré dans settings.json par les installeurs (UserPromptSubmit, Stop, SubagentStart, SubagentStop,
#   PreToolUse et PostToolUse sur AskUserQuestion|Bash), donc global : sans dossier .forge dans le cwd ou ses parents, il sort aussitôt, sans processus git
#   Ne calcule rien, n'affiche rien, ne bloque jamais : sortie 0 dans tous les cas, rien sur la sortie standard
#   Ne garde aucun contenu (prompt, question, commande, réponse d'outil) : seuls des identifiants, durées et marqueurs
#   Question : champ « units », l'unité déléguée de chaque question de la fenêtre (préfixe « [unité] »)
#   Les événements d'un délégué arrivent avec le cwd du parent et un agent_id : ils tombent dans le journal du parent
# Entrée : JSON du hook sur l'entrée standard
# Écrit : <racine>/.forge/branch/<branche>/time-log.jsonl, une ligne par événement retenu ;
#   journal créé alors que plan.md existe déjà → ligne {"event":"late_start"} en tête : mesure partielle

exec 2>/dev/null

source "$(dirname "${BASH_SOURCE[0]}")/../scripts/json.sh" || exit 0

readonly TIME_LOG_NAME="time-log.jsonl"
readonly CHECK_PATTERN_LABEL='**Check pattern:**'
# Retour d'un délégué ou notification de tâche de fond : un UserPromptSubmit qui n'est pas une reprise humaine
readonly AGENT_PROMPT_PATTERN='"prompt":"<(agent-message|task-notification)'

INPUT=""
EVENT_TIME=""

read_number_field() {
  local pattern="(^|[^\\])\"$1\":([0-9]+)"
  REPLY=""
  [[ $INPUT =~ $pattern ]] && REPLY=${BASH_REMATCH[2]}
}

# Millisecondes depuis l'epoch, sans sous-processus ; le séparateur décimal suit la locale.
# Rend 1 sans EPOCHREALTIME (bash < 5) : aucune heure fiable, rien ne s'écrit.
current_time_ms() {
  local microseconds=${EPOCHREALTIME/[.,]/}
  [ ${#microseconds} -gt 3 ] || return 1
  REPLY=${microseconds:0:${#microseconds}-3}
}

# Journal de la branche extraite dans le cwd, dans REPLY ; vide hors dépôt, tête détachée ou branche non forgée.
# Dossier .forge dans <dir> ou l'un de ses parents ? Recherche en bash pur, sans processus : hors projet forgé,
# le hook sort avant tout git.
has_forge_folder() {
  local dir=${1%/}
  while [ -n "$dir" ]; do
    [ -d "$dir/.forge" ] && return 0
    [ "$dir" = "${dir%/*}" ] && return 1
    dir=${dir%/*}
  done
  return 1
}

resolve_time_log() {
  local cwd=$1 lines top branch
  REPLY=""
  lines=$(git -C "$cwd" rev-parse --show-toplevel --abbrev-ref HEAD) || return
  top=${lines%%$'\n'*}
  branch=${lines#*$'\n'}
  [ "$branch" = "HEAD" ] && return
  [ -d "$top/.forge/branch/$branch" ] || return
  REPLY="$top/.forge/branch/$branch/$TIME_LOG_NAME"
}

# Motif de vérification du projet : ligne « **Check pattern:** `<regex>` » de project.md, vide si absente.
read_check_pattern() {
  local project_file=$1 line
  REPLY=""
  [ -f "$project_file" ] || return
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    case $line in
      "$CHECK_PATTERN_LABEL"*)
        line=${line#*\`}
        REPLY=${line%\`*}
        return
        ;;
    esac
  done < "$project_file"
}

# Commande Bash exécutée : correspond-elle au motif de vérification du projet ? Lue pour la comparaison, jamais écrite.
is_check_command() {
  local project_file=$1 pattern
  read_check_pattern "$project_file"
  pattern=$REPLY
  [ -n "$pattern" ] || return 1
  json_string_field command "$INPUT"
  [ -n "$REPLY" ] && [[ $REPLY =~ $pattern ]]
}

# Unité déléguée de chaque question ouverte, lue dans son préfixe « [unité] », séparées par « | » dans REPLY — vide sans
# préfixe (session principale) ; REPLY vide pour une seule question sans préfixe. Le texte des questions n'est jamais écrit.
read_question_units() {
  local rest=$INPUT units=""
  while [[ $rest == *'"question":"'* ]]; do
    rest=${rest#*'"question":"'}
    units+="|"
    [[ $rest =~ ^\[([^]\[\|\"\\]+)\] ]] && units+=${BASH_REMATCH[1]}
  done
  REPLY=${units#|}
}

append_field() {
  json_escape "$2"
  LINE+=",\"$1\":$REPLY"
}

# Événement écouté ? Un sous-agent sans type est un agent interne de Claude Code, jamais un délégué.
is_measured_event() {
  case $EVENT in
    UserPromptSubmit|Stop) return 0 ;;
    SubagentStart|SubagentStop) [ -n "$AGENT_TYPE" ] ;;
    PreToolUse|PostToolUse) [ "$TOOL" = "Bash" ] || [ "$TOOL" = "AskUserQuestion" ] ;;
    *) return 1 ;;
  esac
}

# Ligne JSON de l'événement dans LINE, sans accolade fermante ; l'heure est celle du démarrage du hook.
build_line() {
  local time_log=$1
  LINE="{\"ts\":$EVENT_TIME"
  append_field event "$EVENT"
  json_string_field session_id "$INPUT"
  [ -n "$REPLY" ] && append_field session "$REPLY"
  [ -n "$AGENT_ID" ] && append_field agent_id "$AGENT_ID"
  [ -n "$TOOL" ] && append_field tool "$TOOL"
  if [ "$EVENT" = "UserPromptSubmit" ]; then
    if [[ $INPUT =~ $AGENT_PROMPT_PATTERN ]]; then append_field origin agent; else append_field origin human; fi
  fi
  if [ "$EVENT" = "PreToolUse" ] && [ "$TOOL" = "AskUserQuestion" ]; then
    read_question_units
    [ -n "$REPLY" ] && append_field units "$REPLY"
  fi
  [ "$EVENT" = "PostToolUse" ] || return
  read_number_field duration_ms
  [ -n "$REPLY" ] && LINE+=",\"duration_ms\":$REPLY"
  [ "$TOOL" = "Bash" ] && is_check_command "${time_log%/.forge/*}/.forge/project.md" && LINE+=",\"check\":true"
}

# Journal absent alors que le plan existe : le hook arrive en cours de branche (installé tard, journal effacé).
# Une branche suivie dès son départ crée son journal pendant la rédaction du brief, avant tout plan.
is_late_start() {
  local time_log=$1
  [ ! -f "$time_log" ] && [ -f "${time_log%/*}/plan.md" ]
}

main() {
  local time_log cwd
  # Heure prise avant toute lecture : l'analyse d'une grosse sortie d'outil et git la décaleraient
  current_time_ms || exit 0
  EVENT_TIME=$REPLY
  INPUT=$(cat) || exit 0
  json_string_field hook_event_name "$INPUT"; EVENT=$REPLY
  json_string_field agent_id "$INPUT"; AGENT_ID=$REPLY
  json_string_field agent_type "$INPUT"; AGENT_TYPE=$REPLY
  json_string_field tool_name "$INPUT"; TOOL=$REPLY
  is_measured_event || exit 0
  json_path_field cwd "$INPUT"
  cwd=$REPLY
  has_forge_folder "$cwd" || exit 0
  resolve_time_log "$cwd"
  time_log=$REPLY
  [ -n "$time_log" ] || exit 0
  if is_late_start "$time_log"; then
    printf '{"ts":%s,"event":"late_start"}\n' "$EVENT_TIME" >> "$time_log"
  fi
  build_line "$time_log"
  printf '%s}\n' "$LINE" >> "$time_log"
}

main
exit 0
