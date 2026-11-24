#!/bin/bash
# Tests de skills/forge/scripts/time-calibrate.sh — chaque test tourne dans un dossier jetable,
# synthèses metrics.json écrites à la main.
# Usage : bash tests/time-calibrate.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CALIBRATE_SCRIPT="$REPO_ROOT/skills/forge/scripts/time-calibrate.sh"
PASSED=0
FAILED=0

# ── Bac à sable ───────────────────────────────────────────────────────────────

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  WORK="$SANDBOX/work"
  mkdir -p "$WORK/.forge/branch"
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

calibrate() {
  bash "$CALIBRATE_SCRIPT" --root "$WORK" "$@"
}

# Synthèse d'une branche : nom, date, minutes d'agent, fichiers réels, fichiers prévus, tokens (mesure brute, non lue par le calibrage).
write_metrics() {
  mkdir -p "$WORK/.forge/branch/$1"
  printf '{"event":"engrave","date":"%s","branch":"%s","mode":"delegated","model":"m","planned_files":%s,"actual_files":%s,"lines_added":10,"lines_deleted":0,"agent_minutes":%s,"human_minutes":null,"questions":0,"check_minutes":null,"tokens":%s}\n' \
    "$2" "$1" "$5" "$4" "$3" "$6" > "$WORK/.forge/branch/$1/metrics.json"
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

# ── Sans mesure ───────────────────────────────────────────────────────────────

test_uses_reference_values_without_measure() {
  local output
  output=$(calibrate)
  assert_contains '"minutes_per_file":0.50,"file_error"' "$output"
  assert_contains '"source":"reference"' "$output"
  assert_contains '"indicative":true' "$output"
  assert_contains '"file_error":null,"apply_file_error":false' "$output"
}

test_returns_check_cost_and_branch_threshold() {
  local output
  output=$(calibrate)
  assert_contains '"check_minutes":0.0,"check_source":"reference","branch_minutes":15,"branch_files":30}' "$output"
  case $output in *range_low*|*delegate_minutes*|*merge_minutes*|*fixed*) echo "    unexpected field"; exit 1 ;; esac
}

# ── Gain d'un essaim ──────────────────────────────────────────────────────────

# 3 × 60 fichiers = 3 × 30 min, une par délégué.
test_computes_swarm_gain_for_branches_spread_over_slots() {
  assert_contains '"swarm":{"branches":3,"slots":3,"serial_minutes":90,"swarm_minutes":30}' \
    "$(calibrate --groups 60,60,60)"
}

# Plus de branches que de délégués : la plus longue d'abord, chacune au délégué le moins chargé.
test_queues_branches_beyond_available_slots() {
  assert_contains '"branches":3,"slots":2,"serial_minutes":60,"swarm_minutes":40' "$(calibrate --groups 40,40,40 --slots 2)"
}

# Vérifications mesurées à 1 min par tâche, 5 min par fichier prévu : 4 × 1 + 150, puis 1 + 150.
test_counts_check_cost_of_each_task_of_a_group() {
  # shellcheck disable=SC2046
  write_plan_tasks feature 2026-11-01 $(repeat_task 20 10:6/3/1)
  assert_contains '"serial_minutes":305,' "$(calibrate --groups 30/4,30)"
}

# Une branche seule : 15 min dans les deux cas, rien à paralléliser.
test_shows_no_gain_for_single_branch_without_parent_work() {
  local output
  output=$(calibrate --groups 30)
  assert_contains '"branches":1,"slots":3,"serial_minutes":15,"swarm_minutes":15}' "$output"
}

# Une branche (15 min) et 20 fichiers du parent en 3 tâches (10 min) : série 25, essaim max(15, 10) = 15.
test_counts_parent_work_as_parallel_lane_for_single_branch() {
  assert_contains '"serial_minutes":25,"swarm_minutes":15,"parent_minutes":10}' \
    "$(calibrate --groups 30 --parent 20/3)"
}

# Deux branches de 30 min et un parent de 40 min : la voie du parent fixe la durée.
test_lets_longest_parent_lane_set_swarm_time() {
  assert_contains '"branches":2,"slots":3,"serial_minutes":100,"swarm_minutes":40,"parent_minutes":40}' \
    "$(calibrate --groups 60,60 --parent 80/4)"
}

