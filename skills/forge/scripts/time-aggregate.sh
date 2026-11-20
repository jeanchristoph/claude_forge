#!/bin/bash
# Agrégation de la mesure d'une branche : durées tirées du journal du hook, volume tiré de git.
#   Lecture seule : aucune écriture, aucune commande git modifiant le dépôt
#   Rend compte en JSON sur une ligne — la synthèse metrics.json et sa mise en forme reviennent au skill
#   Session principale : événements sans agent_id du journal de la branche
#   Délégués : identifiants associés à la branche par les lignes {"event":"delegate"} du journal de la parente,
#   leurs événements lus dans ce même journal (un délégué porte toujours le cwd de la session qui l'a lancé) ;
#   tokens = somme des lignes {"event":"delegate_usage"} écrites par la parente à chaque retour d'un délégué
# Usage : time-aggregate.sh --branch <name> [--root <dir>] [--parent-log <file>] [--base <ref>]
#   --parent-log : journal de la branche parente, pour une branche fille travaillée par des délégués
#   --base       : point de départ de la branche ; défaut : master, sinon main
# Sortie : 0 JSON écrit · 1 usage, sans JSON

set -u

source "$(dirname "${BASH_SOURCE[0]}")/json.sh"

readonly EXIT_USAGE=1
readonly TIME_LOG_NAME="time-log.jsonl"
# BUSINESS_RULE: au-delà de 1 h, un écart avant un prompt ou une attente de réponse est une absence, pas du temps humain
readonly HUMAN_ABSENCE_MS=3600000
readonly EXCLUDED_PATHS=(
  ':(exclude).forge'
  ':(exclude,glob)**/package-lock.json' ':(exclude,glob)**/yarn.lock' ':(exclude,glob)**/pnpm-lock.yaml'
  ':(exclude,glob)**/composer.lock' ':(exclude,glob)**/Cargo.lock' ':(exclude,glob)**/poetry.lock'
  ':(exclude,glob)**/Gemfile.lock' ':(exclude,glob)**/go.sum'
)

# Durées en minutes, une décimale ; « null » quand aucun événement n'a été lu.
#   Session principale, par session : tour = UserPromptSubmit → Stop, questions ouvertes retirées ;
#   temps humain = Stop → prompt « origin: human » suivant, plus la durée des questions ;
#   un écart ou une attente de plus de absence_ms est une absence : zéro minute humaine, question toujours comptée.
#   Un prompt « origin: agent » (retour de délégué) ouvre un tour sans compter d'attente humaine.
readonly DURATIONS_PROGRAM='
  function field(name,   pattern, value) {
    pattern = "\"" name "\":(\"[^\"]*\"|[0-9]+|true)"
    if (!match($0, pattern)) return ""
    value = substr($0, RSTART + length(name) + 3, RLENGTH - length(name) - 3)
    gsub(/"/, "", value)
    return value
  }
  function minutes(ms) { return sprintf("%.1f", ms / 60000) }
  function human_share(ms) { return ms > absence_ms ? 0 : ms }
  FNR == 1 { file_index++; reading_parent = (has_parent_log && file_index == 1) }
  reading_parent && field("event") == "delegate" && field("branch") == branch { delegate[field("agent_id")] = 1; next }
  reading_parent {
    id = field("agent_id"); event = field("event"); ts = field("ts") + 0
    if (!(id in delegate)) next
    seen = 1
    if (event == "SubagentStart") agent_start[id] = ts
    if (event == "SubagentStop" && (id in agent_start)) { delegated += ts - agent_start[id]; delete agent_start[id]; runs[id] = 1 }
    if (event == "PostToolUse" && field("check") == "true") checks += field("duration_ms")
    if (event == "delegate_usage") { tokens += field("tokens"); has_tokens = 1 }
    next
  }
  field("agent_id") != "" { next }
  {
    seen = 1; event = field("event"); session = field("session"); ts = field("ts") + 0
    if (event == "UserPromptSubmit") {
      if (field("origin") == "human" && (session in last_stop)) human += human_share(ts - last_stop[session])
      delete last_stop[session]; turn_start[session] = ts; turn_questions[session] = 0
    } else if (event == "Stop") {
      if (session in turn_start) parent += ts - turn_start[session] - turn_questions[session]
      delete turn_start[session]; last_stop[session] = ts
    } else if (event == "PreToolUse" && field("tool") == "AskUserQuestion") {
      question_start[session] = ts
    } else if (event == "PostToolUse" && field("tool") == "AskUserQuestion" && (session in question_start)) {
      wait = ts - question_start[session]; delete question_start[session]
      questions++; question_time += human_share(wait); human += human_share(wait); turn_questions[session] += wait
    } else if (event == "PostToolUse" && field("check") == "true") {
      checks += field("duration_ms")
    }
  }
  END {
    if (!seen) { print "null null null 0 null null 0 null"; exit }
    count = 0; for (id in runs) count++
    printf "%s %s %s %d %s %s %d %s\n", minutes(parent), minutes(delegated), minutes(human), questions, minutes(question_time), minutes(checks), count, (has_tokens ? tokens : "null")
  }'

ROOT="."
BRANCH=""
PARENT_LOG=""
BASE=""

# ── Arguments et gardes ───────────────────────────────────────────────────────

fail_usage() {
  echo "time-aggregate: $1" >&2
  echo "usage: time-aggregate.sh --branch <name> [--root <dir>] [--parent-log <file>] [--base <ref>]" >&2
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
      --parent-log) require_value "$1" $#; PARENT_LOG=$2; shift 2 ;;
      --base)       require_value "$1" $#; BASE=$2; shift 2 ;;
      *)            fail_usage "unknown argument $1" ;;
    esac
  done
  [ -n "$BRANCH" ] || fail_usage "--branch is required"
  [ -d "$ROOT" ] || fail_usage "not a directory: $ROOT"
}

