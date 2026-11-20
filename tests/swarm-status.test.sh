#!/bin/bash
# Tests de skills/forge/scripts/swarm-status.sh — chaque test tourne dans un dépôt jetable
# sur la branche parente « parent », jamais le dépôt courant.
# Usage : bash tests/swarm-status.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_SCRIPT="$REPO_ROOT/skills/forge/scripts/swarm-status.sh"
PASSED=0
FAILED=0

# Plan type : socle ordinaire, deux branches filles dépendantes, vérification finale.
PLAN='# Plan — parent

## Tasks

### T1 — Socle des points d extension
**Depends on:** none
[x]

### T2 — Branch `parent-purchasing` — achats
**Depends on:** T1
[ ]

### T3 — Branch `parent-sales` — ventes
**Depends on:** parent-purchasing
[ ]

### T4 — Documentation
**Depends on:** none
[ ]

### T5 — Vérification d ensemble
**Depends on:** parent-purchasing, parent-sales
[ ]

## Summary
| T1 | S | [x] |
'

# ── Bac à sable ───────────────────────────────────────────────────────────────

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  WORK="$SANDBOX/work"
  git init -q "$WORK"
  git -C "$WORK" config user.name "Forge Test"
  git -C "$WORK" config user.email "forge@test.local"
  git -C "$WORK" config commit.gpgsign false
  git -C "$WORK" config core.autocrlf false
  git -C "$WORK" symbolic-ref HEAD refs/heads/parent
  printf 'shared\n' > "$WORK/shared.txt"
  git -C "$WORK" add shared.txt
  git -C "$WORK" commit -q -m "initial"
  write_plan "$PLAN"
}

teardown_sandbox() {
  git -C "$WORK" worktree prune 2>/dev/null
  rm -rf "$SANDBOX"
}

write_plan() {
  mkdir -p "$WORK/.forge/branch/parent"
  printf '%s' "$1" > "$WORK/.forge/branch/parent/plan.md"
}

swarm_status() {
  bash "$SWARM_SCRIPT" --root "$WORK" "$@"
}

# Branche fille créée depuis la parente, avec un commit qui modifie shared.txt.
create_child() {
  git -C "$WORK" branch "$1"
}

