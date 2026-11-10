#!/bin/bash
# Mise à jour du skill forge depuis son dépôt publié.
#   check   → compare la version installée au dernier tag vX.Y.Z connu, JSON sur une ligne ;
#             contrôle échu (24 heures, install.json absent ou illisible) → interrogation du dépôt en arrière-plan, sans attente ;
#             --force → interrogation au premier plan, quel que soit le délai, version refusée comprise
#   run     → clone le dernier tag connu dans un dossier temporaire et lance l'installeur de la plateforme, JSON sur une ligne
#   dismiss → retient le refus du dernier tag connu : plus proposé par check, sauf --force ou tag plus récent
#   Appelé à chaque lancement : la lecture du contrôle récent n'écrit rien et ne lance aucun processus
# Usage : update.sh <check|run|dismiss> [--force] [--install-dir <dir>] [--installer <path>]
#   --install-dir : dossier contenant install.json (défaut : dossier du skill, parent de scripts/)
#   --installer   : installeur relatif au clone (défaut : selon la plateforme)
# Sortie : 0 rendu écrit · 1 usage, sans JSON · 2 échec de run, JSON écrit

set -u

source "$(dirname "${BASH_SOURCE[0]}")/json.sh"

readonly EXIT_USAGE=1
readonly EXIT_FAILED=2
readonly CHECK_INTERVAL_SECONDS=$((24 * 3600))
readonly DEFAULT_REPOSITORY=${FORGE_UPDATE_REPOSITORY:-"https://github.com/jeanchristoph/claude_forge.git"}
readonly INSTALL_FILE_NAME="install.json"
readonly VERSION_PATTERN='^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
readonly CHECK_SKIPPED="skipped"
readonly CHECK_STARTED="started"
readonly CHECK_DONE="done"
readonly CHECK_FAILED="failed"
readonly STATUS_DONE="done"
readonly STATUS_FAILED="failed"
readonly REASON_NO_KNOWN_VERSION="no known version"
readonly REASON_CLONE_FAILED="clone failed"
readonly REASON_INSTALLER_FAILED="installer failed"
readonly DETAIL_LINES_KEPT=5

MODE=""
IS_FORCED=false
INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER=""
INSTALLED_VERSION=""
REPOSITORY=""
LAST_CHECK=""
LATEST_VERSION=""
DISMISSED_VERSION=""
FAILURE_DETAIL=""
NOW=0

# ── Arguments et gardes ───────────────────────────────────────────────────────

fail_usage() {
  echo "update: $1" >&2
  echo "usage: update.sh <check|run|dismiss> [--force] [--install-dir <dir>] [--installer <path>]" >&2
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
      --force)       IS_FORCED=true; shift ;;
      --install-dir) require_value "$1" $#; INSTALL_DIR=$2; shift 2 ;;
      --installer)   require_value "$1" $#; INSTALLER=$2; shift 2 ;;
      *)             fail_usage "unknown argument $1" ;;
    esac
  done
}

validate_arguments() {
  case $MODE in
    check|run|dismiss) ;;
    *) fail_usage "unknown mode $MODE" ;;
  esac
  [ "$MODE" = check ] || [ "$IS_FORCED" = false ] || fail_usage "--force applies to check only"
  [ -d "$INSTALL_DIR" ] || fail_usage "not a directory: $INSTALL_DIR"
}

# ── install.json — lecture sans sous-processus ────────────────────────────────

install_file() {
  printf '%s' "$INSTALL_DIR/$INSTALL_FILE_NAME"
}

