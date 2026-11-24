#!/bin/bash
# Tests de skills/forge/scripts/swarm-status.sh — chaque test tourne dans un dépôt jetable
# sur la branche parente « parent », jamais le dépôt courant.
# Usage : bash tests/swarm-status.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_SCRIPT="$REPO_ROOT/skills/forge/scripts/swarm-status.sh"
. "$REPO_ROOT/tests/test-runner.sh"

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
  assert_contains '"launchable":[{"task":"T2","type":"child","branch":"parent-purchasing","exists":true,"conflict":false,"conflict_files":[]}]' "$(swarm_status)"
}

test_lists_branch_waiting_for_open_dependency() {
  assert_contains '"waiting":[{"task":"T3","type":"child","branch":"parent-sales","waiting_for":["parent-purchasing"]}]' "$(swarm_status)"
}

test_unblocks_branch_once_dependency_is_done() {
  write_plan "${PLAN/'### T2 — Branch `parent-purchasing` — achats
**Depends on:** T1
[ ]'/'### T2 — Branch `parent-purchasing` — achats
**Depends on:** T1
[x]'}"
  local output
  output=$(swarm_status)
  assert_contains '"launchable":[{"task":"T3","type":"child","branch":"parent-sales","exists":false' "$output"
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
  assert_contains '"running":[{"task":"T2","type":"child","branch":"parent-purchasing","worktree":' "$output"
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

# ── Plans impossibles ─────────────────────────────────────────────────────────

test_reports_dependency_cycle_as_invalid() {
  write_plan '# Plan — parent

## Tasks

### T1 — Branch `parent-a` — a
**Depends on:** parent-b
[ ]

### T2 — Branch `parent-b` — b
**Depends on:** T1
[ ]
'
  local output
  output=$(swarm_status)
  assert_contains '{"task":"T1","branch":"parent-a","dependency":"T1","reason":"cycle"}' "$output"
  assert_contains '{"task":"T2","branch":"parent-b","dependency":"T2","reason":"cycle"}' "$output"
  assert_contains '"waiting":[]' "$output"
}

test_reports_unknown_or_free_text_dependency_as_invalid() {
  write_plan '# Plan — parent

## Tasks

### T1 — Branch `parent-a` — a
**Depends on:** T9
[ ]

### T2 — Branch `parent-b` — b
**Depends on:** T1 (because shared data)
[ ]
'
  local output
  output=$(swarm_status)
  assert_contains '{"task":"T1","branch":"parent-a","dependency":"T9","reason":"unknown"}' "$output"
  assert_contains '{"task":"T2","branch":"parent-b","dependency":"T1(becauseshareddata)","reason":"unknown"}' "$output"
  assert_contains '"launchable":[]' "$output"
}

test_reports_blocked_or_dropped_dependency_as_invalid() {
  write_plan '# Plan — parent

## Tasks

### T1 — Socle
[!] accès refusé

### T2 — Branch `parent-a` — a
**Depends on:** T1
[ ]

### T3 — Abandonnée
[-]

### T4 — Documentation
**Depends on:** T3
[ ]
'
  local output
  output=$(swarm_status)
  assert_contains '{"task":"T2","branch":"parent-a","dependency":"T1","reason":"blocked"}' "$output"
  assert_contains '{"task":"T4","branch":null,"dependency":"T3","reason":"dropped"}' "$output"
  assert_contains '"ordinary":[]' "$output"
}

test_lists_blocked_branch_task() {
  write_plan '# Plan — parent

## Tasks

### T1 — Branch `parent-a` — a
**Depends on:** none
[!] en attente du client
'
  assert_contains '"blocked":[{"task":"T1","branch":"parent-a"}]' "$(swarm_status)"
}

test_rejects_branch_name_refused_by_git() {
  write_plan '# Plan — parent

## Tasks

### T1 — Branch feat/x: achats
**Depends on:** none
[ ]
'
  assert_contains '"invalid":[{"task":"T1","branch":"feat/x:","dependency":"feat/x:","reason":"branch_name"}]' "$(swarm_status)"
}

test_reads_status_on_status_line_not_on_a_note() {
  write_plan '# Plan — parent

## Tasks

### T1 — Socle
**Depends on:** none
[ ]
[x] note recopiée d une autre tâche

### T2 — Branch `parent-a` — a
**Depends on:** T1
[ ]
'
  assert_contains '"waiting":[{"task":"T2","type":"child","branch":"parent-a","waiting_for":["T1"]}]' "$(swarm_status)"
}

# ── Worktrees et suite d une fusion ───────────────────────────────────────────

test_reports_worktree_removed_by_hand_as_stale() {
  create_child parent-purchasing
  git -C "$WORK" worktree add -q "$SANDBOX/wt" parent-purchasing
  rm -rf "$SANDBOX/wt"
  local output
  output=$(swarm_status)
  assert_contains '"stale":[{"task":"T2","branch":"parent-purchasing","worktree":' "$output"
  assert_contains '"running":[]' "$output"
  assert_contains '"slots":3' "$output"
}

test_computes_next_launch_with_assumed_done_branch() {
  create_child parent-purchasing
  git -C "$WORK" worktree add -q "$SANDBOX/wt" parent-purchasing
  local output
  output=$(swarm_status --assume-done parent-purchasing)
  assert_contains '"launchable":[{"task":"T3","type":"child","branch":"parent-sales"' "$output"
  assert_contains '"running":[]' "$output"
}

test_rejects_parent_without_git_branch() {
  mkdir -p "$WORK/.forge/branch/ghost"
  printf '# Plan\n' > "$WORK/.forge/branch/ghost/plan.md"
  local output
  output=$(swarm_status --branch ghost 2>/dev/null)
  assert_equals "1" "$?"
  assert_equals "" "$output"
}

# ── Branches liées ────────────────────────────────────────────────────────────

# Dépôt lié à côté du dépôt parent, forgé (.forge/project.md commité sur master) ou non.
create_linked_repository() {
  local name=$1 is_forged=$2 directory="$SANDBOX/$1"
  git init -q "$directory"
  git -C "$directory" config user.name "Forge Test"
  git -C "$directory" config user.email "forge@test.local"
  git -C "$directory" config commit.gpgsign false
  git -C "$directory" symbolic-ref HEAD refs/heads/master
  printf 'code\n' > "$directory/code.txt"
  if [ "$is_forged" = "forged" ]; then mkdir -p "$directory/.forge"; printf '# Project\n' > "$directory/.forge/project.md"; fi
  git -C "$directory" add -A
  git -C "$directory" commit -q -m "initial"
}

# Tâche liée au format du plan : numéro, projet, branche, dépendances, ligne de statut puis lignes suivantes.
linked_task() {
  printf '### %s — Montée de version %s\n**Files:** `composer.json`\n**Linked branch:** ../%s @ %s\n**Depends on:** %s\n%s\n\n' "$1" "$2" "$2" "$3" "$4" "$5"
}

# Tâches passées une par argument, séparées par une ligne vide.
write_linked_plan() {
  local plan='# Plan — parent

## Tasks' task
  for task in "$@"; do plan+=$'\n\n'"$task"; done
  write_plan "$plan"$'\n\n## Summary\n'
}

test_launches_linked_tasks_of_different_repositories_together() {
  create_linked_repository api forged
  create_linked_repository web forged
  write_linked_plan "$(linked_task T1 api upgrade none '[ ]')" "$(linked_task T2 web upgrade none '[ ]')"
  local output
  output=$(swarm_status)
  assert_contains '"launchable":[{"task":"T1","type":"linked","branch":"upgrade","linked":"../api","tasks":["T1"],"forged":true},{"task":"T2","type":"linked","branch":"upgrade","linked":"../web","tasks":["T2"],"forged":true}]' "$output"
  assert_contains '"open_branches":2' "$output"
  assert_contains '"ordinary":[]' "$output"
}

test_groups_tasks_sharing_a_linked_branch_into_one_unit() {
  create_linked_repository api forged
  write_linked_plan "$(linked_task T1 api upgrade none '[ ]')" "$(linked_task T2 api upgrade T1 '[ ]')"
  local output
  output=$(swarm_status)
  assert_contains '"launchable":[{"task":"T1","type":"linked","branch":"upgrade","linked":"../api","tasks":["T1","T2"],"forged":true}]' "$output"
  assert_contains '"open_branches":1' "$output"
}

test_linked_unit_waits_for_its_open_dependencies() {
  create_linked_repository api forged
  write_linked_plan "$(printf '### T1 — Socle\n**Depends on:** none\n[ ]\n\n')" "$(linked_task T2 api upgrade T1 '[ ]')"
  assert_contains '"waiting":[{"task":"T2","type":"linked","branch":"upgrade","linked":"../api","tasks":["T2"],"waiting_for":["T1"]}]' "$(swarm_status)"
}

test_reports_delegated_linked_unit_as_running() {
  create_linked_repository api forged
  create_linked_repository web forged
  write_linked_plan "$(linked_task T1 api upgrade none '[ ]
delegated to ../api @ upgrade')" "$(linked_task T2 web upgrade none '[ ]')"
  local output
  output=$(swarm_status)
  assert_contains '"running":[{"task":"T1","type":"linked","branch":"upgrade","linked":"../api","tasks":["T1"]}]' "$output"
  assert_contains '"launchable":[{"task":"T2"' "$output"
  assert_contains '"slots":2' "$output"
}

test_reads_linked_unit_from_a_note_without_field() {
  create_linked_repository api forged
  write_linked_plan "$(linked_task T1 api upgrade none '[ ]
delegated to ../api @ upgrade' | sed '/^\*\*Linked branch:/d')"
  assert_contains '"running":[{"task":"T1","type":"linked","branch":"upgrade","linked":"../api","tasks":["T1"]}]' "$(swarm_status)"
}

test_ignores_delegated_to_written_in_a_description() {
  create_linked_repository api forged
  write_linked_plan "$(linked_task T1 api upgrade none '[ ]' | sed 's/^\*\*Files:\*\*.*/**Description:** relire les notes delegated to du plan/')"
  assert_contains '"launchable":[{"task":"T1","type":"linked"' "$(swarm_status)"
}

test_mixes_child_branches_and_linked_units_in_plan_order() {
  create_linked_repository api forged
  write_linked_plan "$(linked_task T1 api upgrade none '[ ]')" "$(printf '### T2 — Branch `parent-a` — a\n**Depends on:** none\n[ ]\n\n')"
  local output
  output=$(swarm_status)
  assert_contains '"launchable":[{"task":"T1","type":"linked"' "$output"
  assert_contains '{"task":"T2","type":"child","branch":"parent-a","exists":false' "$output"
  assert_contains '"open_branches":2' "$output"
}

test_launches_one_unit_at_a_time_on_an_unforged_project() {
  create_linked_repository api unforged
  write_linked_plan "$(linked_task T1 api upgrade-php none '[ ]')" "$(linked_task T2 api upgrade-symfony none '[ ]')"
  local output
  output=$(swarm_status)
  assert_contains '"launchable":[{"task":"T1","type":"linked","branch":"upgrade-php","linked":"../api","tasks":["T1"],"forged":false}]' "$output"
  assert_contains '"waiting":[{"task":"T2","type":"linked","branch":"upgrade-symfony","linked":"../api","tasks":["T2"],"waiting_for":["upgrade-php"]}]' "$output"
}

test_unforged_project_stays_held_by_its_delegated_unit() {
  create_linked_repository api unforged
  write_linked_plan "$(linked_task T1 api upgrade-php none '[ ]')" "$(linked_task T2 api upgrade-symfony none '[ ]
delegated to ../api @ upgrade-symfony')"
  local output
  output=$(swarm_status)
  assert_contains '"waiting":[{"task":"T1","type":"linked","branch":"upgrade-php","linked":"../api","tasks":["T1"],"waiting_for":["upgrade-symfony"]}]' "$output"
  assert_contains '"launchable":[]' "$output"
}

test_reports_missing_linked_project_as_invalid() {
  write_linked_plan "$(linked_task T1 ghost upgrade none '[ ]')"
  assert_contains '"invalid":[{"task":"T1","branch":"upgrade","dependency":"../ghost","reason":"linked_missing"}]' "$(swarm_status)"
}

test_reads_draft_plan_given_by_plan_option() {
  create_linked_repository api forged
  local draft="$SANDBOX/draft.md"
  printf '# Plan — parent\n\n## Tasks\n\n%s\n' "$(linked_task T1 api upgrade none '[ ]')" > "$draft"
  assert_contains '"launchable":[{"task":"T1","type":"linked"' "$(swarm_status --plan "$draft")"
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
run_test test_reports_dependency_cycle_as_invalid "signale un cycle de dépendances comme invalide"
run_test test_reports_unknown_or_free_text_dependency_as_invalid "signale une dépendance inconnue ou en texte libre comme invalide"
run_test test_reports_blocked_or_dropped_dependency_as_invalid "signale une dépendance bloquée ou abandonnée comme invalide"
run_test test_lists_blocked_branch_task "liste une tâche-branche bloquée"
run_test test_rejects_branch_name_refused_by_git "rejette un nom de branche refusé par git"
run_test test_reads_status_on_status_line_not_on_a_note "lit le statut sur sa ligne, jamais sur une note"
run_test test_reports_worktree_removed_by_hand_as_stale "signale périmé un worktree supprimé à la main"
run_test test_computes_next_launch_with_assumed_done_branch "calcule la suite d une fusion avec une branche comptée faite"
run_test test_launches_linked_tasks_of_different_repositories_together "rend lançables ensemble des tâches liées de dépôts différents"
run_test test_groups_tasks_sharing_a_linked_branch_into_one_unit "réunit en une unité les tâches d une même branche liée"
run_test test_linked_unit_waits_for_its_open_dependencies "met en attente une unité liée dont une dépendance est ouverte"
run_test test_reports_delegated_linked_unit_as_running "rend en cours une unité liée déjà déléguée"
run_test test_reads_linked_unit_from_a_note_without_field "lit une unité liée depuis sa seule note"
run_test test_ignores_delegated_to_written_in_a_description "ignore « delegated to » écrit dans une description"
run_test test_mixes_child_branches_and_linked_units_in_plan_order "mêle branches filles et unités liées dans l ordre du plan"
run_test test_launches_one_unit_at_a_time_on_an_unforged_project "ne lance qu une unité à la fois sur un projet non forgé"
run_test test_unforged_project_stays_held_by_its_delegated_unit "garde un projet non forgé à l unité déjà déléguée"
run_test test_reports_missing_linked_project_as_invalid "signale invalide un projet lié introuvable"
run_test test_reads_draft_plan_given_by_plan_option "lit un plan rédigé passé par --plan"
run_test test_rejects_parent_without_git_branch "refuse une parente sans branche git"
run_test test_rejects_branch_without_plan "refuse une branche sans plan"
run_test test_rejects_unknown_argument "refuse un argument inconnu"

report_results
