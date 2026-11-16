#!/bin/bash
# Tests de skills/forge/scripts/checks.sh — chaque test tourne dans un dépôt jetable, jamais le dépôt courant.
# Usage : bash tests/checks.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECKS_SCRIPT="$REPO_ROOT/skills/forge/scripts/checks.sh"
RULE="/.forge/branch/*/input/"
PASSED=0
FAILED=0

# ── Bac à sable ───────────────────────────────────────────────────────────────

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  WORK="$SANDBOX/work"
  git init -q "$WORK"
  git -C "$WORK" config core.autocrlf false
  git -C "$WORK" symbolic-ref HEAD refs/heads/feature
  mkdir -p "$WORK/.forge"
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

checks() {
  bash "$CHECKS_SCRIPT" --root "$WORK"
}

gitignore() {
  cat "$WORK/.gitignore" 2>/dev/null
}

# ── Assertions — chaque test tourne dans un sous-shell, un échec en sort ──────

assert_equals() {
  [ "$1" = "$2" ] && return 0
  printf '    expected: %q\n    actual:   %q\n' "$1" "$2"
  exit 1
}

# ── Ajout de la règle ─────────────────────────────────────────────────────────

test_creates_gitignore_with_forge_block() {
  assert_equals '{"gitignore":"updated"}' "$(checks)"
  assert_equals $'###> claude/forge ###\n'"$RULE"$'\n###< claude/forge ###' "$(gitignore)"
}

test_inserts_rule_before_end_of_existing_block() {
  printf 'node_modules/\n###> claude/forge ###\n!/.forge/\n###< claude/forge ###\n*.log\n' > "$WORK/.gitignore"
  checks > /dev/null
  assert_equals $'node_modules/\n###> claude/forge ###\n!/.forge/\n'"$RULE"$'\n###< claude/forge ###\n*.log' "$(gitignore)"
}

test_appends_block_after_content_without_final_newline() {
  printf 'node_modules/' > "$WORK/.gitignore"
  checks > /dev/null
  assert_equals $'node_modules/\n###> claude/forge ###\n'"$RULE"$'\n###< claude/forge ###' "$(gitignore)"
}

test_keeps_crlf_line_endings() {
  printf 'node_modules/\r\n' > "$WORK/.gitignore"
  checks > /dev/null
  assert_equals $'node_modules/\r\n###> claude/forge ###\r\n'"$RULE"$'\r\n###< claude/forge ###\r\nx' "$(cat "$WORK/.gitignore"; printf x)"
}

test_makes_branch_input_ignored_by_git() {
  checks > /dev/null
  git -C "$WORK" check-ignore -q .forge/branch/feature/input/export.csv || { echo "    input/ not ignored"; exit 1; }
}

test_changes_nothing_on_second_run() {
  checks > /dev/null
  local first
  first=$(gitignore)
  assert_equals '{"gitignore":"unchanged"}' "$(checks)"
  assert_equals "$first" "$(gitignore)"
}

# ── Contrôle écarté ───────────────────────────────────────────────────────────

test_skips_on_master() {
  git -C "$WORK" symbolic-ref HEAD refs/heads/master
  assert_equals '{"gitignore":"skipped"}' "$(checks)"
  [ ! -e "$WORK/.gitignore" ] || { echo "    .gitignore written"; exit 1; }
}

test_skips_on_main() {
  git -C "$WORK" symbolic-ref HEAD refs/heads/main
  assert_equals '{"gitignore":"skipped"}' "$(checks)"
}

test_skips_without_forge_folder() {
  rm -rf "$WORK/.forge"
  assert_equals '{"gitignore":"skipped"}' "$(checks)"
  [ ! -e "$WORK/.gitignore" ] || { echo "    .gitignore written"; exit 1; }
}

test_skips_outside_git() {
  rm -rf "$WORK/.git"
  assert_equals '{"gitignore":"skipped"}' "$(checks)"
}

# ── Lancement détaché ─────────────────────────────────────────────────────────

test_detached_launch_returns_at_once_and_writes_later() {
  local waited=0
  ( bash "$CHECKS_SCRIPT" --root "$WORK" </dev/null >/dev/null 2>&1 & )
  while [ ! -s "$WORK/.gitignore" ] && [ "$waited" -lt 50 ]; do sleep 0.1; waited=$((waited + 1)); done
  assert_equals $'###> claude/forge ###\n'"$RULE"$'\n###< claude/forge ###' "$(gitignore)"
}

# ── Arguments ─────────────────────────────────────────────────────────────────

test_rejects_unknown_argument() {
  local output
  output=$(bash "$CHECKS_SCRIPT" --nope 2>/dev/null)
  assert_equals 1 $?
  assert_equals "" "$output"
}

# ── Exécution ─────────────────────────────────────────────────────────────────

run_test() {
  setup_sandbox
  if ( "$1" ); then PASSED=$((PASSED + 1)); echo "  ok   $2"
  else FAILED=$((FAILED + 1)); echo "  FAIL $2"
  fi
  teardown_sandbox
}

run_test test_creates_gitignore_with_forge_block "crée le .gitignore avec le bloc forge"
run_test test_inserts_rule_before_end_of_existing_block "insère la règle avant la fin du bloc existant"
run_test test_appends_block_after_content_without_final_newline "ajoute le bloc après un contenu sans saut de ligne final"
run_test test_keeps_crlf_line_endings "garde les fins de ligne CRLF"
run_test test_makes_branch_input_ignored_by_git "rend le dossier input/ de la branche ignoré par git"
run_test test_changes_nothing_on_second_run "ne change rien au second passage"
run_test test_skips_on_master "n'écrit rien sur master"
run_test test_skips_on_main "n'écrit rien sur main"
run_test test_skips_without_forge_folder "n'écrit rien sans dossier .forge/"
run_test test_skips_outside_git "n'écrit rien hors dépôt git"
run_test test_detached_launch_returns_at_once_and_writes_later "lancé détaché, rend la main et écrit ensuite"
run_test test_rejects_unknown_argument "refuse un argument inconnu"

echo "$PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ]
