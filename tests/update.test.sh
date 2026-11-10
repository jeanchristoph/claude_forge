#!/bin/bash
# Tests de skills/forge/scripts/update.sh — chaque test tourne dans un bac à sable :
# dépôt distant nu local portant les tags, install.json jetable, jamais le réseau ni ~/.claude.
# Usage : bash tests/update.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPDATE_SCRIPT="$REPO_ROOT/skills/forge/scripts/update.sh"
MORE_THAN_ONE_DAY=$((25 * 3600))
LESS_THAN_ONE_DAY=$((23 * 3600))
SYSTEM_TMPDIR=${TMPDIR:-/tmp}
PASSED=0
FAILED=0

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

now() {
  printf '%(%s)T' -1
}

write_install_file() {
  printf '{"version":%s,"repository":"%s","last_check":%s,"latest":%s}\n' "$1" "$REMOTE" "$2" "$3" \
    > "$INSTALL_DIR/install.json"
}

update() {
  bash "$UPDATE_SCRIPT" "$@" --install-dir "$INSTALL_DIR"
}

# Attend la fin de l'interrogation détachée : install.json réécrit avec un latest donné.
wait_for_latest() {
  local attempt
  for attempt in $(seq 1 50); do
    case $(cat "$INSTALL_DIR/install.json" 2>/dev/null) in *"\"latest\":\"$1\""*) return 0 ;; esac
    sleep 0.1
  done
  return 1
}

# Attend la fin de l'interrogation détachée : last_check passé de 1 à la date courante.
wait_for_refreshed_check() {
  local attempt
  for attempt in $(seq 1 50); do
    case $(cat "$INSTALL_DIR/install.json" 2>/dev/null) in *'"last_check":1,'*) ;; *) return 0 ;; esac
    sleep 0.1
  done
  return 1
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

# ── check ─────────────────────────────────────────────────────────────────────

test_skips_remote_query_and_writes_nothing_when_check_is_recent() {
  write_install_file '"v0.9.2"' "$(now)" '"v0.9.2"'
  local before after output
  before=$(cat "$INSTALL_DIR/install.json")
  output=$(update check)
  after=$(cat "$INSTALL_DIR/install.json")
  assert_equals '{"installed":"v0.9.2","latest":"v0.9.2","update_available":false,"check":"skipped"}' "$output"
  assert_equals "$before" "$after"
}

test_skips_remote_query_when_check_is_less_than_one_day_old() {
  write_install_file '"v0.9.2"' "$(( $(now) - LESS_THAN_ONE_DAY ))" '"v0.9.2"'
  assert_contains '"check":"skipped"' "$(update check)"
}

test_reports_known_newer_version_without_querying() {
  write_install_file '"v0.9.2"' "$(now)" '"v0.9.10"'
  assert_contains '"update_available":true,"check":"skipped"' "$(update check)"
}

test_starts_background_query_when_last_check_is_older_than_one_day() {
  write_install_file '"v0.9.2"' "$(( $(now) - MORE_THAN_ONE_DAY ))" '"v0.9.2"'
  assert_contains '"check":"started"' "$(update check)"
  wait_for_latest v0.9.10 || { echo "    install.json not refreshed"; exit 1; }
}

test_background_query_refreshes_last_check() {
  local old_check=$(( $(now) - MORE_THAN_ONE_DAY ))
  write_install_file '"v0.9.2"' "$old_check" '"v0.9.2"'
  update check > /dev/null
  wait_for_latest v0.9.10 || exit 1
  assert_contains '"update_available":true,"check":"skipped"' "$(update check)"
}

test_forced_check_queries_in_foreground_despite_recent_check() {
  write_install_file '"v0.9.2"' "$(now)" '"v0.9.2"'
  assert_equals '{"installed":"v0.9.2","latest":"v0.9.10","update_available":true,"check":"done"}' \
    "$(update check --force)"
}

test_picks_highest_version_numerically_and_ignores_non_conforming_tags() {
  write_install_file '"v0.9.2"' "$(now)" '"v0.9.2"'
  assert_contains '"latest":"v0.9.10"' "$(update check --force)"
}

test_reports_no_update_when_installed_version_is_latest() {
  write_install_file '"v0.9.10"' "$(now)" '"v0.9.10"'
  assert_contains '"update_available":false,"check":"done"' "$(update check --force)"
}

test_reports_failed_check_and_keeps_install_file_when_remote_is_unreachable() {
  printf '{"version":"v0.9.2","repository":"%s","last_check":1,"latest":"v0.9.2"}\n' "$SANDBOX/missing.git" \
    > "$INSTALL_DIR/install.json"
  local before
  before=$(cat "$INSTALL_DIR/install.json")
  assert_contains '"check":"failed"' "$(update check --force)"
  assert_equals "$before" "$(cat "$INSTALL_DIR/install.json")"
}

