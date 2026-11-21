#!/bin/bash
# Agrégation de la mesure d'une branche : durées tirées du journal du hook, volume tiré de git.
#   Lecture seule : aucune écriture, aucune commande git modifiant le dépôt
#   Rend compte en JSON sur une ligne — la synthèse metrics.json et sa mise en forme reviennent au skill
#   Session principale : événements sans agent_id du journal de la branche
#   Délégués : identifiants associés à la branche par les lignes {"event":"delegate"} du journal de la parente,
#   leurs événements lus dans ce même journal (un délégué porte toujours le cwd de la session qui l'a lancé) ;
#   tokens = somme des lignes {"event":"delegate_usage"} écrites par la parente à chaque retour d'un délégué
# Usage : time-aggregate.sh --branch <name> [--root <dir>] [--parent-log <file>] [--base <ref>] [--task T<n>[,T<n>…]]
#   --parent-log : journal de la branche parente, pour une branche fille travaillée par des délégués
#   --base       : point de départ de la branche ; défaut : master, sinon main
#   --task       : mesure d'une seule tâche, entre ses marques task_start et task_done écrites par time-mark.sh —
#   marques lues dans le journal de la branche, ou avec --parent-log dans celui de la parente (marques portant la branche) ;
#   plusieurs tâches séparées par des virgules → somme, non mesurée dès qu'une ne l'est pas ;
#   sortie propre à la tâche, sans volume ni mode
#   partial : mesure incomplète — journal ouvert par une ligne late_start, ou premier commit propre à la branche
#   antérieur au premier événement du journal ; le calibrage écarte une telle branche
# Sortie : 0 JSON écrit · 1 usage, sans JSON

set -u

source "$(dirname "${BASH_SOURCE[0]}")/json.sh"

readonly EXIT_USAGE=1
readonly TIME_LOG_NAME="time-log.jsonl"
# BUSINESS_RULE: au-delà de 6 h, un écart avant un prompt ou une attente de réponse est une absence, pas du temps humain
readonly HUMAN_ABSENCE_MS=21600000
readonly EXCLUDED_PATHS=(
  ':(exclude).forge'
  ':(exclude,glob)**/package-lock.json' ':(exclude,glob)**/yarn.lock' ':(exclude,glob)**/pnpm-lock.yaml'
  ':(exclude,glob)**/composer.lock' ':(exclude,glob)**/Cargo.lock' ':(exclude,glob)**/poetry.lock'
  ':(exclude,glob)**/Gemfile.lock' ':(exclude,glob)**/go.sum'
)

# Fonctions communes aux programmes awk de la branche et de la tâche.
# field() cherche la clé par index() : un motif construit par concaténation serait recompilé à chaque appel
# (≈ 0,4 ms par ligne sur un journal de 50 000 lignes).
readonly AWK_HELPERS='
  function field(name,   key, start, rest, stop) {
    key = "\"" name "\":"
    start = index($0, key)
    if (!start) return ""
    rest = substr($0, start + length(key))
    if (substr(rest, 1, 1) == "\"") {
      rest = substr(rest, 2)
      stop = index(rest, "\"")
      return stop ? substr(rest, 1, stop - 1) : ""
    }
    return match(rest, /^([0-9]+|true)/) ? substr(rest, 1, RLENGTH) : ""
  }
  function minutes(ms) { return sprintf("%.1f", ms / 60000) }
  function is_absence(ms) { return ms > absence_ms }
  function human_share(ms) { return is_absence(ms) ? 0 : ms }'

# Durées en minutes, une décimale ; « null » quand aucun événement n'a été lu.
#   Session principale, par session : tour = UserPromptSubmit → Stop, questions ouvertes retirées ;
#   temps humain = Stop → prompt « origin: human » suivant, plus la durée des questions ;
#   un écart ou une attente de plus de absence_ms est une absence : zéro minute humaine, question toujours comptée.
#   Un prompt « origin: agent » (retour de délégué) ouvre un tour sans compter d'attente humaine.
#   Un prompt qui arrive sur un tour encore ouvert (message tapé pendant le travail, Échap sans Stop, retour de
#   délégué en plein tour) ferme ce tour à son dernier événement observé avant d'ouvrir le suivant.
readonly DURATIONS_PROGRAM="$AWK_HELPERS"'
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
      if (session in turn_start) parent += last_activity[session] - turn_start[session] - turn_questions[session]
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
    last_activity[session] = ts
  }
  END {
    if (!seen) { print "null null null 0 null null 0 null"; exit }
    count = 0; for (id in runs) count++
    printf "%s %s %s %d %s %s %d %s\n", minutes(parent), minutes(delegated), minutes(human), questions, minutes(question_time), minutes(checks), count, (has_tokens ? tokens : "null")
  }'

