#!/bin/bash
# Lanceur commun des tests, à sourcer. Chaque cas tourne dans son propre processus, TEST_JOBS cas à la fois (12 par défaut).
# Le fichier de test définit setup_sandbox et teardown_sandbox, appelle run_test par cas, puis finit par report_results.
# Exige bash 5, comme les scripts du skill.

TEST_JOBS=${TEST_JOBS:-12}
TEST_LABELS=()
TEST_RUNNING=0
TEST_RESULTS=$(mktemp -d)
trap 'rm -rf "$TEST_RESULTS"' EXIT

# Raison de sauter les tests (outil absent), vide sinon : redéfinie par le fichier de test qui en a une.
skip_reason() { :; }

# Exécute un cas dans son bac à sable et écrit son résultat (ok, FAIL ou skip) une fois le bac à sable supprimé.
run_case() {
  local test_function=$1 result_file=$2 result=FAIL reason
  reason=$(skip_reason)
  if [ -n "$reason" ]; then
    echo "skip $reason" > "$result_file"
    return
  fi
  setup_sandbox
  if ( "$test_function" ); then result=ok; fi
  teardown_sandbox
  echo "$result" > "$result_file"
}

run_test() {
  local test_function=$1 index=${#TEST_LABELS[@]}
  TEST_LABELS+=("$2")
  if [ "$TEST_RUNNING" -ge "$TEST_JOBS" ]; then
    wait -n
    TEST_RUNNING=$((TEST_RUNNING - 1))
  fi
  run_case "$test_function" "$TEST_RESULTS/$index.result" > "$TEST_RESULTS/$index.log" 2>&1 &
  TEST_RUNNING=$((TEST_RUNNING + 1))
}

# Attend les derniers cas, affiche les résultats dans l'ordre de déclaration et échoue si un cas est rouge.
# INVARIANT: un cas sans résultat écrit est un échec, jamais un cas oublié.
report_results() {
  local index result reason passed=0 failed=0 skipped=0
  wait
  for index in "${!TEST_LABELS[@]}"; do
    result="" reason=""
    cat "$TEST_RESULTS/$index.log"
    [ -f "$TEST_RESULTS/$index.result" ] && read -r result reason < "$TEST_RESULTS/$index.result"
    case $result in
      ok) passed=$((passed + 1)); echo "  ok   ${TEST_LABELS[$index]}" ;;
      skip) skipped=$((skipped + 1)); echo "  skip ${TEST_LABELS[$index]} ($reason)" ;;
      FAIL) failed=$((failed + 1)); echo "  FAIL ${TEST_LABELS[$index]}" ;;
      *) failed=$((failed + 1)); echo "  FAIL ${TEST_LABELS[$index]} (aucun résultat)" ;;
    esac
  done
  echo "$passed passed, $failed failed, $skipped skipped"
  [ "$failed" -eq 0 ]
}
