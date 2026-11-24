#!/bin/bash
# Tests de skills/forge/scripts/update.sh — chaque test tourne dans un bac à sable :
# dépôt distant nu local portant les tags, install.json jetable, jamais le réseau ni ~/.claude.
# Usage : bash tests/update.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPDATE_SCRIPT="$REPO_ROOT/skills/forge/scripts/update.sh"
SYSTEM_TMPDIR=${TMPDIR:-/tmp}
. "$REPO_ROOT/tests/test-runner.sh"
set -u

# ── Bac à sable ───────────────────────────────────────────────────────────────

# Dépôt publié : un installeur factice qui écrit un témoin, et les tags demandés.
setup_sandbox() {
  SANDBOX=$(TMPDIR=$SYSTEM_TMPDIR mktemp -d)
  INSTALL_DIR="$SANDBOX/installed"
  REMOTE="$SANDBOX/remote.git"
  export TMPDIR="$SANDBOX/tmp"
  export INSTALL_MARKER="$SANDBOX/installed-from"
  mkdir -p "$INSTALL_DIR" "$TMPDIR"
  local work="$SANDBOX/work"
  git init -q "$work"
  git -C "$work" config user.name "Forge Test"
  git -C "$work" config user.email "forge@test.local"
  git -C "$work" config commit.gpgsign false
  git -C "$work" config core.autocrlf false
  mkdir -p "$work/install"
  printf '#!/bin/bash\ncat version.txt > "$INSTALL_MARKER"\n' > "$work/install/install.sh"
  printf '#!/bin/bash\nfor n in 1 2 3 4 5 6; do echo "step $n"; done\necho "error: disk full" >&2\nexit 3\n' \
    > "$work/install/failing.sh"
  publish_version "$work" v0.9.2
  publish_version "$work" v0.9.10
  git -C "$work" tag v1.0.0-beta
  git -C "$work" tag latest
  git clone -q --bare "$work" "$REMOTE"
}

publish_version() {
  printf '%s\n' "$2" > "$1/version.txt"
  git -C "$1" add .
  git -C "$1" commit -q -m "$2"
  git -C "$1" tag "$2"
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

# Usage : write_install_file <version> <latest> [dépôt]
write_install_file() {
  printf '{"version":%s,"repository":"%s","latest":%s}\n' "$1" "${3:-$REMOTE}" "$2" > "$INSTALL_DIR/install.json"
}

update() {
  bash "$UPDATE_SCRIPT" "$@" --install-dir "$INSTALL_DIR"
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

assert_not_contains() {
  case $2 in *"$1"*) printf '    unexpected: %s\n    in:\n%s\n' "$1" "$2"; exit 1 ;; esac
}

# ── dismiss ───────────────────────────────────────────────────────────────────

test_dismiss_records_last_announced_version() {
  write_install_file '"v0.9.2"' '"v0.9.10"'
  assert_equals '{"dismissed":"v0.9.10"}' "$(update dismiss)"
  assert_contains '"version":"v0.9.2"' "$(cat "$INSTALL_DIR/install.json")"
  assert_contains '"latest":"v0.9.10","dismissed":"v0.9.10"' "$(cat "$INSTALL_DIR/install.json")"
}

test_dismiss_without_known_version_writes_nothing() {
  assert_equals '{"dismissed":null}' "$(update dismiss)"
  [ ! -e "$INSTALL_DIR/install.json" ] || { echo "    install.json written"; exit 1; }
}

# ── run ───────────────────────────────────────────────────────────────────────

test_installs_latest_published_version_with_cloned_installer() {
  write_install_file '"v0.9.2"' '"v0.9.2"'
  assert_equals '{"from":"v0.9.2","to":"v0.9.10","status":"done","reason":null,"detail":null}' \
    "$(update run --installer install/install.sh)"
  assert_equals "v0.9.10" "$(cat "$INSTALL_MARKER")"
}

test_installs_dismissed_version_on_request() {
  write_install_file '"v0.9.2"' '"v0.9.10"'
  update dismiss > /dev/null
  assert_contains '"to":"v0.9.10","status":"done"' "$(update run --installer install/install.sh)"
}

test_installs_when_installed_version_is_unknown() {
  assert_contains '"from":null,"to":"v0.9.10","status":"done"' \
    "$(FORGE_UPDATE_REPOSITORY="$REMOTE" update run --installer install/install.sh)"
}

test_installs_when_install_file_is_damaged() {
  printf 'garbage' > "$INSTALL_DIR/install.json"
  assert_contains '"from":null,"to":"v0.9.10","status":"done"' \
    "$(FORGE_UPDATE_REPOSITORY="$REMOTE" update run --installer install/install.sh)"
}

test_reports_up_to_date_without_installing() {
  write_install_file '"v0.9.10"' '"v0.9.10"'
  assert_equals '{"from":"v0.9.10","to":"v0.9.10","status":"up_to_date","reason":null,"detail":null}' \
    "$(update run --installer install/install.sh)"
  [ ! -e "$INSTALL_MARKER" ] || { echo "    installer launched"; exit 1; }
}

test_removes_temporary_clone_after_install() {
  write_install_file '"v0.9.2"' '"v0.9.2"'
  update run --installer install/install.sh > /dev/null
  [ ! -e "$TMPDIR/forge-update" ] || { echo "    temporary clone left behind"; exit 1; }
}

test_fails_and_keeps_install_file_when_remote_is_unreachable() {
  write_install_file '"v0.9.2"' '"v0.9.10"' "$SANDBOX/missing.git"
  local before output
  before=$(cat "$INSTALL_DIR/install.json")
  output=$(update run --installer install/install.sh)
  assert_equals 2 $?
  assert_contains '"status":"failed","reason":"repository unreachable"' "$output"
  assert_equals "$before" "$(cat "$INSTALL_DIR/install.json")"
}

# git dont la seule commande clone échoue : le dépôt répond, le tag n'est pas clonable.
make_clone_fail() {
  mkdir "$SANDBOX/bin"
  printf '#!/bin/bash
case " $* " in *" clone "*) echo "fatal: tag not found" >&2; exit 128 ;; esac
exec "%s" "$@"
' "$(command -v git)" > "$SANDBOX/bin/git"
  chmod +x "$SANDBOX/bin/git"
}