# Fenêtre d'une tâche : dernière marque task_start, puis la première task_done qui la suit.
#   Marques de la session principale sans « branch » ; marques d'un délégué (journal de la parente) avec sa branche.
#   Sortie : « début fin raison », « - » pour une valeur absente ; raison late_start, missing_start, missing_done ou ok.
readonly TASK_WINDOW_PROGRAM="$AWK_HELPERS"'
  field("event") == "late_start" { late = 1; next }
  field("task") != task || field("branch") != mark_branch { next }
  field("event") == "task_start" { start = field("ts"); finish = ""; next }
  field("event") == "task_done" && start != "" && finish == "" { finish = field("ts") }
  END {
    reason = late ? "late_start" : (start == "" ? "missing_start" : (finish == "" ? "missing_done" : "ok"))
    printf "%s %s %s\n", (start == "" ? "-" : start), (finish == "" ? "-" : finish), reason
  }'

# Durées d'une tâche, mêmes règles que DURATIONS_PROGRAM, chaque intervalle borné à la fenêtre [window_start, window_end].
#   Un tour ou une exécution de délégué encore ouvert à la fin du journal compte jusqu'à window_end : la marque task_done
#   s'écrit en cours de tour, avant son Stop. Seul le plus récent compte : un tour plus ancien sans Stop est une session
#   interrompue, jamais la tâche en cours. Prompt sur un tour ouvert : même fermeture que DURATIONS_PROGRAM.
#   Sortie : « agent humain questions ».
readonly TASK_DURATIONS_PROGRAM="$AWK_HELPERS"'
  function inside(from, to) {
    if (from < window_start) from = window_start
    if (to > window_end) to = window_end
    return to > from ? to - from : 0
  }
  FNR == 1 { file_index++; reading_parent = (has_parent_log && file_index == 1) }
  reading_parent && field("event") == "delegate" && field("branch") == branch { delegate[field("agent_id")] = 1; next }
  reading_parent {
    id = field("agent_id"); event = field("event"); ts = field("ts") + 0
    if (!(id in delegate)) next
    if (event == "SubagentStart") agent_start[id] = ts
    if (event == "SubagentStop" && (id in agent_start)) { delegated += inside(agent_start[id], ts); delete agent_start[id] }
    next
  }
  field("agent_id") != "" { next }
  {
    event = field("event"); session = field("session"); ts = field("ts") + 0
    if (event == "UserPromptSubmit") {
      if (field("origin") == "human" && (session in last_stop) && !is_absence(ts - last_stop[session])) human += inside(last_stop[session], ts)
      if (session in turn_start) parent += inside(turn_start[session], last_activity[session]) - turn_questions[session]
      delete last_stop[session]; turn_start[session] = ts; turn_questions[session] = 0
    } else if (event == "Stop") {
      if (session in turn_start) parent += inside(turn_start[session], ts) - turn_questions[session]
      delete turn_start[session]; last_stop[session] = ts
    } else if (event == "PreToolUse" && field("tool") == "AskUserQuestion") {
      question_start[session] = ts
    } else if (event == "PostToolUse" && field("tool") == "AskUserQuestion" && (session in question_start)) {
      wait = inside(question_start[session], ts)
      if (wait > 0) { questions++; turn_questions[session] += wait }
      if (!is_absence(ts - question_start[session])) human += wait
      delete question_start[session]
    }
    last_activity[session] = ts
  }
  function latest_open(starts,   key, latest) {
    latest = ""
    for (key in starts) if (latest == "" || starts[key] > starts[latest]) latest = key
    return latest
  }
  END {
    session = latest_open(turn_start)
    if (session != "") parent += inside(turn_start[session], window_end) - turn_questions[session]
    id = latest_open(agent_start)
    if (id != "") delegated += inside(agent_start[id], window_end)
    printf "%s %s %d\n", minutes(parent + delegated), minutes(human), questions
  }'

