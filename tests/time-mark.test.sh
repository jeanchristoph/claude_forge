#!/bin/bash
# Tests de skills/forge/scripts/time-mark.sh — chaque test tourne dans un dossier jetable, jamais le dépôt courant.
# Usage : bash tests/time-mark.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARK_SCRIPT="$REPO_ROOT/skills/forge/scripts/time-mark.sh"
. "$REPO_ROOT/tests/test-runner.sh"

# ── Bac à sable ───────────────────────────────────────────────────────────────

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  WORK="$SANDBOX/work"
  mkdir -p "$WORK/.forge/branch/feature"
  OWN_LOG="$WORK/.forge/branch/feature/time-log.jsonl"
  PARENT_LOG="$SANDBOX/parent-time-log.jsonl"
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

mark() {
  bash "$MARK_SCRIPT" --root "$WORK" --branch feature "$@"
}

# ── Assertions — chaque test tourne dans un sous-shell, un échec en sort ──────

assert_equals() {
  [ "$1" = "$2" ] && return 0
  printf '    expected: %s\n    actual:   %s\n' "$1" "$2"
  exit 1
}

assert_matches() {
  [[ $2 =~ $1 ]] && return 0
  printf '    pattern: %s\n    actual:  %s\n' "$1" "$2"
  exit 1
}

# ── Marques ───────────────────────────────────────────────────────────────────

test_appends_start_then_done_to_branch_log() {
  : > "$OWN_LOG"
  mark --task T3 --event start
  mark --task T3 --event done
  assert_equals 2 "$(wc -l < "$OWN_LOG" | tr -d ' ')"
  assert_matches '^\{"ts":[0-9]{13},"event":"task_start","task":"T3"\}$' "$(sed -n 1p "$OWN_LOG")"
  assert_matches '^\{"ts":[0-9]{13},"event":"task_done","task":"T3"\}$' "$(sed -n 2p "$OWN_LOG")"
}

test_keeps_existing_lines() {
  printf '{"ts":1,"event":"Stop","session":"s1"}\n' > "$OWN_LOG"
  mark --task T1 --event start
  assert_equals '{"ts":1,"event":"Stop","session":"s1"}' "$(sed -n 1p "$OWN_LOG")"
  assert_equals 2 "$(wc -l < "$OWN_LOG" | tr -d ' ')"
}

test_delegate_mark_goes_to_parent_log_with_branch() {
  : > "$PARENT_LOG"
  mark --task T2 --event done --time-log "$PARENT_LOG"
  assert_matches '^\{"ts":[0-9]{13},"event":"task_done","task":"T2","branch":"feature"\}$' "$(cat "$PARENT_LOG")"
  [ ! -e "$OWN_LOG" ] || { echo "    own log written"; exit 1; }
}

test_escapes_branch_name() {
  : > "$PARENT_LOG"
  bash "$MARK_SCRIPT" --root "$WORK" --branch 'odd"name' --task T1 --event start --time-log "$PARENT_LOG"
  assert_matches '"branch":"odd\\"name"\}$' "$(cat "$PARENT_LOG")"
}

test_accepts_micro_step() {
  : > "$OWN_LOG"
  mark --task T2.1 --event start
  assert_matches '"task":"T2.1"\}$' "$(cat "$OWN_LOG")"
}

# ── Lignes de délégué ─────────────────────────────────────────────────────────

test_writes_delegate_line_without_timestamp() {
  : > "$PARENT_LOG"
  bash "$MARK_SCRIPT" --time-log "$PARENT_LOG" --event delegate --agent-id a1b2 --branch 'feat/x'
  assert_equals '{"event":"delegate","agent_id":"a1b2","branch":"feat/x"}' "$(cat "$PARENT_LOG")"
}

test_writes_delegate_usage_line_with_tokens() {
  : > "$PARENT_LOG"
  bash "$MARK_SCRIPT" --time-log "$PARENT_LOG" --event delegate_usage --agent-id a1b2 --tokens 0123456
  assert_equals '{"event":"delegate_usage","agent_id":"a1b2","tokens":123456}' "$(cat "$PARENT_LOG")"
}

