#!/bin/bash
# Entrée de LOG : ajoute « - [AAAA-MM-JJ HH:MM] <texte> » en tête du log.md de la branche, heure lue sur l'horloge locale.
#   Seul chemin d'écriture d'une entrée LOG : le skill fournit le texte, jamais la date ni l'heure
#   log.md absent → créé ; titre « # … » en première ligne → gardé en tête, l'entrée passe dessous (ligne vide comprise)
#   Fins de ligne du fichier conservées : CRLF si sa première ligne en porte, LF sinon
#   Texte écrit tel quel, sans interprétation ; une entrée tient sur une ligne
# Usage : log-entry.sh --branch <name> --text <texte> [--root <dir>]
# Sortie : 0 entrée écrite, rien sur la sortie standard · 1 usage, rien d'écrit, erreur sur la sortie d'erreur
#   · 2 bash antérieur à 4.2, rien d'écrit

set -u

readonly EXIT_USAGE=1
readonly EXIT_ENVIRONMENT=2
readonly LOG_NAME="log.md"

ROOT="."
BRANCH=""
TEXT=""
HAS_TEXT=0

fail_usage() {
  echo "log-entry: $1" >&2
  echo "usage: log-entry.sh --branch <name> --text <text> [--root <dir>]" >&2
  exit $EXIT_USAGE
}

parse_arguments() {
  while [ $# -gt 0 ]; do
    [ $# -ge 2 ] || fail_usage "$1 needs a value"
    case $1 in
      --root)   ROOT=$2 ;;
      --branch) BRANCH=$2 ;;
      --text)   TEXT=$2; HAS_TEXT=1 ;;
      *)        fail_usage "unknown argument $1" ;;
    esac
    shift 2
  done
  [ -n "$BRANCH" ] || fail_usage "--branch is required"
  [ "$HAS_TEXT" -eq 1 ] && [ -n "${TEXT//[[:space:]]/}" ] || fail_usage "--text must not be empty"
  [[ $TEXT != *$'\n'* && $TEXT != *$'\r'* ]] || fail_usage "--text must hold on one line"
  [ -d "$ROOT" ] || fail_usage "not a directory: $ROOT"
}

# Nombre de lignes gardées au-dessus de l'entrée : titre « # … » et ligne vide qui le suit, 0 sans titre.
count_header_lines() {
  local log_file=$1 first second
  REPLY=0
  { IFS= read -r first; IFS= read -r second; } < "$log_file"
  [[ ${first:-} == "# "* ]] || return
  REPLY=1
  [ -z "${second%$'\r'}" ] && REPLY=2
}

# Fin de ligne du fichier dans REPLY : CRLF si sa première ligne en porte.
read_line_ending() {
  local first=""
  REPLY=$'\n'
  IFS= read -r first < "$1"
  [[ $first == *$'\r' ]] && REPLY=$'\r\n'
}

# printf %(…)T lit l'horloge sans sous-processus, à partir de bash 4.2.
require_bash_with_clock() {
  (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2) )) && return
  echo "log-entry: bash 4.2 or later required (found $BASH_VERSION)" >&2
  exit $EXIT_ENVIRONMENT
}

main() {
  local branch_dir log_file entry header_lines ending stamp temporary
  require_bash_with_clock
  parse_arguments "$@"
  branch_dir="$ROOT/.forge/branch/$BRANCH"
  log_file="$branch_dir/$LOG_NAME"
  mkdir -p "$branch_dir" || fail_usage "cannot create $branch_dir"
  [ -f "$log_file" ] || : > "$log_file"
  printf -v stamp '%(%Y-%m-%d %H:%M)T' -1
  read_line_ending "$log_file"; ending=$REPLY
  count_header_lines "$log_file"; header_lines=$REPLY
  entry="- [$stamp] $TEXT"
  temporary="$log_file.tmp.$$"
  {
    head -n "$header_lines" "$log_file"
    printf '%s%s' "$entry" "$ending"
    tail -n +"$((header_lines + 1))" "$log_file"
  } > "$temporary" && mv "$temporary" "$log_file"
}

main "$@"