ROOT="."
BRANCH=""
PARENT_LOG=""
BASE=""
TASK=""

# ── Arguments et gardes ───────────────────────────────────────────────────────

fail_usage() {
  echo "time-aggregate: $1" >&2
  echo "usage: time-aggregate.sh --branch <name> [--root <dir>] [--parent-log <file>] [--base <ref>] [--task T<n>[,T<n>…]]" >&2
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
      --task)       require_value "$1" $#; TASK=$2; shift 2 ;;
      *)            fail_usage "unknown argument $1" ;;
    esac
  done
  [ -n "$BRANCH" ] || fail_usage "--branch is required"
  [ -z "$TASK" ] || [[ $TASK =~ ^T[0-9]+(\.[0-9]+)?(,T[0-9]+(\.[0-9]+)?)*$ ]] || fail_usage "--task needs T<n>[,T<n>…]"
  [ -d "$ROOT" ] || fail_usage "not a directory: $ROOT"
}

# ── Durées ────────────────────────────────────────────────────────────────────

# Journal trié par heure, tri stable : le hook asynchrone ne garantit pas l'ordre d'écriture de deux événements proches.
# Une ligne sans « ts » en tête (delegate, delegate_usage, écrites par le skill) passe en premier : l'association
# d'un délégué à sa branche précède ainsi son SubagentStart, écrit avant que le skill connaisse son identifiant.
sort_by_time() {
  LC_ALL=C sort -s -t: -k2,2n "$1"
}

# Programme awk de durées sur les journaux triés, sortie dans REPLY, laissé intact quand aucun journal n'est lu.
# Le journal parent, quand il est lu, est le premier fichier ; un journal vide n'est jamais passé, pour garder ce rang.
# Usage : run_on_logs <programme> [-v nom=valeur]…
run_on_logs() {
  local program=$1 own_log="$ROOT/.forge/branch/$BRANCH/$TIME_LOG_NAME" has_parent_log=0 has_own_log=0
  shift
  [ -n "$PARENT_LOG" ] && [ -s "$PARENT_LOG" ] && has_parent_log=1
  [ -s "$own_log" ] && has_own_log=1
  local awk_command=(awk -v has_parent_log="$has_parent_log" -v branch="$BRANCH" -v absence_ms="$HUMAN_ABSENCE_MS" "$@" "$program")
  case "$has_parent_log$has_own_log" in
    11) REPLY=$("${awk_command[@]}" <(sort_by_time "$PARENT_LOG") <(sort_by_time "$own_log")) ;;
    10) REPLY=$("${awk_command[@]}" <(sort_by_time "$PARENT_LOG")) ;;
    01) REPLY=$("${awk_command[@]}" <(sort_by_time "$own_log")) ;;
  esac
}

# Sortie de DURATIONS_PROGRAM : « parent délégués humain questions attente vérifications délégués_lancés tokens ».
read_durations() {
  REPLY="null null null 0 null null 0 null"
  run_on_logs "$DURATIONS_PROGRAM"
}

# ── Tâche ─────────────────────────────────────────────────────────────────────

# « début fin raison » de la tâche, lu dans le journal qui porte ses marques : celui de la parente pour un délégué
# (marques portant la branche), sinon celui de la branche ; raison no_log sans ce journal.
read_task_window() {
  local task=$1 marks_log="$ROOT/.forge/branch/$BRANCH/$TIME_LOG_NAME" mark_branch=""
  [ -n "$PARENT_LOG" ] && { marks_log=$PARENT_LOG; mark_branch=$BRANCH; }
  REPLY="- - no_log"
  [ -s "$marks_log" ] || return
  REPLY=$(sort_by_time "$marks_log" | awk -v task="$task" -v mark_branch="$mark_branch" "$TASK_WINDOW_PROGRAM")
}

