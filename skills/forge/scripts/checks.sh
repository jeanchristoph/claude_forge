#!/bin/bash
# Contrôles de démarrage du skill, lancés détachés par la « Détection d'état » de SKILL.md, sans attente du résultat.
#   gitignore → ajoute au .gitignore du projet chaque règle forge que git n'applique pas encore —
#               /.forge/branch/*/input/ (fichiers apportés) et /.forge/branch/**/time-log.jsonl (journal du hook de mesure) :
#               lignes insérées dans le bloc claude/forge, ou bloc ajouté en fin de fichier (créé s'il est absent)
#   Rien hors dépôt git, sans dossier .forge/, sur main / master ou HEAD détaché
#   Rend compte en JSON sur une ligne — lu par les tests, ignoré au démarrage
# Usage : checks.sh [--root <dir>]
# Sortie : 0 contrôles faits · 1 usage, sans JSON

set -u

readonly EXIT_USAGE=1
# Règle et chemin témoin de même rang : le témoin ignoré par git, la règle n'est pas réécrite.
readonly IGNORE_RULES=("/.forge/branch/*/input/" "/.forge/branch/**/time-log.jsonl")
readonly IGNORE_PROBES=(".forge/branch/probe/input/probe" ".forge/branch/probe/time-log.jsonl")
readonly BLOCK_START="###> claude/forge ###"
readonly BLOCK_END="###< claude/forge ###"
readonly RESULT_UPDATED="updated"
readonly RESULT_UNCHANGED="unchanged"
readonly RESULT_SKIPPED="skipped"
readonly CARRIAGE_RETURN=$'\r'

ROOT="."
GITIGNORE_RESULT=""
MISSING_RULES=()

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

# Règles dont le chemin témoin n'est pas encore ignoré par git, dans MISSING_RULES.
collect_missing_rules() {
  local index
  MISSING_RULES=()
  for index in "${!IGNORE_RULES[@]}"; do
    git -C "$ROOT" check-ignore -q -- "${IGNORE_PROBES[$index]}" 2>/dev/null || MISSING_RULES+=("${IGNORE_RULES[$index]}")
  done
}

# Règles manquantes, une par ligne, dans REPLY.
missing_rule_lines() {
  local eol=$1 rule
  REPLY=""
  for rule in "${MISSING_RULES[@]}"; do REPLY+="$rule$eol"; done
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
  local file=$1 eol=$2 line content="" rules
  missing_rule_lines "$eol"
  rules=$REPLY
  while IFS= read -r line || [ -n "$line" ]; do
    [ "${line%"$CARRIAGE_RETURN"}" = "$BLOCK_END" ] && content+="$rules"
    content+="${line%"$CARRIAGE_RETURN"}$eol"
  done < "$file"
  printf '%s' "$content" > "$file"
}

append_block() {
  local file=$1 eol=$2
  missing_rule_lines "$eol"
  [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ] && printf '%s' "$eol" >> "$file"
  printf '%s%s%s%s%s' "$BLOCK_START" "$eol" "$REPLY" "$BLOCK_END" "$eol" >> "$file"
}

check_gitignore() {
  local file="$ROOT/.gitignore" eol
  if ! is_forge_working_branch; then GITIGNORE_RESULT=$RESULT_SKIPPED; return; fi
  collect_missing_rules
  if [ ${#MISSING_RULES[@]} -eq 0 ]; then GITIGNORE_RESULT=$RESULT_UNCHANGED; return; fi
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