test_writes_no_delegate_line_on_invalid_arguments() {
  : > "$PARENT_LOG"
  bash "$MARK_SCRIPT" --time-log "$PARENT_LOG" --event delegate --agent-id a1b2 || exit 1
  bash "$MARK_SCRIPT" --time-log "$PARENT_LOG" --event delegate_usage --agent-id a1b2 --tokens 12k || exit 1
  bash "$MARK_SCRIPT" --time-log "$PARENT_LOG" --event delegate_usage --tokens 12 || exit 1
  bash "$MARK_SCRIPT" --root "$WORK" --event delegate --agent-id a1b2 --branch feature || exit 1
  assert_equals 0 "$(wc -c < "$PARENT_LOG" | tr -d ' ')"
  [ ! -e "$OWN_LOG" ] || { echo "    own log written"; exit 1; }
}

test_ignores_removed_merge_marks() {
  : > "$PARENT_LOG"
  bash "$MARK_SCRIPT" --time-log "$PARENT_LOG" --event merge_start --branch 'parent-a' || exit 1
  assert_equals 0 "$(wc -c < "$PARENT_LOG" | tr -d ' ')"
}

# ── Rien d'écrit ──────────────────────────────────────────────────────────────

test_writes_nothing_without_log() {
  mark --task T1 --event start
  [ ! -e "$OWN_LOG" ] || { echo "    log created"; exit 1; }
}

test_writes_nothing_without_parent_log() {
  mark --task T1 --event start --time-log "$PARENT_LOG"
  [ ! -e "$PARENT_LOG" ] || { echo "    parent log created"; exit 1; }
}

test_exits_zero_and_writes_nothing_on_invalid_arguments() {
  : > "$OWN_LOG"
  mark --task T1 --event finish || exit 1
  mark --task 3 --event start || exit 1
  mark --event start || exit 1
  mark --task T1 --event || exit 1
  mark --task T1 --event start --unknown x || exit 1
  bash "$MARK_SCRIPT" --root "$WORK" --task T1 --event start || exit 1
  assert_equals 0 "$(wc -c < "$OWN_LOG" | tr -d ' ')"
}

# Bash < 5 n'a pas EPOCHREALTIME : variable retirée dans le shell qui exécute le marqueur.
test_exits_zero_and_writes_nothing_without_clock() {
  : > "$OWN_LOG"
  local output
  output=$(bash -c 'unset EPOCHREALTIME; script=$1; shift; . "$script"' mark "$MARK_SCRIPT" \
    --root "$WORK" --branch feature --task T1 --event start)
  assert_equals "0" "$?"
  assert_equals "" "$output"
  assert_equals "" "$(cat "$OWN_LOG")"
}

test_writes_nothing_on_stdout() {
  : > "$OWN_LOG"
  assert_equals "" "$(mark --task T1 --event start; mark --task T1 --event bad; mark --task T1 --event done --time-log "$PARENT_LOG")"
}

# ── Exécution ─────────────────────────────────────────────────────────────────

echo "time-mark.sh"
run_test test_appends_start_then_done_to_branch_log "ajoute la marque de début puis de fin au journal de la branche"
run_test test_keeps_existing_lines "garde les lignes déjà présentes du journal"
run_test test_delegate_mark_goes_to_parent_log_with_branch "range la marque d'un délégué dans le journal du parent, avec sa branche"
run_test test_escapes_branch_name "échappe le nom de branche"
run_test test_accepts_micro_step "accepte une micro-étape T2.1"
run_test test_writes_delegate_line_without_timestamp "écrit la ligne delegate sans horodatage"
run_test test_writes_delegate_usage_line_with_tokens "écrit la ligne delegate_usage avec ses tokens"
run_test test_writes_no_delegate_line_on_invalid_arguments "n'écrit aucune ligne de délégué sur des arguments invalides"
run_test test_ignores_removed_merge_marks "ignore les anciennes marques de fusion, sans erreur"
run_test test_writes_nothing_without_log "n'écrit rien sans journal de la branche"
run_test test_writes_nothing_without_parent_log "n'écrit rien sans journal du parent"
run_test test_exits_zero_and_writes_nothing_on_invalid_arguments "sort en 0 sans rien écrire sur des arguments invalides"
run_test test_exits_zero_and_writes_nothing_without_clock "sort en 0 sans rien écrire sans horloge EPOCHREALTIME (bash < 5)"
run_test test_writes_nothing_on_stdout "n'écrit rien sur la sortie standard"

report_results
