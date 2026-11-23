#!/bin/bash
# Tests de skills/forge/scripts/linked-worktree-cleanup.sh — chaque test tourne dans des dépôts jetables, jamais le dépôt courant.
# Usage : bash tests/linked-worktree-cleanup.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLEANUP_SCRIPT="$REPO_ROOT/skills/forge/scripts/linked-worktree-cleanup.sh"
LINKED_BRANCH="export-csv"
PASSED=0
FAILED=0

# ── Bac à sable ───────────────────────────────────────────────────────────────

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  LINKED="$SANDBOX/my-api"
  WORKTREE="$SANDBOX/my-api.worktrees/$LINKED_BRANCH"
  git init -q "$LINKED"
  git -C "$LINKED" config core.autocrlf false
  git -C "$LINKED" config user.email test@example.com
  git -C "$LINKED" config user.name test
  git -C "$LINKED" symbolic-ref HEAD refs/heads/master
  commit_in "$LINKED" readme.md "initial"
  git -C "$LINKED" worktree add -q -b "$LINKED_BRANCH" "$WORKTREE" master 2>/dev/null
  commit_in "$WORKTREE" export.csv "export"
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

# Usage : commit_in <dossier> <fichier> <message>
commit_in() {
  printf '%s\n' "$3" > "$1/$2"
  git -C "$1" add "$2"
  git -C "$1" -c user.email=test@example.com -c user.name=test commit -q -m "$3"
}

merge_branch_into_master() {
  git -C "$LINKED" merge -q --no-ff -m "merge" "$LINKED_BRANCH"
}

cleanup() {
  bash "$CLEANUP_SCRIPT" --linked "$LINKED" --branch "${1:-$LINKED_BRANCH}"
}

# Champ texte d'un JSON sur une ligne, vide si null.
field() {
  local pattern="\"$1\":\"([^\"]*)\""
  [[ $2 =~ $pattern ]] && printf '%s' "${BASH_REMATCH[1]}"
}

# ── Assertions — chaque test tourne dans un sous-shell, un échec en sort ──────

assert_equals() {
  [ "$1" = "$2" ] && return 0
  printf '    expected: %q\n    actual:   %q\n' "$1" "$2"
  exit 1
}

assert_worktree_present() {
  [ -d "$WORKTREE" ] || { echo "    worktree removed"; exit 1; }
}

# ── Retrait ───────────────────────────────────────────────────────────────────

test_removes_merged_and_clean_worktree() {
  local output
  merge_branch_into_master
  output=$(cleanup)
  assert_equals removed "$(field status "$output")"
  [ -d "$WORKTREE" ] && { echo "    worktree still present"; exit 1; }
  git -C "$LINKED" show-ref --verify --quiet "refs/heads/$LINKED_BRANCH" || { echo "    branch deleted"; exit 1; }
}

test_removes_worktree_merged_only_on_remote() {
  local remote="$SANDBOX/remote.git" output
  git init -q --bare "$remote"
  git -C "$LINKED" remote add origin "$remote"
  git -C "$LINKED" push -q origin master "$LINKED_BRANCH" 2>/dev/null
  git clone -q "$remote" "$SANDBOX/elsewhere" 2>/dev/null
  git -C "$SANDBOX/elsewhere" -c user.email=t@e.com -c user.name=t merge -q --no-ff -m "pull request" "origin/$LINKED_BRANCH"
  git -C "$SANDBOX/elsewhere" push -q origin master 2>/dev/null
  output=$(cleanup)
  assert_equals removed "$(field status "$output")"
  git -C "$LINKED" merge-base --is-ancestor "refs/heads/$LINKED_BRANCH" refs/heads/master && { echo "    merged locally"; exit 1; }
  [ -d "$WORKTREE" ] && { echo "    worktree still present"; exit 1; }
  return 0
}

# ── Worktree gardé ────────────────────────────────────────────────────────────

test_keeps_unmerged_worktree() {
  local output
  output=$(cleanup)
  assert_equals kept "$(field status "$output")"
  assert_equals "not merged" "$(field reason "$output")"
  assert_worktree_present
}

test_keeps_worktree_with_uncommitted_changes() {
  local output
  merge_branch_into_master
  printf 'draft\n' > "$WORKTREE/draft.md"
  output=$(cleanup)
  assert_equals kept "$(field status "$output")"
  assert_equals "uncommitted changes" "$(field reason "$output")"
  assert_worktree_present
}

test_never_removes_main_working_tree() {
  local output
  git -C "$LINKED" worktree remove "$WORKTREE"
  git -C "$LINKED" checkout -q "$LINKED_BRANCH"
  output=$(cleanup)
  assert_equals kept "$(field status "$output")"
  assert_equals "main working tree" "$(field reason "$output")"
  [ -d "$LINKED/.git" ] || { echo "    linked project damaged"; exit 1; }
}

test_reports_absent_without_worktree_for_branch() {
  local output
  merge_branch_into_master
  git -C "$LINKED" worktree remove "$WORKTREE"
  output=$(cleanup)
  assert_equals '{"worktree":null,"status":"absent","reason":null}' "$output"
}

# ── Arguments ─────────────────────────────────────────────────────────────────

test_rejects_missing_branch() {
  local output
  output=$(bash "$CLEANUP_SCRIPT" --linked "$LINKED" 2>/dev/null)
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

run_test test_removes_merged_and_clean_worktree "retire le worktree d'une branche fusionnée au working tree propre, branche gardée"
run_test test_removes_worktree_merged_only_on_remote "retire le worktree d'une branche fusionnée seulement sur la branche distante"
run_test test_keeps_unmerged_worktree "garde le worktree d'une branche non fusionnée"
run_test test_keeps_worktree_with_uncommitted_changes "garde un worktree aux modifications non commitées"
run_test test_never_removes_main_working_tree "ne retire jamais le dossier principal du projet lié"
run_test test_reports_absent_without_worktree_for_branch "rend absent quand aucun worktree n'extrait la branche"
run_test test_rejects_missing_branch "refuse un appel sans branche"

echo "$PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ]