test_starts_query_when_install_file_is_missing() {
  assert_equals '{"installed":null,"latest":null,"update_available":false,"check":"started"}' \
    "$(FORGE_UPDATE_REPOSITORY="$REMOTE" update check)"
}

test_treats_unknown_installed_version_as_outdated_once_latest_is_known() {
  FORGE_UPDATE_REPOSITORY="$REMOTE" update check --force > /dev/null
  assert_contains '"version":null' "$(cat "$INSTALL_DIR/install.json")"
  assert_contains '"installed":null,"latest":"v0.9.10","update_available":true' "$(update check)"
}

test_starts_query_when_install_file_is_damaged() {
  printf 'garbage' > "$INSTALL_DIR/install.json"
  assert_contains '"check":"started"' "$(FORGE_UPDATE_REPOSITORY="$REMOTE" update check)"
}

test_converts_ssh_repository_to_https() {
  printf '{"version":"v0.9.2","repository":"git@host.invalid:owner/repo.git","last_check":1,"latest":"v0.9.2"}\n' \
    > "$INSTALL_DIR/install.json"
  GIT_TRACE="$SANDBOX/git-trace" update check --force > /dev/null
  assert_contains 'https://host.invalid/owner/repo.git' "$(cat "$SANDBOX/git-trace")"
}

# ── dismiss ───────────────────────────────────────────────────────────────────

test_does_not_offer_dismissed_version_again() {
  write_install_file '"v0.9.2"' "$(now)" '"v0.9.10"'
  assert_equals '{"dismissed":"v0.9.10"}' "$(update dismiss)"
  assert_contains '"update_available":false,"check":"skipped"' "$(update check)"
}

test_dismiss_keeps_last_check_date() {
  write_install_file '"v0.9.2"' 1234 '"v0.9.10"'
  update dismiss > /dev/null
  assert_contains '"last_check":1234,' "$(cat "$INSTALL_DIR/install.json")"
}

test_offers_version_newer_than_dismissed_one() {
  printf '{"version":"v0.9.2","repository":"%s","last_check":1,"latest":"v0.9.2","dismissed":"v0.9.3"}\n' "$REMOTE" \
    > "$INSTALL_DIR/install.json"
  update check > /dev/null
  wait_for_latest v0.9.10 || exit 1
  assert_contains '"latest":"v0.9.10","update_available":true' "$(update check)"
}

test_forced_check_offers_dismissed_version() {
  write_install_file '"v0.9.2"' "$(now)" '"v0.9.10"'
  update dismiss > /dev/null
  assert_contains '"update_available":true,"check":"done"' "$(update check --force)"
}

test_background_query_keeps_dismissed_version() {
  write_install_file '"v0.9.2"' 1 '"v0.9.10"'
  update dismiss > /dev/null
  update check > /dev/null
  wait_for_refreshed_check || { echo "    install.json not refreshed"; exit 1; }
  assert_contains '"dismissed":"v0.9.10"' "$(cat "$INSTALL_DIR/install.json")"
  assert_contains '"update_available":false' "$(update check)"
}

test_dismiss_without_known_version_writes_nothing() {
  assert_equals '{"dismissed":null}' "$(update dismiss)"
  [ ! -e "$INSTALL_DIR/install.json" ] || { echo "    install.json written"; exit 1; }
}

# ── run ───────────────────────────────────────────────────────────────────────

test_installs_latest_known_version_with_cloned_installer() {
  write_install_file '"v0.9.2"' "$(now)" '"v0.9.10"'
  assert_equals '{"from":"v0.9.2","to":"v0.9.10","status":"done","reason":null,"detail":null}' \
    "$(update run --installer install/install.sh)"
  assert_equals "v0.9.10" "$(cat "$INSTALL_MARKER")"
}

test_removes_temporary_clone_after_install() {
  write_install_file '"v0.9.2"' "$(now)" '"v0.9.10"'
  update run --installer install/install.sh > /dev/null
  [ ! -e "$TMPDIR/forge-update" ] || { echo "    temporary clone left behind"; exit 1; }
}

test_fails_without_known_latest_version() {
  local output
  output=$(update run --installer install/install.sh)
  assert_equals 2 $?
  assert_contains '"status":"failed","reason":"no known version"' "$output"
}

test_fails_when_tag_cannot_be_cloned() {
  write_install_file '"v0.9.2"' "$(now)" '"v9.9.9"'
  assert_contains '"reason":"clone failed"' "$(update run --installer install/install.sh)"
}

