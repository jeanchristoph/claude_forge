#!/bin/bash
# Contrôles de démarrage du skill, lancés détachés par la « Détection d'état » de SKILL.md, sans attente du résultat.
#   gitignore → ajoute /.forge/branch/*/input/ au .gitignore du projet quand git ne l'ignore pas encore :
#               ligne insérée dans le bloc claude/forge, ou bloc ajouté en fin de fichier (créé s'il est absent)
#   Rien hors dépôt git, sans dossier .forge/, sur main / master ou HEAD détaché
#   Rend compte en JSON sur une ligne — lu par les tests, ignoré au démarrage
# Usage : checks.sh [--root <dir>]
# Sortie : 0 contrôles faits · 1 usage, sans JSON

set -u

readonly EXIT_USAGE=1
readonly BRANCH_INPUT_RULE="/.forge/branch/*/input/"
readonly BRANCH_INPUT_PROBE=".forge/branch/probe/input/probe"
readonly BLOCK_START="###> claude/forge ###"
readonly BLOCK_END="###< claude/forge ###"
readonly RESULT_UPDATED="updated"
readonly RESULT_UNCHANGED="unchanged"
readonly RESULT_SKIPPED="skipped"
readonly CARRIAGE_RETURN=$'\r'

ROOT="."
GITIGNORE_RESULT=""

# ── Arguments et gardes ───────────────────────────────────────────────────────

fail_usage() {
  echo "checks: $1" >&2
  echo "usage: checks.sh [--root <dir>]" >&2
  exit $EXIT_USAGE
}

parse_arguments() {
  while [ $# -gt 0 ]; do
    case $1 in
      --root) [ $# -ge 2 ] || fail_usage "$1 needs a value"; ROOT=$2; shift 2 ;;
      *)      fail_usage "unknown argument $1" ;;
    esac
  done
  [ -d "$ROOT" ] || fail_usage "not a directory: $ROOT"
}

# Branche de travail forge : dépôt git, dossier .forge/, branche nommée autre que main / master.
is_forge_working_branch() {
  local branch
  [ -d "$ROOT/.forge" ] || return 1
  branch=$(git -C "$ROOT" branch --show-current 2>/dev/null) || return 1
  case $branch in
    ""|main|master) return 1 ;;
  esac
}

is_branch_input_ignored() {
  git -C "$ROOT" check-ignore -q -- "$BRANCH_INPUT_PROBE" 2>/dev/null
}

# ── .gitignore ────────────────────────────────────────────────────────────────

# Fin de ligne du fichier existant : CRLF gardé si sa première ligne en porte un, LF sinon.
# Lecture bash plutôt que grep : le grep de Git Bash peut ignorer les CR en mode texte.
line_ending_of() {
  local first_line=""
  REPLY=$'\n'
  [ -f "$1" ] && IFS= read -r first_line < "$1"
  [[ $first_line == *"$CARRIAGE_RETURN" ]] && REPLY=$'\r\n'
  return 0
}

has_block_end() {
  [ -f "$1" ] && grep -q "^$BLOCK_END" "$1"
}

insert_rule_in_block() {
  local file=$1 eol=$2 line content=""
  while IFS= read -r line || [ -n "$line" ]; do
    [ "${line%"$CARRIAGE_RETURN"}" = "$BLOCK_END" ] && content+="$BRANCH_INPUT_RULE$eol"
    content+="${line%"$CARRIAGE_RETURN"}$eol"
  done < "$file"
  printf '%s' "$content" > "$file"
}

append_block() {
  local file=$1 eol=$2
  [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ] && printf '%s' "$eol" >> "$file"
  printf '%s%s%s%s%s%s' "$BLOCK_START" "$eol" "$BRANCH_INPUT_RULE" "$eol" "$BLOCK_END" "$eol" >> "$file"
}

check_gitignore() {
  local file="$ROOT/.gitignore" eol
  if ! is_forge_working_branch; then GITIGNORE_RESULT=$RESULT_SKIPPED; return; fi
  if is_branch_input_ignored; then GITIGNORE_RESULT=$RESULT_UNCHANGED; return; fi
  line_ending_of "$file"
  eol=$REPLY
  if has_block_end "$file"; then insert_rule_in_block "$file" "$eol"; else append_block "$file" "$eol"; fi
  GITIGNORE_RESULT=$RESULT_UPDATED
}

main() {
  parse_arguments "$@"
  check_gitignore
  printf '{"gitignore":"%s"}\n' "$GITIGNORE_RESULT"
}

main "$@"