# ── Durées ────────────────────────────────────────────────────────────────────

# Journal trié par heure, tri stable : le hook asynchrone ne garantit pas l'ordre d'écriture de deux événements proches.
# Une ligne sans « ts » en tête (delegate, delegate_usage, écrites par le skill) passe en premier : l'association
# d'un délégué à sa branche précède ainsi son SubagentStart, écrit avant que le skill connaisse son identifiant.
sort_by_time() {
  LC_ALL=C sort -s -t: -k2,2n "$1"
}

# Sortie de DURATIONS_PROGRAM : « parent délégués humain questions attente vérifications délégués_lancés tokens ».
# Le journal parent, quand il est lu, est le premier fichier ; un journal vide n'est jamais passé, pour garder ce rang.
read_durations() {
  local own_log="$ROOT/.forge/branch/$BRANCH/$TIME_LOG_NAME" has_parent_log=0 has_own_log=0
  [ -n "$PARENT_LOG" ] && [ -s "$PARENT_LOG" ] && has_parent_log=1
  [ -s "$own_log" ] && has_own_log=1
  REPLY="null null null 0 null null 0 null"
  local awk_command=(awk -v has_parent_log="$has_parent_log" -v branch="$BRANCH" -v absence_ms="$HUMAN_ABSENCE_MS" "$DURATIONS_PROGRAM")
  case "$has_parent_log$has_own_log" in
    11) REPLY=$("${awk_command[@]}" <(sort_by_time "$PARENT_LOG") <(sort_by_time "$own_log")) ;;
    10) REPLY=$("${awk_command[@]}" <(sort_by_time "$PARENT_LOG")) ;;
    01) REPLY=$("${awk_command[@]}" <(sort_by_time "$own_log")) ;;
  esac
}

resolve_mode() {
  local parent=$1 delegated=$2
  local has_parent=0 has_delegated=0
  [ "$parent" != "null" ] && [ "$parent" != "0.0" ] && has_parent=1
  [ "$delegated" != "null" ] && [ "$delegated" != "0.0" ] && has_delegated=1
  case "$has_parent$has_delegated" in
    11) REPLY='"mixed"' ;;
    10) REPLY='"parent"' ;;
    01) REPLY='"delegated"' ;;
    *)  REPLY=null ;;
  esac
}

# ── Volume ────────────────────────────────────────────────────────────────────

resolve_start_point() {
  local candidate
  if [ -z "$BASE" ]; then
    for candidate in master main; do
      git -C "$ROOT" show-ref --verify --quiet "refs/heads/$candidate" && { BASE=$candidate; break; }
    done
  fi
  REPLY=""
  [ -n "$BASE" ] || return
  REPLY=$(git -C "$ROOT" merge-base "$BASE" HEAD 2>/dev/null)
}

# « fichiers ajoutées supprimées » depuis le point de départ : fichiers suivis (commités ou non) et non suivis,
# hors .forge et fichiers de verrouillage ; « null null null » sans point de départ.
read_volume() {
  local start=$1
  if [ -z "$start" ]; then
    REPLY="null null null"
    return
  fi
  local tracked untracked_files untracked_lines
  tracked=$(git -C "$ROOT" diff --numstat "$start" -- . "${EXCLUDED_PATHS[@]}" \
    | awk -F '\t' 'NF >= 3 { files++; if ($1 != "-") { added += $1; deleted += $2 } }
                   END { printf "%d %d %d", files, added, deleted }')
  untracked_files=$(cd "$ROOT" && git ls-files --others --exclude-standard -- . "${EXCLUDED_PATHS[@]}" | wc -l)
  untracked_lines=$(cd "$ROOT" && git ls-files --others --exclude-standard -z -- . "${EXCLUDED_PATHS[@]}" \
    | xargs -0 -r cat | wc -l)
  set -- $tracked
  REPLY="$(($1 + untracked_files)) $(($2 + untracked_lines)) $3"
}

# ── Rendu ─────────────────────────────────────────────────────────────────────

render() {
  local parent=$1 delegated=$2 human=$3 questions=$4 question_time=$5 checks=$6 delegates=$7 tokens=$8
  local files=$9 added=${10} deleted=${11} mode branch_json
  resolve_mode "$parent" "$delegated"; mode=$REPLY
  json_escape "$BRANCH"; branch_json=$REPLY
  printf '{"branch":%s,"parent_minutes":%s,"delegated_minutes":%s,"human_minutes":%s,' "$branch_json" "$parent" "$delegated" "$human"
  printf '"questions":%s,"question_minutes":%s,"check_minutes":%s,"delegates":%s,"mode":%s,' "$questions" "$question_time" "$checks" "$delegates" "$mode"
  printf '"tokens":%s,"files":%s,"lines_added":%s,"lines_deleted":%s}\n' "$tokens" "$files" "$added" "$deleted"
}

main() {
  local durations volume
  parse_arguments "$@"
  read_durations; durations=$REPLY
  resolve_start_point
  read_volume "$REPLY"; volume=$REPLY
  # shellcheck disable=SC2086 — découpage voulu des champs numériques
  render $durations $volume
}

main "$@"
