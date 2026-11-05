#!/bin/bash
# Tests de skills/forge/scripts/status.sh — chaque test tourne dans un dépôt jetable
# sur master, jamais le dépôt courant.
# Usage : bash tests/status.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATUS_SCRIPT="$REPO_ROOT/skills/forge/scripts/status.sh"
PLAN_WITH_ALL_STATUSES='# Plan\n\n## Tasks\n\n### T1 — Premier\n**Effort:** S\n[x] fait\n\n### T2 — Deuxième\n[ ]\n\n### T3 — Troisième\n[!] blocked — raison\n\n### T4 — Quatrième\n[ ]\n\n## Summary\n| T1 | S | [ ] |\n'
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
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

status() {
  bash "$STATUS_SCRIPT" --root "$WORK" "$@"
}

forge_project() {
  mkdir -p "$WORK/.forge"
  printf '# Project\n' > "$WORK/.forge/project.md"
  printf '# Standards\n' > "$WORK/.forge/coding-standards.md"
}

write_branch_file() {
  mkdir -p "$WORK/.forge/branch/$1"
  printf '%b' "$3" > "$WORK/.forge/branch/$1/$2"
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

# ── État ──────────────────────────────────────────────────────────────────────

test_reports_project_init_without_forge_folder() {
  assert_contains '"state":"project_init"' "$(status)"
}

test_reports_coding_standards_init_when_only_project_exists() {
  mkdir -p "$WORK/.forge"
  printf '# Project\n' > "$WORK/.forge/project.md"
  assert_contains '"state":"coding_standards_init"' "$(status)"
}

test_reports_brief_state_without_brief() {
  forge_project
  assert_contains '"state":"brief"' "$(status)"
}

test_reports_plan_state_with_brief_and_no_log() {
  forge_project
  write_branch_file master brief.md '## Objective\n'
  assert_contains '"state":"plan"' "$(status)"
}

test_reports_active_state_with_brief_and_plan() {
  forge_project
  write_branch_file master brief.md '## Objective\n'
  write_branch_file master plan.md '# Plan\n'
  assert_contains '"state":"active"' "$(status)"
}

test_reports_no_branch_outside_git() {
  forge_project
  rm -rf "$WORK/.git"
  local output
  output=$(status)
  assert_contains '"branch":null' "$output"
  assert_contains '"state":"no_branch"' "$output"
}

# ── Branche ───────────────────────────────────────────────────────────────────

test_uses_current_git_branch_by_default() {
  git -C "$WORK" checkout -q -b feature
  assert_contains '"branch":"feature"' "$(status)"
}

test_evaluates_ticket_passed_instead_of_current_branch() {
  forge_project
  write_branch_file CU-123 brief.md '## Objective\n'
  local output
  output=$(status --branch CU-123)
  assert_contains '"branch":"CU-123"' "$output"
  assert_contains '"state":"plan"' "$output"
}

test_reads_branch_folder_containing_a_slash() {
  forge_project
  git -C "$WORK" checkout -q -b feature/login
  write_branch_file feature/login brief.md '## Objective\n'
  write_branch_file feature/login plan.md "$PLAN_WITH_ALL_STATUSES"
  assert_contains '"state":"active"' "$(status)"
}

# ── Avancement ────────────────────────────────────────────────────────────────

test_counts_tasks_by_status() {
  forge_project
  write_branch_file master brief.md '## Objective\n'
  write_branch_file master plan.md "$PLAN_WITH_ALL_STATUSES"
  assert_contains '"tasks":{"done":1,"open":2,"blocked":1,"total":4}' "$(status)"
}

test_lists_only_open_task_titles() {
  forge_project
  write_branch_file master brief.md '## Objective\n'
  write_branch_file master plan.md "$PLAN_WITH_ALL_STATUSES"
  assert_contains '"open_tasks":["T2 — Deuxième","T4 — Quatrième"]' "$(status)"
}

test_reports_zero_tasks_without_plan() {
  forge_project
  local output
  output=$(status)
  assert_contains '"tasks":{"done":0,"open":0,"blocked":0,"total":0}' "$output"
  assert_contains '"open_tasks":[]' "$output"
}

test_ignores_micro_steps_and_summary_table() {
  forge_project
  write_branch_file master brief.md '## Objective\n'
  write_branch_file master plan.md '## Tasks\n\n### T1 — Tâche\n[x]\n[ ] T1.1 — étape\n\n## Summary\n| T1 | S | [ ] |\n'
  assert_contains '"tasks":{"done":1,"open":0,"blocked":0,"total":1}' "$(status)"
}

test_counts_task_without_status_line_as_open() {
  forge_project
  write_branch_file master brief.md '## Objective\n'
  write_branch_file master plan.md '## Tasks\n\n### T1 — Tâche\n**Effort:** S\n'
  assert_contains '"tasks":{"done":0,"open":1,"blocked":0,"total":1}' "$(status)"
}

test_reads_plan_with_crlf_line_endings() {
  forge_project
  write_branch_file master brief.md '## Objective\r\n'
  write_branch_file master plan.md '## Tasks\r\n\r\n### T1 — Tâche\r\n[ ]\r\n'
  assert_contains '"open_tasks":["T1 — Tâche"]' "$(status)"
}

# ── Journal ───────────────────────────────────────────────────────────────────

test_returns_empty_log_when_file_is_absent() {
  forge_project
  assert_contains '"recent_log":[]' "$(status)"
}

test_keeps_ten_most_recent_log_entries() {
  forge_project
  local entries="" rank
  for rank in 1 2 3 4 5 6 7 8 9 10 11 12; do entries+="- [2026-11-05 10:00] entrée $rank\n"; done
  write_branch_file master log.md "$entries"
  local output
  output=$(status)
  assert_contains 'entrée 1"' "$output"
  assert_contains 'entrée 10"' "$output"
  assert_not_contains 'entrée 11"' "$output"
}

test_escapes_quotes_and_backslashes_in_log() {
  forge_project
  write_branch_file master log.md '- [2026-11-05 10:00] choix "B" dans c:\\temp\n'
  assert_contains '"recent_log":["- [2026-11-05 10:00] choix \"B\" dans c:\\temp"]' "$(status)"
}

# ── Branches à reprendre ──────────────────────────────────────────────────────

test_lists_other_local_branches_with_open_tasks() {
  forge_project
  git -C "$WORK" branch feature
  write_branch_file feature plan.md "$PLAN_WITH_ALL_STATUSES"
  assert_contains '"resumable":[{"branch":"feature","open":2}]' "$(status)"
}

test_excludes_finished_branches() {
  forge_project
  git -C "$WORK" branch feature
  write_branch_file feature plan.md '## Tasks\n\n### T1 — Tâche\n[x]\n'
  assert_contains '"resumable":[]' "$(status)"
}

test_excludes_plan_of_branch_that_no_longer_exists() {
  forge_project
  write_branch_file deleted plan.md "$PLAN_WITH_ALL_STATUSES"
  assert_contains '"resumable":[]' "$(status)"
}

test_excludes_current_branch() {
  forge_project
  write_branch_file master plan.md "$PLAN_WITH_ALL_STATUSES"
  assert_contains '"resumable":[]' "$(status)"
}

test_finds_resumable_branch_containing_a_slash() {
  forge_project
  git -C "$WORK" branch feature/login
  write_branch_file feature/login plan.md "$PLAN_WITH_ALL_STATUSES"
  assert_contains '"resumable":[{"branch":"feature/login","open":2}]' "$(status)"
}

# ── Lecture seule et usage ────────────────────────────────────────────────────

test_changes_nothing_in_repository() {
  forge_project
  write_branch_file master plan.md "$PLAN_WITH_ALL_STATUSES"
  local before
  before=$(git -C "$WORK" status --porcelain)
  status > /dev/null
  assert_equals "$before" "$(git -C "$WORK" status --porcelain)"
}

test_rejects_missing_root() {
  bash "$STATUS_SCRIPT" --root "$WORK/absent" > /dev/null 2>&1
  assert_equals 1 $?
}

test_rejects_unknown_argument() {
  status --unknown > /dev/null 2>&1
  assert_equals 1 $?
}

test_writes_nothing_on_stdout_for_usage_error() {
  assert_equals "" "$(status --unknown 2>/dev/null)"
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

run_test test_reports_project_init_without_forge_folder "rend l'état project_init sans dossier .forge"
run_test test_reports_coding_standards_init_when_only_project_exists "rend coding_standards_init quand seul project.md existe"
run_test test_reports_brief_state_without_brief "rend l'état brief sans brief.md"
run_test test_reports_plan_state_with_brief_and_no_log "rend l'état plan avec un brief, même sans log.md"
run_test test_reports_active_state_with_brief_and_plan "rend l'état active avec un brief et un plan"
run_test test_reports_no_branch_outside_git "rend no_branch et une branche nulle hors dépôt git"
run_test test_uses_current_git_branch_by_default "prend la branche git courante par défaut"
run_test test_evaluates_ticket_passed_instead_of_current_branch "évalue l'identifiant de ticket passé à la place de la branche courante"
run_test test_reads_branch_folder_containing_a_slash "lit le dossier d'une branche contenant un slash"
run_test test_counts_tasks_by_status "compte les tâches par statut"
run_test test_lists_only_open_task_titles "liste uniquement les titres des tâches ouvertes"
run_test test_reports_zero_tasks_without_plan "rend zéro tâche sans plan"
run_test test_ignores_micro_steps_and_summary_table "ignore les micro-étapes et le tableau récapitulatif"
run_test test_counts_task_without_status_line_as_open "compte comme ouverte une tâche sans ligne de statut"
run_test test_reads_plan_with_crlf_line_endings "lit un plan en fins de ligne CRLF"
run_test test_returns_empty_log_when_file_is_absent "rend un journal vide quand log.md est absent"
run_test test_keeps_ten_most_recent_log_entries "garde les dix entrées les plus récentes du journal"
run_test test_escapes_quotes_and_backslashes_in_log "échappe guillemets et barres obliques inverses du journal"
run_test test_lists_other_local_branches_with_open_tasks "liste les autres branches locales ayant des tâches ouvertes"
run_test test_excludes_finished_branches "écarte les branches sans tâche ouverte"
run_test test_excludes_plan_of_branch_that_no_longer_exists "écarte le plan d'une branche disparue"
run_test test_excludes_current_branch "écarte la branche courante"
run_test test_finds_resumable_branch_containing_a_slash "trouve une branche à reprendre contenant un slash"
run_test test_changes_nothing_in_repository "ne modifie rien dans le dépôt"
run_test test_rejects_missing_root "refuse une racine absente"
run_test test_rejects_unknown_argument "refuse un argument inconnu"
run_test test_writes_nothing_on_stdout_for_usage_error "n'écrit rien sur la sortie standard en erreur d'usage"

echo "$PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ]
