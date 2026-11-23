#!/bin/bash
# Garde d'écriture dans un projet lié : la session parente n'écrit jamais dans un autre projet forgé.
#   Déclaré par les installeurs sur PreToolUse (Edit|Write|MultiEdit|NotebookEdit), synchrone.
#   Appel d'un sous-agent (agent_id présent) → autorisé : un délégué écrit dans son worktree.
#   ROOT = racine git du cwd, qui contient .forge/ — sinon autorisé.
#   Fichier visé hors de ROOT, dans un dossier dont un parent contient .forge/project.md (projet forgé ou son
#   worktree) → refusé (permissionDecision deny), sauf .forge/branch/*/brief.md et .forge/branch/*/log.md de ce
#   projet, écrits par la délégation elle-même (« Délégation — projet lié » de commands/delegation.md).
#   Sans projet forgé autour du fichier visé : sortie sans lancer de processus.
#   Limite : une écriture par commande shell (sed -i, git worktree add, redirection) n'est pas couverte.
# Entrée : JSON du hook sur l'entrée standard
# Sortie : décision deny avec sa raison, rien sinon ; sortie 0 dans tous les cas

exec 2>/dev/null

readonly SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")/../scripts"
source "$SCRIPT_DIR/json.sh" || exit 0

readonly DELEGATION_FILE_PATTERN='^\.forge/branch/.+/(brief|log)\.md$'

INPUT=""

# Fichier visé, absolu, dans REPLY ; rend 1 sans fichier.
target_file() {
  local file
  json_path_field file_path "$INPUT"
  [ -n "$REPLY" ] || json_path_field notebook_path "$INPUT"
  file=$REPLY
  [ -n "$file" ] || return 1
  if [[ $file != /* && ! $file =~ ^[A-Za-z]:/ ]]; then
    json_path_field cwd "$INPUT"
    file="$REPLY/$file"
  fi
  REPLY=$file
}

# Dossier forgé le plus proche du fichier visé (parent qui contient .forge/project.md) dans REPLY ; rend 1 sans lui.
forged_project_of() {
  local dir=${1%/*}
  while [ -n "$dir" ] && [[ $dir == */* ]]; do
    [ -f "$dir/.forge/project.md" ] && { REPLY=$dir; return 0; }
    dir=${dir%/*}
  done
  return 1
}

# ROOT de la session dans REPLY : racine git du cwd qui contient .forge/ ; rend 1 sinon.
session_root() {
  json_path_field cwd "$INPUT"
  [ -n "$REPLY" ] || return 1
  REPLY=$(git -C "$REPLY" rev-parse --show-toplevel) || return 1
  [ -d "$REPLY/.forge" ]
}

# Fichier <1> sous le dossier <2> : comparaison des dossiers eux-mêmes (-ef), jamais des textes — git rend
# « C:/x » là où le hook reçoit parfois « /c/x » ou une autre casse de lecteur.
is_inside() {
  local dir=${1%/*}
  while [ -n "$dir" ] && [[ $dir == */* ]]; do
    [ "$dir" -ef "$2" ] && return 0
    dir=${dir%/*}
  done
  return 1
}

deny() {
  json_escape "forge: $1 belongs to the forged project $2, outside ROOT — the parent never writes there: add the task to the plan, then delegate (« Délégation — projet lié »)."
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}\n' "$REPLY"
}

main() {
  local file project root
  INPUT=$(cat) || exit 0
  json_string_field agent_id "$INPUT"
  [ -z "$REPLY" ] || exit 0
  target_file || exit 0
  file=$REPLY
  forged_project_of "$file" || exit 0
  project=$REPLY
  session_root || exit 0
  root=$REPLY
  is_inside "$file" "$root" && exit 0
  [[ ${file#"$project"/} =~ $DELEGATION_FILE_PATTERN ]] && exit 0
  deny "$file" "$project"
}

main
exit 0
