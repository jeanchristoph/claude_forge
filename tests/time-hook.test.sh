#!/bin/bash
# Tests de skills/forge/scripts/time-hook.sh — chaque test tourne dans un dépôt jetable
# sur master, jamais le dépôt courant.
# Usage : bash tests/time-hook.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_SCRIPT="$REPO_ROOT/skills/forge/scripts/time-hook.sh"
PASSED=0
FAILED=0

# ── Bac à sable ───────────────────────────────────────────────────────────────

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  WORK="$SANDBOX/work"
  git init -q "$WORK"
  git -C "$WORK" config user.name "Forge Test"
  git -C "$WORK" config user.email "forge@test.local"
  git -C "$WORK" config commit.gpgsign false
  git -C "$WORK" config core.autocrlf false
  git -C "$WORK" symbolic-ref HEAD refs/heads/master
  printf 'initial\n' > "$WORK/readme.txt"
  git -C "$WORK" add readme.txt
  git -C "$WORK" commit -q -m "initial"
  mkdir -p "$WORK/.forge/branch/master"
  TIME_LOG="$WORK/.forge/branch/master/time-log.jsonl"
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

# cwd au format Windows échappé quand le système en a un (C:\\Users\\…), tel que Claude Code l'envoie.
escaped_cwd() {
  local path
  path=$(cd "$1" && pwd -W 2>/dev/null || pwd)
  path=${path//\//\\\\}
  printf '%s' "$path"
}

run_hook() {
  printf '%s' "$1" | bash "$HOOK_SCRIPT"
}

event_json() {
  printf '{"session_id":"s1","transcript_path":"/tmp/t.jsonl","cwd":"%s","hook_event_name":"%s"%s}' \
    "$(escaped_cwd "$WORK")" "$1" "${2:-}"
}

# ── Assertions — chaque test tourne dans un sous-shell, un échec en sort ──────

assert_equals() {
  [ "$1" = "$2" ] && return 0
  printf '    expected: %s\n    actual:   %s\n' "$1" "$2"
  exit 1
}

assert_contains() {
  case $2 in *"$1"*) return 0 ;; esac
  printf '    missing:  %s\n    in:\n%s\n' "$1" "$2"
  exit 1
}

assert_not_contains() {
  case $2 in *"$1"*) printf '    unexpected: %s\n    in:\n%s\n' "$1" "$2"; exit 1 ;; esac
}

logged() {
  cat "$TIME_LOG" 2>/dev/null
}

# ── Événements retenus ────────────────────────────────────────────────────────

