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

# Synthèse d'une branche : nom, date, minutes d'agent, fichiers réels, fichiers prévus, tokens.
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
  assert_contains '"minutes_per_file":0.50,"tokens_per_file":5000' "$output"
  assert_contains '"source":"reference"' "$output"
  assert_contains '"indicative":true' "$output"
  assert_contains '"file_error":null,"apply_file_error":false' "$output"
}

test_returns_reference_thresholds_and_fixed_costs() {
  local output
  output=$(calibrate)
  assert_contains '"range_low":0.75,"range_high":1.3' "$output"
  assert_contains '"delegate_minutes":8,"merge_minutes":5,"delegate_tokens":50000' "$output"
  assert_contains '"branch_criteria_required":4,"branch_minutes":15,"branch_tokens":300000,"branch_layers":3}' "$output"
}

test_estimates_files_with_range_and_tokens() {
  assert_contains '"estimate":{"files":120,"minutes":60,"low":45,"high":78,"tokens":600000}' "$(calibrate --files 120)"
}

# ── Ratios du projet ──────────────────────────────────────────────────────────

test_takes_median_of_measured_branches() {
  write_metrics a 2026-11-01 30 100 100 400000
  write_metrics b 2026-11-02 40 100 100 500000
  write_metrics c 2026-11-03 60 100 100 600000
  local output
  output=$(calibrate)
  assert_contains '"minutes_per_file":0.40,"tokens_per_file":5000' "$output"
  assert_contains '"source":"project"' "$output"
}

test_keeps_only_five_most_recent_branches() {
  write_metrics old 2026-01-01 1000 100 100 null
  write_metrics a 2026-11-01 40 100 100 null
  write_metrics b 2026-11-02 40 100 100 null
  write_metrics c 2026-11-03 40 100 100 null
  write_metrics d 2026-11-04 40 100 100 null
  write_metrics e 2026-11-05 40 100 100 null
  assert_contains '"minutes_per_file":0.40' "$(calibrate)"
}

test_ignores_branch_without_measured_minutes() {
  write_metrics a 2026-11-01 null 100 100 null
  write_metrics b 2026-11-02 30 100 100 null
  assert_contains '"minutes_per_file":0.30' "$(calibrate)"
}

test_ignores_partially_measured_branch() {
  write_metrics a 2026-11-01 1 100 100 null
  sed -i 's/}$/,"partial":true}/' "$WORK/.forge/branch/a/metrics.json"
  write_metrics b 2026-11-02 30 100 100 null
  local output
  output=$(calibrate)
  assert_contains '"minutes_per_file":0.30' "$output"
  assert_contains '"measured_branches":1' "$output"
}

test_ignores_mixed_branch_for_tokens_per_file() {
  write_metrics a 2026-11-01 30 30 30 100000
  sed -i 's/"mode":"delegated"/"mode":"mixed"/' "$WORK/.forge/branch/a/metrics.json"
  local output
  output=$(calibrate)
  assert_contains '"tokens_per_file":5000' "$output"
  assert_contains '"minutes_per_file":1.00' "$output"
}

test_takes_tokens_per_file_from_delegated_branch() {
  write_metrics a 2026-11-01 30 10 10 100000
  assert_contains '"tokens_per_file":10000' "$(calibrate)"
}

test_reads_branch_folder_containing_a_slash() {
  write_metrics feature/x 2026-11-01 20 100 100 null
  assert_contains '"minutes_per_file":0.20' "$(calibrate)"
}

# ── Erreur de prévision des fichiers ──────────────────────────────────────────

test_applies_file_error_beyond_tolerance() {
  write_metrics a 2026-11-01 50 100 80 null
  write_metrics b 2026-11-02 50 100 80 null
  local output
  output=$(calibrate --files 80)
  assert_contains '"file_error":1.25,"apply_file_error":true' "$output"
  assert_contains '"estimate":{"files":80,"minutes":50' "$output"
}

test_ignores_file_error_within_tolerance() {
  write_metrics a 2026-11-01 50 110 100 null
  assert_contains '"file_error":1.10,"apply_file_error":false' "$(calibrate)"
}

# ── Fiabilité ─────────────────────────────────────────────────────────────────

test_is_reliable_with_five_branches_in_range() {
  local name
  for name in a b c d e; do write_metrics "$name" "2026-11-0${#name}$name" 50 100 100 null; done
  local output
  output=$(calibrate)
  assert_contains '"measured_branches":5,"checked":5,"in_range":5,"indicative":false' "$output"
}

test_is_indicative_below_five_measures() {
  write_metrics a 2026-11-01 50 100 100 null
  assert_contains '"indicative":true' "$(calibrate)"
}

test_is_indicative_when_too_few_branches_in_range() {
  write_metrics a 2026-11-01 50 100 100 null
  write_metrics b 2026-11-02 50 100 100 null
  write_metrics c 2026-11-03 50 100 100 null
  write_metrics d 2026-11-04 200 100 100 null
  write_metrics e 2026-11-05 5 100 100 null
  assert_contains '"in_range":3,"indicative":true' "$(calibrate)"
}

# ── Usage ─────────────────────────────────────────────────────────────────────

test_rejects_non_numeric_files() {
  local output
  output=$(calibrate --files abc 2>/dev/null)
  assert_equals "1" "$?"
  assert_equals "" "$output"
}

test_rejects_unknown_argument() {
  calibrate --nope 2>/dev/null
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

echo "time-calibrate.sh"
run_test test_uses_reference_values_without_measure "prend les valeurs de référence sans mesure du projet"
run_test test_returns_reference_thresholds_and_fixed_costs "rend les seuils de la règle de branche et les coûts fixes"
run_test test_estimates_files_with_range_and_tokens "estime un nombre de fichiers avec fourchette et tokens"
run_test test_takes_median_of_measured_branches "prend la médiane des branches mesurées"
run_test test_keeps_only_five_most_recent_branches "ne garde que les cinq branches les plus récentes"
run_test test_ignores_branch_without_measured_minutes "écarte une branche sans minutes mesurées"
run_test test_ignores_partially_measured_branch "écarte une branche mesurée en partie"
run_test test_ignores_mixed_branch_for_tokens_per_file "écarte une branche mixte du ratio de tokens par fichier"
run_test test_takes_tokens_per_file_from_delegated_branch "tire le ratio de tokens d'une branche entièrement déléguée"
run_test test_reads_branch_folder_containing_a_slash "lit la synthèse d'une branche contenant un slash"
run_test test_applies_file_error_beyond_tolerance "applique l'erreur de prévision des fichiers au-delà de 20 %"
run_test test_ignores_file_error_within_tolerance "n'applique pas l'erreur de prévision sous 20 %"
run_test test_is_reliable_with_five_branches_in_range "est fiable avec cinq branches dans leur fourchette"
run_test test_is_indicative_below_five_measures "est indicative sous cinq mesures"
run_test test_is_indicative_when_too_few_branches_in_range "est indicative quand trop peu de branches tombent dans leur fourchette"
run_test test_rejects_non_numeric_files "refuse un nombre de fichiers non entier"
run_test test_rejects_unknown_argument "refuse un argument inconnu"

echo "$PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ]
