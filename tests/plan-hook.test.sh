#!/bin/bash
# Tests de skills/forge/hooks/plan-hook.sh — chaque test tourne dans un dépôt jetable, jamais le dépôt courant.
# Usage : bash tests/plan-hook.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_SCRIPT="$REPO_ROOT/skills/forge/hooks/plan-hook.sh"
. "$REPO_ROOT/tests/test-runner.sh"

# ── Bac à sable ───────────────────────────────────────────────────────────────

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  WORK="$SANDBOX/work"
  BRANCH_DIR="$WORK/.forge/branch/feature"
  PLAN="$BRANCH_DIR/plan.md"
  OWN_LOG="$BRANCH_DIR/time-log.jsonl"
  mkdir -p "$BRANCH_DIR"
  git -C "$WORK" init -q -b feature
  git -C "$WORK" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

# Plan à trois tâches ; statuts passés dans l'ordre (« [ ] », « [x] »…).
write_plan() {
  cat > "$PLAN" <<EOF
# Plan — feature

## Tasks

### T1 — Première
**Effort:** S
**Estimated time:** ≈ 1 min (1-2)
**Files:** \`a.txt\`
**Description:** un
$1

### T2 — Deuxième
**Effort:** S
**Estimated time:** ≈ 1 min (1-2)
**Files:** \`b.txt\`
**Description:** deux
$2

### T3 — Troisième
**Effort:** S
**Files:** \`c.txt\`
**Description:** trois
$3

## Risks
- aucun
EOF
}

# Appel du hook pour une écriture du fichier <chemin> ; champs JSON supplémentaires en second argument.
run_hook() {
  printf '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Edit","cwd":"%s","tool_input":{"file_path":"%s","old_string":"[ ]"}%s}' \
    "$WORK" "$1" "$2" | bash "$HOOK_SCRIPT"
}

seed_checkpoint() {
  printf '{"ts":%s,"event":"plan_checkpoint","done":"%s","files":""}\n' "$1" "$2" >> "$OWN_LOG"
}

actual_line_of() {
  awk -v task="$1" '/^### T/ { current = $2 } current == task && /^\*\*Actual time:\*\*/ { print; exit }' "$PLAN"
}

count_events() {
  grep -c "\"event\":\"$1\"" "$2"
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

# ── Garde ─────────────────────────────────────────────────────────────────────

last_checkpoint_ts() {
  grep '"event":"plan_checkpoint"' "$OWN_LOG" | tail -1 | grep -oE '"ts":[0-9]+' | grep -oE '[0-9]+'
}

# Plan dont T3, sans estimation, vient d'entrer au plan ; point d'étape ancien, empreinte <json>.
write_plan_with_added_task() {
  printf '{"ts":1700000000000,"event":"plan_checkpoint","done":"T1","files":%s}\n' "$1" >> "$OWN_LOG"
  write_plan "[x]" "[ ]" "[ ]"
}

test_added_task_moves_checkpoint_when_no_code_is_in_progress() {
  write_plan_with_added_task '""'
  run_hook "$PLAN" >/dev/null
  [ "$(last_checkpoint_ts)" -gt 1700000000000 ] || { echo "    checkpoint kept"; exit 1; }
  run_hook "$PLAN" >/dev/null
  assert_equals 2 "$(count_events plan_checkpoint "$OWN_LOG")"
}

test_added_task_moves_checkpoint_when_everything_is_committed() {
  write_plan_with_added_task '"old.txt\tabc123"'
  run_hook "$PLAN" >/dev/null
  [ "$(last_checkpoint_ts)" -gt 1700000000000 ] || { echo "    checkpoint kept"; exit 1; }
}

test_added_task_keeps_checkpoint_of_a_task_in_progress() {
  write_plan_with_added_task '""'
  printf 'x\n' > "$WORK/code.txt"
  run_hook "$PLAN" >/dev/null
  assert_equals 1700000000000 "$(last_checkpoint_ts)"
}

test_ignores_file_outside_plan() {
  : > "$OWN_LOG"
  write_plan "[x]" "[ ]" "[ ]"
  assert_equals "" "$(run_hook "$WORK/src/app.sh")"
  assert_equals "" "$(run_hook "$BRANCH_DIR/brief.md")"
  assert_equals 0 "$(wc -l < "$OWN_LOG" | tr -d ' ')"
}

test_first_pass_writes_checkpoint_without_marks() {
  : > "$OWN_LOG"
  write_plan "[x]" "[ ]" "[ ]"
  run_hook "$PLAN" >/dev/null
  assert_matches '^\{"ts":[0-9]{13},"event":"plan_checkpoint","done":"T1","files":""\}$' "$(cat "$OWN_LOG")"
  assert_equals "" "$(actual_line_of T1)"
}

# ── Coches ────────────────────────────────────────────────────────────────────

test_tick_writes_retroactive_start_done_and_actual_time() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x] fait" "[ ]" "[ ]"
  echo a > "$WORK/a.txt"
  local output
  output=$(run_hook "$PLAN")
  assert_matches '^\{"ts":1700000000000,"event":"task_start","task":"T1","files":""\}$' "$(sed -n 2p "$OWN_LOG")"
  assert_matches '^\{"ts":[0-9]{13},"event":"task_done","task":"T1","files":"a.txt\\t[0-9a-f]{12}"\}$' "$(sed -n 3p "$OWN_LOG")"
  assert_matches '"event":"plan_checkpoint","done":"T1"' "$(sed -n 4p "$OWN_LOG")"
  assert_equals '**Actual time:** ≈ 0.0 min agent (incl. 0.0 min checks) · human 0.0 min (0 questions) · 1 files · total ≈ 0.0 min' "$(actual_line_of T1)"
  assert_matches '"additionalContext":"forge plan-hook: .*T1 → ≈ 0\.0 min agent \(incl\. 0\.0 min checks\) · human 0\.0 min \(0 questions\) · 1 files · total ≈ 0\.0 min' "$output"
}

test_actual_time_goes_under_estimated_time() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x]" "[ ]" "[ ]"
  run_hook "$PLAN" >/dev/null
  assert_equals '**Actual time:** ≈ 0.0 min agent (incl. 0.0 min checks) · human 0.0 min (0 questions) · 0 files · total ≈ 0.0 min' "$(grep -A1 -F '**Estimated time:**' "$PLAN" | sed -n 2p)"
}

test_actual_time_goes_under_effort_without_estimate() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 "T1 T2"
  write_plan "[x]" "[x]" "[x]"
  sed -i '/^\*\*Files:\*\* `c.txt`$/d' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals '**Actual time:** ≈ 0.0 min agent (incl. 0.0 min checks) · human 0.0 min (0 questions) · 0 files · total ≈ 0.0 min' "$(awk '/^### T3/ { getline; getline; print }' "$PLAN")"
}

test_replaces_existing_actual_time() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x]" "[ ]" "[ ]"
  sed -i 's/^\*\*Estimated time:\*\* ≈ 1 min (1-2)$/&\n**Actual time:** ≈ 9 min/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals 1 "$(awk '/^### T1/,/^### T2/' "$PLAN" | grep -c 'Actual time')"
  assert_equals '**Actual time:** ≈ 0.0 min agent (incl. 0.0 min checks) · human 0.0 min (0 questions) · 0 files · total ≈ 0.0 min' "$(actual_line_of T1)"
}

test_two_ticks_at_once_are_not_measured() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x]" "[x]" "[ ]"
  run_hook "$PLAN" >/dev/null
  assert_equals '**Actual time:** —' "$(actual_line_of T1)"
  assert_equals '**Actual time:** —' "$(actual_line_of T2)"
}

test_rewrite_without_new_tick_writes_nothing() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 "T1"
  write_plan "[x]" "[ ]" "[ ]"
  sed -i 's/^\*\*Files:\*\* `c\.txt`$/**Estimated time:** ≈ 1 min (1-2)\n&/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals "" "$(run_hook "$PLAN")"
  assert_equals 1 "$(wc -l < "$OWN_LOG" | tr -d ' ')"
}

test_removed_tick_keeps_checkpoint_time_and_retick_measures_from_it() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 "T1"
  write_plan "[ ]" "[ ]" "[ ]"
  run_hook "$PLAN" >/dev/null
  assert_equals '{"ts":1700000000000,"event":"plan_checkpoint","done":"","files":""}' "$(sed -n 2p "$OWN_LOG")"
  write_plan "[x]" "[ ]" "[ ]"
  run_hook "$PLAN" >/dev/null
  assert_matches '^\{"ts":1700000000000,"event":"task_start","task":"T1"' "$(sed -n 3p "$OWN_LOG")"
}

test_task_picked_out_of_order_is_measured() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 "T1"
  write_plan "[x]" "[ ]" "[x]"
  run_hook "$PLAN" >/dev/null
  assert_matches '"event":"task_start","task":"T3"' "$(cat "$OWN_LOG")"
  assert_equals '**Actual time:** ≈ 0.0 min agent (incl. 0.0 min checks) · human 0.0 min (0 questions) · 0 files · total ≈ 0.0 min' "$(actual_line_of T3)"
  assert_equals "" "$(actual_line_of T2)"
}

test_sequential_tasks_are_not_overlapping() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x]" "[ ]" "[ ]"
  run_hook "$PLAN" >/dev/null
  write_plan "[x]" "[x]" "[ ]"
  run_hook "$PLAN" >/dev/null
  assert_equals '**Actual time:** ≈ 0.0 min agent (incl. 0.0 min checks) · human 0.0 min (0 questions) · 0 files · total ≈ 0.0 min' "$(actual_line_of T2)"
}

test_skipped_tasks_get_no_mark() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x] delegated to ../other @ dev · done" "[ ]" "[ ]"
  sed -i 's/^### T2 — Deuxième$/### T2 — Branch feature-two/' "$PLAN"
  sed -i '0,/^\[ \]$/s//[x]/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals 0 "$(count_events task_start "$OWN_LOG")"
  assert_matches '"event":"plan_checkpoint","done":"T1 T2"' "$(sed -n 2p "$OWN_LOG")"
}

test_keeps_crlf_line_endings() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x]" "[ ]" "[ ]"
  sed -i 's/$/\r/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals "$(wc -l < "$PLAN" | tr -d ' ')" "$(grep -c $'\r$' "$PLAN")"
}

# ── Délégué et journal absent ─────────────────────────────────────────────────

test_delegate_marks_go_to_parent_log_with_branch() {
  local parent="$SANDBOX/parent" parent_log
  mkdir -p "$parent/.forge/branch/main-task"
  git -C "$parent" init -q -b main-task
  git -C "$parent" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  parent_log="$parent/.forge/branch/main-task/time-log.jsonl"
  printf '{"ts":1700000000000,"event":"plan_checkpoint","branch":"feature","done":"","files":""}\n' > "$parent_log"
  write_plan "[x]" "[ ]" "[ ]"
  printf '{"session_id":"s1","agent_id":"a1","hook_event_name":"PostToolUse","tool_name":"Edit","cwd":"%s","tool_input":{"file_path":"%s"}}' \
    "$parent" "$PLAN" | bash "$HOOK_SCRIPT" >/dev/null
  assert_matches '"event":"task_start","task":"T1","branch":"feature"' "$(cat "$parent_log")"
  assert_matches '"event":"task_done","task":"T1","branch":"feature"' "$(cat "$parent_log")"
  [ ! -e "$OWN_LOG" ] || { echo "    own log written"; exit 1; }
  assert_matches '^\*\*Actual time:\*\* ≈ [0-9.]+ min' "$(actual_line_of T1)"
}

# ── Projets liés ──────────────────────────────────────────────────────────────

# Dépôt lié <nom> à côté du parent, branche php85 extraite dans son worktree, plan du délégué à deux tâches.
create_linked_project() {
  local repository="$SANDBOX/$1" worktree="$SANDBOX/$1.worktrees/php85"
  git init -q -b master "$repository"
  git -C "$repository" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$repository" worktree add -q -b php85 "$worktree" master 2>/dev/null
  mkdir -p "$worktree/.forge/branch/php85"
  printf '# Plan\n\n## Tasks\n\n### T1 — Un ← parent T1\n**Effort:** S\n[ ]\n\n### T2 — Deux ← parent T2\n**Effort:** S\n[ ]\n' \
    > "$worktree/.forge/branch/php85/plan.md"
}

linked_plan() {
  printf '%s' "$SANDBOX/$1.worktrees/php85/.forge/branch/php85/plan.md"
}

# Écriture du plan lié <nom> par le délégué <agent>, lancé par la session parente.
run_delegate_hook() {
  run_hook "$(linked_plan "$1")" ",\"agent_id\":\"$2\""
}

# Exécution d'un délégué associé au projet <projet> : début et fin en minutes.
seed_delegate_run() {
  printf '{"event":"delegate","agent_id":"%s","branch":"php85","project":"%s"}\n{"ts":%s,"event":"SubagentStart","session":"s1","agent_id":"%s"}\n{"ts":%s,"event":"SubagentStop","session":"s1","agent_id":"%s"}\n' \
    "$2" "$1" $((1700000000000 + $3 * 60000)) "$2" $((1700000000000 + $4 * 60000)) "$2" >> "$OWN_LOG"
}

# Plan parent : T1 et T2 portent le champ de branche liée <champ1>, <champ2> (vide → sans champ).
write_parent_plan() {
  write_plan "$1" "$2" "[ ]"
  [ -n "$3" ] && sed -i "s|^\*\*Description:\*\* un\$|**Linked branch:** $3\n&|" "$PLAN"
  [ -n "$4" ] && sed -i "s|^\*\*Description:\*\* deux\$|**Linked branch:** $4\n&|" "$PLAN"
  return 0
}

test_hook_associates_delegate_to_its_linked_project_once() {
  : > "$OWN_LOG"
  create_linked_project api
  run_delegate_hook api a1 >/dev/null
  run_delegate_hook api a1 >/dev/null
  assert_equals 1 "$(grep -cxF '{"event":"delegate","agent_id":"a1","branch":"php85","project":"../api"}' "$OWN_LOG")"
  assert_matches '"event":"plan_checkpoint","branch":"php85","project":"\.\./api"' "$(cat "$OWN_LOG")"
}

test_hook_associates_child_branch_of_same_repository_without_project() {
  local worktree="$SANDBOX/work.worktrees/child"
  : > "$OWN_LOG"
  git -C "$WORK" worktree add -q -b child "$worktree" feature 2>/dev/null
  mkdir -p "$worktree/.forge/branch/child"
  printf '# Plan\n\n## Tasks\n\n### T1 — Un\n**Effort:** S\n[ ]\n' > "$worktree/.forge/branch/child/plan.md"
  run_hook "$worktree/.forge/branch/child/plan.md" ',"agent_id":"a1"' >/dev/null
  assert_equals 1 "$(grep -cxF '{"event":"delegate","agent_id":"a1","branch":"child"}' "$OWN_LOG")"
}

test_two_linked_projects_on_same_branch_keep_their_own_checkpoint() {
  : > "$OWN_LOG"
  create_linked_project api
  create_linked_project pos
  run_delegate_hook api a1 >/dev/null
  run_delegate_hook pos b1 >/dev/null
  sed -i '0,/^\[ \]$/s//[x]/' "$(linked_plan api)"
  run_delegate_hook api a1 >/dev/null
  assert_equals 1 "$(count_events task_done "$OWN_LOG")"
  assert_matches '"event":"task_done","task":"T1","branch":"php85","project":"\.\./api"' "$(cat "$OWN_LOG")"
  run_delegate_hook pos b1 >/dev/null
  assert_equals 1 "$(count_events task_done "$OWN_LOG")"
}

# Tâche d'un plan délégué : <numéro> <titre> <statut> <estimation, vide → sans> <réel, vide → sans>.
unit_task() {
  printf '### T%s — %s\n**Effort:** S\n**Files:** `src` (≈ 10)\n' "$1" "$2"
  [ -n "$4" ] && printf '**Estimated time:** %s\n' "$4"
  [ -n "$5" ] && printf '**Actual time:** %s\n' "$5"
  printf '**Description:** x\n%s\n\n' "$3"
}

# Plan délégué <fichier> dont les tâches arrivent sur l'entrée standard.
write_unit_plan() {
  mkdir -p "${1%/*}"
  { printf '# Plan\n\n## Tasks\n\n'; cat; printf '## Risks\n- aucun\n'; } > "$1"
}

readonly ACTUAL_A='≈ 10.0 min agent (incl. 2.0 min checks) · human 1.0 min (1 questions) · 6 files · total ≈ 11.0 min'
readonly ACTUAL_B='≈ 4.5 min agent (incl. 0.5 min checks) · human 0.0 min (0 questions) · 3 files · total ≈ 4.5 min'
readonly ACTUAL_SUM='**Actual time:** ≈ 14.5 min agent (incl. 2.5 min checks) · human 1.0 min (1 questions) · 9 files · total ≈ 15.5 min'

test_linked_task_is_the_sum_of_its_own_plan_tasks() {
  create_linked_project api
  create_linked_project pos
  seed_checkpoint 1700000000000 ""
  seed_delegate_run ../api a1 0 120
  { unit_task 1 Un '[x] fait' '' "$ACTUAL_A"; unit_task 2 Deux '[x] fait' '' "$ACTUAL_B"; } | write_unit_plan "$(linked_plan api)"
  unit_task 1 Un '[x] fait' '' "$ACTUAL_B" | write_unit_plan "$(linked_plan pos)"
  write_parent_plan "[x] fait" "[x] fait" "../api @ php85" "../pos @ php85"
  run_hook "$PLAN" >/dev/null
  assert_equals "$ACTUAL_SUM" "$(actual_line_of T1)"
  assert_equals "**Actual time:** $ACTUAL_B" "$(actual_line_of T2)"
  assert_equals 0 "$(count_events task_start "$OWN_LOG")"
}

test_delegation_note_on_its_own_line_marks_a_linked_task() {
  create_linked_project api
  seed_checkpoint 1700000000000 ""
  unit_task 1 Un '[x] fait' '' "$ACTUAL_B" | write_unit_plan "$(linked_plan api)"
  write_parent_plan "[x] fait" "[ ]" "" ""
  sed -i 's|^\[x\] fait$|&\ndelegated to ../api @ php85 · done|' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals "**Actual time:** $ACTUAL_B" "$(actual_line_of T1)"
}

test_unit_task_with_an_unmeasured_done_task_gets_dash() {
  create_linked_project api
  seed_checkpoint 1700000000000 ""
  { unit_task 1 Un '[x] fait' '' "$ACTUAL_A"; unit_task 2 Deux '[x] fait' '' '—'; } | write_unit_plan "$(linked_plan api)"
  write_parent_plan "[x] fait" "[ ]" "../api @ php85" ""
  run_hook "$PLAN" >/dev/null
  assert_equals '**Actual time:** —' "$(actual_line_of T1)"
}

test_unit_task_ignores_open_and_dropped_tasks() {
  create_linked_project api
  seed_checkpoint 1700000000000 ""
  { unit_task 1 Un '[x] fait' '' "$ACTUAL_B"; unit_task 2 Deux '[-] abandon' '' '—'; unit_task 3 Trois '[!] blocked' '' ''; } \
    | write_unit_plan "$(linked_plan api)"
  write_parent_plan "[x] fait" "[ ]" "../api @ php85" ""
  run_hook "$PLAN" >/dev/null
  assert_equals "**Actual time:** $ACTUAL_B" "$(actual_line_of T1)"
}

test_linked_task_without_measured_delegate_gets_dash_never_parent_time() {
  create_linked_project api
  seed_checkpoint 1700000000000 ""
  printf '{"event":"delegate","agent_id":"old","branch":"php85"}\n{"ts":1700000000000,"event":"SubagentStart","session":"s1","agent_id":"old"}\n{"ts":1700000600000,"event":"SubagentStop","session":"s1","agent_id":"old"}\n' >> "$OWN_LOG"
  write_parent_plan "[x] fait" "[ ]" "../api @ php85" ""
  run_hook "$PLAN" >/dev/null
  assert_equals '**Actual time:** —' "$(actual_line_of T1)"
  assert_equals 0 "$(count_events task_start "$OWN_LOG")"
}

test_tasks_sharing_a_linked_branch_are_measured_by_their_child_tasks() {
  create_linked_project api
  seed_checkpoint 1700000000000 ""
  { unit_task 1 'Un ← parent T1' '[x] fait' '' "$ACTUAL_A"; unit_task 2 'Deux ← parent T1' '[x] fait' '' "$ACTUAL_B"
    unit_task 3 'Trois ← parent T2' '[x] fait' '' '—'; } | write_unit_plan "$(linked_plan api)"
  write_parent_plan "[x] fait" "[x] fait" "../api @ php85" "../api @ php85"
  run_hook "$PLAN" >/dev/null
  assert_equals "$ACTUAL_SUM" "$(actual_line_of T1)"
  assert_equals '**Actual time:** —' "$(actual_line_of T2)"
}

# Plan parent dont T2 et T3 sont des tâches-branches.
write_branches_plan() {
  write_plan "[ ]" "$1" "$2"
  sed -i 's/^### T2 — Deuxième$/### T2 — Branch `feature-two` — lot/; s/^### T3 — Troisième$/### T3 — Branch `feature-three` — lot/' "$PLAN"
}

test_child_branch_task_is_the_sum_of_its_merged_plan_tasks() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  { unit_task 1 Un '[x] fait' '' "$ACTUAL_A"; unit_task 2 Deux '[x] fait' '' "$ACTUAL_B"; } | write_unit_plan "$WORK/.forge/branch/feature-two/plan.md"
  printf '{"event":"engrave","agent_minutes":99.0}\n' > "$WORK/.forge/branch/feature-two/metrics.json"
  write_branches_plan "[x] fusionnée" "[x] fusionnée"
  run_hook "$PLAN" >/dev/null
  assert_equals "$ACTUAL_SUM" "$(actual_line_of T2)"
  assert_equals '**Actual time:** —' "$(actual_line_of T3)"
  assert_equals 0 "$(count_events task_start "$OWN_LOG")"
}

estimate_line_of() {
  awk -v task="$1" '/^### T/ { current = $2 } current == task && /^\*\*Estimated time:\*\*/ { print; exit }' "$PLAN"
}

test_child_branch_estimate_is_indicative_then_sum_of_its_plan_once() {
  local worktree="$SANDBOX/work.worktrees/two" adopted
  : > "$OWN_LOG"
  write_branches_plan "[ ]" "[ ]"
  sed -i '/^\*\*Estimated time:\*\*/d' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_matches '^\*\*Estimated time:\*\* ≈ [0-9]+ min \([0-9]+-[0-9]+\) · indicative$' "$(estimate_line_of T2)"
  git -C "$WORK" worktree add -q -b feature-two "$worktree" feature 2>/dev/null
  { unit_task 1 Un '[ ]' '≈ 30 min (20-40)' ''; unit_task 2 Deux '[ ]' '≈ 12 min (9-16)' ''; } | write_unit_plan "$worktree/.forge/branch/feature-two/plan.md"
  run_hook "$PLAN" >/dev/null
  adopted='**Estimated time:** ≈ 42 min (29-56)'
  assert_equals "$adopted" "$(estimate_line_of T2)"
  assert_equals '**Estimated files:** 20' "$(grep '^\*\*Estimated files:\*\*' "$PLAN")"
  sed -i 's/≈ 30 min/≈ 300 min/' "$worktree/.forge/branch/feature-two/plan.md"
  run_hook "$PLAN" >/dev/null
  assert_equals "$adopted" "$(estimate_line_of T2)"
  assert_matches ' indicative$' "$(estimate_line_of T3)"
}

test_unit_estimate_waits_until_every_task_is_estimated() {
  : > "$OWN_LOG"
  create_linked_project api
  write_unestimated_linked_plan
  { unit_task 1 Un '[ ]' '≈ 30 min (20-40)' ''; unit_task 2 Deux '[ ]' '' ''; } | write_unit_plan "$(linked_plan api)"
  run_hook "$PLAN" >/dev/null
  run_hook "$PLAN" >/dev/null
  assert_matches ' indicative$' "$(estimate_line_of T1)"
}

test_frozen_unit_estimate_is_never_replaced() {
  : > "$OWN_LOG"
  create_linked_project api
  unit_task 1 Un '[ ]' '≈ 30 min (20-40)' '' | write_unit_plan "$(linked_plan api)"
  write_parent_plan "[ ]" "[ ]" "../api @ php85" ""
  run_hook "$PLAN" >/dev/null
  assert_equals '**Estimated time:** ≈ 1 min (1-2)' "$(estimate_line_of T1)"
}

test_remaining_counts_unit_task_by_its_written_estimate() {
  : > "$OWN_LOG"
  write_parent_plan "[ ]" "[x]" "../api @ php85" ""
  sed -i '0,/≈ 1 min (1-2)/s//≈ 100 min (90-120)/; s/^\[ \]$/[x]/; 0,/^\[x\]$/s//[ ]/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_matches '^\| \*\*Remaining\*\* .*≈ 100 min \(90-120\)' "$(grep '^| \*\*Remaining\*\*' "$PLAN")"
}

# Plan parent dont T1 vise la branche liée, sans estimation encore écrite.
write_unestimated_linked_plan() {
  write_parent_plan "[ ]" "[ ]" "../api @ php85" ""
  sed -i '0,/^\*\*Estimated time:\*\*/{/^\*\*Estimated time:\*\*/d}' "$PLAN"
}

test_linked_task_estimate_is_indicative_until_its_delegate_has_a_plan() {
  : > "$OWN_LOG"
  write_unestimated_linked_plan
  run_hook "$PLAN" >/dev/null
  assert_matches '^\*\*Estimated time:\*\* ≈ [0-9]+ min \([0-9]+-[0-9]+\) · indicative$' "$(estimate_line_of T1)"
  [[ $(estimate_line_of T3) != *indicative* ]] || { echo "    ordinary task marked indicative"; exit 1; }
}

test_linked_task_estimate_follows_its_delegate_plan_once() {
  : > "$OWN_LOG"
  write_unestimated_linked_plan
  run_hook "$PLAN" >/dev/null
  create_linked_project api
  { unit_task 1 Un '[ ]' '≈ 30 min (20-40)' ''; unit_task 2 Deux '[ ]' '≈ 12 min (9-16)' ''; } | write_unit_plan "$(linked_plan api)"
  run_hook "$PLAN" >/dev/null
  local adopted
  adopted=$(estimate_line_of T1)
  assert_equals '**Estimated time:** ≈ 42 min (29-56)' "$adopted"
  assert_equals '**Estimated files:** 20' "$(grep '^\*\*Estimated files:\*\*' "$PLAN")"
  [[ $adopted != *indicative* ]] || { echo "    still indicative: $adopted"; exit 1; }
  sed -i 's/≈ 30 min/≈ 300 min/' "$(linked_plan api)"
  run_hook "$PLAN" >/dev/null
  assert_equals "$adopted" "$(estimate_line_of T1)"
  assert_equals 1 "$(grep -c '^\*\*Estimated files:\*\*' "$PLAN")"
}

test_tasks_sharing_a_linked_branch_take_their_own_child_estimates() {
  : > "$OWN_LOG"
  create_linked_project api
  { unit_task 1 'Un ← parent T1' '[ ]' '≈ 30 min (20-40)' ''; unit_task 2 'Deux ← parent T2' '[ ]' '≈ 12 min (9-16)' ''; } | write_unit_plan "$(linked_plan api)"
  write_parent_plan "[ ]" "[ ]" "../api @ php85" "../api @ php85"
  sed -i '/^\*\*Estimated time:\*\*/d' "$PLAN"
  run_hook "$PLAN" >/dev/null
  run_hook "$PLAN" >/dev/null
  assert_equals '**Estimated time:** ≈ 30 min (20-40)' "$(estimate_line_of T1)"
  assert_equals '**Estimated time:** ≈ 12 min (9-16)' "$(estimate_line_of T2)"
}

test_keeps_unplanned_row_under_total() {
  : > "$OWN_LOG"
  write_plan "[ ]" "[ ]" "[ ]"
  run_hook "$PLAN" >/dev/null
  sed -i 's/^| \*\*Total\*\*.*$/&\n| **Unplanned** | | | | **≈ 4.0 min** | |/' "$PLAN"
  sed -i 's/^\*\*Description:\*\* trois$/**Description:** trois bis/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals '| **Unplanned** | | | | **≈ 4.0 min** | |' "$(grep -A1 '^| \*\*Total\*\*' "$PLAN" | tail -1)"
  assert_equals 1 "$(grep -c '^| \*\*Unplanned\*\*' "$PLAN")"
}

test_linked_task_without_log_gets_dash() {
  create_linked_project api
  write_parent_plan "[x] fait" "[ ]" "../api @ php85" ""
  run_hook "$PLAN" >/dev/null
  assert_equals '**Actual time:** —' "$(actual_line_of T1)"
}

test_ordinary_subagent_uses_own_log() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x]" "[ ]" "[ ]"
  run_hook "$PLAN" ',"agent_id":"a1"' >/dev/null
  assert_matches '"event":"task_start","task":"T1","files"' "$(cat "$OWN_LOG")"
}

test_without_log_writes_dash_for_ticked_tasks_only() {
  write_plan "[x]" "[ ]" "[x]"
  sed -i 's/^### T3 — Troisième$/&\n**Actual time:** ≈ 4 min/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals '**Actual time:** —' "$(actual_line_of T1)"
  assert_equals "" "$(actual_line_of T2)"
  assert_equals '**Actual time:** ≈ 4 min' "$(actual_line_of T3)"
  [ ! -e "$OWN_LOG" ] || { echo "    log created"; exit 1; }
}

test_windows_path_in_hook_json() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x]" "[ ]" "[ ]"
  local escaped=${PLAN//\//\\\\}
  run_hook "$escaped" >/dev/null
  assert_matches '"event":"task_done","task":"T1"' "$(cat "$OWN_LOG")"
}

# ── Estimation et tableau récapitulatif ───────────────────────────────────────

# Plan neuf tel que l'écrit le modèle : ni temps estimé, ni en-tête **Estimate:**, tableau à l'ancien format.
write_new_plan() {
  cat > "$PLAN" <<'EOF'
# Plan — feature
**Objective:** objet
**Date:** 2026-11-22

## Tasks

### T1 — Première
**Effort:** S
**Files:** `a.txt`, `a.test.sh`
**Description:** un
[ ]

### T2 — Deuxième
**Effort:** M
**Files:** `src/**/*.ts` (≈ 6)
**Description:** deux
[ ]

## Summary
| Task | Effort | Files | Status |
|---|---|---|---|
| T1 — Court | S | 2 | [ ] |
| **Total** | **1S** | **2** | |
EOF
}

summary_row_of() {
  grep -F "| $1 " "$PLAN"
}

test_new_plan_gets_estimates_and_header() {
  write_new_plan
  run_hook "$PLAN" >/dev/null
  assert_matches '^\*\*Estimate:\*\* ≈ 8 files · ≈ [0-9]+ min \([0-9]+-[0-9]+\)( · indicative)?$' "$(grep '^\*\*Estimate:\*\*' "$PLAN")"
  assert_matches '^\*\*Estimated time:\*\* ≈ [0-9]+ min \([0-9]+-[0-9]+\)$' "$(awk '/^### T1/ { getline; getline; print }' "$PLAN")"
  assert_equals 2 "$(grep -c '^\*\*Estimated time:\*\*' "$PLAN")"
}

test_pattern_count_is_used_for_estimate() {
  write_new_plan
  run_hook "$PLAN" >/dev/null
  assert_matches '^\| T2 — Deuxième \| M \| 6 \| ≈ [0-9]+ min \| — \| \[ \] \|$' "$(summary_row_of T2)"
}

test_existing_estimate_is_never_recomputed() {
  write_new_plan
  sed -i 's/^\*\*Effort:\*\* S$/&\n**Estimated time:** ≈ 42 min (40-50)/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals '**Estimated time:** ≈ 42 min (40-50)' "$(grep -F '42 min' "$PLAN" | head -1)"
  assert_equals 2 "$(grep -c '^\*\*Estimated time:\*\*' "$PLAN")"
}

test_added_task_gets_its_estimate_and_header_follows() {
  write_new_plan
  run_hook "$PLAN" >/dev/null
  local first
  first=$(grep -m1 '^\*\*Estimated time:\*\*' "$PLAN")
  printf '\n### T3 — Ajoutée\n**Effort:** S\n**Files:** `c.txt`\n**Description:** trois\n[ ]\n' > "$SANDBOX/task"
  sed -i "/^## Summary/e cat $SANDBOX/task" "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals "$first" "$(grep -m1 '^\*\*Estimated time:\*\*' "$PLAN")"
  assert_equals 3 "$(grep -c '^\*\*Estimated time:\*\*' "$PLAN")"
  assert_matches '^\| T3 — Ajoutée \| S \| 1 \|' "$(summary_row_of T3)"
  local minutes
  minutes=$(grep '^\*\*Estimated time:\*\*' "$PLAN" | awk '{ sum += $4 } END { print sum }')
  assert_matches "^\\*\\*Estimate:\\*\\* ≈ 9 files · ≈ $minutes min \\(" "$(grep '^\*\*Estimate:\*\*' "$PLAN")"
}

test_summary_gets_new_columns_and_keeps_short_title() {
  write_new_plan
  run_hook "$PLAN" >/dev/null
  assert_equals '| Task | Effort | Files | Estimated | Actual | Status |' "$(grep -F '| Task |' "$PLAN")"
  assert_equals '|---|---|---|---|---|---|' "$(grep -F '|---|' "$PLAN")"
  assert_matches '^\| T1 — Court \| S \| 2 \| ≈ [0-9]+ min \| — \| \[ \] \|$' "$(summary_row_of T1)"
}

test_total_counts_only_measured_tasks() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x]" "[ ]" "[ ]"
  run_hook "$PLAN" >/dev/null
  assert_equals '| **Total** (1/3 measured) | **1S** | **1** | **≈ 1 min** | **≈ 0.0 min** | |' "$(summary_row_of '**Total**')"
}

test_measured_actual_is_never_replaced_by_dash() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x]" "[x]" "[ ]"
  sed -i 's/^\*\*Estimated time:\*\* ≈ 1 min (1-2)$/&\n**Actual time:** ≈ 3.0 min · 1 files/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals '**Actual time:** ≈ 3.0 min · 1 files' "$(actual_line_of T1)"
  assert_equals '**Actual time:** ≈ 3.0 min · 1 files' "$(actual_line_of T2)"
}

test_summary_cells_follow_task_fields() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x] fait" "[!] blocked — accès refusé | relance" "[ ]"
  run_hook "$PLAN" >/dev/null
  assert_equals '| T1 — Première | S | 1 | ≈ 1 min | ≈ 0.0 min agent (incl. 0.0 min checks) · human 0.0 min (0 questions) · 0 files · total ≈ 0.0 min | [x] |' "$(summary_row_of T1)"
  assert_equals '| T2 — Deuxième | S | 1 | ≈ 1 min | — | [!] blocked — accès refusé \| relance |' "$(summary_row_of T2)"
}

test_total_and_remaining_rows() {
  write_new_plan
  run_hook "$PLAN" >/dev/null
  assert_equals '| **Total** (0/2 measured) | | | — | — | |' "$(summary_row_of '**Total**')"
  assert_matches '^\| \*\*Remaining\*\* \| \| \*\*8\*\* \| \*\*≈ [0-9]+ min \([0-9]+-[0-9]+\)\*\* \| \| \|$' "$(summary_row_of '**Remaining**')"
}

test_remaining_row_removed_when_nothing_is_open() {
  write_new_plan
  run_hook "$PLAN" >/dev/null
  sed -i 's/^\[ \]$/[x]/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals "" "$(summary_row_of '**Remaining**')"
  assert_matches '^\| \*\*Total\*\*' "$(summary_row_of '**Total**')"
}

test_summary_section_added_when_missing() {
  write_plan "[ ]" "[ ]" "[ ]"
  run_hook "$PLAN" >/dev/null
  assert_equals 1 "$(grep -c '^## Summary' "$PLAN")"
  assert_matches '^\| T3 — Troisième \| S \| 1 \|' "$(summary_row_of T3)"
}

test_second_identical_write_changes_nothing() {
  write_new_plan
  run_hook "$PLAN" >/dev/null
  local before
  before=$(cat "$PLAN")
  assert_equals "" "$(run_hook "$PLAN")"
  assert_equals "$before" "$(cat "$PLAN")"
}

test_actual_time_carries_checks_share() {
  local now
  now=$(( $(date +%s) * 1000 ))
  : > "$OWN_LOG"
  seed_checkpoint $((now - 60000)) ""
  printf '{"ts":%s,"event":"PostToolUse","session":"s1","tool":"Bash","duration_ms":12000,"check":true}\n' $((now - 30000)) >> "$OWN_LOG"
  write_plan "[x]" "[ ]" "[ ]"
  run_hook "$PLAN" >/dev/null
  assert_equals '**Actual time:** ≈ 0.0 min agent (incl. 0.2 min checks) · human 0.0 min (0 questions) · 0 files · total ≈ 0.0 min' "$(actual_line_of T1)"
}

# Vingt tâches mesurées d'une autre branche : 1 min de vérification par tâche, 5 min par fichier prévu.
write_measured_branch() {
  local index
  mkdir -p "$WORK/.forge/branch/other"
  {
    printf '# Plan\n**Date:** 2026-11-01\n\n## Tasks\n'
    for index in {1..20}; do
      printf '\n### T%d — Faite\n**Estimated time:** ≈ 6 min (1-9)\n**Actual time:** ≈ 6 min agent (incl. 1 min checks) · 3 files\n**Files:** `a`\n[x] fait\n' "$index"
    done
  } > "$WORK/.forge/branch/other/plan.md"
}

test_remaining_adds_check_cost_of_each_open_task() {
  write_measured_branch
  write_new_plan
  run_hook "$PLAN" >/dev/null
  assert_matches '^\| \*\*Remaining\*\* \| \| \*\*8\*\* \| \*\*≈ 42 min \(' "$(summary_row_of '**Remaining**')"
}

# ── Réel ventilé par poste ────────────────────────────────────────────────────

actual_header() {
  grep '^\*\*Actual:\*\*' "$PLAN"
}

# Journal d'une branche : un tour d'agent de 6 min, dont 1 min de vérification, une question de 2 min.
seed_branch_log() {
  local base=1700000000000
  cat >> "$OWN_LOG" <<LOG
{"ts":$base,"event":"UserPromptSubmit","session":"s1","origin":"human"}
{"ts":$((base + 60000)),"event":"PreToolUse","session":"s1","tool":"AskUserQuestion"}
{"ts":$((base + 180000)),"event":"PostToolUse","session":"s1","tool":"AskUserQuestion"}
{"ts":$((base + 240000)),"event":"PostToolUse","session":"s1","tool":"Bash","duration_ms":60000,"check":true}
{"ts":$((base + 480000)),"event":"Stop","session":"s1"}
LOG
}

readonly ENGRAVED_HEADER='**Actual:** ≈ 3.0 min agent (incl. — checks) · human — (— questions, —) · delegates — in parallel · total ≈ 3.0 min'

test_plan_write_never_adds_branch_header() {
  : > "$OWN_LOG"
  seed_branch_log
  write_plan "[ ]" "[ ]" "[ ]"
  sed -i 's/^# Plan — feature$/&\n**Date:** 2026-11-23/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals "" "$(actual_header)"
}

test_plan_write_keeps_engraved_branch_header() {
  : > "$OWN_LOG"
  seed_branch_log
  write_plan "[ ]" "[ ]" "[ ]"
  sed -i "s/^# Plan — feature\$/&\n**Date:** 2026-11-23\n$ENGRAVED_HEADER/" "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals "$ENGRAVED_HEADER" "$(actual_header)"
  assert_equals 1 "$(grep -c '^\*\*Actual:\*\*' "$PLAN")"
}

test_no_header_without_log() {
  write_plan "[x]" "[ ]" "[ ]"
  sed -i 's/^# Plan — feature$/&\n**Date:** 2026-11-23/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals "" "$(actual_header)"
  assert_equals '| **Total** (0/3 measured) | | | — | — | |' "$(summary_row_of '**Total**')"
}

test_total_row_points_to_header_when_nothing_is_measured() {
  : > "$OWN_LOG"
  write_plan "[ ]" "[ ]" "[ ]"
  sed -i "s/^# Plan — feature\$/&\n**Date:** 2026-11-23\n$ENGRAVED_HEADER/" "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals '| **Total** (0/3 measured) | | | — | see **Actual:** | |' "$(summary_row_of '**Total**')"
}

test_task_actual_time_is_broken_down_and_calibration_reads_it() {
  local now
  now=$(( $(date +%s) * 1000 ))
  : > "$OWN_LOG"
  seed_checkpoint $((now - 600000)) ""
  cat >> "$OWN_LOG" <<EOF
{"ts":$((now - 600000)),"event":"Stop","session":"s1"}
{"ts":$((now - 480000)),"event":"UserPromptSubmit","session":"s1","origin":"human"}
{"ts":$((now - 420000)),"event":"PreToolUse","session":"s1","tool":"AskUserQuestion"}
{"ts":$((now - 360000)),"event":"PostToolUse","session":"s1","tool":"AskUserQuestion"}
{"ts":$((now - 300000)),"event":"PostToolUse","session":"s1","tool":"Bash","duration_ms":30000,"check":true}
EOF
  write_plan "[x]" "[ ]" "[ ]"
  sed -i 's/^# Plan — feature$/&\n**Date:** 2026-11-23/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_matches '^\*\*Actual time:\*\* ≈ 7\.[0-9] min agent \(incl\. 0\.5 min checks\) · human 3\.0 min \(1 questions\) · 0 files · total ≈ 10\.[0-9] min$' "$(actual_line_of T1)"
  local samples
  samples=$(source "$REPO_ROOT/skills/forge/scripts/task-files.sh"; eval "$(sed -n '/^readonly TASK_SAMPLES_PROGRAM=/,/^  END { flush() }'"'"'$/p' "$REPO_ROOT/skills/forge/scripts/time-calibrate.sh")"; awk "$TASK_SAMPLES_PROGRAM" "$PLAN")
  assert_matches $'^2026-11-23\t0001\t[0-9.]+\t7(\\.[0-9])?\t0\t1\t0\\.5$' "$samples"
}

# ── Script de déploiement SQL ─────────────────────────────────────────────────

# Plan dont ## Deployment cite deux fichiers d'étape et le script de déploiement lui-même.
write_deployment_plan() {
  write_plan "[ ]" "[ ]" "[ ]"
  cat >> "$PLAN" <<'EOF'

## Deployment
- [ ] Réparation — before deploy · T1 — `output/20261123-repair.sql`
- [ ] Procédure — after deploy · T2 — `output/20261123-procedure.sql`
- [ ] Script de déploiement — `output/20261123-deployment-script.sql`
EOF
}

write_output() {
  mkdir -p "$BRANCH_DIR/output"
  printf '%s\n' "${2:-SELECT 1;}" > "$BRANCH_DIR/output/$1"
}

test_missing_deployment_script_is_reported() {
  write_deployment_plan
  write_output 20261123-repair.sql
  assert_matches 'deployment script missing — SQL step files written: output/20261123-repair\.sql — apply commands/deployment-sql\.md now\.' "$(run_hook "$PLAN")"
}

test_missing_deployment_script_is_reported_without_plan_rewrite() {
  write_deployment_plan
  write_output 20261123-repair.sql
  run_hook "$PLAN" >/dev/null
  local output
  output=$(run_hook "$PLAN")
  assert_matches 'deployment script missing' "$output"
  [[ $output == *"plan.md rewritten"* ]] && { echo "    unexpected rewrite report"; exit 1; }
  return 0
}

test_complete_deployment_script_reports_nothing() {
  write_deployment_plan
  write_output 20261123-repair.sql
  write_output 20261123-procedure.sql
  write_output 20261123-deployment-script.sql $'-- STEP 1 — output/20261123-repair.sql\n-- STEP 2 — output/20261123-procedure.sql'
  run_hook "$PLAN" >/dev/null
  assert_equals "" "$(run_hook "$PLAN")"
}

test_unwritten_step_file_reports_nothing() {
  write_deployment_plan
  run_hook "$PLAN" >/dev/null
  assert_equals "" "$(run_hook "$PLAN")"
}

test_incomplete_deployment_script_names_only_unreferenced_file() {
  write_deployment_plan
  write_output 20261123-repair.sql
  write_output 20261123-procedure.sql
  write_output 20261123-deployment-script.sql '-- STEP 1 — output/20261123-repair.sql'
  local output
  output=$(run_hook "$PLAN")
  assert_matches 'deployment script incomplete — SQL step files not referenced: output/20261123-procedure\.sql — apply' "$output"
  [[ $output == *"not referenced: output/20261123-repair.sql"* ]] && { echo "    referenced file reported"; exit 1; }
  return 0
}

# ── Exécution ─────────────────────────────────────────────────────────────────

run_test test_ignores_file_outside_plan "ignore tout fichier autre que .forge/branch/<branche>/plan.md"
run_test test_first_pass_writes_checkpoint_without_marks "premier passage : point d'étape seul, aucune marque ni réel"
run_test test_added_task_moves_checkpoint_when_no_code_is_in_progress "tâche ajoutée sans code modifié : le compteur repart, une seule fois"
run_test test_added_task_moves_checkpoint_when_everything_is_committed "tâche ajoutée, tout commité : le compteur repart"
run_test test_added_task_keeps_checkpoint_of_a_task_in_progress "tâche ajoutée pendant une tâche en cours : heure gardée"
run_test test_tick_writes_retroactive_start_done_and_actual_time "coche : début au dernier point d'étape, fin maintenant, réel écrit et signalé au modèle"
run_test test_actual_time_goes_under_estimated_time "écrit le réel sous le temps estimé"
run_test test_actual_time_goes_under_effort_without_estimate "écrit le réel sous l'effort quand la tâche n'a pas d'estimation"
run_test test_replaces_existing_actual_time "remplace un réel déjà présent, jamais de doublon"
run_test test_two_ticks_at_once_are_not_measured "deux coches d'un coup : tâches simultanées, réel « — » pour chacune"
run_test test_rewrite_without_new_tick_writes_nothing "plan réécrit sans nouvelle coche : rien d'écrit"
run_test test_removed_tick_keeps_checkpoint_time_and_retick_measures_from_it "coche retirée : point d'étape gardé ; remise : mesurée depuis lui"
run_test test_task_picked_out_of_order_is_measured "tâche prise hors ordre : mesurée, les autres intactes"
run_test test_sequential_tasks_are_not_overlapping "deux tâches successives : la seconde reste mesurée"
run_test test_skipped_tasks_get_no_mark "tâche-branche et tâche déléguée à un projet lié : aucune marque, point d'étape déplacé"
run_test test_keeps_crlf_line_endings "garde les fins de ligne CRLF du plan"
run_test test_delegate_marks_go_to_parent_log_with_branch "délégué : marques dans le journal du parent, avec la branche du plan"
run_test test_hook_associates_delegate_to_its_linked_project_once "associe une seule fois un délégué à son projet lié"
run_test test_hook_associates_child_branch_of_same_repository_without_project "branche fille du même dépôt : association sans projet"
run_test test_two_linked_projects_on_same_branch_keep_their_own_checkpoint "deux projets liés sur la même branche : points d'étape séparés"
run_test test_linked_task_is_the_sum_of_its_own_plan_tasks "tâche liée : somme des tâches de son seul plan, jamais le temps total du délégué"
run_test test_delegation_note_on_its_own_line_marks_a_linked_task "note de délégation sur sa propre ligne : tâche liée"
run_test test_linked_task_without_measured_delegate_gets_dash_never_parent_time "tâche liée sans délégué mesuré : tiret, jamais le temps du parent"
run_test test_tasks_sharing_a_linked_branch_are_measured_by_their_child_tasks "tâches d'une même branche liée : mesurées par leurs tâches enfant"
run_test test_unit_task_with_an_unmeasured_done_task_gets_dash "tâche liée : une tâche faite non mesurée donne « — »"
run_test test_unit_task_ignores_open_and_dropped_tasks "tâche liée : tâches abandonnées et bloquées hors de la somme"
run_test test_child_branch_task_is_the_sum_of_its_merged_plan_tasks "tâche-branche : somme des tâches de son plan fusionné, jamais son metrics.json"
run_test test_child_branch_estimate_is_indicative_then_sum_of_its_plan_once "tâche-branche : estimation indicative, puis somme de son plan une seule fois"
run_test test_unit_estimate_waits_until_every_task_is_estimated "plan délégué pas encore estimé en entier : estimation gardée indicative"
run_test test_frozen_unit_estimate_is_never_replaced "estimation déjà figée d'une tâche liée : jamais remplacée"
run_test test_remaining_counts_unit_task_by_its_written_estimate "reste à faire : tâche liée comptée à son estimation écrite"
run_test test_linked_task_estimate_is_indicative_until_its_delegate_has_a_plan "tâche liée : estimation indicative avant le plan du délégué"
run_test test_linked_task_estimate_follows_its_delegate_plan_once "tâche liée : estimation reprise du plan du délégué, une seule fois"
run_test test_tasks_sharing_a_linked_branch_take_their_own_child_estimates "tâches d'une même branche liée : estimations de leurs tâches enfant"
run_test test_keeps_unplanned_row_under_total "ligne Unplanned gardée sous Total"
run_test test_linked_task_without_log_gets_dash "tâche liée sans journal : tiret"
run_test test_ordinary_subagent_uses_own_log "sous-agent ordinaire dans la même branche : journal de la branche"
run_test test_without_log_writes_dash_for_ticked_tasks_only "sans journal : « — » pour les tâches cochées sans réel, rien d'autre"
run_test test_windows_path_in_hook_json "lit un chemin Windows à barres obliques inverses"
run_test test_new_plan_gets_estimates_and_header "plan neuf : temps estimé de chaque tâche et en-tête Estimate écrits"
run_test test_pattern_count_is_used_for_estimate "motif (≈ n) : compte de fichiers retenu"
run_test test_existing_estimate_is_never_recomputed "estimation existante jamais recalculée"
run_test test_added_task_gets_its_estimate_and_header_follows "tâche ajoutée : seule elle est estimée, l'en-tête suit la somme des tâches"
run_test test_summary_gets_new_columns_and_keeps_short_title "ancien tableau : colonnes Estimated et Actual ajoutées, titre court gardé"
run_test test_total_counts_only_measured_tasks "ligne Total : seules les tâches au réel mesuré, estimé et réel comparables"
run_test test_measured_actual_is_never_replaced_by_dash "un réel mesuré n'est jamais remplacé par « — »"
run_test test_summary_cells_follow_task_fields "cellules recopiées des tâches : réel, statut, raison du blocage échappée"
run_test test_total_and_remaining_rows "lignes Total et Remaining"
run_test test_remaining_row_removed_when_nothing_is_open "ligne Remaining retirée quand plus rien n'est ouvert"
run_test test_summary_section_added_when_missing "section Summary ajoutée quand elle manque"
run_test test_second_identical_write_changes_nothing "seconde écriture identique : plan intact, rien signalé"
run_test test_actual_time_carries_checks_share "le réel porte la part de vérifications de la tâche"
run_test test_remaining_adds_check_cost_of_each_open_task "reste à faire : coût fixe de vérification de chaque tâche ouverte"
run_test test_plan_write_never_adds_branch_header "écriture du plan avec un journal : aucune ligne Actual de branche ajoutée"
run_test test_plan_write_keeps_engraved_branch_header "écriture du plan : ligne Actual de la dernière livraison gardée telle quelle"
run_test test_no_header_without_log "sans journal : aucune ligne Actual, Total inchangé"
run_test test_total_row_points_to_header_when_nothing_is_measured "Total à 0 tâche mesurée : renvoi à la ligne Actual quand elle existe"
run_test test_task_actual_time_is_broken_down_and_calibration_reads_it "réel par tâche ventilé avec « incl. », total = agent + humain, premier nombre, fichiers et part checks lus par le calibrage"
run_test test_missing_deployment_script_is_reported "fichier d'étape SQL écrit sans script de déploiement : « missing » signalé"
run_test test_missing_deployment_script_is_reported_without_plan_rewrite "« missing » encore signalé quand le plan n'est pas réécrit"
run_test test_complete_deployment_script_reports_nothing "script de déploiement citant tous les fichiers écrits : rien signalé"
run_test test_unwritten_step_file_reports_nothing "fichier d'étape pas encore écrit : rien signalé"
run_test test_incomplete_deployment_script_names_only_unreferenced_file "« incomplete » avec le seul fichier d'étape non cité"

report_results
