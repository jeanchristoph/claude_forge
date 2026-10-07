#!/bin/bash
# Tests de skills/forge/scripts/engrave.sh — chaque test tourne dans un bac à sable jetable :
# un remote bare et un clone, branches master / dev / ship, jamais le dépôt courant.
# Usage : bash tests/engrave.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENGRAVE_SCRIPT="$REPO_ROOT/skills/forge/scripts/engrave.sh"
PASSED=0
FAILED=0

# ── Bac à sable ───────────────────────────────────────────────────────────────

configure_identity() {
  git -C "$1" config user.email "forge@test.local"
  git -C "$1" config user.name "Forge Test"
  git -C "$1" config commit.gpgsign false
  git -C "$1" config core.autocrlf false
}

commit_file() {
  local work=$1 file=$2 content=$3
  printf '%s\n' "$content" > "$work/$file"
  git -C "$work" add "$file"
  git -C "$work" commit -q -m "edit $file"
}

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  REMOTE="$SANDBOX/remote.git"
  WORK="$SANDBOX/work"
  git init -q --bare "$REMOTE"
  git init -q "$WORK"
  configure_identity "$WORK"
  git -C "$WORK" symbolic-ref HEAD refs/heads/master
  git -C "$WORK" remote add origin "$REMOTE"
  commit_file "$WORK" readme.txt "initial"
  git -C "$WORK" push -q -u origin master 2>/dev/null
  local branch
  for branch in dev ship; do
    git -C "$WORK" checkout -q -b "$branch" master
    git -C "$WORK" push -q -u origin "$branch" 2>/dev/null
  done
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

engrave() {
  bash "$ENGRAVE_SCRIPT" "$@"
}

remote_head() {
  git -C "$REMOTE" rev-parse "refs/heads/$1"
}

# ── Assertions — chaque test tourne dans un sous-shell, un échec en sort ──────

assert_equals() {
  [ "$1" = "$2" ] && return 0
  printf '    expected: %s\n    actual:   %s\n' "$1" "$2"
  exit 1
}

assert_contains() {
  case $2 in *"$1"*) return 0 ;; esac
  printf '    missing:  %s\n    in:\n%s\n' "$1" "$2"
  exit 1
}

assert_not_contains() {
  case $2 in *"$1"*) printf '    unexpected: %s\n    in:\n%s\n' "$1" "$2"; exit 1 ;; esac
  return 0
}

# ── Aperçu ────────────────────────────────────────────────────────────────────

test_preview_without_target() {
  printf 'change\n' >> "$WORK/readme.txt"
  local output
  output=$(engrave preview --root "$WORK" --branch ship --message "Livre la branche")
  assert_equals '{"branch":"ship","actions":[{"step":1,"action":"add","detail":"ship","skip":null},{"step":2,"action":"commit","detail":"Livre la branche","skip":null},{"step":3,"action":"push","detail":"origin · ship","skip":null}]}' "$output"
}

test_preview_with_one_target() {
  printf 'change\n' >> "$WORK/readme.txt"
  local output
  output=$(engrave preview --root "$WORK" --branch ship --message "m" master)
  assert_contains '{"step":4,"action":"merge","detail":"ship → master","skip":null},{"step":5,"action":"checkout","detail":"ship","skip":null}]}' "$output"
}

test_preview_with_three_targets() {
  git -C "$WORK" branch release master
  printf 'change\n' >> "$WORK/readme.txt"
  local output
  output=$(engrave preview --root "$WORK" --branch ship --message "m" dev master release)
  assert_contains '{"step":4,"action":"merge","detail":"ship → dev","skip":null},{"step":5,"action":"merge","detail":"ship → master","skip":null},{"step":6,"action":"merge","detail":"ship → release","skip":null},{"step":7,"action":"checkout","detail":"ship","skip":null}]}' "$output"
}

test_preview_ignores_starting_branch() {
  printf 'change\n' >> "$WORK/readme.txt"
  local output
  output=$(engrave preview --root "$WORK" --branch ship --message "m" ship dev)
  assert_not_contains "ship → ship" "$output"
  assert_contains '{"step":4,"action":"merge","detail":"ship → dev","skip":null}' "$output"
}