test_fails_with_git_error_when_tag_cannot_be_cloned() {
  local output
  write_install_file '"v0.9.2"' '"v0.9.2"'
  make_clone_fail
  output=$(PATH="$SANDBOX/bin:$PATH" update run --installer install/install.sh)
  assert_equals 2 $?
  assert_contains '"reason":"clone failed"' "$output"
  assert_contains '"detail":"fatal: tag not found"' "$output"
}

test_reports_last_five_lines_of_failing_installer_output() {
  write_install_file '"v0.9.2"' '"v0.9.2"'
  local output
  output=$(update run --installer install/failing.sh)
  assert_contains '"detail":"step 3\nstep 4\nstep 5\nstep 6\nerror: disk full"}' "$output"
  assert_not_contains 'step 2' "$output"
}

test_fails_when_installer_fails() {
  write_install_file '"v0.9.2"' '"v0.9.2"'
  assert_contains '"reason":"installer failed"' "$(update run --installer install/failing.sh)"
}

# ── Usage ─────────────────────────────────────────────────────────────────────

test_rejects_unknown_mode() {
  update check 2>/dev/null
  assert_equals 1 $?
}

test_rejects_unknown_argument() {
  update run --force 2>/dev/null
  assert_equals 1 $?
}

test_writes_nothing_on_stdout_for_usage_error() {
  assert_equals "" "$(update 2>/dev/null)"
}

# ── Exécution ─────────────────────────────────────────────────────────────────

run_test test_dismiss_records_last_announced_version "retient le refus de la dernière version annoncée"
run_test test_dismiss_without_known_version_writes_nothing "un refus sans version connue n'écrit rien"
run_test test_installs_latest_published_version_with_cloned_installer "installe la dernière version publiée avec l'installeur du clone"
run_test test_installs_dismissed_version_on_request "installe à la demande une version ignorée"
run_test test_installs_when_installed_version_is_unknown "installe quand install.json est absent"
run_test test_installs_when_install_file_is_damaged "installe quand install.json est illisible"
run_test test_reports_up_to_date_without_installing "version à jour : rien n'est installé"
run_test test_removes_temporary_clone_after_install "supprime le clone temporaire après l'installation"
run_test test_fails_and_keeps_install_file_when_remote_is_unreachable "échoue et garde install.json quand le dépôt est injoignable"
run_test test_fails_with_git_error_when_tag_cannot_be_cloned "échoue avec l'erreur git quand le clone échoue"
run_test test_fails_when_installer_fails "échoue quand l'installeur échoue"
run_test test_reports_last_five_lines_of_failing_installer_output "rend les cinq dernières lignes de la sortie d'un installeur en échec"
run_test test_rejects_unknown_mode "refuse un mode inconnu, check compris"
run_test test_rejects_unknown_argument "refuse un argument inconnu"
run_test test_writes_nothing_on_stdout_for_usage_error "n'écrit rien sur la sortie standard en erreur d'usage"

report_results