# Champ chaîne de install.json dans REPLY, vide s'il est absent ou nul.
read_string_field() {
  REPLY=""
  [[ $1 =~ \"$2\":\"([^\"]*)\" ]] && REPLY=${BASH_REMATCH[1]}
}

# install.json absent ou sans last_check numérique → illisible : contrôle échu, version inconnue.
load_install_file() {
  local content="" file
  file=$(install_file)
  [ -f "$file" ] && IFS= read -r -d '' content < "$file"
  read_string_field "$content" version;    INSTALLED_VERSION=$REPLY
  read_string_field "$content" repository; REPOSITORY=$REPLY
  read_string_field "$content" latest;     LATEST_VERSION=$REPLY
  read_string_field "$content" dismissed;  DISMISSED_VERSION=$REPLY
  [[ $content =~ \"last_check\":([0-9]+) ]] && LAST_CHECK=${BASH_REMATCH[1]}
  [ -n "$REPOSITORY" ] || REPOSITORY=$DEFAULT_REPOSITORY
}

save_install_file() {
  local version_json latest_json repository_json dismissed_json
  nullable_json "$INSTALLED_VERSION"; version_json=$REPLY
  json_escape "$REPOSITORY"; repository_json=$REPLY
  nullable_json "$LATEST_VERSION"; latest_json=$REPLY
  nullable_json "$DISMISSED_VERSION"; dismissed_json=$REPLY
  printf '{"version":%s,"repository":%s,"last_check":%s,"latest":%s,"dismissed":%s}\n' \
    "$version_json" "$repository_json" "${LAST_CHECK:-0}" "$latest_json" "$dismissed_json" > "$(install_file)"
}

nullable_json() {
  REPLY=null
  [ -n "$1" ] && json_escape "$1"
}

# ── Versions ──────────────────────────────────────────────────────────────────

# Vrai si la version $1 est strictement plus récente que $2 ; $2 hors format vX.Y.Z → toujours vrai.
is_newer_version() {
  [[ $1 =~ $VERSION_PATTERN ]] || return 1
  local -a candidate=("${BASH_REMATCH[@]:1}")
  [[ $2 =~ $VERSION_PATTERN ]] || return 0
  local -a reference=("${BASH_REMATCH[@]:1}") index
  for index in 0 1 2; do
    [ "$((10#${candidate[index]}))" -gt "$((10#${reference[index]}))" ] && return 0
    [ "$((10#${candidate[index]}))" -lt "$((10#${reference[index]}))" ] && return 1
  done
  return 1
}

# Version refusée (dismiss) → plus proposée, sauf contrôle forcé.
is_update_available() {
  [ -n "$LATEST_VERSION" ] && is_newer_version "$LATEST_VERSION" "$INSTALLED_VERSION" \
    && { [ "$IS_FORCED" = true ] || [ "$LATEST_VERSION" != "$DISMISSED_VERSION" ]; }
}

is_check_due() {
  [ -z "$LAST_CHECK" ] || [ $((NOW - LAST_CHECK)) -ge $CHECK_INTERVAL_SECONDS ]
}

# ── Dépôt distant ─────────────────────────────────────────────────────────────

# git@host:path → https://host/path : l'https n'exige ni clé ni passphrase, rien n'attend une saisie.
https_repository() {
  local url=$1
  [[ $url =~ ^git@([^:]+):(.+)$ ]] && url="https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  printf '%s' "$url"
}

# Dernier tag vX.Y.Z publié dans REPLY ; échec réseau ou aucun tag conforme → retour 1.
fetch_latest_tag() {
  local refs line tag latest=""
  refs=$(GIT_TERMINAL_PROMPT=0 git -c http.lowSpeedLimit=1 -c http.lowSpeedTime=10 \
    ls-remote --tags --refs "$(https_repository "$REPOSITORY")" 2>/dev/null) || return 1
  while IFS= read -r line; do
    tag=${line##*refs/tags/}
    [[ $tag =~ $VERSION_PATTERN ]] || continue
    { [ -z "$latest" ] || is_newer_version "$tag" "$latest"; } && latest=$tag
  done <<< "$refs"
  REPLY=$latest
  [ -n "$latest" ]
}

# Seule écriture du contrôle : au plus une fois par délai, échec d'écriture silencieux.
refresh_latest_version() {
  fetch_latest_tag || return 1
  LATEST_VERSION=$REPLY
  LAST_CHECK=$NOW
  save_install_file 2>/dev/null || true
}

# ── check ─────────────────────────────────────────────────────────────────────

run_check() {
  local check_status=$CHECK_SKIPPED
  if [ "$IS_FORCED" = true ]; then
    refresh_latest_version && check_status=$CHECK_DONE || check_status=$CHECK_FAILED
  elif is_check_due; then
    ( refresh_latest_version ) </dev/null >/dev/null 2>&1 &
    check_status=$CHECK_STARTED
  fi
  render_check "$check_status"
}

render_check() {
  local installed_json latest_json is_available=false status_json
  nullable_json "$INSTALLED_VERSION"; installed_json=$REPLY
  nullable_json "$LATEST_VERSION"; latest_json=$REPLY
  is_update_available && is_available=true
  json_escape "$1"; status_json=$REPLY
  printf '{"installed":%s,"latest":%s,"update_available":%s,"check":%s}\n' \
    "$installed_json" "$latest_json" "$is_available" "$status_json"
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
  REPLY=$REASON_NO_KNOWN_VERSION
  [ -n "$LATEST_VERSION" ] || return 1
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
  if ! install_latest_version; then
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
  printf -v NOW '%(%s)T' -1
  load_install_file
  case $MODE in
    check)   run_check ;;
    run)     run_update ;;
    dismiss) run_dismiss ;;
  esac
}

main "$@"
