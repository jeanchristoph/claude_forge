#!/bin/bash
# Retrait du worktree d'une branche liée une fois cette branche fusionnée dans la branche par défaut du projet lié,
# ou dans l'une des branches cibles de la livraison (--merged-into : une livraison limitée à dev compte).
#   Appelé par la livraison relayée (commands/engrave.md) et par la clôture de la branche parente (commands/closure.md).
#   Retire seulement si : worktree distinct du dossier principal du projet lié, working tree propre, branche fusionnée
#   dans la branche par défaut (master puis main) ou une branche de --merged-into, locale ou origin/<branche> après
#   fetch — par git worktree remove,
#   jamais --force. Sinon le worktree est gardé, la raison dans le JSON.
#   Aucun worktree pour la branche → status absent : rien à retirer.
# ⚠️ Fusion par squash ou rebase (pull request) : la branche n'est pas ancêtre de la branche par défaut → gardé, not merged.
# Usage : linked-worktree-cleanup.sh --linked <dossier du projet lié> --branch <branche liée> [--merged-into <b>[,<b>…]]
# Sortie : 0 JSON écrit sur une ligne, {"worktree":<chemin|null>,"status":"removed|kept|absent","reason":<raison|null>}
#          · 1 usage, sans JSON

set -u

source "$(dirname "${BASH_SOURCE[0]}")/json.sh"

readonly EXIT_USAGE=1
readonly STATUS_REMOVED="removed"
readonly STATUS_KEPT="kept"
readonly STATUS_ABSENT="absent"
readonly REASON_NOT_MERGED="not merged"
readonly REASON_UNCOMMITTED="uncommitted changes"
readonly REASON_MAIN_WORKING_TREE="main working tree"
readonly REASON_GIT_ERROR="git error"
readonly DEFAULT_BRANCH_CANDIDATES=(master main)
readonly REMOTE="origin"

LINKED=""
BRANCH=""
WORKTREE=""
MAIN_WORKTREE=""
MERGED_INTO=""
INTEGRATION_BRANCHES=()

# ── Arguments ─────────────────────────────────────────────────────────────────

fail_usage() {
  echo "linked-worktree-cleanup: $1" >&2
  echo "usage: linked-worktree-cleanup.sh --linked <dir> --branch <branch> [--merged-into <branch>[,<branch>...]]" >&2
  exit $EXIT_USAGE
}

parse_arguments() {
  while [ $# -gt 0 ]; do
    case $1 in
      --linked) [ $# -ge 2 ] || fail_usage "$1 needs a value"; LINKED=$2; shift 2 ;;
      --branch) [ $# -ge 2 ] || fail_usage "$1 needs a value"; BRANCH=$2; shift 2 ;;
      --merged-into) [ $# -ge 2 ] || fail_usage "$1 needs a value"; MERGED_INTO=$2; shift 2 ;;
      *)        fail_usage "unknown argument $1" ;;
    esac
  done
  [ -n "$LINKED" ] || fail_usage "--linked is required"
  [ -n "$BRANCH" ] || fail_usage "--branch is required"
  [ -d "$LINKED" ] || fail_usage "not a directory: $LINKED"
}

# ── Rendu ─────────────────────────────────────────────────────────────────────

# Usage : report <status> [reason] — chemin du worktree repris de WORKTREE, null si vide.
report() {
  local worktree="null" reason="null"
  [ -n "$WORKTREE" ] && worktree=$(json_string "$WORKTREE")
  [ $# -ge 2 ] && reason=$(json_string "$2")
  printf '{"worktree":%s,"status":%s,"reason":%s}\n' "$worktree" "$(json_string "$1")" "$reason"
  exit 0
}

# ── Lecture git ───────────────────────────────────────────────────────────────

# WORKTREE = worktree qui extrait refs/heads/<BRANCH>, MAIN_WORKTREE = premier de la liste (dossier principal).
locate_worktrees() {
  local listing line current=""
  listing=$(git -C "$LINKED" worktree list --porcelain 2>/dev/null) || return 1
  while IFS= read -r line; do
    case $line in
      "worktree "*) current=${line#worktree }; [ -z "$MAIN_WORKTREE" ] && MAIN_WORKTREE=$current ;;
      "branch refs/heads/$BRANCH") WORKTREE=$current ;;
    esac
  done <<< "$listing"
}