commit_on() {
  local branch=$1 content=$2
  git -C "$WORK" checkout -q "$branch"
  printf '%s\n' "$content" > "$WORK/shared.txt"
  git -C "$WORK" commit -q -am "change on $branch"
  git -C "$WORK" checkout -q parent
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

# ── Horloge ───────────────────────────────────────────────────────────────────

test_reports_local_time_now() {
  local before after output pattern='"now":"([0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2})"\}$'
  before=$(date '+%Y-%m-%d %H:%M')
  output=$(swarm_status)
  after=$(date '+%Y-%m-%d %H:%M')
  [[ $output =~ $pattern ]] || { echo "    now missing: $output"; exit 1; }
  [ "${BASH_REMATCH[1]}" = "$before" ] || [ "${BASH_REMATCH[1]}" = "$after" ] \
    || { echo "    clock mismatch: ${BASH_REMATCH[1]} ($before / $after)"; exit 1; }
}

# ── Sélection ─────────────────────────────────────────────────────────────────

test_launches_branch_whose_dependencies_are_done() {
  create_child parent-purchasing
  assert_contains '"launchable":[{"task":"T2","branch":"parent-purchasing","exists":true,"conflict":false,"conflict_files":[]}]' "$(swarm_status)"
}

test_lists_branch_waiting_for_open_dependency() {
  assert_contains '"waiting":[{"task":"T3","branch":"parent-sales","waiting_for":["parent-purchasing"]}]' "$(swarm_status)"
}

test_unblocks_branch_once_dependency_is_done() {
  write_plan "${PLAN/'### T2 — Branch `parent-purchasing` — achats
**Depends on:** T1
[ ]'/'### T2 — Branch `parent-purchasing` — achats
**Depends on:** T1
[x]'}"
  local output
  output=$(swarm_status)
  assert_contains '"launchable":[{"task":"T3","branch":"parent-sales","exists":false' "$output"
  assert_contains '"waiting":[]' "$output"
}

test_reports_branch_not_created_yet() {
  assert_contains '"branch":"parent-purchasing","exists":false,"conflict":false' "$(swarm_status)"
}

# ── En cours ──────────────────────────────────────────────────────────────────

test_reports_branch_checked_out_in_worktree_as_running_with_progress() {
  create_child parent-purchasing
  git -C "$WORK" worktree add -q "$SANDBOX/wt" parent-purchasing
  mkdir -p "$SANDBOX/wt/.forge/branch/parent-purchasing"
  printf '# Plan\n\n## Tasks\n\n### T1 — a\n[x]\n\n### T2 — b\n[ ]\n\n### T3 — c\n[ ]\n' > "$SANDBOX/wt/.forge/branch/parent-purchasing/plan.md"
  local output
  output=$(swarm_status)
  assert_contains '"running":[{"task":"T2","branch":"parent-purchasing","worktree":' "$output"
  assert_contains '"done":1,"total":3}]' "$output"
  assert_contains '"launchable":[]' "$output"
  assert_contains '"slots":2' "$output"
}

test_reads_swarm_size_from_swarm_file() {
  printf '# Essaim — parent\n**N:** 2\n' > "$WORK/.forge/branch/parent/swarm.md"
  assert_contains '"n":2,"slots":2' "$(swarm_status)"
}

test_defaults_swarm_size_to_three() {
  assert_contains '"n":3,"slots":3,"open_branches":2' "$(swarm_status)"
}

# ── Fusion simulée ────────────────────────────────────────────────────────────

test_reports_conflict_between_parent_and_branch() {
  create_child parent-purchasing
  commit_on parent-purchasing 'child version'
  printf 'parent version\n' > "$WORK/shared.txt"
  git -C "$WORK" commit -q -am "change on parent"
  assert_contains '"conflict":true,"conflict_files":["shared.txt"]' "$(swarm_status)"
}

test_simulates_merge_without_touching_repository() {
  create_child parent-purchasing
  commit_on parent-purchasing 'child version'
  printf 'parent version\n' > "$WORK/shared.txt"
  git -C "$WORK" commit -q -am "change on parent"
  local head_before
  head_before=$(git -C "$WORK" rev-parse HEAD)
  swarm_status > /dev/null
  assert_equals "$head_before" "$(git -C "$WORK" rev-parse HEAD)"
  assert_equals "" "$(git -C "$WORK" status --porcelain -- shared.txt)"
}

# ── Tâches ordinaires ─────────────────────────────────────────────────────────

test_lists_open_ordinary_tasks_for_the_parent() {
  local output
  output=$(swarm_status)
  assert_contains '{"task":"T4","title":"Documentation","waiting_for":[],"is_last":false}' "$output"
  assert_contains '{"task":"T5","title":"Vérification d ensemble","waiting_for":["parent-purchasing","parent-sales"],"is_last":true}' "$output"
  assert_not_contains '"task":"T1"' "$output"
}

test_reads_plan_without_branch_task() {
  write_plan $'# Plan\n\n## Tasks\n\n### T1 — Seule\n[ ]\n'
  local output
  output=$(swarm_status)
  assert_contains '"open_branches":0,"running":[],"launchable":[],"waiting":[]' "$output"
  assert_contains '"ordinary":[{"task":"T1","title":"Seule","waiting_for":[],"is_last":true}]' "$output"
}

test_reads_plan_with_crlf_line_endings() {
  write_plan "$(printf '%s' "$PLAN" | sed 's/$/\r/')"
  assert_contains '"waiting_for":["parent-purchasing"]' "$(swarm_status)"
}

# ── Usage ─────────────────────────────────────────────────────────────────────

test_rejects_branch_without_plan() {
  local output
  output=$(swarm_status --branch other 2>/dev/null)
  assert_equals "1" "$?"
  assert_equals "" "$output"
}

test_rejects_unknown_argument() {
  swarm_status --nope 2>/dev/null
  assert_equals "1" "$?"
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

echo "swarm-status.sh"
run_test test_reports_local_time_now "rend l'heure locale dans now"
run_test test_launches_branch_whose_dependencies_are_done "rend lançable une branche dont les dépendances sont faites"
run_test test_lists_branch_waiting_for_open_dependency "met en attente une branche dont une dépendance est ouverte"
run_test test_unblocks_branch_once_dependency_is_done "débloque une branche dès que sa dépendance est cochée"
run_test test_reports_branch_not_created_yet "signale une branche lançable pas encore créée"
run_test test_reports_branch_checked_out_in_worktree_as_running_with_progress "rend en cours une branche extraite dans un worktree, avec son avancement"
run_test test_reads_swarm_size_from_swarm_file "lit N dans swarm.md"
run_test test_defaults_swarm_size_to_three "prend N = 3 à défaut"
run_test test_reports_conflict_between_parent_and_branch "signale un conflit entre la parente et la branche"
run_test test_simulates_merge_without_touching_repository "simule la fusion sans toucher au dépôt"
run_test test_lists_open_ordinary_tasks_for_the_parent "liste les tâches ordinaires ouvertes du parent"
run_test test_reads_plan_without_branch_task "lit un plan sans tâche-branche"
run_test test_reads_plan_with_crlf_line_endings "lit un plan en fins de ligne CRLF"
run_test test_rejects_branch_without_plan "refuse une branche sans plan"
run_test test_rejects_unknown_argument "refuse un argument inconnu"

echo "$PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ]