test_preview_skips_missing_branch() {
  printf 'change\n' >> "$WORK/readme.txt"
  local output
  output=$(engrave preview --root "$WORK" --branch ship --message "m" ghost)
  assert_contains '{"step":4,"action":"merge","detail":"ship → ghost","skip":"branch missing"}' "$output"
}

test_preview_skips_branch_checked_out_elsewhere() {
  git -C "$WORK" worktree add -q "$SANDBOX/dev-worktree" dev
  printf 'change\n' >> "$WORK/readme.txt"
  local output
  output=$(engrave preview --root "$WORK" --branch ship --message "m" dev)
  assert_contains '{"step":4,"action":"merge","detail":"ship → dev","skip":"checked out in another worktree"}' "$output"
}

test_preview_skips_commit_when_tree_is_clean() {
  local output
  output=$(engrave preview --root "$WORK" --branch ship --message "m")
  assert_contains '{"step":1,"action":"add","detail":"ship","skip":"nothing to commit"}' "$output"
  assert_contains '{"step":2,"action":"commit","detail":"m","skip":"nothing to commit"}' "$output"
  assert_contains '{"step":3,"action":"push","detail":"origin · ship","skip":null}' "$output"
}

test_preview_escapes_json_special_characters_in_message() {
  printf 'change\n' >> "$WORK/readme.txt"
  local output
  output=$(engrave preview --root "$WORK" --branch ship --message $'dit "oui" \\ a\tb')
  assert_equals '{"step":2,"action":"commit","detail":"dit \"oui\" \\ a\tb","skip":null}' "$(printf '%s' "$output" | grep -o '{"step":2[^}]*}')"
}

test_preview_keeps_pipe_unescaped_in_message() {
  printf 'change\n' >> "$WORK/readme.txt"
  local output
  output=$(engrave preview --root "$WORK" --branch ship --message "a | b")
  assert_contains '"detail":"a | b"' "$output"
}

test_preview_writes_nothing() {
  printf 'change\n' >> "$WORK/readme.txt"
  local status_before head_before
  status_before=$(git -C "$WORK" status --porcelain)
  head_before=$(git -C "$WORK" rev-parse HEAD)
  engrave preview --root "$WORK" --branch ship --message "m" dev master > /dev/null
  assert_equals "$status_before" "$(git -C "$WORK" status --porcelain)"
  assert_equals "$head_before" "$(git -C "$WORK" rev-parse HEAD)"
  assert_equals "ship" "$(git -C "$WORK" branch --show-current)"
}

# ── Exécution ─────────────────────────────────────────────────────────────────

test_run_ships_and_merges_every_target() {
  printf 'feature\n' > "$WORK/feature.txt"
  local output
  output=$(engrave run --root "$WORK" --branch ship --message "Ajoute la feature" dev master)
  assert_equals 0 $?
  local shipped
  shipped=$(git -C "$WORK" rev-parse ship)
  assert_equals "Ajoute la feature" "$(git -C "$WORK" log -1 --format=%s ship)"
  assert_equals "$shipped" "$(remote_head ship)"
  git -C "$REMOTE" merge-base --is-ancestor "$shipped" "$(remote_head dev)" || exit 1
  git -C "$REMOTE" merge-base --is-ancestor "$shipped" "$(remote_head master)" || exit 1
  assert_equals "ship" "$(git -C "$WORK" branch --show-current)"
  assert_contains "commit $(git -C "$WORK" rev-parse --short ship)" "$output"
  assert_contains "updated: ship, dev, master" "$output"
}

test_run_merges_starting_branch_never_previous_target() {
  git -C "$WORK" checkout -q dev
  commit_file "$WORK" dev-only.txt "dev"
  git -C "$WORK" checkout -q ship
  printf 'feature\n' > "$WORK/feature.txt"
  engrave run --root "$WORK" --branch ship --message "m" dev master > /dev/null
  git -C "$WORK" cat-file -e master:dev-only.txt 2>/dev/null && exit 1
  return 0
}

