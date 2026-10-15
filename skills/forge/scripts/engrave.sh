#!/bin/bash
# Séquence git de la livraison forge (grave / engrave).
#   preview → décrit la séquence en JSON sur une ligne, n'écrit rien
#   run     → exécute la séquence, s'arrête au premier échec git, rend compte de chaque opération en JSON sur une ligne
# Usage : engrave.sh <preview|run> --branch <BRANCH> --message <msg> [--root <dir>] [target...]
# Sortie : 0 succès · 1 usage ou garde · 2 échec git (conflit, push rejeté) — le JSON de run est écrit dans les deux cas

set -u

readonly EXIT_USAGE=1
readonly EXIT_GIT=2
readonly MAX_MESSAGE_LENGTH=150
readonly REASON_NOTHING_TO_COMMIT="nothing to commit"
readonly REASON_BRANCH_MISSING="branch missing"
readonly REASON_CHECKED_OUT_ELSEWHERE="checked out in another worktree"
readonly REASON_CONFLICT="conflict"
readonly REASON_REJECTED="rejected"
readonly REASON_GIT_ERROR="git error"
readonly STATUS_PLANNED="planned"
readonly STATUS_SKIPPED="skipped"
readonly STATUS_DONE="done"
readonly STATUS_FAILED="failed"
readonly STATUS_NOT_RUN="not_run"

MODE=""
BRANCH=""
MESSAGE=""
ROOT="."
TARGETS=()

# Une action = une opération git sur une branche ; les tableaux sont indexés par action.
ACTION_KINDS=()
ACTION_BRANCHES=()
ACTION_STATUSES=()
ACTION_DETAILS=()
ACTION_REASONS=()
SEQUENCE_STATUS=$STATUS_PLANNED

# Résultat de la dernière opération exécutée, lu par run_action.
RESULT_DETAIL=""
RESULT_REASON=""

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
  if ! branch_exists "$1"; then echo "$REASON_BRANCH_MISSING"; return; fi
  if is_checked_out_elsewhere "$1"; then echo "$REASON_CHECKED_OUT_ELSEWHERE"; return; fi
  echo ""
}

# ── Séquence — une seule liste, rendue par preview, exécutée par run ──────────

# add_action <kind> <branch> <planned detail> <skip reason>
add_action() {
  local status=$STATUS_PLANNED
  [ -n "$4" ] && status=$STATUS_SKIPPED
  ACTION_KINDS+=("$1")
  ACTION_BRANCHES+=("$2")
  ACTION_DETAILS+=("$3")
  ACTION_REASONS+=("$4")
  ACTION_STATUSES+=("$status")
}

# Cible ignorée → une seule ligne merge ; sinon checkout, merge, push de la cible.
add_target_actions() {
  local reason
  reason=$(target_skip_reason "$1")
  if [ -n "$reason" ]; then
    add_action merge "$1" "" "$reason"
    return
  fi
  add_action checkout "$1" "" ""
  add_action merge "$1" "" ""
  add_action push "$1" "$(push_remote "$1")" ""
}

build_actions() {
  local commit_skip=""
  is_tree_clean && commit_skip=$REASON_NOTHING_TO_COMMIT
  add_action add "$BRANCH" "" "$commit_skip"
  add_action commit "$BRANCH" "$MESSAGE" "$commit_skip"
  add_action push "$BRANCH" "$(push_remote "$BRANCH")" ""
  local target has_target=""
  for target in ${TARGETS[@]+"${TARGETS[@]}"}; do
    [ "$target" = "$BRANCH" ] && continue
    add_target_actions "$target"
    has_target=1
  done
  [ -n "$has_target" ] && add_action checkout "$BRANCH" "" ""
}

# ── Opérations git — stdout de git renvoyé sur stderr : stdout porte le JSON seul ──

run_add() {
  git_in_root add -A >&2
}

run_commit() {
  git_in_root commit -q -m "$MESSAGE" >&2 || return 1
  RESULT_DETAIL=$(git_in_root rev-parse --short HEAD)
}

run_checkout() {
  git_in_root checkout -q "$1" >&2
}

conflicted_files() {
  local file list="" separator=""
  while IFS= read -r file; do
    list+="$separator$file"
    separator=", "
  done < <(git_in_root diff --name-only --diff-filter=U)
  echo "$list"
}

merge_outcome() {
  local before=$1 after=$2
  if [ "$before" = "$after" ]; then echo "already up to date"; return; fi
  if [ "$after" = "$(git_in_root rev-parse "$BRANCH")" ]; then echo "fast-forward"; return; fi
  echo "merge commit $(git_in_root rev-parse --short "$after")"
}

