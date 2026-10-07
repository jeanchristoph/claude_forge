#!/bin/bash
# Séquence git de la livraison forge (grave / engrave / ship).
#   preview → affiche le tableau récapitulatif, n'écrit rien
#   run     → exécute la séquence, s'arrête au premier échec git
# Usage : engrave.sh <preview|run> --branch <BRANCH> --message <msg> [--root <dir>] [target...]
# Sortie : 0 succès · 1 usage ou garde · 2 échec git (conflit, push rejeté)

set -u

readonly EXIT_USAGE=1
readonly EXIT_GIT=2
readonly MAX_MESSAGE_LENGTH=150
readonly SKIP_NOTHING_TO_COMMIT="skipped — nothing to commit"
readonly SKIP_BRANCH_MISSING="skipped — branch missing"
readonly SKIP_CHECKED_OUT_ELSEWHERE="skipped — checked out in another worktree"

MODE=""
BRANCH=""
MESSAGE=""
ROOT="."
TARGETS=()

ACTION_KINDS=()
ACTION_DETAILS=()
ACTION_TARGETS=()
ACTION_SKIPS=()

# ── Arguments et gardes ───────────────────────────────────────────────────────

fail_usage() {
  echo "engrave: $1" >&2
  echo "usage: engrave.sh <preview|run> --branch <BRANCH> --message <msg> [--root <dir>] [target...]" >&2
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
      --branch)  require_value "$1" $#; BRANCH=$2; shift 2 ;;
      --message) require_value "$1" $#; MESSAGE=$2; shift 2 ;;
      --root)    require_value "$1" $#; ROOT=$2; shift 2 ;;
      -*)        fail_usage "unknown option $1" ;;
      *)         TARGETS+=("$1"); shift ;;
    esac
  done
}

git_in_root() {
  git -C "$ROOT" "$@"
}

# Longueur en caractères, jamais en octets : un accent compte pour un.
message_length() {
  local LC_ALL=C.UTF-8
  echo ${#MESSAGE}
}

validate_arguments() {
  case $MODE in
    preview|run) ;;
    *) fail_usage "unknown mode '$MODE'" ;;
  esac
  [ -n "$BRANCH" ] || fail_usage "--branch is required"
  [ -n "$MESSAGE" ] || fail_usage "--message is required"
  [ "$(message_length)" -le $MAX_MESSAGE_LENGTH ] || fail_usage "message longer than $MAX_MESSAGE_LENGTH characters"
  git_in_root rev-parse --git-dir > /dev/null 2>&1 || fail_usage "not a git repository: $ROOT"
  local current
  current=$(git_in_root branch --show-current)
  [ "$current" = "$BRANCH" ] || fail_usage "current branch is '$current', expected '$BRANCH'"
}

# ── État du dépôt ─────────────────────────────────────────────────────────────

is_tree_clean() {
  [ -z "$(git_in_root status --porcelain)" ]
}

branch_exists() {
  git_in_root show-ref --verify --quiet "refs/heads/$1"
}

is_checked_out_elsewhere() {
  local self
  self=$(git_in_root rev-parse --show-toplevel)
  git_in_root worktree list --porcelain | awk -v ref="branch refs/heads/$1" -v self="$self" '
    /^worktree / { path = substr($0, 10) }
    $0 == ref && path != self { found = 1 }
    END { exit !found }'
}

push_remote() {
  git_in_root config --get "branch.$1.remote" || echo origin
}

target_skip_reason() {
  if ! branch_exists "$1"; then echo "$SKIP_BRANCH_MISSING"; return; fi
  if is_checked_out_elsewhere "$1"; then echo "$SKIP_CHECKED_OUT_ELSEWHERE"; return; fi
  echo ""
}

# ── Séquence — une seule liste, rendue par preview, exécutée par run ──────────

add_action() {
  ACTION_KINDS+=("$1")
  ACTION_DETAILS+=("$2")
  ACTION_TARGETS+=("$3")
  ACTION_SKIPS+=("$4")
}

build_actions() {
  local commit_skip=""
  is_tree_clean && commit_skip=$SKIP_NOTHING_TO_COMMIT
  add_action add "$BRANCH" "" "$commit_skip"
  add_action commit "\"$MESSAGE\"" "" "$commit_skip"
  add_action push "$(push_remote "$BRANCH") · $BRANCH" "" ""
  local target has_target=""
  for target in ${TARGETS[@]+"${TARGETS[@]}"}; do
    [ "$target" = "$BRANCH" ] && continue
    add_action merge "$BRANCH → $target" "$target" "$(target_skip_reason "$target")"
    has_target=1
  done
  [ -n "$has_target" ] && add_action checkout "$BRANCH" "" ""
}

escape_cell() {
  printf '%s' "${1//|/\\|}"
}

render_table() {
  echo "| # | Action | Detail |"
  echo "|---|---|---|"
  local i detail
  for i in "${!ACTION_KINDS[@]}"; do
    detail=$(escape_cell "${ACTION_DETAILS[$i]}")
    [ -n "${ACTION_SKIPS[$i]}" ] && detail="$detail — ${ACTION_SKIPS[$i]}"
    echo "| $((i + 1)) | \`${ACTION_KINDS[$i]}\` | $detail |"
  done
}

push_branch() {
  git_in_root push -q -u "$(push_remote "$1")" "$1"
}

merge_into() {
  git_in_root checkout -q "$1" && git_in_root merge -q --no-edit "$BRANCH" && push_branch "$1"
}

run_action() {
  case $1 in
    add)      git_in_root add -A ;;
    commit)   git_in_root commit -q -m "$MESSAGE" ;;
    push)     push_branch "$BRANCH" ;;
    merge)    merge_into "$2" ;;
    checkout) git_in_root checkout -q "$BRANCH" ;;
  esac
}

render_report() {
  local commit_line="commit none — nothing to commit"
  [ -z "${ACTION_SKIPS[1]}" ] && commit_line="commit $(git_in_root rev-parse --short "$BRANCH")"
  echo "$commit_line"
  local updated=$BRANCH skipped="" i
  for i in "${!ACTION_KINDS[@]}"; do
    [ "${ACTION_KINDS[$i]}" = merge ] || continue
    if [ -z "${ACTION_SKIPS[$i]}" ]; then
      updated="$updated, ${ACTION_TARGETS[$i]}"
    else
      skipped="$skipped, ${ACTION_TARGETS[$i]} (${ACTION_SKIPS[$i]#skipped — })"
    fi
  done
  echo "updated: $updated"
  [ -n "$skipped" ] && echo "skipped: ${skipped#, }"
  return 0
}

run_actions() {
  local i
  for i in "${!ACTION_KINDS[@]}"; do
    [ -n "${ACTION_SKIPS[$i]}" ] && continue
    if ! run_action "${ACTION_KINDS[$i]}" "${ACTION_TARGETS[$i]}"; then
      echo "engrave: stopped at step $((i + 1)) (${ACTION_KINDS[$i]} ${ACTION_DETAILS[$i]})" >&2
      exit $EXIT_GIT
    fi
  done
  render_report
}

main() {
  parse_arguments "$@"
  validate_arguments
  build_actions
  case $MODE in
    preview) render_table ;;
    run)     run_actions ;;
  esac
}

main "$@"