test_run_without_target_stays_on_starting_branch() {
  printf 'feature\n' > "$WORK/feature.txt"
  engrave run --root "$WORK" --branch ship --message "m" > /dev/null
  assert_equals 0 $?
  assert_equals "$(git -C "$WORK" rev-parse ship)" "$(remote_head ship)"
  assert_equals "ship" "$(git -C "$WORK" branch --show-current)"
}

test_run_with_clean_tree_only_pushes_and_merges() {
  commit_file "$WORK" local.txt "already committed"
  local output
  output=$(engrave run --root "$WORK" --branch ship --message "m" dev)
  assert_equals 0 $?
  assert_equals "edit local.txt" "$(git -C "$WORK" log -1 --format=%s ship)"
  assert_equals "$(git -C "$WORK" rev-parse ship)" "$(remote_head ship)"
  assert_contains "commit none — nothing to commit" "$output"
}

test_run_never_creates_missing_branch() {
  printf 'feature\n' > "$WORK/feature.txt"
  engrave run --root "$WORK" --branch ship --message "m" ghost dev > /dev/null
  assert_equals 0 $?
  git -C "$WORK" show-ref --verify --quiet refs/heads/ghost && exit 1
  git -C "$REMOTE" merge-base --is-ancestor "$(git -C "$WORK" rev-parse ship)" "$(remote_head dev)" || exit 1
}

test_run_reports_every_skipped_branch_with_its_reason() {
  git -C "$WORK" worktree add -q "$SANDBOX/dev-worktree" dev
  printf 'feature\n' > "$WORK/feature.txt"
  local output
  output=$(engrave run --root "$WORK" --branch ship --message "m" ghost dev master)
  assert_equals 0 $?
  assert_contains "updated: ship, master" "$output"
  assert_contains "skipped: ghost (branch missing), dev (checked out in another worktree)" "$output"
}

test_run_without_skip_prints_no_skipped_line() {
  printf 'feature\n' > "$WORK/feature.txt"
  local output
  output=$(engrave run --root "$WORK" --branch ship --message "m" dev)
  assert_not_contains "skipped:" "$output"
}

test_run_stops_at_first_merge_conflict() {
  git -C "$WORK" checkout -q dev
  commit_file "$WORK" readme.txt "dev side"
  git -C "$WORK" checkout -q ship
  printf 'ship side\n' > "$WORK/readme.txt"
  local master_before
  master_before=$(remote_head master)
  engrave run --root "$WORK" --branch ship --message "m" dev master > /dev/null 2>&1
  assert_equals 2 $?
  assert_equals "$master_before" "$(remote_head master)"
  assert_equals "dev" "$(git -C "$WORK" branch --show-current)"
}

test_run_stops_on_rejected_push() {
  local other="$SANDBOX/other"
  git clone -q "$REMOTE" "$other" 2>/dev/null
  configure_identity "$other"
  git -C "$other" checkout -q ship
  commit_file "$other" remote-only.txt "ahead"
  git -C "$other" push -q origin ship 2>/dev/null
  printf 'feature\n' > "$WORK/feature.txt"
  local dev_before errors
  dev_before=$(remote_head dev)
  errors=$(engrave run --root "$WORK" --branch ship --message "m" dev 2>&1 > /dev/null)
  assert_equals 2 $?
  assert_contains "rejected" "$errors"
  assert_contains "engrave: stopped at step 3" "$errors"
  assert_equals "$dev_before" "$(remote_head dev)"
}

test_run_from_another_directory_with_root() {
  printf 'feature\n' > "$WORK/feature.txt"
  (cd "$SANDBOX" && engrave run --root "$WORK" --branch ship --message "m" > /dev/null)
  assert_equals 0 $?
  assert_equals "$(git -C "$WORK" rev-parse ship)" "$(remote_head ship)"
}

# ── Gardes ────────────────────────────────────────────────────────────────────

test_rejects_message_longer_than_150_characters() {
  local message
  message=$(printf 'a%.0s' $(seq 1 151))
  engrave preview --root "$WORK" --branch ship --message "$message" > /dev/null 2>&1
  assert_equals 1 $?
}