test_logs_stop_with_timestamp_and_session() {
  run_hook "$(event_json Stop ',"stop_hook_active":false,"last_assistant_message":"fini"')"
  local line
  line=$(logged)
  assert_contains '"event":"Stop"' "$line"
  assert_contains '"session":"s1"' "$line"
  [[ $line =~ ^\{\"ts\":[0-9]{13}, ]] || { echo "    timestamp missing: $line"; exit 1; }
}

test_marks_human_prompt() {
  run_hook "$(event_json UserPromptSubmit ',"prompt":"/forge go"')"
  assert_contains '"origin":"human"' "$(logged)"
}

test_marks_agent_message_prompt_as_agent() {
  run_hook "$(event_json UserPromptSubmit ',"prompt":"<agent-message from=\"a1\">\nrapport"')"
  assert_contains '"origin":"agent"' "$(logged)"
}

test_marks_task_notification_prompt_as_agent() {
  run_hook "$(event_json UserPromptSubmit ',"prompt":"<task-notification>\n<task-id>x</task-id>"')"
  assert_contains '"origin":"agent"' "$(logged)"
}

test_logs_subagent_start_with_agent_id() {
  run_hook "$(event_json SubagentStart ',"agent_id":"a42","agent_type":"general-purpose"')"
  local line
  line=$(logged)
  assert_contains '"event":"SubagentStart"' "$line"
  assert_contains '"agent_id":"a42"' "$line"
}

test_logs_delegate_tool_event_in_parent_log() {
  run_hook "$(event_json PostToolUse ',"agent_id":"a42","agent_type":"general-purpose","tool_name":"Bash","tool_input":{"command":"ls"},"duration_ms":120')"
  local line
  line=$(logged)
  assert_contains '"agent_id":"a42"' "$line"
  assert_contains '"duration_ms":120' "$line"
}

test_logs_question_open_and_close() {
  run_hook "$(event_json PreToolUse ',"tool_name":"AskUserQuestion","tool_input":{}')"
  run_hook "$(event_json PostToolUse ',"tool_name":"AskUserQuestion","tool_input":{},"duration_ms":45000')"
  local log
  log=$(logged)
  assert_contains '"event":"PreToolUse","session":"s1","tool":"AskUserQuestion"}' "$log"
  assert_contains '"tool":"AskUserQuestion","duration_ms":45000}' "$log"
}

test_marks_check_command_matching_project_pattern() {
  printf '# Project\n**Check pattern:** `^bash tests/.*\\.test\\.sh`\n' > "$WORK/.forge/project.md"
  run_hook "$(event_json PostToolUse ',"tool_name":"Bash","tool_input":{"command":"bash tests/status.test.sh"},"duration_ms":3000')"
  assert_contains '"check":true' "$(logged)"
}

test_does_not_mark_other_command_as_check() {
  printf '# Project\n**Check pattern:** `^bash tests/`\n' > "$WORK/.forge/project.md"
  run_hook "$(event_json PostToolUse ',"tool_name":"Bash","tool_input":{"command":"git status"},"duration_ms":30')"
  assert_not_contains '"check"' "$(logged)"
}

test_marks_no_check_without_project_pattern() {
  printf '# Project\n' > "$WORK/.forge/project.md"
  run_hook "$(event_json PostToolUse ',"tool_name":"Bash","tool_input":{"command":"bash tests/a.test.sh"},"duration_ms":30')"
  assert_not_contains '"check"' "$(logged)"
}

test_reads_check_pattern_from_crlf_project() {
  printf '# Project\r\n**Check pattern:** `^npm test`\r\n' > "$WORK/.forge/project.md"
  run_hook "$(event_json PostToolUse ',"tool_name":"Bash","tool_input":{"command":"npm test"},"duration_ms":30')"
  assert_contains '"check":true' "$(logged)"
}

# ── Confidentialité ───────────────────────────────────────────────────────────

test_keeps_no_prompt_command_or_response_content() {
  run_hook "$(event_json UserPromptSubmit ',"prompt":"mot-de-passe-secret"')"
  run_hook "$(event_json PostToolUse ',"tool_name":"Bash","tool_input":{"command":"echo commande-secrete"},"tool_response":{"stdout":"sortie-secrete"},"duration_ms":5')"
  local log
  log=$(logged)
  assert_not_contains 'secret' "$log"
  assert_not_contains 'transcript' "$log"
}

test_ignores_field_names_inside_escaped_strings() {
  run_hook "$(event_json PostToolUse ',"tool_name":"Bash","tool_input":{"command":"echo \"agent_id\":\"fake\""},"duration_ms":7')"
  assert_not_contains 'fake' "$(logged)"
}

# ── Événements écartés ────────────────────────────────────────────────────────

test_ignores_internal_subagent_without_type() {
  run_hook "$(event_json SubagentStop ',"agent_id":"a1","agent_type":""')"
  assert_equals "" "$(logged)"
}

test_ignores_other_tools() {
  run_hook "$(event_json PostToolUse ',"tool_name":"Read","tool_input":{},"duration_ms":3')"
  assert_equals "" "$(logged)"
}

test_ignores_other_events() {
  run_hook "$(event_json SessionStart)"
  assert_equals "" "$(logged)"
}

test_writes_nothing_for_unforged_branch() {
  git -C "$WORK" checkout -q -b feature
  run_hook "$(event_json Stop)"
  assert_equals "master" "$(ls "$WORK/.forge/branch")"
  assert_equals "" "$(logged)"
}

test_writes_nothing_outside_git() {
  local outside="$SANDBOX/outside"
  mkdir -p "$outside"
  run_hook "{\"cwd\":\"$(escaped_cwd "$outside")\",\"hook_event_name\":\"Stop\"}"
  assert_equals "" "$(ls -A "$outside")"
}

test_writes_nothing_on_detached_head() {
  git -C "$WORK" checkout -q --detach
  run_hook "$(event_json Stop)"
  assert_equals "" "$(logged)"
  assert_equals "" "$(ls "$WORK/.forge/branch/master")"
}

# ── Garanties du hook ─────────────────────────────────────────────────────────

test_exits_zero_and_writes_nothing_on_invalid_input() {
  local output
  output=$(printf 'pas du json' | bash "$HOOK_SCRIPT")
  assert_equals "0" "$?"
  assert_equals "" "$output"
}

test_writes_nothing_on_stdout() {
  local output
  output=$(run_hook "$(event_json Stop)")
  assert_equals "" "$output"
}

test_appends_one_line_per_event() {
  run_hook "$(event_json UserPromptSubmit ',"prompt":"go"')"
  run_hook "$(event_json Stop)"
  assert_equals "2" "$(logged | wc -l | tr -d ' ')"
}

test_marks_late_start_when_plan_exists_before_log() {
  printf '# Plan\n' > "$WORK/.forge/branch/master/plan.md"
  run_hook "$(event_json Stop)"
  run_hook "$(event_json Stop)"
  assert_equals "1" "$(logged | grep -c '"event":"late_start"')"
  assert_contains '"event":"late_start"' "$(logged | head -1)"
}

test_marks_no_late_start_without_plan() {
  run_hook "$(event_json Stop)"
  assert_not_contains 'late_start' "$(logged)"
}

test_resolves_branch_containing_a_slash() {
  git -C "$WORK" checkout -q -b feature/x
  mkdir -p "$WORK/.forge/branch/feature/x"
  run_hook "$(event_json Stop)"
  assert_contains '"event":"Stop"' "$(cat "$WORK/.forge/branch/feature/x/time-log.jsonl")"
}

run_test() {
  local result
  setup_sandbox
  ( "$1" )
  result=$?
  teardown_sandbox
  if [ $result -eq 0 ]; then
    PASSED=$((PASSED + 1))
    echo "  ok   $2"
  else
    FAILED=$((FAILED + 1))
    echo "  FAIL $2"
  fi
}

echo "time-hook.sh"
run_test test_logs_stop_with_timestamp_and_session "journalise Stop avec horodatage en millisecondes et session"
run_test test_marks_human_prompt "marque human un prompt saisi par l'utilisateur"
run_test test_marks_agent_message_prompt_as_agent "marque agent le retour d'un délégué"
run_test test_marks_task_notification_prompt_as_agent "marque agent une notification de tâche de fond"
run_test test_logs_subagent_start_with_agent_id "journalise SubagentStart avec l'identifiant du délégué"
run_test test_logs_delegate_tool_event_in_parent_log "range l'outil d'un délégué dans le journal du parent, avec sa durée"
run_test test_logs_question_open_and_close "journalise l'ouverture et la réponse d'une question"
run_test test_marks_check_command_matching_project_pattern "marque check une commande conforme au motif du projet"
run_test test_does_not_mark_other_command_as_check "ne marque pas check une autre commande"
run_test test_marks_no_check_without_project_pattern "ne marque rien sans motif de vérification dans project.md"
run_test test_reads_check_pattern_from_crlf_project "lit le motif d'un project.md en fins de ligne CRLF"
run_test test_keeps_no_prompt_command_or_response_content "ne garde ni prompt, ni commande, ni réponse d'outil"
run_test test_ignores_field_names_inside_escaped_strings "ignore un nom de champ cité dans une chaîne échappée"
run_test test_ignores_internal_subagent_without_type "écarte un sous-agent interne sans type"
run_test test_ignores_other_tools "écarte les outils autres que Bash et AskUserQuestion"
run_test test_ignores_other_events "écarte les événements non écoutés"
run_test test_writes_nothing_for_unforged_branch "n'écrit rien pour une branche sans dossier forge"
run_test test_writes_nothing_outside_git "n'écrit rien hors dépôt git"
run_test test_writes_nothing_on_detached_head "n'écrit rien en tête détachée"
run_test test_exits_zero_and_writes_nothing_on_invalid_input "sort en 0 sans rien écrire sur une entrée invalide"
run_test test_writes_nothing_on_stdout "n'écrit rien sur la sortie standard"
run_test test_appends_one_line_per_event "ajoute une ligne par événement"
run_test test_marks_late_start_when_plan_exists_before_log "marque un départ tardif quand le plan existe avant le journal"
run_test test_marks_no_late_start_without_plan "ne marque aucun départ tardif sans plan"
run_test test_resolves_branch_containing_a_slash "résout une branche contenant un slash"

echo "$PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ]
