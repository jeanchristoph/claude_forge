#!/bin/bash
# Branche temporaire forge, proposée par la garde de sécurité sur main / master.
#   Nom : tmp/<identité>-<ddmmyyyy>, suffixé -2, -3… si le nom du jour existe déjà
#   Identité : partie locale de user.email, préfixe noreply GitHub / GitLab retiré, convertie en slug
#   Crée la branche depuis HEAD, bascule dessus, rend compte en JSON sur une ligne
# Usage : temp-branch.sh [--root <dir>] [--date <ddmmyyyy>]
# Sortie : 0 branche créée · 1 usage ou identité absente · 2 échec git — le JSON est écrit sauf en erreur d'usage

set -u

readonly EXIT_USAGE=1
readonly EXIT_NO_IDENTITY=1
readonly EXIT_GIT=2
readonly BRANCH_PREFIX="tmp/"
readonly GITLAB_NOREPLY_DOMAIN="users.noreply.gitlab.com"
readonly STATUS_CREATED="created"
readonly STATUS_NO_IDENTITY="no_identity"
readonly STATUS_FAILED="failed"

ROOT="."
DAY=""

# ── Arguments et gardes ───────────────────────────────────────────────────────

fail_usage() {
  echo "temp-branch: $1" >&2
  echo "usage: temp-branch.sh [--root <dir>] [--date <ddmmyyyy>]" >&2
  exit $EXIT_USAGE
}

require_value() {
  [ "$2" -ge 2 ] || fail_usage "$1 needs a value"
}

parse_arguments() {
  while [ $# -gt 0 ]; do
    case $1 in
      --root) require_value "$1" $#; ROOT=$2; shift 2 ;;
      --date) require_value "$1" $#; DAY=$2; shift 2 ;;
      *)      fail_usage "unknown argument $1" ;;
    esac
  done
}

git_in_root() {
  git -C "$ROOT" "$@"
}

validate_arguments() {
  [ -n "$DAY" ] || DAY=$(date +%d%m%Y)
  [[ $DAY =~ ^[0-9]{8}$ ]] || fail_usage "date must be ddmmyyyy, got '$DAY'"
  git_in_root rev-parse --git-dir > /dev/null 2>&1 || fail_usage "not a git repository: $ROOT"
}

# ── Identité ──────────────────────────────────────────────────────────────────

# Partie locale de l'e-mail, sans le préfixe numérique des adresses noreply :
# GitHub <id>+<login>@users.noreply.github.com · GitLab <id>-<login>@users.noreply.gitlab.com
email_identity() {
  local email=$1
  local local_part=${email%%@*} domain=${email#*@}
  if [[ $local_part =~ ^[0-9]+\+(.+)$ ]]; then
    local_part=${BASH_REMATCH[1]}
  elif [ "$domain" = "$GITLAB_NOREPLY_DOMAIN" ] && [[ $local_part =~ ^[0-9]+-(.+)$ ]]; then
    local_part=${BASH_REMATCH[1]}
  fi
  printf '%s' "$local_part"
}

# Accents translittérés, puis les marques que //TRANSLIT laisse selon la plateforme (é → 'e, ô → ^o) retirées.
transliterate() {
  printf '%s' "$1" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | tr -d "'\"^~\`?"
}

slugify() {
  transliterate "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//'
}

# ── Nom de la branche ─────────────────────────────────────────────────────────

branch_exists() {
  git_in_root show-ref --verify --quiet "refs/heads/$1"
}

# Premier nom libre : <base>, puis <base>-2, <base>-3…
free_branch_name() {
  local base=$1 candidate=$1 rank=2
  while branch_exists "$candidate"; do
    candidate="$base-$rank"
    rank=$((rank + 1))
  done
  printf '%s' "$candidate"
}

# ── Rendu — données seules, la mise en page revient au skill (SKILL.md) ───────

# Chaîne JSON sans jq (absent de Git Bash) : barre oblique inverse, guillemet et contrôles échappés.
json_string() {
  local text=${1//\\/\\\\}
  text=${text//\"/\\\"}
  text=${text//$'\n'/\\n}
  text=${text//$'\r'/\\r}
  text=${text//$'\t'/\\t}
  printf '"%s"' "$text"
}

main() {
  parse_arguments "$@"
  validate_arguments
  local identity
  identity=$(slugify "$(email_identity "$(git_in_root config user.email)")")
  if [ -z "$identity" ]; then
    printf '{"status":%s}\n' "$(json_string "$STATUS_NO_IDENTITY")"
    exit $EXIT_NO_IDENTITY
  fi
  local branch output
  branch=$(free_branch_name "$BRANCH_PREFIX$identity-$DAY")
  if ! output=$(git_in_root checkout -b "$branch" 2>&1); then
    printf '{"status":%s,"branch":%s,"detail":%s}\n' "$(json_string "$STATUS_FAILED")" \
      "$(json_string "$branch")" "$(json_string "$output")"
    exit $EXIT_GIT
  fi
  printf '{"status":%s,"branch":%s}\n' "$(json_string "$STATUS_CREATED")" "$(json_string "$branch")"
}

main "$@"