test_accepts_150_accented_characters() {
  local message
  message=$(printf 'é%.0s' $(seq 1 150))
  engrave preview --root "$WORK" --branch ship --message "$message" > /dev/null 2>&1
  assert_equals 0 $?
}

test_rejects_empty_message() {
  engrave preview --root "$WORK" --branch ship --message "" > /dev/null 2>&1
  assert_equals 1 $?
}

test_rejects_wrong_current_branch() {
  local errors
  errors=$(engrave run --root "$WORK" --branch dev --message "m" 2>&1)
  assert_equals 1 $?
  assert_contains "current branch is 'ship', expected 'dev'" "$errors"
}

test_rejects_unknown_mode() {
  engrave deploy --root "$WORK" --branch ship --message "m" > /dev/null 2>&1
  assert_equals 1 $?
}

test_rejects_root_outside_git_repository() {
  engrave preview --root "$SANDBOX" --branch ship --message "m" > /dev/null 2>&1
  assert_equals 1 $?
}

# ── Lanceur ───────────────────────────────────────────────────────────────────

run_test() {
  local name=$1 label=$2
  setup_sandbox
  ( "$name" )
  local status=$?
  teardown_sandbox
  if [ $status -eq 0 ]; then
    PASSED=$((PASSED + 1)); echo "ok   $label"
  else
    FAILED=$((FAILED + 1)); echo "FAIL $label"
  fi
}

run_test test_preview_without_target "aperçu sans branche citée : add, commit, push, sans retour final"
run_test test_preview_with_one_target "aperçu avec une branche : une ligne merge puis le retour sur la branche de départ"
run_test test_preview_with_three_targets "aperçu avec trois branches : une ligne merge par branche, dans l'ordre cité"
run_test test_preview_ignores_starting_branch "ignore la branche citée égale à la branche de départ"
run_test test_preview_skips_missing_branch "marque une branche absente comme ignorée"
run_test test_preview_skips_branch_checked_out_elsewhere "marque une branche extraite dans un autre worktree comme ignorée"
run_test test_preview_skips_commit_when_tree_is_clean "marque add et commit ignorés quand rien n'est à commiter"
run_test test_preview_escapes_json_special_characters_in_message "échappe guillemet, barre oblique inverse et tabulation du message dans le JSON"
run_test test_preview_keeps_pipe_unescaped_in_message "garde la barre verticale du message telle quelle dans le JSON"
run_test test_preview_writes_nothing "l'aperçu ne modifie ni le working tree, ni HEAD, ni la branche courante"
run_test test_run_ships_and_merges_every_target "livre la branche et la fusionne dans chaque branche citée, poussées sur le remote"
run_test test_run_merges_starting_branch_never_previous_target "fusionne toujours la branche de départ, jamais la branche précédente de la chaîne"
run_test test_run_without_target_stays_on_starting_branch "sans branche citée, pousse et reste sur la branche de départ"
run_test test_run_with_clean_tree_only_pushes_and_merges "working tree propre : aucun commit, push et merges exécutés"
run_test test_run_never_creates_missing_branch "ne crée jamais une branche citée absente et livre les suivantes"
run_test test_run_reports_every_skipped_branch_with_its_reason "le compte rendu liste chaque branche ignorée avec sa raison"
run_test test_run_without_skip_prints_no_skipped_line "sans branche ignorée, le compte rendu n'a pas de ligne skipped"
run_test test_run_stops_at_first_merge_conflict "s'arrête au premier conflit de merge sans toucher les branches suivantes"
run_test test_run_stops_on_rejected_push "s'arrête sur un push rejeté et affiche l'erreur git"
run_test test_run_from_another_directory_with_root "livre un dépôt situé ailleurs grâce à --root"
run_test test_rejects_message_longer_than_150_characters "refuse un message de plus de 150 caractères"
run_test test_accepts_150_accented_characters "accepte un message de 150 caractères accentués"
run_test test_rejects_empty_message "refuse un message vide"
run_test test_rejects_wrong_current_branch "refuse de livrer si la branche courante n'est pas celle annoncée"
run_test test_rejects_unknown_mode "refuse un mode inconnu"
run_test test_rejects_root_outside_git_repository "refuse une racine hors dépôt git"

echo "$PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ]
