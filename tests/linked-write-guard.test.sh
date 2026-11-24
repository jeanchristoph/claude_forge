#!/bin/bash
# Tests de skills/forge/hooks/linked-write-guard.sh — chaque test tourne dans des dossiers jetables, jamais le dépôt courant.
# Usage : bash tests/linked-write-guard.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_SCRIPT="$REPO_ROOT/skills/forge/hooks/linked-write-guard.sh"
. "$REPO_ROOT/tests/test-runner.sh"

# ── Bac à sable ───────────────────────────────────────────────────────────────

# Projet de la session (PARENT) et projet lié (LINKED), tous deux forgés ; dossier non forgé (PLAIN).
setup_sandbox() {
  SANDBOX=$(mktemp -d)
  PARENT="$SANDBOX/parent"
  LINKED="$SANDBOX/linked"
  PLAIN="$SANDBOX/plain"
  mkdir -p "$PARENT/.forge" "$LINKED/.forge/branch/parent/feature" "$PLAIN"
  printf '# Project\n' > "$PARENT/.forge/project.md"
  printf '# Project\n' > "$LINKED/.forge/project.md"
  git -C "$PARENT" init -q
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

# Appel du hook pour une écriture de <fichier> depuis le projet de la session ; champs JSON supplémentaires en second argument.
run_hook() {
  printf '{"session_id":"s1","hook_event_name":"PreToolUse","tool_name":"Write","cwd":"%s","tool_input":{"file_path":"%s","content":"x"}%s}' \
    "$PARENT" "$1" "$2" | bash "$HOOK_SCRIPT"
}

# ── Assertions — chaque test tourne dans un sous-shell, un échec en sort ──────

assert_equals() {
  [ "$1" = "$2" ] && return 0
  printf '    expected: %s\n    actual:   %s\n' "$1" "$2"
  exit 1
}

assert_contains() {
  [[ $2 == *"$1"* ]] && return 0
  printf '    expected to contain: %s\n    actual: %s\n' "$1" "$2"
  exit 1
}

# ── Cas ───────────────────────────────────────────────────────────────────────

test_denies_write_into_other_forged_project() {
  local output
  output=$(run_hook "$LINKED/src/app.php")
  assert_contains '"permissionDecision":"deny"' "$output"
  assert_contains "forge: $LINKED/src/app.php belongs to the forged project $LINKED, outside ROOT" "$output"
  assert_contains 'add the task to the plan, then delegate' "$output"
}

test_allows_brief_and_log_of_linked_project() {
  assert_equals "" "$(run_hook "$LINKED/.forge/branch/parent/feature/brief.md")"
  assert_equals "" "$(run_hook "$LINKED/.forge/branch/parent/feature/log.md")"
}

test_denies_plan_of_linked_project() {
  assert_contains '"permissionDecision":"deny"' "$(run_hook "$LINKED/.forge/branch/parent/feature/plan.md")"
}

test_allows_subagent() {
  assert_equals "" "$(run_hook "$LINKED/src/app.php" ',"agent_id":"a1","agent_type":"general-purpose"')"
}

test_allows_file_under_root() {
  assert_equals "" "$(run_hook "$PARENT/src/app.php")"
}

test_allows_unforged_folder_outside_root() {
  assert_equals "" "$(run_hook "$PLAIN/notes.txt")"
}

test_allows_everything_when_session_is_not_forged() {
  rm -rf "$PARENT/.forge"
  assert_equals "" "$(run_hook "$LINKED/src/app.php")"
}

# ── Exécution ─────────────────────────────────────────────────────────────────

run_test test_denies_write_into_other_forged_project "refuse l'écriture dans un autre projet forgé, raison et marche à suivre données"
run_test test_allows_brief_and_log_of_linked_project "autorise le brief et le log du projet lié, écrits par la délégation"
run_test test_denies_plan_of_linked_project "refuse le plan du projet lié : seuls brief et log sont permis"
run_test test_allows_subagent "autorise un sous-agent : le délégué écrit dans son worktree"
run_test test_allows_file_under_root "autorise un fichier sous ROOT"
run_test test_allows_unforged_folder_outside_root "autorise un dossier hors ROOT non forgé"
run_test test_allows_everything_when_session_is_not_forged "autorise tout quand la session n'est pas dans un projet forgé"

report_results