# « agent humain questions » d'une tâche dans REPLY, ou « raison » seule quand elle n'est pas mesurée.
measure_task() {
  local window_start window_end reason
  read_task_window "$1"
  read -r window_start window_end reason <<< "$REPLY"
  [ "$reason" = "ok" ] || { REPLY=$reason; return; }
  REPLY="0.0 0.0 0"
  run_on_logs "$TASK_DURATIONS_PROGRAM" -v window_start="$window_start" -v window_end="$window_end"
}

render_task() {
  local agent=$1 human=$2 questions=$3 reason=$4 branch_json task_json measured=true reason_json=null
  if [ "$reason" != "ok" ]; then
    measured=false; reason_json="\"$reason\""
  fi
  json_escape "$BRANCH"; branch_json=$REPLY
  json_escape "$TASK"; task_json=$REPLY
  printf '{"branch":%s,"task":%s,"agent_minutes":%s,"human_minutes":%s,"questions":%s,"measured":%s,"reason":%s}\n' \
    "$branch_json" "$task_json" "$agent" "$human" "$questions" "$measured" "$reason_json"
}

# Mesure d'une ou plusieurs tâches (T1,T4 : tâches enfant d'une même tâche parente), sommées.
# BUSINESS_RULE: une seule tâche non mesurée rend la somme non mesurée — jamais de somme partielle présentée comme complète
aggregate_task() {
  local task totals="0.0 0.0 0" tasks
  IFS=, read -ra tasks <<< "$TASK"
  for task in "${tasks[@]}"; do
    measure_task "$task"
    case $REPLY in
      *" "*) totals=$(awk -v a="$totals" -v b="$REPLY" 'BEGIN { split(a, x, " "); split(b, y, " ")
                printf "%.1f %.1f %d", x[1] + y[1], x[2] + y[2], x[3] + y[3] }') ;;
      *)     render_task null null null "$REPLY"; return ;;
    esac
  done
  # shellcheck disable=SC2086 — découpage voulu des champs numériques
  render_task $totals ok
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

# ── Couverture ────────────────────────────────────────────────────────────────

# « true » si le journal de la branche ne couvre pas son début, « false » sinon — sans journal, rien à écarter.
read_partial() {
  local start=$1 own_log="$ROOT/.forge/branch/$BRANCH/$TIME_LOG_NAME" first_event first_commit
  REPLY=false
  [ -s "$own_log" ] || return
  grep -q '"event":"late_start"' "$own_log" && { REPLY=true; return; }
  [ -n "$start" ] || return
  first_event=$(sort_by_time "$own_log" | awk -F '[:,]' '/^\{"ts":/ { print $2; exit }')
  first_commit=$(git -C "$ROOT" log --reverse --format=%ct "$start..HEAD" 2>/dev/null | head -1)
  [ -n "$first_event" ] && [ -n "$first_commit" ] && [ $((first_commit * 1000)) -lt "$first_event" ] && REPLY=true
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
  local files=$9 added=${10} deleted=${11} partial=${12} mode branch_json
  resolve_mode "$parent" "$delegated"; mode=$REPLY
  json_escape "$BRANCH"; branch_json=$REPLY
  printf '{"branch":%s,"parent_minutes":%s,"delegated_minutes":%s,"human_minutes":%s,' "$branch_json" "$parent" "$delegated" "$human"
  printf '"questions":%s,"question_minutes":%s,"check_minutes":%s,"delegates":%s,"mode":%s,' "$questions" "$question_time" "$checks" "$delegates" "$mode"
  printf '"tokens":%s,"files":%s,"lines_added":%s,"lines_deleted":%s,"partial":%s}\n' "$tokens" "$files" "$added" "$deleted" "$partial"
}

main() {
  local durations volume start partial
  parse_arguments "$@"
  [ -z "$TASK" ] || { aggregate_task; return; }
  read_durations; durations=$REPLY
  resolve_start_point; start=$REPLY
  read_volume "$start"; volume=$REPLY
  read_partial "$start"; partial=$REPLY
  # shellcheck disable=SC2086 — découpage voulu des champs numériques
  render $durations $volume "$partial"
}

main "$@"
