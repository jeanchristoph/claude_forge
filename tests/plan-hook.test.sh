#!/bin/bash
# Tests de skills/forge/scripts/plan-hook.sh — chaque test tourne dans un dépôt jetable, jamais le dépôt courant.
# Usage : bash tests/plan-hook.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_SCRIPT="$REPO_ROOT/skills/forge/scripts/plan-hook.sh"
PASSED=0
FAILED=0

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
  assert_equals '**Actual time:** ≈ 0.0 min · 1 files · 0.0 min checks' "$(actual_line_of T1)"
  assert_matches '"additionalContext":"forge plan-hook: .*T1 → ≈ 0.0 min · 1 files · 0.0 min checks' "$output"
}

test_actual_time_goes_under_estimated_time() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x]" "[ ]" "[ ]"
  run_hook "$PLAN" >/dev/null
  assert_equals '**Actual time:** ≈ 0.0 min · 0 files · 0.0 min checks' "$(grep -A1 -F '**Estimated time:**' "$PLAN" | sed -n 2p)"
}

test_actual_time_goes_under_effort_without_estimate() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 "T1 T2"
  write_plan "[x]" "[x]" "[x]"
  sed -i '/^\*\*Files:\*\* `c.txt`$/d' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals '**Actual time:** ≈ 0.0 min · 0 files · 0.0 min checks' "$(awk '/^### T3/ { getline; getline; print }' "$PLAN")"
}

test_replaces_existing_actual_time() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x]" "[ ]" "[ ]"
  sed -i 's/^\*\*Estimated time:\*\* ≈ 1 min (1-2)$/&\n**Actual time:** ≈ 9 min/' "$PLAN"
  run_hook "$PLAN" >/dev/null
  assert_equals 1 "$(awk '/^### T1/,/^### T2/' "$PLAN" | grep -c 'Actual time')"
  assert_equals '**Actual time:** ≈ 0.0 min · 0 files · 0.0 min checks' "$(actual_line_of T1)"
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
  assert_equals '**Actual time:** ≈ 0.0 min · 0 files · 0.0 min checks' "$(actual_line_of T3)"
  assert_equals "" "$(actual_line_of T2)"
}

test_sequential_tasks_are_not_overlapping() {
  : > "$OWN_LOG"
  seed_checkpoint 1700000000000 ""
  write_plan "[x]" "[ ]" "[ ]"
  run_hook "$PLAN" >/dev/null
  write_plan "[x]" "[x]" "[ ]"
  run_hook "$PLAN" >/dev/null
  assert_equals '**Actual time:** ≈ 0.0 min · 0 files · 0.0 min checks' "$(actual_line_of T2)"
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
  assert_equals '| T1 — Première | S | 1 | ≈ 1 min | ≈ 0.0 min · 0 files · 0.0 min checks | [x] |' "$(summary_row_of T1)"
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
  assert_equals '**Actual time:** ≈ 0.0 min · 0 files · 0.2 min checks' "$(actual_line_of T1)"
}

test_remaining_adds_check_cost_of_each_open_task() {
  write_new_plan
  run_hook "$PLAN" >/dev/null
  assert_matches '^\| \*\*Remaining\*\* \| \| \*\*8\*\* \| \*\*≈ 8 min \(' "$(summary_row_of '**Remaining**')"
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

run_test test_ignores_file_outside_plan "ignore tout fichier autre que .forge/branch/<branche>/plan.md"
run_test test_first_pass_writes_checkpoint_without_marks "premier passage : point d'étape seul, aucune marque ni réel"
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

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
