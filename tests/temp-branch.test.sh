#!/bin/bash
# Tests de skills/forge/scripts/temp-branch.sh — chaque test tourne dans un dépôt jetable
# sur master, jamais le dépôt courant.
# Usage : bash tests/temp-branch.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP_BRANCH_SCRIPT="$REPO_ROOT/skills/forge/scripts/temp-branch.sh"
DAY="27102026"
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

set_email() {
  git -C "$WORK" config user.email "$1"
}

temp_branch() {
  bash "$TEMP_BRANCH_SCRIPT" --root "$WORK" --date "$DAY" "$@"
}

current_branch() {
  git -C "$WORK" branch --show-current
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

# ── Nom de la branche ─────────────────────────────────────────────────────────

test_names_branch_after_email_local_part_and_date() {
  set_email "claude.malaval@topdata.fr"
  local output
  output=$(temp_branch)
  assert_equals '{"status":"created","branch":"tmp/claude-malaval-27102026"}' "$output"
}

test_switches_to_created_branch() {
  set_email "claude.malaval@topdata.fr"
  temp_branch > /dev/null
  assert_equals "tmp/claude-malaval-27102026" "$(current_branch)"
}

test_strips_github_noreply_numeric_prefix() {
  set_email "64985971+jeanchristoph@users.noreply.github.com"
  local output
  output=$(temp_branch)
  assert_equals '{"status":"created","branch":"tmp/jeanchristoph-27102026"}' "$output"
}

test_strips_gitlab_noreply_numeric_prefix() {
  set_email "1234567-jeanchristoph@users.noreply.gitlab.com"
  local output
  output=$(temp_branch)
  assert_equals '{"status":"created","branch":"tmp/jeanchristoph-27102026"}' "$output"
}

test_keeps_numeric_dash_prefix_outside_gitlab_noreply() {
  set_email "2024-equipe@topdata.fr"
  local output
  output=$(temp_branch)
  assert_equals '{"status":"created","branch":"tmp/2024-equipe-27102026"}' "$output"
}

test_lowercases_and_removes_accents() {
  set_email "Jérôme.DUPONT@topdata.fr"
  local output
  output=$(temp_branch)
  assert_equals '{"status":"created","branch":"tmp/jerome-dupont-27102026"}' "$output"
}

test_collapses_special_characters_into_single_dashes() {
  set_email "_jean..christophe+dev_@topdata.fr"
  local output
  output=$(temp_branch)
  assert_equals '{"status":"created","branch":"tmp/jean-christophe-dev-27102026"}' "$output"
}

test_uses_today_when_no_date_given() {
  set_email "claude.malaval@topdata.fr"
  local output
  output=$(bash "$TEMP_BRANCH_SCRIPT" --root "$WORK")
  assert_equals "{\"status\":\"created\",\"branch\":\"tmp/claude-malaval-$(date +%d%m%Y)\"}" "$output"
}

# ── Doublons du jour ──────────────────────────────────────────────────────────

test_suffixes_second_branch_of_the_day() {
  set_email "claude.malaval@topdata.fr"
  temp_branch > /dev/null
  git -C "$WORK" checkout -q master
  local output
  output=$(temp_branch)
  assert_equals '{"status":"created","branch":"tmp/claude-malaval-27102026-2"}' "$output"
}

test_suffixes_third_branch_of_the_day() {
  set_email "claude.malaval@topdata.fr"
  temp_branch > /dev/null
  git -C "$WORK" checkout -q master
  temp_branch > /dev/null
  git -C "$WORK" checkout -q master
  local output
  output=$(temp_branch)
  assert_equals '{"status":"created","branch":"tmp/claude-malaval-27102026-3"}' "$output"
}

# ── Identité absente ──────────────────────────────────────────────────────────

test_reports_missing_email_without_creating_branch() {
  git -C "$WORK" config --unset user.email
  local output status
  output=$(HOME="$SANDBOX" XDG_CONFIG_HOME="$SANDBOX" GIT_CONFIG_NOSYSTEM=1 temp_branch)
  status=$?
  assert_equals '{"status":"no_identity"}' "$output"
  assert_equals 1 "$status"
  assert_equals master "$(current_branch)"
}

test_reports_email_without_any_letter_or_digit() {
  set_email "+._@topdata.fr"
  local output status
  output=$(temp_branch)
  status=$?
  assert_equals '{"status":"no_identity"}' "$output"
  assert_equals 1 "$status"
}

# ── Échecs ────────────────────────────────────────────────────────────────────

# Une branche nommée « tmp » interdit toute branche « tmp/… » : git refuse la création.
test_reports_git_failure_with_its_message() {
  set_email "claude.malaval@topdata.fr"
  git -C "$WORK" branch tmp
  local output status
  output=$(temp_branch)
  status=$?
  assert_contains '"status":"failed","branch":"tmp/claude-malaval-27102026","detail":' "$output"
  assert_equals 2 "$status"
  assert_equals master "$(current_branch)"
}

test_rejects_malformed_date() {
  local status
  bash "$TEMP_BRANCH_SCRIPT" --root "$WORK" --date "2026-10-27" > /dev/null 2>&1
  status=$?
  assert_equals 1 "$status"
}

test_rejects_root_outside_git_repository() {
  local status
  bash "$TEMP_BRANCH_SCRIPT" --root "$SANDBOX" --date "$DAY" > /dev/null 2>&1
  status=$?
  assert_equals 1 "$status"
}

test_writes_nothing_on_stdout_for_usage_error() {
  local output
  output=$(bash "$TEMP_BRANCH_SCRIPT" --unknown 2>/dev/null)
  assert_equals "" "$output"
}

# ── Exécution ─────────────────────────────────────────────────────────────────

run_test() {
  local name=$1 label=$2
  setup_sandbox
  ( "$name" )
  local status=$?
  teardown_sandbox
  if [ $status -eq 0 ]; then
    PASSED=$((PASSED + 1)); echo "ok   $label"
  else
    FAILED=$((FAILED + 1)); echo "FAIL $label"
  fi
}

run_test test_names_branch_after_email_local_part_and_date "nomme la branche d'après la partie locale de l'e-mail et la date du jour"
run_test test_switches_to_created_branch "bascule sur la branche créée"
run_test test_strips_github_noreply_numeric_prefix "retire le préfixe numérique d'une adresse noreply GitHub"
run_test test_strips_gitlab_noreply_numeric_prefix "retire le préfixe numérique d'une adresse noreply GitLab"
run_test test_keeps_numeric_dash_prefix_outside_gitlab_noreply "garde un préfixe numérique suivi d'un tiret hors adresse noreply GitLab"
run_test test_lowercases_and_removes_accents "passe l'identité en minuscules et retire les accents"
run_test test_collapses_special_characters_into_single_dashes "remplace les caractères spéciaux par un seul tiret, sans tiret en bordure"
run_test test_uses_today_when_no_date_given "prend la date du jour quand aucune date n'est fournie"
run_test test_suffixes_second_branch_of_the_day "suffixe -2 la deuxième branche temporaire du jour"
run_test test_suffixes_third_branch_of_the_day "suffixe -3 la troisième branche temporaire du jour"
run_test test_reports_missing_email_without_creating_branch "signale l'absence d'e-mail git sans créer de branche"
run_test test_reports_email_without_any_letter_or_digit "signale une identité vide quand l'e-mail n'a ni lettre ni chiffre"
run_test test_reports_git_failure_with_its_message "rend compte d'un échec git avec son message, sans changer de branche"
run_test test_rejects_malformed_date "refuse une date hors format ddmmyyyy"
run_test test_rejects_root_outside_git_repository "refuse une racine hors dépôt git"
run_test test_writes_nothing_on_stdout_for_usage_error "n'écrit rien sur la sortie standard en erreur d'usage"

echo "$PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ]