test_reports_last_five_lines_of_failing_installer_output() {
  write_install_file '"v0.9.2"' "$(now)" '"v0.9.10"'
  local output
  output=$(update run --installer install/failing.sh)
  assert_contains '"detail":"step 3\nstep 4\nstep 5\nstep 6\nerror: disk full"}' "$output"
  assert_not_contains 'step 2' "$output"
}

test_reports_git_error_when_clone_fails() {
  write_install_file '"v0.9.2"' "$(now)" '"v9.9.9"'
  assert_contains 'v9.9.9 not found' "$(update run --installer install/install.sh)"
}

test_fails_when_installer_fails() {
  write_install_file '"v0.9.2"' "$(now)" '"v0.9.10"'
  assert_contains '"reason":"installer failed"' "$(update run --installer install/failing.sh)"
}

# ── Usage ─────────────────────────────────────────────────────────────────────

test_rejects_unknown_mode() {
  update preview 2>/dev/null
  assert_equals 1 $?
}

test_rejects_force_outside_check() {
  update run --force 2>/dev/null
  assert_equals 1 $?
}

test_writes_nothing_on_stdout_for_usage_error() {
  assert_equals "" "$(update 2>/dev/null)"
}

# ── Exécution ─────────────────────────────────────────────────────────────────

run_test() {
  setup_sandbox
  if ( set -u; $1 ); then
    PASSED=$((PASSED + 1))
    echo "  ok   $2"
  else
    FAILED=$((FAILED + 1))
    echo "  FAIL $2"
  fi
  teardown_sandbox
}

run_test test_skips_remote_query_and_writes_nothing_when_check_is_recent "n'interroge pas le dépôt et n'écrit rien quand le contrôle date de moins de 24 heures"
run_test test_reports_known_newer_version_without_querying "signale une version plus récente déjà connue sans interroger le dépôt"
run_test test_skips_remote_query_when_check_is_less_than_one_day_old "n'interroge pas le dépôt quand le contrôle date de 23 heures"
run_test test_starts_background_query_when_last_check_is_older_than_one_day "lance l'interrogation en arrière-plan quand le contrôle date de plus de 24 heures"
run_test test_background_query_refreshes_last_check "l'interrogation en arrière-plan remet la date du contrôle à jour"
run_test test_forced_check_queries_in_foreground_despite_recent_check "le contrôle forcé interroge au premier plan malgré un contrôle récent"
run_test test_picks_highest_version_numerically_and_ignores_non_conforming_tags "retient le plus grand tag vX.Y.Z numériquement et ignore les tags non conformes"
run_test test_reports_no_update_when_installed_version_is_latest "ne signale aucune mise à jour quand la version installée est la dernière"
run_test test_reports_failed_check_and_keeps_install_file_when_remote_is_unreachable "signale l'échec et garde install.json quand le dépôt est injoignable"
run_test test_starts_query_when_install_file_is_missing "lance l'interrogation quand install.json est absent"
run_test test_treats_unknown_installed_version_as_outdated_once_latest_is_known "traite une version installée inconnue comme dépassée dès que le dernier tag est connu"
run_test test_starts_query_when_install_file_is_damaged "lance l'interrogation quand install.json est illisible"
run_test test_converts_ssh_repository_to_https "convertit une URL ssh du dépôt en https"
run_test test_does_not_offer_dismissed_version_again "ne repropose pas une version refusée"
run_test test_dismiss_keeps_last_check_date "le refus garde la date du dernier contrôle"
run_test test_offers_version_newer_than_dismissed_one "propose une version plus récente que celle refusée"
run_test test_forced_check_offers_dismissed_version "le contrôle forcé repropose une version refusée"
run_test test_background_query_keeps_dismissed_version "l'interrogation en arrière-plan garde la version refusée"
run_test test_dismiss_without_known_version_writes_nothing "un refus sans version connue n'écrit rien"
run_test test_installs_latest_known_version_with_cloned_installer "installe la dernière version connue avec l'installeur du clone"
run_test test_removes_temporary_clone_after_install "supprime le clone temporaire après l'installation"
run_test test_fails_without_known_latest_version "échoue sans dernière version connue"
run_test test_fails_when_tag_cannot_be_cloned "échoue quand le tag ne peut pas être cloné"
run_test test_fails_when_installer_fails "échoue quand l'installeur échoue"
run_test test_reports_last_five_lines_of_failing_installer_output "rend les cinq dernières lignes de la sortie d'un installeur en échec"
run_test test_reports_git_error_when_clone_fails "rend l'erreur git quand le clone échoue"
run_test test_rejects_unknown_mode "refuse un mode inconnu"
run_test test_rejects_force_outside_check "refuse --force hors du mode check"
run_test test_writes_nothing_on_stdout_for_usage_error "n'écrit rien sur la sortie standard en erreur d'usage"

echo "$PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ]
