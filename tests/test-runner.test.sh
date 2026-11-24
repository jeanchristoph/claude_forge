#!/bin/bash
# Tests du lanceur commun test-runner.sh et de la suite complète run-all.sh — fichiers de test jetables uniquement.
# Usage : bash tests/test-runner.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$REPO_ROOT/tests/test-runner.sh"

# ── Bac à sable ───────────────────────────────────────────────────────────────

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  cp "$REPO_ROOT/tests/test-runner.sh" "$REPO_ROOT/tests/run-all.sh" "$SANDBOX/"
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

# Écrit un fichier de test jetable : nom, puis corps (cas et appels run_test).
write_test_file() {
  cat > "$SANDBOX/$1.test.sh" <<END
. "\$(dirname "\$0")/test-runner.sh"
setup_sandbox() { CASE_FOLDER=\$(mktemp -d); }
teardown_sandbox() { rm -rf "\$CASE_FOLDER"; }
passes() { :; }
fails() { echo "detail"; false; }
$2
report_results
END
}

run_sample() {
  bash "$SANDBOX/sample.test.sh"
}

assert_equals() {
  [ "$1" = "$2" ] || { printf '    attendu : %s\n    obtenu  : %s\n' "$1" "$2"; exit 1; }
}

assert_contains() {
  case $2 in *"$1"*) ;; *) printf '    absent : %s\n    dans   : %s\n' "$1" "$2"; exit 1 ;; esac
}

# ── Lanceur ───────────────────────────────────────────────────────────────────

test_counts_passed_cases_and_succeeds() {
  local output
  write_test_file sample 'run_test passes "premier"
run_test passes "second"'
  output=$(run_sample) || exit 1
  assert_equals $'  ok   premier\n  ok   second\n2 passed, 0 failed, 0 skipped' "$output"
}

test_fails_with_detail_of_the_failed_case() {
  local output
  write_test_file sample 'run_test passes "vert"
run_test fails "rouge"'
  output=$(run_sample) && exit 1
  assert_equals $'  ok   vert\ndetail\n  FAIL rouge\n1 passed, 1 failed, 0 skipped' "$output"
}

test_counts_exit_inside_a_case_as_a_failure_after_teardown() {
  local output
  write_test_file sample 'exits() { exit 3; }
teardown_sandbox() { rm -rf "$CASE_FOLDER"; echo "nettoye"; }
run_test exits "sort"'
  output=$(run_sample) && exit 1
  assert_equals $'nettoye\n  FAIL sort\n0 passed, 1 failed, 0 skipped' "$output"
}

test_counts_case_without_result_as_a_failure() {
  local output
  write_test_file sample 'teardown_sandbox() { rm -rf "$CASE_FOLDER"; exit 0; }
run_test passes "interrompu"'
  output=$(run_sample) && exit 1
  assert_equals $'  FAIL interrompu (aucun résultat)\n0 passed, 1 failed, 0 skipped' "$output"
}

test_keeps_declaration_order_whatever_the_end_order() {
  write_test_file sample 'slow() { sleep 1; }
run_test slow "lent"
run_test passes "rapide"'
  assert_equals $'  ok   lent\n  ok   rapide\n2 passed, 0 failed, 0 skipped' "$(run_sample)"
}

# Chaque cas relève le nombre de cas en cours à son départ : le plus grand relevé, pour un TEST_JOBS donné.
highest_number_of_running_cases() {
  write_test_file sample 'RUNNING=$(dirname "$0")/running
mkdir -p "$RUNNING"
counted() {
  : > "$RUNNING/$BASHPID"
  echo "$(ls "$RUNNING" | wc -l)" > "$RUNNING.$BASHPID"
  sleep 2
  rm "$RUNNING/$BASHPID"
}
for index in 1 2 3 4; do run_test counted "cas $index"; done'
  TEST_JOBS=$1 run_sample > /dev/null
  cat "$SANDBOX"/running.* | tr -d ' ' | sort -rn | head -1
}

test_never_runs_more_cases_than_test_jobs() {
  assert_equals 1 "$(highest_number_of_running_cases 1)"
}

test_runs_several_cases_at_once() {
  [ "$(highest_number_of_running_cases 4)" -ge 2 ] || exit 1
}

test_skips_cases_with_the_reason_of_the_file() {
  local output
  write_test_file sample 'skip_reason() { echo "outil absent"; }
run_test fails "cas"'
  output=$(run_sample) || exit 1
  assert_equals $'  skip cas (outil absent)\n0 passed, 0 failed, 1 skipped' "$output"
}

test_removes_its_results_folder() {
  mkdir "$SANDBOX/tmp"
  write_test_file sample 'run_test passes "cas"'
  TMPDIR="$SANDBOX/tmp" run_sample > /dev/null
  assert_equals "" "$(ls "$SANDBOX/tmp")"
}

# ── Suite complète ────────────────────────────────────────────────────────────

test_full_suite_writes_one_line_per_green_file() {
  local output
  write_test_file first 'run_test passes "cas"'
  write_test_file second 'run_test passes "cas"'
  output=$(bash "$SANDBOX/run-all.sh") || exit 1
  assert_equals $'ok   first.test.sh — 1 passed, 0 failed, 0 skipped\nok   second.test.sh — 1 passed, 0 failed, 0 skipped' "$output"
}

test_full_suite_fails_and_runs_every_file_after_a_red_one() {
  local output
  write_test_file first 'run_test fails "cas rouge"'
  write_test_file second 'run_test passes "cas"'
  output=$(bash "$SANDBOX/run-all.sh") && exit 1
  assert_contains $'  FAIL cas rouge\n0 passed, 1 failed, 0 skipped\nFAIL first.test.sh' "$output"
  assert_contains 'ok   second.test.sh' "$output"
}

# ── Exécution ─────────────────────────────────────────────────────────────────

run_test test_counts_passed_cases_and_succeeds "compte les cas verts et sort en succès"
run_test test_fails_with_detail_of_the_failed_case "cas rouge : sort en échec, détail affiché"
run_test test_counts_exit_inside_a_case_as_a_failure_after_teardown "exit dans un cas : échec, bac à sable supprimé"
run_test test_counts_case_without_result_as_a_failure "cas sans résultat écrit : échec"
run_test test_keeps_declaration_order_whatever_the_end_order "affiche les résultats dans l'ordre de déclaration"
run_test test_never_runs_more_cases_than_test_jobs "jamais plus de cas à la fois que TEST_JOBS"
run_test test_runs_several_cases_at_once "lance plusieurs cas en même temps"
run_test test_skips_cases_with_the_reason_of_the_file "saute les cas avec la raison donnée par le fichier"
run_test test_removes_its_results_folder "supprime son dossier de résultats"
run_test test_full_suite_writes_one_line_per_green_file "suite complète : une ligne par fichier vert"
run_test test_full_suite_fails_and_runs_every_file_after_a_red_one "suite complète : échec signalé, tous les fichiers lancés"

report_results
