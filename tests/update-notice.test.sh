#!/bin/bash
# Tests de skills/forge/hooks/update-notice.sh — chaque test tourne dans un bac à sable : dépôt distant nu local
# portant les tags, install.json jetable, jamais le réseau ni ~/.claude.
# Usage : bash tests/update-notice.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK_SCRIPT="$REPO_ROOT/skills/forge/hooks/update-notice.sh"
. "$REPO_ROOT/tests/test-runner.sh"
set -u

# ── Bac à sable ───────────────────────────────────────────────────────────────

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  INSTALL_DIR="$SANDBOX/installed"
  REMOTE="$SANDBOX/remote.git"
  mkdir -p "$INSTALL_DIR"
  git init -q --bare "$REMOTE"
  local commit tag
  commit=$(git -C "$REMOTE" -c user.name=t -c user.email=t@test.local commit-tree -m initial "$(git -C "$REMOTE" hash-object -t tree -w /dev/null)")
  for tag in v0.9.2 v0.9.10 v1.0.0-beta latest; do git -C "$REMOTE" tag "$tag" "$commit"; done
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

# Usage : write_install_file <version> <latest> <dismissed> [dépôt]
write_install_file() {
  printf '{"version":%s,"repository":"%s","latest":%s,"dismissed":%s}\n' "$1" "${4:-$REMOTE}" "$2" "$3" \
    > "$INSTALL_DIR/install.json"
}

# Sortie d'erreur du hook, celle que Claude reçoit ; code de sortie gardé.
notice() {
  printf '{"hook_event_name":"UserPromptExpansion","command_name":"forge"}' \
    | bash "$HOOK_SCRIPT" --install-dir "$INSTALL_DIR" 2>&1 >/dev/null
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

assert_stays_silent() {
  local output
  output=$(notice)
  assert_equals 0 $?
  assert_equals "" "$output"
}

# ── Réveil ────────────────────────────────────────────────────────────────────

test_wakes_claude_with_version_and_both_commands() {
  local output
  write_install_file '"v0.9.2"' '"v0.9.2"' null
  output=$(notice)
  assert_equals 2 $?
  assert_contains 'New forge version available: v0.9.10 (installed: v0.9.2).' "$output"
  assert_contains 'mets à jour la forge' "$output"
  assert_contains 'ignore cette version' "$output"
}

test_wakes_claude_again_when_version_is_already_known() {
  write_install_file '"v0.9.2"' '"v0.9.10"' null
  notice > /dev/null
  assert_equals 2 $?
}

test_wakes_claude_for_version_newer_than_dismissed_one() {
  write_install_file '"v0.9.2"' '"v0.9.3"' '"v0.9.3"'
  assert_contains 'v0.9.10' "$(notice)"
}

test_leaves_out_unknown_installed_version() {
  local output
  output=$(FORGE_UPDATE_REPOSITORY="$REMOTE" notice)
  assert_equals 2 $?
  assert_contains 'New forge version available: v0.9.10.' "$output"
}

# ── Silence ───────────────────────────────────────────────────────────────────

test_stays_silent_when_up_to_date() {
  write_install_file '"v0.9.10"' '"v0.9.10"' null
  assert_stays_silent
}

test_stays_silent_for_dismissed_version() {
  write_install_file '"v0.9.2"' '"v0.9.10"' '"v0.9.10"'
  assert_stays_silent
}

test_stays_silent_and_keeps_install_file_when_remote_is_unreachable() {
  write_install_file '"v0.9.2"' '"v0.9.10"' null "$SANDBOX/missing.git"
  local before
  before=$(cat "$INSTALL_DIR/install.json")
  assert_stays_silent
  assert_equals "$before" "$(cat "$INSTALL_DIR/install.json")"
}

test_writes_nothing_on_stdout() {
  write_install_file '"v0.9.2"' '"v0.9.2"' null
  assert_equals "" "$(bash "$HOOK_SCRIPT" --install-dir "$INSTALL_DIR" < /dev/null 2>/dev/null)"
}

# ── install.json ──────────────────────────────────────────────────────────────

test_records_version_found_for_a_later_dismiss() {
  write_install_file '"v0.9.2"' '"v0.9.2"' '"v0.9.1"'
  notice > /dev/null
  assert_equals "{\"version\":\"v0.9.2\",\"repository\":\"$REMOTE\",\"latest\":\"v0.9.10\",\"dismissed\":\"v0.9.1\"}" \
    "$(cat "$INSTALL_DIR/install.json")"
}

test_version_dismissed_after_notice_is_no_longer_announced() {
  write_install_file '"v0.9.2"' '"v0.9.2"' null
  notice > /dev/null
  bash "$REPO_ROOT/skills/forge/scripts/update.sh" dismiss --install-dir "$INSTALL_DIR" > /dev/null
  assert_stays_silent
}

# Format de install.json avant la 0.13.8 : last_check en plus, dismissed absent.
test_reads_install_file_of_older_versions() {
  printf '{"version":"v0.9.2","repository":"%s","last_check":1795537306,"latest":"v0.9.2"}\n' "$REMOTE" > "$INSTALL_DIR/install.json"
  assert_contains 'v0.9.10 (installed: v0.9.2)' "$(notice)"
}

test_converts_ssh_repository_to_https() {
  write_install_file '"v0.9.2"' '"v0.9.2"' null git@host.invalid:owner/repo.git
  GIT_TRACE="$SANDBOX/git-trace" notice > /dev/null
  assert_contains 'https://host.invalid/owner/repo.git' "$(cat "$SANDBOX/git-trace")"
}

# ── Exécution ─────────────────────────────────────────────────────────────────

run_test test_wakes_claude_with_version_and_both_commands "version plus récente : réveille Claude avec la version et les deux commandes, plus grand tag vX.Y.Z"
run_test test_wakes_claude_again_when_version_is_already_known "version déjà connue, ni installée ni ignorée : annoncée de nouveau"
run_test test_wakes_claude_for_version_newer_than_dismissed_one "version plus récente que celle ignorée : annoncée"
run_test test_leaves_out_unknown_installed_version "sans install.json : annoncée, version installée omise"
run_test test_stays_silent_when_up_to_date "à jour : silencieux"
run_test test_stays_silent_for_dismissed_version "version ignorée : silencieux"
run_test test_stays_silent_and_keeps_install_file_when_remote_is_unreachable "hors réseau : silencieux, install.json gardé"
run_test test_writes_nothing_on_stdout "n'écrit rien sur la sortie standard"
run_test test_records_version_found_for_a_later_dismiss "retient la version trouvée, garde le refus précédent"
run_test test_version_dismissed_after_notice_is_no_longer_announced "version ignorée après l'annonce : plus annoncée"
run_test test_reads_install_file_of_older_versions "lit l'install.json des versions précédentes"
run_test test_converts_ssh_repository_to_https "convertit une URL ssh du dépôt en https"

report_results
