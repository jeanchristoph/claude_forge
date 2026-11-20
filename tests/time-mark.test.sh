#!/bin/bash
# Tests de skills/forge/scripts/time-mark.sh — chaque test tourne dans un dossier jetable, jamais le dépôt courant.
# Usage : bash tests/time-mark.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARK_SCRIPT="$REPO_ROOT/skills/forge/scripts/time-mark.sh"
PASSED=0
FAILED=0

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

test_writes_nothing_on_stdout() {
  : > "$OWN_LOG"
  assert_equals "" "$(mark --task T1 --event start; mark --task T1 --event bad; mark --task T1 --event done --time-log "$PARENT_LOG")"
}

# ── Exécution ─────────────────────────────────────────────────────────────────

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

echo "time-mark.sh"
run_test test_appends_start_then_done_to_branch_log "ajoute la marque de début puis de fin au journal de la branche"
run_test test_keeps_existing_lines "garde les lignes déjà présentes du journal"
run_test test_delegate_mark_goes_to_parent_log_with_branch "range la marque d'un délégué dans le journal du parent, avec sa branche"
run_test test_escapes_branch_name "échappe le nom de branche"
run_test test_writes_nothing_without_log "n'écrit rien sans journal de la branche"
run_test test_writes_nothing_without_parent_log "n'écrit rien sans journal du parent"
run_test test_exits_zero_and_writes_nothing_on_invalid_arguments "sort en 0 sans rien écrire sur des arguments invalides"
run_test test_writes_nothing_on_stdout "n'écrit rien sur la sortie standard"

echo "$PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ]
