#!/bin/bash
# Mise à jour du skill forge depuis son dépôt publié, à la demande de l'utilisateur seulement.
#   run     → cherche le dernier tag vX.Y.Z publié, le clone dans un dossier temporaire et lance l'installeur de la
#             plateforme ; déjà installé → rien n'est lancé. JSON sur une ligne
#   dismiss → retient le refus du dernier tag annoncé par le hook update-notice.sh, qui ne l'annonce plus
# Usage : update.sh <run|dismiss> [--install-dir <dir>] [--installer <path>]
#   --install-dir : dossier contenant install.json (défaut : dossier du skill, parent de scripts/)
#   --installer   : installeur relatif au clone (défaut : selon la plateforme)
# Sortie : 0 rendu écrit · 1 usage, sans JSON · 2 échec de run, JSON écrit

set -u

source "$(dirname "${BASH_SOURCE[0]}")/json.sh"
source "$(dirname "${BASH_SOURCE[0]}")/latest-version.sh"

readonly EXIT_USAGE=1
readonly EXIT_FAILED=2
readonly STATUS_DONE="done"
readonly STATUS_UP_TO_DATE="up_to_date"
readonly STATUS_FAILED="failed"
readonly REASON_UNREACHABLE="repository unreachable"
readonly REASON_CLONE_FAILED="clone failed"
readonly REASON_INSTALLER_FAILED="installer failed"
readonly DETAIL_LINES_KEPT=5

MODE=""
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER=""
FAILURE_DETAIL=""

# ── Arguments et gardes ───────────────────────────────────────────────────────

fail_usage() {
  echo "update: $1" >&2
  echo "usage: update.sh <run|dismiss> [--install-dir <dir>] [--installer <path>]" >&2
  exit $EXIT_USAGE
}

require_value() {
  [ "$2" -ge 2 ] || fail_usage "$1 needs a value"
}

parse_arguments() {
  [ $# -ge 1 ] || fail_usage "missing mode"
  MODE=$1
  shift
  while [ $# -gt 0 ]; do
    case $1 in
      --install-dir) require_value "$1" $#; INSTALL_DIR=$2; shift 2 ;;
      --installer)   require_value "$1" $#; INSTALLER=$2; shift 2 ;;
      *)             fail_usage "unknown argument $1" ;;
    esac
  done
}

validate_arguments() {
  case $MODE in
    run|dismiss) ;;
    *) fail_usage "unknown mode $MODE" ;;
  esac
  [ -d "$INSTALL_DIR" ] || fail_usage "not a directory: $INSTALL_DIR"
}

# ── run ───────────────────────────────────────────────────────────────────────

platform_installer() {
  [ -n "$INSTALLER" ] && { printf '%s' "$INSTALLER"; return; }
  case $OSTYPE in
    msys*|cygwin*) printf '%s' "install/install.ps1" ;;
    *)             printf '%s' "install/install.sh" ;;
  esac
}

# Installeur PowerShell lancé avec une stratégie d'exécution limitée à ce processus : rien de persistant.
launch_installer() {
  local installer=$1
  case $installer in
    *.ps1) powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$installer" ;;
    *)     bash "$installer" ;;
  esac
}

# Dernières lignes de la sortie $1 dans FAILURE_DETAIL, retours chariot retirés.
keep_failure_detail() {
  local -a lines
  mapfile -t lines <<< "${1//$'\r'/}"
  local first=$(( ${#lines[@]} > DETAIL_LINES_KEPT ? ${#lines[@]} - DETAIL_LINES_KEPT : 0 ))
  printf -v FAILURE_DETAIL '%s\n' "${lines[@]:first}"
  FAILURE_DETAIL=${FAILURE_DETAIL%$'\n'}
}

clone_latest_version() {
  local output
  output=$(GIT_TERMINAL_PROMPT=0 git clone -q --depth 1 --branch "$LATEST_VERSION" \
    "$(https_repository "$REPOSITORY")" "$1" 2>&1) && return 0
  keep_failure_detail "$output"
  return 1
}

run_cloned_installer() {
  local output
  output=$(cd "$1" && launch_installer "$(platform_installer)" 2>&1) && return 0
  keep_failure_detail "$output"
  return 1
}

# Clone du tag et installation ; motif d'échec dans REPLY, fin de sortie dans FAILURE_DETAIL.
install_latest_version() {
  local clone_dir="${TMPDIR:-/tmp}/forge-update" is_installed=false
  rm -rf "$clone_dir"
  REPLY=$REASON_CLONE_FAILED
  clone_latest_version "$clone_dir" || return 1
  REPLY=$REASON_INSTALLER_FAILED
  run_cloned_installer "$clone_dir" && is_installed=true
  rm -rf "$clone_dir" 2>/dev/null
  [ "$is_installed" = true ]
}

run_update() {
  local status=$STATUS_DONE reason="" exit_code=0
  if ! refresh_latest_version; then
    status=$STATUS_FAILED
    reason=$REASON_UNREACHABLE
    exit_code=$EXIT_FAILED
  elif ! is_newer_version "$LATEST_VERSION" "$INSTALLED_VERSION"; then
    status=$STATUS_UP_TO_DATE
  elif ! install_latest_version; then
    status=$STATUS_FAILED
    reason=$REPLY
    exit_code=$EXIT_FAILED
  fi
  render_run "$status" "$reason"
  return $exit_code
}

render_run() {
  local from_json to_json status_json reason_json detail_json
  nullable_json "$INSTALLED_VERSION"; from_json=$REPLY
  nullable_json "$LATEST_VERSION"; to_json=$REPLY
  json_escape "$1"; status_json=$REPLY
  nullable_json "$2"; reason_json=$REPLY
  nullable_json "$FAILURE_DETAIL"; detail_json=$REPLY
  printf '{"from":%s,"to":%s,"status":%s,"reason":%s,"detail":%s}\n' \
    "$from_json" "$to_json" "$status_json" "$reason_json" "$detail_json"
}

# ── dismiss ───────────────────────────────────────────────────────────────────

run_dismiss() {
  DISMISSED_VERSION=$LATEST_VERSION
  [ -z "$DISMISSED_VERSION" ] || save_install_file 2>/dev/null || true
  nullable_json "$DISMISSED_VERSION"
  printf '{"dismissed":%s}\n' "$REPLY"
}

main() {
  parse_arguments "$@"
  validate_arguments
  load_install_file
  case $MODE in
    run)     run_update ;;
    dismiss) run_dismiss ;;
  esac
}

main "$@"