test_rejects_parent_work_without_groups_or_malformed() {
  calibrate --parent 20/3 >/dev/null 2>&1
  assert_equals "1" "$?"
  calibrate --groups 30 --parent 20/0 >/dev/null 2>&1
  assert_equals "1" "$?"
  calibrate --groups 30 --parent 20,3 >/dev/null 2>&1
  assert_equals "1" "$?"
}

test_rejects_malformed_groups_or_slots() {
  calibrate --groups 3,,5 >/dev/null 2>&1
  assert_equals "1" "$?"
  calibrate --groups 3/0,5 >/dev/null 2>&1
  assert_equals "1" "$?"
  calibrate --groups 3,5 --slots 0 >/dev/null 2>&1
  assert_equals "1" "$?"
}

test_estimates_at_least_one_minute() {
  assert_contains '"estimate":{"files":1,"minutes":1,"low":1,"high":1}' "$(calibrate --files 1)"
}

test_estimates_each_task_of_a_list_and_their_sum() {
  local output
  output=$(calibrate --files 3,5,8)
  assert_contains '"estimate":{"files":16,"minutes":8,"low":6,"high":10}' "$output"
  assert_contains '"estimates":[{"files":3,"minutes":2,"low":1,"high":2},{"files":5,"minutes":2,"low":2,"high":3},{"files":8,"minutes":4,"low":3,"high":5}]' "$output"
}

test_gives_no_list_for_a_single_value() {
  case $(calibrate --files 4) in *'"estimates"'*) echo "    unexpected estimates list"; exit 1 ;; esac
}

test_estimates_files_with_range() {
  assert_contains '"estimate":{"files":120,"minutes":60,"low":45,"high":78}' "$(calibrate --files 120)"
}

# ── Ratios du projet ──────────────────────────────────────────────────────────









# ── Erreur de prévision des fichiers ──────────────────────────────────────────




# ── Fiabilité ─────────────────────────────────────────────────────────────────



# ── Fourchette ────────────────────────────────────────────────────────────────

