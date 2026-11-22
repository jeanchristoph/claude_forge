#!/bin/bash
# Tests de skills/forge/scripts/metrics.sh — chaque test tourne dans un dépôt jetable, jamais le dépôt courant.
# Usage : bash tests/metrics.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
METRICS_SCRIPT="$REPO_ROOT/skills/forge/scripts/metrics.sh"
PASSED=0
FAILED=0

readonly FIELD_ORDER="event,date,branch,mode,model,planned_files,actual_files,branch_files,lines_added,lines_deleted,agent_minutes,human_minutes,questions,check_minutes,tokens,partial,delegate_setup_minutes,merge_minutes"

# ── Bac à sable ───────────────────────────────────────────────────────────────

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  WORK="$SANDBOX/work"
  BRANCH_DIR="$WORK/.forge/branch/feature"
  LOG="$BRANCH_DIR/time-log.jsonl"
  git init -q -b master "$WORK"
  git -C "$WORK" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$WORK" checkout -q -b feature
  mkdir -p "$BRANCH_DIR"
  printf '# Plan — feature\n**Date:** 2026-11-22\n**Estimate:** ≈ 3 files · ≈ 2 min (1-3) · indicative\n\n## Tasks\n\n### T1 — Un\n**Effort:** S\n**Files:** `a.txt`, `b.txt`\n[x]\n' > "$BRANCH_DIR/plan.md"
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

metrics() {
  bash "$METRICS_SCRIPT" --root "$WORK" --branch feature --model claude-test "$@"
}

# Un tour de deux minutes, à partir de maintenant moins dix minutes.
write_turn() {
  local start=$(( $(date +%s) * 1000 - 600000 ))
  printf '{"ts":%s,"event":"UserPromptSubmit","session":"s1","origin":"human"}\n{"ts":%s,"event":"Stop","session":"s1"}\n' \
    "$start" $((start + 120000)) > "$LOG"
}

field_names() {
  grep -o '"[a-z_]*":' "$1" | tr -d '":' | paste -sd, -
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

# ── Tests ─────────────────────────────────────────────────────────────────────

test_writes_one_line_with_fixed_field_order() {
  write_turn
  metrics --event engrave >/dev/null
  assert_equals 1 "$(wc -l < "$BRANCH_DIR/metrics.json" | tr -d ' ')"
  assert_equals "$FIELD_ORDER" "$(field_names "$BRANCH_DIR/metrics.json")"
  assert_matches '^\{"event":"engrave","date":"[0-9]{4}-[0-9]{2}-[0-9]{2}","branch":"feature","mode":"parent","model":"claude-test",' "$(cat "$BRANCH_DIR/metrics.json")"
}

test_agent_minutes_sum_parent_and_delegates() {
  write_turn
  metrics --event engrave >/dev/null
  assert_matches '"agent_minutes":2\.0,' "$(cat "$BRANCH_DIR/metrics.json")"
}

test_durations_are_null_without_log() {
  metrics --event engrave >/dev/null
  assert_matches '"agent_minutes":null,"human_minutes":null,' "$(cat "$BRANCH_DIR/metrics.json")"
}

test_branch_files_used_without_measured_task() {
  echo a > "$WORK/a.txt"
  metrics --event engrave >/dev/null
  assert_matches '"planned_files":null,"actual_files":1,"branch_files":1,' "$(cat "$BRANCH_DIR/metrics.json")"
}

test_task_files_used_when_a_task_is_measured() {
  local now=$(( $(date +%s) * 1000 ))
  printf '{"ts":%s,"event":"task_start","task":"T1","files":""}\n{"ts":%s,"event":"task_done","task":"T1","files":"a.txt\\tabc123abc123"}\n' \
    $((now - 60000)) "$now" > "$LOG"
  echo a > "$WORK/a.txt"
  echo c > "$WORK/c.txt"
  metrics --event engrave >/dev/null
  assert_matches '"planned_files":2,"actual_files":1,"branch_files":2,' "$(cat "$BRANCH_DIR/metrics.json")"
}

test_closure_event_is_recorded() {
  metrics --event closure >/dev/null
  assert_matches '^\{"event":"closure",' "$(cat "$BRANCH_DIR/metrics.json")"
}

test_report_carries_estimate_from_plan_header() {
  write_turn
  local report
  report=$(metrics --event engrave)
  assert_matches '"planned_files":null,"estimated_minutes":2,"estimated_low":1,"estimated_high":3,"actual_files":0,"agent_minutes":2\.0,"partial":false\}$' "$report"
}

test_report_estimate_is_null_without_header() {
  sed -i '/^\*\*Estimate:\*\*/d' "$BRANCH_DIR/plan.md"
  assert_matches '"estimated_minutes":null,"estimated_low":null,"estimated_high":null,' "$(metrics --event engrave)"
}

test_rejects_missing_model_and_unknown_event() {
  bash "$METRICS_SCRIPT" --root "$WORK" --branch feature --event engrave >/dev/null 2>&1 && exit 1
  metrics --event ship >/dev/null 2>&1 && exit 1
  [ ! -e "$BRANCH_DIR/metrics.json" ]
}

# ── Exécution ─────────────────────────────────────────────────────────────────

run_test() {
  setup_sandbox
  if ( "$1" ); then
    PASSED=$((PASSED + 1)); echo "  ok   $2"
  else
    FAILED=$((FAILED + 1)); echo "  FAIL $2"
  fi
  teardown_sandbox
}

run_test test_writes_one_line_with_fixed_field_order "écrit metrics.json sur une ligne, champs dans l'ordre figé"
run_test test_agent_minutes_sum_parent_and_delegates "minutes d'agent : somme du parent et des délégués"
run_test test_durations_are_null_without_log "sans journal, durées à null"
run_test test_branch_files_used_without_measured_task "sans tâche mesurée : prévus null, réels = fichiers de la branche"
run_test test_task_files_used_when_a_task_is_measured "tâche mesurée : prévus et réels comptés par tâche"
run_test test_closure_event_is_recorded "événement closure écrit tel quel"
run_test test_report_carries_estimate_from_plan_header "le compte rendu porte l'estimé de l'en-tête Estimate et le réel"
run_test test_report_estimate_is_null_without_header "sans en-tête Estimate, estimé à null"
run_test test_rejects_missing_model_and_unknown_event "refuse un modèle absent ou un événement inconnu, rien d'écrit"

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
