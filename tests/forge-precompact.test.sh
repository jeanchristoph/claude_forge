#!/bin/bash
# Tests du hook d'état skills/forge/hooks/forge-precompact.sh — chaque test tourne dans un dépôt jetable
# sur la branche feature, jamais le dépôt courant. Le hook exige node : sans lui, les tests sont sautés.
# Usage : bash tests/forge-precompact.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_SCRIPT="$REPO_ROOT/skills/forge/hooks/forge-precompact.sh"
PASSED=0
FAILED=0
SKIPPED=0

# ── Bac à sable ───────────────────────────────────────────────────────────────

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  WORK="$SANDBOX/work"
  git init -q "$WORK"
  git -C "$WORK" symbolic-ref HEAD refs/heads/feature
  BRANCH_DIR="$WORK/.forge/branch/feature"
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

write_branch_state() {
  mkdir -p "$BRANCH_DIR"
  printf '# Brief\n\n## Objective\n\nRefondre la facturation.\n\n## Scope & rules\n\n- jamais de SQL libre\n' > "$BRANCH_DIR/brief.md"
  printf '# Plan — feature\n\n## Tasks\n\n### T1 — Modèle\n[ ]\n' > "$BRANCH_DIR/plan.md"
  printf -- '- [2026-11-22 10:04] quatrième\n- [2026-11-22 10:03] troisième\n- [2026-11-22 10:02] deuxième\n- [2026-11-22 10:01] première\n' > "$BRANCH_DIR/log.md"
}

# Hook lancé depuis le dépôt jetable, entrée JSON passée sur stdin.
run_hook() {
  (cd "$WORK" && printf '%s' "$1" | bash "$HOOK_SCRIPT")
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

# ── Contenu injecté ───────────────────────────────────────────────────────────

test_injects_objective_plan_and_last_three_log_entries() {
  write_branch_state
  local output
  output=$(run_hook '{"hook_event_name":"PreCompact"}')
  assert_contains '[FORGE STATE]' "$output"
  assert_contains 'Refondre la facturation.' "$output"
  assert_contains '### T1 — Modèle' "$output"
  assert_contains 'quatrième' "$output"
  assert_contains 'deuxième' "$output"
  assert_not_contains 'première' "$output"
  assert_not_contains 'jamais de SQL libre' "$output"
}

test_names_pre_compact_event() {
  write_branch_state
  assert_contains '"hookEventName":"PreCompact"' "$(run_hook '{"hook_event_name":"PreCompact"}')"
}

test_names_session_start_event() {
  write_branch_state
  assert_contains '"hookEventName":"SessionStart"' "$(run_hook '{"hook_event_name":"SessionStart","source":"compact"}')"
}

test_defaults_to_pre_compact_without_event_name() {
  write_branch_state
  assert_contains '"hookEventName":"PreCompact"' "$(run_hook '{}')"
}

test_reads_project_from_cwd_of_input() {
  write_branch_state
  local cwd output
  cwd=$WORK
  command -v cygpath > /dev/null 2>&1 && cwd=$(cygpath -m "$WORK")
  output=$(cd "$SANDBOX" && printf '{"hook_event_name":"SessionStart","cwd":"%s"}' "$cwd" | bash "$HOOK_SCRIPT")
  assert_contains 'Refondre la facturation.' "$output"
}

test_injects_plan_without_brief_or_log() {
  mkdir -p "$BRANCH_DIR"
  printf '# Plan — feature\n' > "$BRANCH_DIR/plan.md"
  local output
  output=$(run_hook '{}')
  assert_contains '# Plan — feature' "$output"
  assert_not_contains 'Objective' "$output"
  assert_not_contains 'Last log entries' "$output"
}

# ── Silence ───────────────────────────────────────────────────────────────────

test_writes_nothing_without_plan() {
  mkdir -p "$BRANCH_DIR"
  assert_equals '' "$(run_hook '{}')"
}

test_writes_nothing_outside_git() {
  rm -rf "$WORK/.git"
  write_branch_state
  assert_equals '' "$(run_hook '{}')"
}

test_exits_zero_without_plan() {
  run_hook '{}' > /dev/null
  assert_equals 0 $?
}

# ── Exécution ─────────────────────────────────────────────────────────────────

run_test() {
  if ! command -v node > /dev/null 2>&1; then
    SKIPPED=$((SKIPPED + 1))
    echo "  skip $2 (node absent)"
    return
  fi
  setup_sandbox
  if ( set -u; $1 ); then
    PASSED=$((PASSED + 1))
    echo "  ok   $2"
  else
    FAILED=$((FAILED + 1))
    echo "  FAIL $2"
  fi
  teardown_sandbox
}

run_test test_injects_objective_plan_and_last_three_log_entries "injecte l'objectif, le plan et les trois dernières entrées LOG"
run_test test_names_pre_compact_event "nomme l'événement PreCompact"
run_test test_names_session_start_event "nomme l'événement SessionStart"
run_test test_defaults_to_pre_compact_without_event_name "retient PreCompact sans nom d'événement"
run_test test_reads_project_from_cwd_of_input "lit le projet du cwd transmis par le hook"
run_test test_injects_plan_without_brief_or_log "injecte le plan seul sans brief ni LOG"
run_test test_writes_nothing_without_plan "n'écrit rien sans plan"
run_test test_writes_nothing_outside_git "n'écrit rien hors dépôt git"
run_test test_exits_zero_without_plan "sort en succès sans plan"

echo "$PASSED passed, $FAILED failed, $SKIPPED skipped"
[ $FAILED -eq 0 ]