# Toujours <BRANCH> fusionnée dans la branche extraite, jamais la cible précédente de la chaîne.
run_merge() {
  local before
  before=$(git_in_root rev-parse HEAD)
  if ! git_in_root merge -q --no-edit "$BRANCH" >&2; then
    RESULT_DETAIL=$(conflicted_files)
    [ -n "$RESULT_DETAIL" ] && RESULT_REASON=$REASON_CONFLICT
    return 1
  fi
  RESULT_DETAIL=$(merge_outcome "$before" "$(git_in_root rev-parse HEAD)")
}

# Ligne --porcelain de la ref poussée : « <flag>\t<src>:<dst>\t<résumé> » → « <flag>\t<résumé> ».
push_ref_line() {
  printf '%s\n' "$1" | awk -F '\t' -v ref="refs/heads/$2:refs/heads/$2" '$2 == ref { print $1 "\t" $3 }'
}

run_push() {
  local remote report line summary
  remote=$(push_remote "$1")
  report=$(git_in_root push --porcelain -u "$remote" "$1")
  local status=$?
  line=$(push_ref_line "$report" "$1")
  summary=${line#*$'\t'}
  summary=${summary//[\[\]]/}
  RESULT_DETAIL="$remote: $summary"
  [ $status -eq 0 ] && return 0
  printf '%s\n' "$report" >&2
  [ "${line%%$'\t'*}" = "!" ] && RESULT_REASON=$REASON_REJECTED
  return 1
}

# ── Exécution ─────────────────────────────────────────────────────────────────

record_result() {
  ACTION_STATUSES[$1]=$2
  ACTION_DETAILS[$1]=$RESULT_DETAIL
  ACTION_REASONS[$1]=$3
}

run_action() {
  local i=$1
  RESULT_DETAIL=""
  RESULT_REASON=$REASON_GIT_ERROR
  if "run_${ACTION_KINDS[$i]}" "${ACTION_BRANCHES[$i]}"; then
    record_result "$i" "$STATUS_DONE" ""
    return 0
  fi
  record_result "$i" "$STATUS_FAILED" "$RESULT_REASON"
  echo "engrave: stopped at step $((i + 1)) (${ACTION_KINDS[$i]} ${ACTION_BRANCHES[$i]})" >&2
  return 1
}

mark_remaining_not_run() {
  local i
  for ((i = $1; i < ${#ACTION_KINDS[@]}; i++)); do
    [ "${ACTION_STATUSES[$i]}" = "$STATUS_SKIPPED" ] && continue
    ACTION_STATUSES[$i]=$STATUS_NOT_RUN
    ACTION_DETAILS[$i]=""
  done
}

run_actions() {
  local i
  SEQUENCE_STATUS=$STATUS_DONE
  for i in "${!ACTION_KINDS[@]}"; do
    [ "${ACTION_STATUSES[$i]}" = "$STATUS_SKIPPED" ] && continue
    run_action "$i" && continue
    SEQUENCE_STATUS=$STATUS_FAILED
    mark_remaining_not_run $((i + 1))
    break
  done
  render_json
  [ "$SEQUENCE_STATUS" = "$STATUS_DONE" ] || exit $EXIT_GIT
}

# ── Rendu — données seules, la mise en page revient au skill (p5-resume.md) ───

# Chaîne JSON sans jq (absent de Git Bash) : barre oblique inverse, guillemet et contrôles échappés.
json_string() {
  local text=${1//\\/\\\\}
  text=${text//\"/\\\"}
  text=${text//$'\n'/\\n}
  text=${text//$'\r'/\\r}
  text=${text//$'\t'/\\t}
  printf '"%s"' "$text"
}

json_nullable() {
  if [ -z "$1" ]; then printf null; else json_string "$1"; fi
}

render_json_action() {
  printf '{"step":%d,"action":%s,"branch":%s,"status":%s,"detail":%s,"reason":%s}' $(($1 + 1)) \
    "$(json_string "${ACTION_KINDS[$1]}")" "$(json_string "${ACTION_BRANCHES[$1]}")" \
    "$(json_string "${ACTION_STATUSES[$1]}")" "$(json_nullable "${ACTION_DETAILS[$1]}")" \
    "$(json_nullable "${ACTION_REASONS[$1]}")"
}

render_json() {
  local i separator="" actions=""
  for i in "${!ACTION_KINDS[@]}"; do
    actions+="$separator$(render_json_action "$i")"
    separator=","
  done
  printf '{"branch":%s,"status":%s,"actions":[%s]}\n' \
    "$(json_string "$BRANCH")" "$(json_string "$SEQUENCE_STATUS")" "$actions"
}

main() {
  parse_arguments "$@"
  validate_arguments
  build_actions
  case $MODE in
    preview) render_json ;;
    run)     run_actions ;;
  esac
}

main "$@"