# Plan d'une branche : nom, date, puis une tâche par argument « estimé:réel » — réel « — » non mesuré,
# « minutes/fichiers » avec ses fichiers réels, « minutes/fichiers/vérifications » avec sa part de vérifications ;
# chaque tâche liste un fichier prévu ;
# préfixe « branch: » pour une tâche-branche d'essaim, « delegated: » pour une tâche déléguée à un projet lié.
write_plan_tasks() {
  local branch=$1 date=$2 index=0 task kind estimated actual title note minutes files checks
  shift 2
  mkdir -p "$WORK/.forge/branch/$branch"
  {
    printf '# Plan — %s\n**Objective:** o\n**Date:** %s\n\n## Tasks\n' "$branch" "$date"
    for task in "$@"; do
      index=$((index + 1)); kind=plain; title="Tâche"; note="fait"
      case $task in branch:*|delegated:*) kind=${task%%:*}; task=${task#*:} ;; esac
      estimated=${task%%:*}; actual=${task#*:}
      [ "$kind" = branch ] && title="Branch \`$branch-x$index\` — lot"
      [ "$kind" = delegated ] && note="delegated to ../api @ forge/x · done"
      printf '\n### T%d — %s\n**Effort:** S\n**Estimated time:** ≈ %s min (1-2)\n' "$index" "$title" "$estimated"
      if [ "$actual" = "—" ]; then printf '**Actual time:** —\n'
      elif [[ $actual == */*/* ]]; then
        IFS=/ read -r minutes files checks <<< "$actual"
        printf '**Actual time:** ≈ %s min · %s files · %s min checks\n' "$minutes" "$files" "$checks"
      elif [[ $actual == */* ]]; then printf '**Actual time:** ≈ %s min · %s files\n' "${actual%/*}" "${actual#*/}"
      else printf '**Actual time:** ≈ %s min\n' "$actual"; fi
      printf '**Files:** `a`\n**Description:** d\n[x] %s\n' "$note"
    done
    printf '\n## Summary\n'
  } > "$WORK/.forge/branch/$branch/plan.md"
}

repeat_task() {
  local count=$1 task=$2 i
  for ((i = 0; i < count; i++)); do printf '%s ' "$task"; done
}

test_linked_branch_field_without_note_is_left_out_of_calibration() {
  # shellcheck disable=SC2046 — liste de tâches voulue
  write_plan_tasks feature 2026-11-01 $(repeat_task 20 10:10)
  assert_contains '"range_source":"tasks"' "$(calibrate --files 100)"
  sed -i '0,/^\*\*Files:\*\*/s//**Linked branch:** ..\/api @ php85\n&/' "$WORK/.forge/branch/feature/plan.md"
  assert_contains '"range_source":"reference"' "$(calibrate --files 100)"
}

test_keeps_reference_range_below_twenty_tasks() {
  # shellcheck disable=SC2046 — liste de tâches voulue
  write_plan_tasks feature 2026-11-01 $(repeat_task 19 10:10)
  local output
  output=$(calibrate --files 100)
  assert_contains '"range_source":"reference"' "$output"
  assert_contains '"estimate":{"files":100,"minutes":50,"low":38,"high":65}' "$output"
}

# Vingt tâches exactement à leur estimation : la fourchette se resserre sur elle.
test_narrows_range_for_regular_tasks() {
  # shellcheck disable=SC2046
  write_plan_tasks feature 2026-11-01 $(repeat_task 20 10:10)
  local output
  output=$(calibrate --files 100)
  assert_contains '"range_source":"tasks"' "$output"
  assert_contains '"estimate":{"files":100,"minutes":50,"low":50,"high":50}' "$output"
}

# Écarts réels ÷ estimés de 0,4 à 2 : centiles 20 et 80 à 0,76 et 1,28.
test_widens_range_for_dispersed_tasks() {
  write_plan_tasks feature 2026-11-01 10:4 10:4 10:6 10:6 10:8 10:8 10:9 10:9 10:10 10:10 \
    10:10 10:10 10:11 10:11 10:12 10:12 10:16 10:16 10:20 10:20
  assert_contains '"estimate":{"files":100,"minutes":50,"low":38,"high":64}' "$(calibrate --files 100)"
}

test_ignores_unmeasured_branch_and_delegated_tasks() {
  # shellcheck disable=SC2046
  write_plan_tasks feature 2026-11-01 $(repeat_task 19 10:10) 10:— branch:10:40 delegated:10:40
  assert_contains '"range_source":"reference"' "$(calibrate)"
}

test_keeps_forty_most_recent_tasks() {
  # shellcheck disable=SC2046
  write_plan_tasks old 2026-11-01 $(repeat_task 40 10:20)
  # shellcheck disable=SC2046
  write_plan_tasks new 2026-11-02 $(repeat_task 40 10:10)
  assert_contains '"estimate":{"files":100,"minutes":50,"low":50,"high":50}' "$(calibrate --files 100)"
}

test_counts_tasks_of_child_branch_plans() {
  # shellcheck disable=SC2046
  write_plan_tasks parent/child 2026-11-01 $(repeat_task 20 10:10)
  assert_contains '"range_source":"tasks"' "$(calibrate)"
}

# ── Ratios par tâche ──────────────────────────────────────────────────────────

# Vingt tâches : 6 min réelles pour 3 fichiers réels, 1 fichier prévu → 2 min par fichier, prévision × 3.
test_takes_rates_from_tasks_with_their_files() {
  # shellcheck disable=SC2046
  write_plan_tasks feature 2026-11-01 $(repeat_task 20 10:6/3)
  write_metrics other 2026-11-02 50 100 100 null
  local output
  output=$(calibrate --files 2)
  assert_contains '"minutes_per_file":2.00,"file_error":3.00,"apply_file_error":true' "$output"
  assert_contains '"source":"tasks"' "$output"
  assert_contains '"estimate":{"files":2,"minutes":12' "$output"
}

# 2 min par fichier × erreur 3 appliquée = 6 min par fichier : 15 ÷ 6 = 2,5 → 3 fichiers, arrondi au-dessus.
test_rounds_branch_files_up_at_applied_rate() {
  # shellcheck disable=SC2046
  write_plan_tasks feature 2026-11-01 $(repeat_task 20 10:6/3)
  assert_contains '"branch_minutes":15,"branch_files":3}' "$(calibrate)"
}

# 5 min par fichier, erreur dans la tolérance : 15 ÷ 5 = 3 fichiers tout juste, sans fichier de plus.
test_keeps_exact_branch_files_at_calibrated_rate() {
  # shellcheck disable=SC2046
  write_plan_tasks feature 2026-11-01 $(repeat_task 20 10:5/1)
  assert_contains '"branch_files":3}' "$(calibrate)"
}

test_ignores_file_error_within_tolerance() {
  # shellcheck disable=SC2046
  write_plan_tasks feature 2026-11-01 $(repeat_task 20 10:5/1)
  assert_contains '"minutes_per_file":5.00,"file_error":1.00,"apply_file_error":false' "$(calibrate)"
}

# Les branches ne fournissent plus de ratio : sous vingt tâches mesurées avec leurs fichiers, référence.
test_uses_reference_rates_below_twenty_tasks_even_with_measured_branches() {
  # shellcheck disable=SC2046
  write_plan_tasks feature 2026-11-01 $(repeat_task 19 10:6/3) $(repeat_task 5 10:6)
  write_metrics other 2026-11-02 40 100 100 null
  local output
  output=$(calibrate)
  assert_contains '"minutes_per_file":0.50,"file_error":null,"apply_file_error":false' "$output"
  assert_contains '"source":"reference"' "$output"
}

test_is_reliable_once_rates_and_range_come_from_tasks() {
  # shellcheck disable=SC2046
  write_plan_tasks feature 2026-11-01 $(repeat_task 20 10:6/3)
  assert_contains '"indicative":false' "$(calibrate)"
}

test_is_indicative_while_rates_come_from_reference() {
  # shellcheck disable=SC2046
  write_plan_tasks feature 2026-11-01 $(repeat_task 20 10:6)
  local output
  output=$(calibrate)
  assert_contains '"indicative":true' "$output"
  assert_contains '"source":"reference","range_source":"tasks"' "$output"
}

# ── Usage ─────────────────────────────────────────────────────────────────────

test_rejects_non_numeric_files() {
  local output
  output=$(calibrate --files abc 2>/dev/null)
  assert_equals "1" "$?"
  assert_equals "" "$output"
}

test_rejects_malformed_files_list() {
  local output
  output=$(calibrate --files 3,,5 2>/dev/null)
  assert_equals "1" "$?"
  assert_equals "" "$output"
}

test_rejects_unknown_argument() {
  calibrate --nope 2>/dev/null
  assert_equals "1" "$?"
}

# ── Coût fixe de vérification ─────────────────────────────────────────────────

# Vingt tâches : 6 min réelles dont 1 min de vérifications, 3 fichiers → coût fixe 1 min, (6 − 1) ÷ 3 min par fichier.
test_takes_check_cost_from_tasks_and_rate_without_checks() {
  # shellcheck disable=SC2046
  write_plan_tasks feature 2026-11-01 $(repeat_task 20 10:6/3/1)
  local output
  output=$(calibrate --files 2)
  assert_contains '"minutes_per_file":1.67,' "$output"
  assert_contains '"check_minutes":1.0,"check_source":"tasks"' "$output"
  assert_contains '"estimate":{"files":2,"minutes":11,' "$output"
}

test_keeps_reference_check_cost_below_twenty_tasks() {
  # shellcheck disable=SC2046
  write_plan_tasks feature 2026-11-01 $(repeat_task 19 10:6/3/1)
  assert_contains '"check_minutes":0.0,"check_source":"reference"' "$(calibrate)"
}

test_list_estimate_counts_check_cost_once_per_task() {
  local output
  # shellcheck disable=SC2046
  write_plan_tasks feature 2026-11-01 $(repeat_task 20 10:6/3/1)
  output=$(calibrate --files 2,2)
  assert_contains '"estimate":{"files":4,"minutes":22,' "$output"
  assert_contains '"estimates":[{"files":2,"minutes":11,' "$output"
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

echo "time-calibrate.sh"
run_test test_uses_reference_values_without_measure "prend les valeurs de référence sans mesure du projet"
run_test test_returns_check_cost_and_branch_threshold "rend le coût de vérification et le seuil de branche, aucun coût fixe de branche"
run_test test_computes_swarm_gain_for_branches_spread_over_slots "calcule le gain d'un essaim réparti sur les délégués"
run_test test_queues_branches_beyond_available_slots "met en file les branches au-delà des délégués disponibles"
run_test test_counts_check_cost_of_each_task_of_a_group "essaim : coût fixe de vérification de chaque tâche d'un groupe"
run_test test_shows_no_gain_for_single_branch_without_parent_work "aucun gain pour une branche seule sans travail du parent"
run_test test_counts_parent_work_as_parallel_lane_for_single_branch "une branche seule : travail du parent compté comme voie parallèle"
run_test test_lets_longest_parent_lane_set_swarm_time "plusieurs branches : la voie du parent la plus longue fixe la durée"
run_test test_rejects_parent_work_without_groups_or_malformed "refuse un travail du parent sans groupes ou mal formé"
run_test test_rejects_malformed_groups_or_slots "refuse des groupes ou un nombre de délégués mal formés"
run_test test_estimates_at_least_one_minute "une tâche d'un fichier : une minute au moins, bornes comprises"
run_test test_estimates_each_task_of_a_list_and_their_sum "estime chaque tâche d'une liste et leur somme en un appel"
run_test test_gives_no_list_for_a_single_value "ne rend pas de liste pour une seule valeur"
run_test test_estimates_files_with_range "estime un nombre de fichiers avec sa fourchette"
run_test test_linked_branch_field_without_note_is_left_out_of_calibration "branche liée sans note : écartée du calibrage"
run_test test_keeps_reference_range_below_twenty_tasks "garde la fourchette de référence sous vingt tâches mesurées"
run_test test_narrows_range_for_regular_tasks "resserre la fourchette sur des tâches régulières"
run_test test_widens_range_for_dispersed_tasks "élargit la fourchette sur des tâches dispersées"
run_test test_ignores_unmeasured_branch_and_delegated_tasks "écarte les tâches non mesurées, les tâches-branches et les tâches déléguées"
run_test test_keeps_forty_most_recent_tasks "ne garde que les quarante tâches les plus récentes"
run_test test_counts_tasks_of_child_branch_plans "compte les tâches des plans de branches filles"
run_test test_takes_rates_from_tasks_with_their_files "tire minutes par fichier et erreur de prévision des tâches mesurées avec leurs fichiers"
run_test test_rounds_branch_files_up_at_applied_rate "seuil de branche en fichiers arrondi au-dessus, aux minutes par fichier appliquées"
run_test test_keeps_exact_branch_files_at_calibrated_rate "seuil de branche en fichiers exact sans fichier de plus"
run_test test_ignores_file_error_within_tolerance "n'applique pas l'erreur de prévision sous 20 %"
run_test test_uses_reference_rates_below_twenty_tasks_even_with_measured_branches "prend les ratios de référence sous vingt tâches, branches mesurées ou non"
run_test test_is_reliable_once_rates_and_range_come_from_tasks "est fiable quand ratios et fourchette viennent des tâches"
run_test test_is_indicative_while_rates_come_from_reference "reste indicative tant que les ratios viennent de la référence"
run_test test_rejects_non_numeric_files "refuse un nombre de fichiers non entier"
run_test test_rejects_malformed_files_list "refuse une liste de fichiers mal formée"
run_test test_rejects_unknown_argument "refuse un argument inconnu"
run_test test_takes_check_cost_from_tasks_and_rate_without_checks "coût fixe tiré des vérifications des tâches, minutes par fichier hors vérifications"
run_test test_keeps_reference_check_cost_below_twenty_tasks "aucune vérification estimée sous vingt tâches qui portent leurs vérifications"
run_test test_list_estimate_counts_check_cost_once_per_task "estimation d'une liste : un coût fixe par tâche"

echo "$PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ]