is_main_working_tree() {
  [ "$WORKTREE" = "$MAIN_WORKTREE" ] || [ "$WORKTREE" -ef "$MAIN_WORKTREE" ] || [ "$WORKTREE" -ef "$LINKED" ]
}

# Sortie 0 propre · 1 modifié · 2 erreur git.
working_tree_state() {
  local changes
  changes=$(git -C "$WORKTREE" status --porcelain 2>/dev/null) || return 2
  [ -z "$changes" ]
}

has_ref() {
  git -C "$LINKED" show-ref --verify --quiet "$1"
}

has_remote() {
  git -C "$LINKED" remote get-url "$REMOTE" > /dev/null 2>&1
}

# Branche par défaut du projet lié dans REPLY : master puis main, locale ou distante. Sortie 1 si aucune.
default_branch() {
  local candidate
  for candidate in "${DEFAULT_BRANCH_CANDIDATES[@]}"; do
    REPLY=$candidate
    has_ref "refs/heads/$candidate" && return 0
    has_ref "refs/remotes/$REMOTE/$candidate" && return 0
  done
  return 1
}

is_ancestor_of() {
  has_ref "$1" && git -C "$LINKED" merge-base --is-ancestor "refs/heads/$BRANCH" "$1" 2>/dev/null
}

# Branches dont la fusion vaut retrait, dans INTEGRATION_BRANCHES : branche par défaut connue, puis celles de
# --merged-into, la branche liée elle-même exclue. Sortie 1 si aucune.
collect_integration_branches() {
  local target
  default_branch && INTEGRATION_BRANCHES+=("$REPLY")
  local IFS=,
  for target in $MERGED_INTO; do
    [ -n "$target" ] && [ "$target" != "$BRANCH" ] && INTEGRATION_BRANCHES+=("$target")
  done
  [ ${#INTEGRATION_BRANCHES[@]} -gt 0 ]
}

# Fusion locale d'abord ; sinon un seul fetch (un échec réseau n'empêche pas de lire les références distantes connues).
is_branch_merged() {
  local branch
  for branch in "${INTEGRATION_BRANCHES[@]}"; do is_ancestor_of "refs/heads/$branch" && return 0; done
  has_remote || return 1
  git -C "$LINKED" fetch --quiet "$REMOTE" > /dev/null 2>&1
  for branch in "${INTEGRATION_BRANCHES[@]}"; do is_ancestor_of "refs/remotes/$REMOTE/$branch" && return 0; done
  return 1
}

# ── Décision ──────────────────────────────────────────────────────────────────

main() {
  local state
  parse_arguments "$@"
  locate_worktrees || report "$STATUS_KEPT" "$REASON_GIT_ERROR"
  [ -n "$WORKTREE" ] || report "$STATUS_ABSENT"
  is_main_working_tree && report "$STATUS_KEPT" "$REASON_MAIN_WORKING_TREE"
  working_tree_state; state=$?
  [ $state -eq 2 ] && report "$STATUS_KEPT" "$REASON_GIT_ERROR"
  [ $state -eq 1 ] && report "$STATUS_KEPT" "$REASON_UNCOMMITTED"
  collect_integration_branches || report "$STATUS_KEPT" "$REASON_GIT_ERROR"
  is_branch_merged || report "$STATUS_KEPT" "$REASON_NOT_MERGED"
  git -C "$LINKED" worktree remove "$WORKTREE" > /dev/null 2>&1 || report "$STATUS_KEPT" "$REASON_GIT_ERROR"
  report "$STATUS_REMOVED"
}

main "$@"
