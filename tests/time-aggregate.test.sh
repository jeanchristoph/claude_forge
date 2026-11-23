#!/bin/bash
# Tests de skills/forge/scripts/time-aggregate.sh — chaque test tourne dans un dépôt jetable,
# jamais le dépôt courant. Journaux écrits à la main, horodatages en millisecondes choisis.
# Usage : bash tests/time-aggregate.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AGGREGATE_SCRIPT="$REPO_ROOT/skills/forge/scripts/time-aggregate.sh"
MARK_SCRIPT="$REPO_ROOT/skills/forge/scripts/time-mark.sh"
PASSED=0
FAILED=0

# ── Bac à sable ───────────────────────────────────────────────────────────────

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  WORK="$SANDBOX/work"
  git init -q "$WORK"
  git -C "$WORK" config user.name "Forge Test"
  git -C "$WORK" config user.email "forge@test.local"
  git -C "$WORK" config commit.gpgsign false
  git -C "$WORK" config core.autocrlf false
  git -C "$WORK" symbolic-ref HEAD refs/heads/master
  printf 'initial\n' > "$WORK/readme.txt"
  git -C "$WORK" add readme.txt
  git -C "$WORK" commit -q -m "initial"
  git -C "$WORK" checkout -q -b feature
  mkdir -p "$WORK/.forge/branch/feature"
  OWN_LOG="$WORK/.forge/branch/feature/time-log.jsonl"
  PARENT_LOG="$SANDBOX/parent-time-log.jsonl"
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

aggregate() {
  bash "$AGGREGATE_SCRIPT" --root "$WORK" --branch feature "$@"
}

own_events() {
  printf '%s\n' "$@" >> "$OWN_LOG"
}

parent_events() {
  printf '%s\n' "$@" >> "$PARENT_LOG"
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

# ── Session principale ────────────────────────────────────────────────────────

test_measures_one_turn_of_main_session() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":60000,"event":"Stop","session":"s"}'
  local output
  output=$(aggregate)
  assert_contains '"parent_minutes":1.0' "$output"
  assert_contains '"mode":"parent"' "$output"
}

test_removes_question_wait_from_turn_and_counts_it_as_human() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":10000,"event":"PreToolUse","session":"s","tool":"AskUserQuestion"}' \
             '{"ts":70000,"event":"PostToolUse","session":"s","tool":"AskUserQuestion","duration_ms":60000}' \
             '{"ts":130000,"event":"Stop","session":"s"}'
  local output
  output=$(aggregate)
  assert_contains '"parent_minutes":1.2' "$output"
  assert_contains '"questions":1' "$output"
  assert_contains '"question_minutes":1.0' "$output"
  assert_contains '"human_minutes":1.0' "$output"
}

test_counts_gap_before_human_prompt_as_human_time() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":60000,"event":"Stop","session":"s"}' \
             '{"ts":180000,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":240000,"event":"Stop","session":"s"}'
  local output
  output=$(aggregate)
  assert_contains '"parent_minutes":2.0' "$output"
  assert_contains '"human_minutes":2.0' "$output"
}

test_does_not_count_wait_for_delegate_as_human_time() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":60000,"event":"Stop","session":"s"}' \
             '{"ts":600000,"event":"UserPromptSubmit","session":"s","origin":"agent"}' \
             '{"ts":660000,"event":"Stop","session":"s"}'
  local output
  output=$(aggregate)
  assert_contains '"parent_minutes":2.0' "$output"
  assert_contains '"human_minutes":0.0' "$output"
}

test_does_not_count_absence_over_six_hours_as_human_time() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":60000,"event":"Stop","session":"s"}'              '{"ts":21660001,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":21720001,"event":"Stop","session":"s"}'
  local output
  output=$(aggregate)
  assert_contains '"parent_minutes":2.0' "$output"
  assert_contains '"human_minutes":0.0' "$output"
}

test_counts_gap_of_exactly_six_hours_as_human_time() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":60000,"event":"Stop","session":"s"}'              '{"ts":21660000,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":21720000,"event":"Stop","session":"s"}'
  assert_contains '"human_minutes":360.0' "$(aggregate)"
}

test_does_not_count_question_left_over_six_hours_as_human_time() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":10000,"event":"PreToolUse","session":"s","tool":"AskUserQuestion"}'              '{"ts":21610001,"event":"PostToolUse","session":"s","tool":"AskUserQuestion"}'              '{"ts":21670001,"event":"Stop","session":"s"}'
  local output
  output=$(aggregate)
  assert_contains '"parent_minutes":1.2' "$output"
  assert_contains '"questions":1' "$output"
  assert_contains '"question_minutes":0.0' "$output"
  assert_contains '"human_minutes":0.0' "$output"
}

test_ignores_turn_without_stop() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":60000,"event":"Stop","session":"s"}' \
             '{"ts":120000,"event":"UserPromptSubmit","session":"s","origin":"human"}'
  assert_contains '"parent_minutes":1.0' "$(aggregate)"
}

# Message tapé pendant le travail : le prompt arrive avant le Stop du tour en cours, qui n'en reçoit jamais.
test_closes_turn_interrupted_by_queued_prompt_at_last_activity() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":10000,"event":"PreToolUse","session":"s","tool":"Bash"}'              '{"ts":60000,"event":"PostToolUse","session":"s","tool":"Bash","duration_ms":50000}'              '{"ts":90000,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":150000,"event":"Stop","session":"s"}'
  assert_contains '"parent_minutes":2.0' "$(aggregate)"
}

# Échap : Claude Code n'envoie pas de Stop, le tour suivant s'ouvre après une pause humaine non mesurable.
test_closes_turn_interrupted_by_escape_without_counting_the_pause() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":30000,"event":"PostToolUse","session":"s","tool":"Bash","duration_ms":30000}'              '{"ts":600000,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":660000,"event":"Stop","session":"s"}'
  assert_contains '"parent_minutes":1.5' "$(aggregate)"
}

test_closes_turn_interrupted_by_task_notification() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":120000,"event":"PostToolUse","session":"s","tool":"Bash","duration_ms":1000}'              '{"ts":120000,"event":"UserPromptSubmit","session":"s","origin":"agent"}'              '{"ts":180000,"event":"Stop","session":"s"}'
  assert_contains '"parent_minutes":3.0' "$(aggregate)"
}

test_keeps_interleaved_sessions_apart() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"a","origin":"human"}' \
             '{"ts":30000,"event":"UserPromptSubmit","session":"b","origin":"human"}' \
             '{"ts":60000,"event":"Stop","session":"a"}' \
             '{"ts":150000,"event":"Stop","session":"b"}'
  assert_contains '"parent_minutes":3.0' "$(aggregate)"
}

test_sums_check_durations_of_main_session() {
  own_events '{"ts":0,"event":"PostToolUse","session":"s","tool":"Bash","duration_ms":90000,"check":true}' \
             '{"ts":1000,"event":"PostToolUse","session":"s","tool":"Bash","duration_ms":50000}'
  assert_contains '"check_minutes":1.5' "$(aggregate)"
}

test_ignores_events_of_agent_delegated_to_another_branch() {
  own_events '{"event":"delegate","agent_id":"x1","branch":"feature-child"}' \
             '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":10000,"event":"SubagentStart","session":"s","agent_id":"x1"}' \
             '{"ts":20000,"event":"PostToolUse","session":"s","agent_id":"x1","tool":"Bash","duration_ms":600000,"check":true}' \
             '{"ts":50000,"event":"SubagentStop","session":"s","agent_id":"x1"}' \
             '{"ts":60000,"event":"Stop","session":"s"}'
  local output
  output=$(aggregate)
  assert_contains '"parent_minutes":1.0' "$output"
  assert_contains '"check_minutes":0.0' "$output"
  assert_contains '"delegated_minutes":0.0' "$output"
  assert_contains '"delegates":0' "$output"
}

test_counts_ordinary_subagent_of_own_log() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":10000,"event":"SubagentStart","session":"s","agent_id":"x1"}' \
             '{"ts":20000,"event":"PostToolUse","session":"s","agent_id":"x1","tool":"Bash","duration_ms":30000,"check":true}' \
             '{"ts":60000,"event":"Stop","session":"s"}' \
             '{"ts":190000,"event":"SubagentStop","session":"s","agent_id":"x1"}'
  local output
  output=$(aggregate)
  assert_contains '"parent_minutes":1.0' "$output"
  assert_contains '"delegated_minutes":3.0' "$output"
  assert_contains '"check_minutes":0.5' "$output"
  assert_contains '"delegates":1' "$output"
  assert_contains '"mode":"mixed"' "$output"
}

test_sums_parallel_ordinary_subagents() {
  own_events '{"ts":0,"event":"SubagentStart","session":"s","agent_id":"x1"}' \
             '{"ts":0,"event":"SubagentStart","session":"s","agent_id":"x2"}' \
             '{"ts":60000,"event":"SubagentStop","session":"s","agent_id":"x1"}' \
             '{"ts":120000,"event":"SubagentStop","session":"s","agent_id":"x2"}'
  local output
  output=$(aggregate)
  assert_contains '"delegated_minutes":3.0' "$output"
  assert_contains '"delegates":2' "$output"
}

test_ignores_ordinary_subagent_still_running() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":10000,"event":"SubagentStart","session":"s","agent_id":"x1"}' \
             '{"ts":60000,"event":"Stop","session":"s"}'
  local output
  output=$(aggregate)
  assert_contains '"delegated_minutes":0.0' "$output"
  assert_contains '"delegates":0' "$output"
}

# ── Délégués ──────────────────────────────────────────────────────────────────

test_sums_runs_of_delegates_mapped_to_branch() {
  parent_events '{"ts":0,"event":"delegate","agent_id":"a1","branch":"feature"}' \
                '{"ts":0,"event":"SubagentStart","session":"p","agent_id":"a1"}' \
                '{"ts":120000,"event":"SubagentStop","session":"p","agent_id":"a1"}' \
                '{"ts":300000,"event":"SubagentStart","session":"p","agent_id":"a1"}' \
                '{"ts":360000,"event":"SubagentStop","session":"p","agent_id":"a1"}'
  local output
  output=$(aggregate --parent-log "$PARENT_LOG")
  assert_contains '"delegated_minutes":3.0' "$output"
  assert_contains '"delegates":1' "$output"
  assert_contains '"mode":"delegated"' "$output"
}

test_counts_delegate_mapped_after_its_start() {
  parent_events '{"ts":60000,"event":"SubagentStart","session":"p","agent_id":"a1"}'                 '{"event":"delegate","agent_id":"a1","branch":"feature"}'                 '{"ts":180000,"event":"SubagentStop","session":"p","agent_id":"a1"}'
  assert_contains '"delegated_minutes":2.0' "$(aggregate --parent-log "$PARENT_LOG")"
}

test_measures_events_written_out_of_order() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":120000,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":60000,"event":"Stop","session":"s"}'              '{"ts":180000,"event":"Stop","session":"s"}'
  local output
  output=$(aggregate)
  assert_contains '"parent_minutes":2.0' "$output"
  assert_contains '"human_minutes":1.0' "$output"
}

test_adds_relaunched_delegate_after_interruption() {
  parent_events '{"ts":0,"event":"delegate","agent_id":"a1","branch":"feature"}' \
                '{"ts":0,"event":"SubagentStart","session":"p","agent_id":"a1"}' \
                '{"ts":60000,"event":"SubagentStop","session":"p","agent_id":"a1"}' \
                '{"ts":90000,"event":"delegate","agent_id":"a9","branch":"feature"}' \
                '{"ts":90000,"event":"SubagentStart","session":"p","agent_id":"a9"}' \
                '{"ts":150000,"event":"SubagentStop","session":"p","agent_id":"a9"}'
  local output
  output=$(aggregate --parent-log "$PARENT_LOG")
  assert_contains '"delegated_minutes":2.0' "$output"
  assert_contains '"delegates":2' "$output"
}

test_ignores_delegates_of_other_branches() {
  parent_events '{"ts":0,"event":"delegate","agent_id":"a2","branch":"other"}' \
                '{"ts":0,"event":"SubagentStart","session":"p","agent_id":"a2"}' \
                '{"ts":600000,"event":"SubagentStop","session":"p","agent_id":"a2"}'
  local output
  output=$(aggregate --parent-log "$PARENT_LOG")
  assert_contains '"delegated_minutes":null' "$output"
  assert_contains '"mode":null' "$output"
}

test_sums_check_durations_of_mapped_delegates() {
  parent_events '{"ts":0,"event":"delegate","agent_id":"a1","branch":"feature"}' \
                '{"ts":10,"event":"PostToolUse","session":"p","agent_id":"a1","tool":"Bash","duration_ms":180000,"check":true}'
  assert_contains '"check_minutes":3.0' "$(aggregate --parent-log "$PARENT_LOG")"
}

test_reports_mixed_mode_with_main_session_and_delegates() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":60000,"event":"Stop","session":"s"}'
  parent_events '{"ts":0,"event":"delegate","agent_id":"a1","branch":"feature"}' \
                '{"ts":0,"event":"SubagentStart","session":"p","agent_id":"a1"}' \
                '{"ts":60000,"event":"SubagentStop","session":"p","agent_id":"a1"}'
  assert_contains '"mode":"mixed"' "$(aggregate --parent-log "$PARENT_LOG")"
}

test_sums_tokens_reported_for_mapped_delegates() {
  parent_events '{"ts":0,"event":"delegate","agent_id":"a1","branch":"feature"}' \
                '{"ts":5,"event":"delegate_usage","agent_id":"a1","tokens":120000}' \
                '{"ts":9,"event":"delegate_usage","agent_id":"a1","tokens":30000}' \
                '{"ts":9,"event":"delegate_usage","agent_id":"a2","tokens":999}'
  assert_contains '"tokens":150000' "$(aggregate --parent-log "$PARENT_LOG")"
}

test_returns_null_tokens_without_delegate_usage() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":60000,"event":"Stop","session":"s"}'
  assert_contains '"tokens":null' "$(aggregate)"
}

test_ignores_delegate_still_running() {
  parent_events '{"ts":0,"event":"delegate","agent_id":"a1","branch":"feature"}' \
                '{"ts":0,"event":"SubagentStart","session":"p","agent_id":"a1"}'
  assert_contains '"delegated_minutes":0.0' "$(aggregate --parent-log "$PARENT_LOG")"
}

# ── Journal absent ────────────────────────────────────────────────────────────

test_returns_null_durations_without_any_log() {
  local output
  output=$(aggregate)
  assert_contains '"parent_minutes":null,"delegated_minutes":null,"human_minutes":null' "$output"
  assert_contains '"questions":0,"question_minutes":null,"check_minutes":null,"delegates":0,"mode":null' "$output"
}

test_ignores_missing_parent_log() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":60000,"event":"Stop","session":"s"}'
  assert_contains '"parent_minutes":1.0' "$(aggregate --parent-log "$SANDBOX/absent.jsonl")"
}

# ── Volume ────────────────────────────────────────────────────────────────────

test_counts_committed_modified_and_untracked_files() {
  printf 'a\nb\n' > "$WORK/new.txt"
  git -C "$WORK" add new.txt
  git -C "$WORK" commit -q -m "new"
  printf 'initial\nmore\n' > "$WORK/readme.txt"
  printf '1\n2\n3\n' > "$WORK/untracked.txt"
  local output
  output=$(aggregate)
  assert_contains '"files":3,"lines_added":6,"lines_deleted":0' "$output"
}

test_counts_deleted_lines() {
  printf 'replaced\n' > "$WORK/readme.txt"
  assert_contains '"files":1,"lines_added":1,"lines_deleted":1' "$(aggregate)"
}

test_excludes_forge_folder_and_lock_files() {
  mkdir -p "$WORK/app"
  printf '{}\n' > "$WORK/package-lock.json"
  printf 'x\n' > "$WORK/app/composer.lock"
  printf 'note\n' > "$WORK/.forge/branch/feature/plan.md"
  assert_contains '"files":0,"lines_added":0,"lines_deleted":0' "$(aggregate)"
}

test_measures_from_given_base() {
  printf 'a\n' > "$WORK/one.txt"
  git -C "$WORK" add one.txt
  git -C "$WORK" commit -q -m "one"
  git -C "$WORK" branch parent
  printf 'b\n' > "$WORK/two.txt"
  git -C "$WORK" add two.txt
  git -C "$WORK" commit -q -m "two"
  assert_contains '"files":1,"lines_added":1' "$(aggregate --base parent)"
}

test_returns_null_volume_without_start_point() {
  git -C "$WORK" branch -m master trunk
  assert_contains '"files":null,"lines_added":null,"lines_deleted":null' "$(aggregate)"
}

# ── Couverture ────────────────────────────────────────────────────────────────

# Commit propre à la branche, daté en secondes depuis l'epoch.
commit_at() {
  printf '%s\n' "$1" > "$WORK/dated.txt"
  git -C "$WORK" add dated.txt
  GIT_COMMITTER_DATE="@$1 +0000" GIT_AUTHOR_DATE="@$1 +0000" git -C "$WORK" commit -q -m "dated"
}

test_marks_partial_when_log_opens_with_late_start() {
  own_events '{"ts":0,"event":"late_start"}' \
             '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":60000,"event":"Stop","session":"s"}'
  assert_contains '"partial":true' "$(aggregate)"
}

test_marks_partial_when_branch_commit_precedes_log() {
  commit_at 1000
  own_events '{"ts":2000000,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":2060000,"event":"Stop","session":"s"}'
  assert_contains '"partial":true' "$(aggregate)"
}

test_marks_full_measure_when_log_precedes_branch_commits() {
  commit_at 5000
  own_events '{"ts":2000000,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":2060000,"event":"Stop","session":"s"}'
  assert_contains '"partial":false' "$(aggregate)"
}

test_marks_full_measure_without_branch_commit() {
  own_events '{"ts":2000000,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":2060000,"event":"Stop","session":"s"}'
  assert_contains '"partial":false' "$(aggregate)"
}

test_marks_no_partial_without_log() {
  commit_at 1000
  assert_contains '"partial":false' "$(aggregate)"
}

# ── Usage ─────────────────────────────────────────────────────────────────────

test_rejects_missing_branch() {
  local output
  output=$(bash "$AGGREGATE_SCRIPT" --root "$WORK" 2>/dev/null)
  assert_equals "1" "$?"
  assert_equals "" "$output"
}

test_rejects_unknown_argument() {
  bash "$AGGREGATE_SCRIPT" --branch feature --nope 2>/dev/null
  assert_equals "1" "$?"
}

test_changes_nothing_in_repository() {
  printf 'x\n' > "$WORK/untracked.txt"
  local before
  before=$(git -C "$WORK" status --porcelain)
  aggregate > /dev/null
  assert_equals "$before" "$(git -C "$WORK" status --porcelain)"
}

# ── Coûts fixes d'une branche ─────────────────────────────────────────────────

test_measures_delegate_setup_until_first_task_mark() {
  parent_events '{"event":"delegate","agent_id":"a1","branch":"feature"}' \
                '{"ts":0,"event":"SubagentStart","session":"p","agent_id":"a1"}' \
                '{"ts":360000,"event":"task_start","task":"T1","branch":"feature"}' \
                '{"ts":600000,"event":"task_start","task":"T2","branch":"feature"}' \
                '{"ts":900000,"event":"SubagentStop","session":"p","agent_id":"a1"}'
  assert_contains '"delegate_setup_minutes":6.0' "$(aggregate --parent-log "$PARENT_LOG")"
}

test_counts_setup_of_first_run_only_after_relaunch() {
  parent_events '{"event":"delegate","agent_id":"a1","branch":"feature"}' \
                '{"event":"delegate","agent_id":"a2","branch":"feature"}' \
                '{"ts":0,"event":"SubagentStart","session":"p","agent_id":"a1"}' \
                '{"ts":240000,"event":"task_start","task":"T1","branch":"feature"}' \
                '{"ts":300000,"event":"SubagentStop","session":"p","agent_id":"a1"}' \
                '{"ts":900000,"event":"SubagentStart","session":"p","agent_id":"a2"}' \
                '{"ts":1200000,"event":"task_start","task":"T2","branch":"feature"}'
  assert_contains '"delegate_setup_minutes":4.0' "$(aggregate --parent-log "$PARENT_LOG")"
}

test_ignores_task_marks_of_other_branches_for_setup() {
  parent_events '{"event":"delegate","agent_id":"a1","branch":"feature"}' \
                '{"ts":0,"event":"SubagentStart","session":"p","agent_id":"a1"}' \
                '{"ts":60000,"event":"task_start","task":"T1","branch":"other"}' \
                '{"ts":180000,"event":"task_start","task":"T1","branch":"feature"}'
  assert_contains '"delegate_setup_minutes":3.0' "$(aggregate --parent-log "$PARENT_LOG")"
}

test_averages_merges_without_question_waits() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":0,"event":"merge_start","branch":"feature-a"}' \
             '{"ts":60000,"event":"PreToolUse","session":"s","tool":"AskUserQuestion"}' \
             '{"ts":180000,"event":"PostToolUse","session":"s","tool":"AskUserQuestion"}' \
             '{"ts":420000,"event":"merge_done","branch":"feature-a"}' \
             '{"ts":500000,"event":"merge_start","branch":"feature-b"}' \
             '{"ts":680000,"event":"merge_done","branch":"feature-b"}' \
             '{"ts":700000,"event":"Stop","session":"s"}'
  assert_contains '"merge_minutes":4.0' "$(aggregate)"
}

test_returns_null_fixed_costs_without_marks() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":0,"event":"merge_start","branch":"feature-a"}' \
             '{"ts":60000,"event":"Stop","session":"s"}'
  assert_contains '"delegate_setup_minutes":null,"merge_minutes":null,' "$(aggregate)"
}

# ── Fichiers par tâche ────────────────────────────────────────────────────────

# Marque réelle de time-mark.sh dans le dépôt jetable : tâche, événement.
mark() {
  bash "$MARK_SCRIPT" --root "$WORK" --branch feature --task "$1" --event "$2"
}

task_files() {
  local output pattern='"actual_files":([0-9a-z]+)'
  output=$(aggregate --task "$1")
  [[ $output =~ $pattern ]] && printf '%s' "${BASH_REMATCH[1]}"
}

test_counts_a_file_in_every_task_that_changes_it() {
  : > "$OWN_LOG"
  mark T1 start; printf 'one\n' > "$WORK/shared.txt"; printf 'b\n' > "$WORK/b.txt"; mark T1 done
  mark T2 start; printf 'two\n' > "$WORK/shared.txt"; mark T2 done
  assert_equals 2 "$(task_files T1)"
  assert_equals 1 "$(task_files T2)"
}

test_ignores_file_left_unchanged_during_the_task() {
  : > "$OWN_LOG"
  printf 'before\n' > "$WORK/earlier.txt"
  mark T1 start; printf 'x\n' > "$WORK/x.txt"; mark T1 done
  assert_equals 1 "$(task_files T1)"
}

test_counts_deleted_tracked_file_but_not_temporary_one() {
  : > "$OWN_LOG"
  mark T1 start; rm "$WORK/readme.txt"; printf 'tmp\n' > "$WORK/tmp.txt"; rm "$WORK/tmp.txt"; mark T1 done
  assert_equals 1 "$(task_files T1)"
}

test_ignores_forge_files() {
  : > "$OWN_LOG"
  mark T1 start; printf 'note\n' > "$WORK/.forge/branch/feature/plan.md"; mark T1 done
  assert_equals 0 "$(task_files T1)"
}

test_sums_task_files_and_their_planned_files_for_the_branch() {
  : > "$OWN_LOG"
  printf '# Plan\n\n## Tasks\n\n### T1 — a\n**Files:** `a.txt`, `b.txt`\n[x]\n\n### T2 — b\n**Files:** `a.txt`\n[x]\n\n### T3 — c\n**Files:** `c.txt`\n[ ]\n' \
    > "$WORK/.forge/branch/feature/plan.md"
  mark T1 start; printf 'a\n' > "$WORK/a.txt"; mark T1 done
  mark T2 start; printf 'a2\n' > "$WORK/a.txt"; mark T2 done
  assert_contains '"task_files":2,"task_planned_files":3,"measured_tasks":2}' "$(aggregate)"
}

test_measures_files_of_a_delegate_in_its_worktree() {
  : > "$PARENT_LOG"
  git -C "$WORK" worktree add -q "$SANDBOX/child wt" -b child
  bash "$MARK_SCRIPT" --root "$SANDBOX/child wt" --branch child --task T1 --event start --time-log "$PARENT_LOG"
  printf 'c\n' > "$SANDBOX/child wt/c.txt"
  bash "$MARK_SCRIPT" --root "$SANDBOX/child wt" --branch child --task T1 --event done --time-log "$PARENT_LOG"
  assert_contains '"actual_files":1' "$(bash "$AGGREGATE_SCRIPT" --root "$SANDBOX/child wt" --branch child --parent-log "$PARENT_LOG" --task T1)"
  git -C "$WORK" worktree remove --force "$SANDBOX/child wt"
}

# ── Tâche ─────────────────────────────────────────────────────────────────────

test_task_measures_turn_part_inside_window() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":30000,"event":"task_start","task":"T2"}' \
             '{"ts":90000,"event":"task_done","task":"T2"}' \
             '{"ts":120000,"event":"Stop","session":"s"}'
  assert_equals '{"branch":"feature","task":"T2","agent_minutes":1.0,"human_minutes":0.0,"questions":0,"check_minutes":0.0,"actual_files":null,"measured":true,"reason":null}' \
    "$(aggregate --task T2)"
}

test_task_counts_checks_finished_inside_window() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":10000,"event":"PostToolUse","session":"s","tool":"Bash","duration_ms":6000,"check":true}' \
             '{"ts":20000,"event":"task_start","task":"T1"}' \
             '{"ts":50000,"event":"PostToolUse","session":"s","tool":"Bash","duration_ms":12000,"check":true}' \
             '{"ts":60000,"event":"PostToolUse","session":"s","tool":"Bash","duration_ms":9000}' \
             '{"ts":70000,"event":"PostToolUse","session":"s","agent_id":"a1","tool":"Bash","duration_ms":6000,"check":true}' \
             '{"ts":80000,"event":"task_done","task":"T1"}' \
             '{"ts":90000,"event":"PostToolUse","session":"s","tool":"Bash","duration_ms":30000,"check":true}' \
             '{"ts":100000,"event":"Stop","session":"s"}'
  assert_contains '"check_minutes":0.3,' "$(aggregate --task T1)"
}

test_task_counts_open_turn_up_to_done_mark() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":120000,"event":"task_done","task":"T1"}'
  assert_contains '"agent_minutes":2.0' "$(aggregate --task T1)"
}

test_task_ignores_older_turn_left_without_stop() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"old","origin":"human"}' \
             '{"ts":60000,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":60000,"event":"task_start","task":"T1"}' \
             '{"ts":120000,"event":"task_done","task":"T1"}'
  assert_contains '"agent_minutes":1.0' "$(aggregate --task T1)"
}

test_task_closes_turn_interrupted_by_prompt_at_last_activity() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":0,"event":"task_start","task":"T1"}'              '{"ts":60000,"event":"PostToolUse","session":"s","tool":"Bash","duration_ms":1000}'              '{"ts":300000,"event":"UserPromptSubmit","session":"s","origin":"human"}'              '{"ts":330000,"event":"task_done","task":"T1"}'              '{"ts":360000,"event":"Stop","session":"s"}'
  assert_contains '"agent_minutes":1.5' "$(aggregate --task T1)"
}

test_task_removes_question_inside_window_and_counts_it_as_human() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":10000,"event":"task_start","task":"T1"}' \
             '{"ts":20000,"event":"PreToolUse","session":"s","tool":"AskUserQuestion"}' \
             '{"ts":80000,"event":"PostToolUse","session":"s","tool":"AskUserQuestion"}' \
             '{"ts":100000,"event":"task_done","task":"T1"}' \
             '{"ts":110000,"event":"Stop","session":"s"}'
  local output
  output=$(aggregate --task T1)
  assert_contains '"agent_minutes":0.5' "$output"
  assert_contains '"human_minutes":1.0' "$output"
  assert_contains '"questions":1' "$output"
}

test_task_ignores_turns_and_questions_outside_window() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":10000,"event":"PreToolUse","session":"s","tool":"AskUserQuestion"}' \
             '{"ts":70000,"event":"PostToolUse","session":"s","tool":"AskUserQuestion"}' \
             '{"ts":80000,"event":"task_start","task":"T1"}' \
             '{"ts":140000,"event":"task_done","task":"T1"}' \
             '{"ts":200000,"event":"Stop","session":"s"}'
  local output
  output=$(aggregate --task T1)
  assert_contains '"agent_minutes":1.0' "$output"
  assert_contains '"human_minutes":0.0' "$output"
  assert_contains '"questions":0' "$output"
}

test_task_counts_gap_before_human_prompt_inside_window() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":60000,"event":"Stop","session":"s"}' \
             '{"ts":180000,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":240000,"event":"task_done","task":"T1"}'
  local output
  output=$(aggregate --task T1)
  assert_contains '"agent_minutes":2.0' "$output"
  assert_contains '"human_minutes":2.0' "$output"
}

test_task_does_not_count_absence_over_six_hours_as_human_time() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":60000,"event":"Stop","session":"s"}' \
             '{"ts":21660001,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":21720001,"event":"task_done","task":"T1"}'
  local output
  output=$(aggregate --task T1)
  assert_contains '"agent_minutes":2.0' "$output"
  assert_contains '"human_minutes":0.0' "$output"
}

test_task_keeps_last_start_mark() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":60000,"event":"task_start","task":"T1"}' \
             '{"ts":120000,"event":"task_done","task":"T1"}' \
             '{"ts":130000,"event":"Stop","session":"s"}'
  assert_contains '"agent_minutes":1.0' "$(aggregate --task T1)"
}

test_task_ignores_marks_of_other_tasks() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":60000,"event":"task_done","task":"T1"}' \
             '{"ts":60000,"event":"task_start","task":"T10"}' \
             '{"ts":180000,"event":"task_done","task":"T10"}' \
             '{"ts":200000,"event":"Stop","session":"s"}'
  assert_contains '"agent_minutes":1.0' "$(aggregate --task T1)"
  assert_contains '"agent_minutes":2.0' "$(aggregate --task T10)"
}

test_task_unmeasured_without_start_mark() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":60000,"event":"task_done","task":"T1"}'
  assert_equals '{"branch":"feature","task":"T1","agent_minutes":null,"human_minutes":null,"questions":null,"check_minutes":null,"actual_files":null,"measured":false,"reason":"missing_start"}' \
    "$(aggregate --task T1)"
}

test_task_unmeasured_without_done_mark() {
  own_events '{"ts":0,"event":"task_start","task":"T1"}'
  assert_contains '"measured":false,"reason":"missing_done"' "$(aggregate --task T1)"
}

test_task_unmeasured_with_late_start() {
  own_events '{"ts":0,"event":"late_start"}' \
             '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":60000,"event":"task_done","task":"T1"}'
  assert_contains '"measured":false,"reason":"late_start"' "$(aggregate --task T1)"
}

test_task_started_after_late_start_is_measured() {
  own_events '{"ts":0,"event":"late_start"}' \
             '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":1000,"event":"task_start","task":"T1"}' \
             '{"ts":61000,"event":"task_done","task":"T1"}'
  assert_contains '"measured":true' "$(aggregate --task T1)"
}

test_task_started_before_late_start_stays_unmeasured() {
  own_events '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":1000,"event":"late_start"}' \
             '{"ts":1000,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":61000,"event":"task_done","task":"T1"}'
  assert_contains '"measured":false,"reason":"late_start"' "$(aggregate --task T1)"
}

test_task_unmeasured_without_log() {
  assert_contains '"measured":false,"reason":"no_log"' "$(aggregate --task T1)"
}

test_task_counts_ordinary_subagent_inside_window() {
  own_events '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":0,"event":"SubagentStart","session":"s","agent_id":"x1"}' \
             '{"ts":60000,"event":"Stop","session":"s"}' \
             '{"ts":180000,"event":"SubagentStop","session":"s","agent_id":"x1"}' \
             '{"ts":240000,"event":"UserPromptSubmit","session":"s","origin":"agent"}' \
             '{"ts":240000,"event":"task_done","task":"T1"}' \
             '{"ts":300000,"event":"SubagentStart","session":"s","agent_id":"x2"}' \
             '{"ts":360000,"event":"SubagentStop","session":"s","agent_id":"x2"}'
  assert_contains '"agent_minutes":4.0' "$(aggregate --task T1)"
}

test_task_ignores_agent_delegated_to_another_branch() {
  own_events '{"event":"delegate","agent_id":"x1","branch":"feature-child"}' \
             '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":0,"event":"SubagentStart","session":"s","agent_id":"x1"}' \
             '{"ts":60000,"event":"Stop","session":"s"}' \
             '{"ts":120000,"event":"SubagentStop","session":"s","agent_id":"x1"}' \
             '{"ts":120000,"event":"task_done","task":"T1"}'
  assert_contains '"agent_minutes":1.0' "$(aggregate --task T1)"
}

test_task_unmeasured_when_started_with_another_task() {
  own_events '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":0,"event":"task_start","task":"T2"}' \
             '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":120000,"event":"Stop","session":"s"}' \
             '{"ts":60000,"event":"task_done","task":"T1"}' \
             '{"ts":120000,"event":"task_done","task":"T2"}'
  local first second
  first=$(aggregate --task T1)
  second=$(aggregate --task T2)
  assert_contains '"measured":false' "$first"
  assert_contains '"reason":"overlapping_tasks"' "$first"
  assert_contains '"measured":false' "$second"
  assert_contains '"reason":"overlapping_tasks"' "$second"
}

test_task_measured_when_tasks_follow_each_other() {
  own_events '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":60000,"event":"task_done","task":"T1"}' \
             '{"ts":60000,"event":"task_start","task":"T2"}' \
             '{"ts":180000,"event":"task_done","task":"T2"}' \
             '{"ts":180000,"event":"Stop","session":"s"}'
  assert_contains '"agent_minutes":1.0' "$(aggregate --task T1)"
  assert_contains '"agent_minutes":2.0' "$(aggregate --task T2)"
}

test_task_unmeasured_when_another_task_runs_inside_it() {
  own_events '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":30000,"event":"task_start","task":"T2"}' \
             '{"ts":60000,"event":"task_done","task":"T2"}' \
             '{"ts":120000,"event":"task_done","task":"T1"}' \
             '{"ts":120000,"event":"Stop","session":"s"}'
  assert_contains '"reason":"overlapping_tasks"' "$(aggregate --task T1)"
  assert_contains '"reason":"overlapping_tasks"' "$(aggregate --task T2)"
}

test_task_restarted_before_its_end_leaves_no_phantom_open_task() {
  own_events '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":5000,"event":"task_start","task":"T1"}' \
             '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":60000,"event":"task_done","task":"T1"}' \
             '{"ts":60000,"event":"task_start","task":"T2"}' \
             '{"ts":120000,"event":"task_done","task":"T2"}' \
             '{"ts":120000,"event":"Stop","session":"s"}'
  assert_contains '"agent_minutes":1.0' "$(aggregate --task T2)"
}

test_task_ignores_open_task_of_another_branch() {
  own_events '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":0,"event":"task_start","task":"T7","branch":"other"}' \
             '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":60000,"event":"task_done","task":"T1"}' \
             '{"ts":60000,"event":"Stop","session":"s"}'
  assert_contains '"agent_minutes":1.0' "$(aggregate --task T1)"
}

test_task_measures_delegate_from_parent_log() {
  parent_events '{"event":"delegate","agent_id":"a1","branch":"feature"}' \
                '{"ts":0,"event":"SubagentStart","agent_id":"a1"}' \
                '{"ts":10000,"event":"task_start","task":"T1","branch":"feature"}' \
                '{"ts":10000,"event":"task_start","task":"T1","branch":"other"}' \
                '{"ts":70000,"event":"task_done","task":"T1","branch":"feature"}' \
                '{"ts":90000,"event":"SubagentStop","agent_id":"a1"}' \
                '{"ts":0,"event":"UserPromptSubmit","session":"p","origin":"human"}' \
                '{"ts":200000,"event":"Stop","session":"p"}'
  local output
  output=$(aggregate --task T1 --parent-log "$PARENT_LOG")
  assert_contains '"agent_minutes":1.0' "$output"
  assert_contains '"measured":true' "$output"
}

test_task_counts_delegate_still_running_up_to_done_mark() {
  parent_events '{"event":"delegate","agent_id":"a1","branch":"feature"}' \
                '{"ts":0,"event":"SubagentStart","agent_id":"a1"}' \
                '{"ts":0,"event":"task_start","task":"T1","branch":"feature"}' \
                '{"ts":90000,"event":"task_done","task":"T1","branch":"feature"}'
  assert_contains '"agent_minutes":1.5' "$(aggregate --task T1 --parent-log "$PARENT_LOG")"
}

test_task_ignores_main_session_marks_for_delegate() {
  own_events '{"ts":0,"event":"task_start","task":"T1"}' \
             '{"ts":60000,"event":"task_done","task":"T1"}'
  parent_events '{"event":"delegate","agent_id":"a1","branch":"feature"}'
  assert_contains '"reason":"missing_start"' "$(aggregate --task T1 --parent-log "$PARENT_LOG")"
}

test_task_rejects_malformed_task() {
  bash "$AGGREGATE_SCRIPT" --root "$WORK" --branch feature --task 3 2>/dev/null
  assert_equals "1" "$?"
}

test_task_marks_keep_full_branch_measure_unchanged() {
  own_events '{"ts":0,"event":"UserPromptSubmit","session":"s","origin":"human"}' \
             '{"ts":10000,"event":"task_start","task":"T1"}' \
             '{"ts":50000,"event":"task_done","task":"T1"}' \
             '{"ts":60000,"event":"Stop","session":"s"}'
  local output
  output=$(aggregate)
  assert_contains '"parent_minutes":1.0' "$output"
  assert_contains '"partial":false' "$output"
}

linked_events() {
  parent_events '{"event":"delegate","agent_id":"l1","branch":"parent/main-branch"}' \
                '{"ts":0,"event":"SubagentStart","agent_id":"l1"}' \
                '{"ts":0,"event":"task_start","task":"T1","branch":"parent/main-branch"}' \
                '{"ts":60000,"event":"task_done","task":"T1","branch":"parent/main-branch"}' \
                '{"ts":60000,"event":"task_start","task":"T2","branch":"parent/main-branch"}' \
                '{"ts":150000,"event":"task_done","task":"T2","branch":"parent/main-branch"}' \
                '{"ts":150000,"event":"task_start","task":"T3","branch":"parent/main-branch"}' \
                '{"ts":200000,"event":"SubagentStop","agent_id":"l1"}'
}

aggregate_linked() {
  bash "$AGGREGATE_SCRIPT" --root "$WORK" --branch parent/main-branch --parent-log "$PARENT_LOG" "$@"
}

test_task_measures_linked_project_delegate_from_parent_log() {
  linked_events
  assert_equals '{"branch":"parent/main-branch","task":"T2","agent_minutes":1.5,"human_minutes":0.0,"questions":0,"check_minutes":0.0,"actual_files":null,"measured":true,"reason":null}' \
    "$(aggregate_linked --task T2)"
}

test_task_sums_child_tasks_of_a_parent_task() {
  linked_events
  assert_contains '"task":"T1,T2","agent_minutes":2.5' "$(aggregate_linked --task T1,T2)"
}

test_task_sum_unmeasured_when_one_child_is_unmeasured() {
  linked_events
  assert_contains '"agent_minutes":null,"human_minutes":null,"questions":null,"check_minutes":null,"actual_files":null,"measured":false,"reason":"missing_done"' \
    "$(aggregate_linked --task T1,T3)"
}

test_task_rejects_malformed_task_list() {
  bash "$AGGREGATE_SCRIPT" --root "$WORK" --branch feature --task T1, 2>/dev/null
  assert_equals "1" "$?"
}

run_test() {
  local result
  setup_sandbox
  ( "$1" )
  result=$?
  teardown_sandbox
  if [ $result -eq 0 ]; then
    PASSED=$((PASSED + 1))
    echo "  ok   $2"
  else
    FAILED=$((FAILED + 1))
    echo "  FAIL $2"
  fi
}

echo "time-aggregate.sh"
run_test test_measures_one_turn_of_main_session "mesure un tour de la session principale"
run_test test_removes_question_wait_from_turn_and_counts_it_as_human "retire l'attente d'une question du tour et la compte en temps humain"
run_test test_counts_gap_before_human_prompt_as_human_time "compte en temps humain l'écart avant un prompt de l'utilisateur"
run_test test_does_not_count_wait_for_delegate_as_human_time "ne compte pas en temps humain l'attente d'un délégué"
run_test test_does_not_count_absence_over_six_hours_as_human_time "ne compte pas en temps humain une absence de plus de 6 h avant un prompt"
run_test test_counts_gap_of_exactly_six_hours_as_human_time "compte en temps humain un écart de 6 h tout juste"
run_test test_does_not_count_question_left_over_six_hours_as_human_time "ne compte pas en temps humain une question restée plus de 6 h sans réponse"
run_test test_ignores_turn_without_stop "ignore un tour resté ouvert en fin de journal"
run_test test_closes_turn_interrupted_by_queued_prompt_at_last_activity "ferme au dernier événement un tour interrompu par un prompt en file"
run_test test_closes_turn_interrupted_by_escape_without_counting_the_pause "ferme un tour interrompu par Échap sans compter la pause"
run_test test_closes_turn_interrupted_by_task_notification "ferme un tour interrompu par une notification de tâche de fond"
run_test test_keeps_interleaved_sessions_apart "sépare deux sessions entrelacées"
run_test test_sums_check_durations_of_main_session "additionne les vérifications de la session principale"
run_test test_ignores_events_of_agent_delegated_to_another_branch "écarte les événements d'un agent délégué à une autre branche"
run_test test_counts_ordinary_subagent_of_own_log "compte un sous-agent ordinaire du journal de la branche"
run_test test_sums_parallel_ordinary_subagents "additionne des sous-agents ordinaires lancés en parallèle"
run_test test_ignores_ordinary_subagent_still_running "écarte un sous-agent ordinaire encore en cours"
run_test test_sums_runs_of_delegates_mapped_to_branch "additionne les exécutions des délégués associés à la branche"
run_test test_counts_delegate_mapped_after_its_start "compte un délégué associé à sa branche après son démarrage"
run_test test_measures_events_written_out_of_order "mesure des événements écrits dans le désordre"
run_test test_adds_relaunched_delegate_after_interruption "ajoute le délégué relancé après interruption"
run_test test_ignores_delegates_of_other_branches "écarte les délégués des autres branches"
run_test test_sums_check_durations_of_mapped_delegates "additionne les vérifications des délégués associés"
run_test test_reports_mixed_mode_with_main_session_and_delegates "rend le mode mixed avec session principale et délégués"
run_test test_sums_tokens_reported_for_mapped_delegates "additionne les tokens rapportés pour les délégués associés"
run_test test_returns_null_tokens_without_delegate_usage "rend des tokens nuls sans rapport de délégué"
run_test test_ignores_delegate_still_running "ignore un délégué encore en cours"
run_test test_returns_null_durations_without_any_log "rend des durées nulles sans journal"
run_test test_ignores_missing_parent_log "ignore un journal parent absent"
run_test test_counts_committed_modified_and_untracked_files "compte les fichiers commités, modifiés et non suivis"
run_test test_counts_deleted_lines "compte les lignes supprimées"
run_test test_excludes_forge_folder_and_lock_files "écarte le dossier .forge et les fichiers de verrouillage"
run_test test_measures_from_given_base "mesure depuis le point de départ donné"
run_test test_returns_null_volume_without_start_point "rend un volume nul sans point de départ"
run_test test_marks_partial_when_log_opens_with_late_start "marque partielle une mesure dont le journal s'ouvre sur un départ tardif"
run_test test_marks_partial_when_branch_commit_precedes_log "marque partielle une mesure commencée après le premier commit de la branche"
run_test test_marks_full_measure_when_log_precedes_branch_commits "marque complète une mesure commencée avant les commits de la branche"
run_test test_marks_full_measure_without_branch_commit "marque complète une mesure sans commit propre à la branche"
run_test test_marks_no_partial_without_log "ne marque rien de partiel sans journal"
run_test test_rejects_missing_branch "refuse l'absence de branche"
run_test test_rejects_unknown_argument "refuse un argument inconnu"
run_test test_changes_nothing_in_repository "ne modifie rien dans le dépôt"
run_test test_measures_delegate_setup_until_first_task_mark "mesure la mise en route d'un délégué jusqu'à sa première marque de tâche"
run_test test_counts_setup_of_first_run_only_after_relaunch "ne compte que la mise en route de la première exécution après une relance"
run_test test_ignores_task_marks_of_other_branches_for_setup "écarte les marques de tâche des autres branches pour la mise en route"
run_test test_averages_merges_without_question_waits "fait la moyenne des fusions, attentes de question retirées"
run_test test_returns_null_fixed_costs_without_marks "rend des coûts fixes nuls sans marques complètes"
run_test test_counts_a_file_in_every_task_that_changes_it "compte un fichier dans chaque tâche qui le modifie"
run_test test_ignores_file_left_unchanged_during_the_task "écarte un fichier resté inchangé pendant la tâche"
run_test test_counts_deleted_tracked_file_but_not_temporary_one "compte un fichier suivi supprimé, pas un fichier créé puis supprimé"
run_test test_ignores_forge_files "écarte les fichiers de .forge"
run_test test_sums_task_files_and_their_planned_files_for_the_branch "additionne fichiers réels et prévus des tâches mesurées de la branche"
run_test test_measures_files_of_a_delegate_in_its_worktree "mesure les fichiers d'un délégué dans son worktree"
run_test test_task_measures_turn_part_inside_window "tâche : mesure la part d'un tour comprise dans la fenêtre"
run_test test_task_counts_checks_finished_inside_window "tâche : compte les vérifications terminées dans la fenêtre, session et agents"
run_test test_task_counts_open_turn_up_to_done_mark "tâche : compte un tour encore ouvert jusqu'à la marque de fin"
run_test test_task_ignores_older_turn_left_without_stop "tâche : écarte un tour plus ancien resté sans Stop"
run_test test_task_closes_turn_interrupted_by_prompt_at_last_activity "tâche : ferme au dernier événement un tour interrompu par un prompt"
run_test test_task_removes_question_inside_window_and_counts_it_as_human "tâche : retire une question de la fenêtre et la compte en temps humain"
run_test test_task_ignores_turns_and_questions_outside_window "tâche : écarte tours et questions hors de la fenêtre"
run_test test_task_counts_gap_before_human_prompt_inside_window "tâche : compte en temps humain l'écart avant un prompt dans la fenêtre"
run_test test_task_does_not_count_absence_over_six_hours_as_human_time "tâche : ne compte pas en temps humain une absence de plus de 6 h"
run_test test_task_keeps_last_start_mark "tâche : retient la dernière marque de début"
run_test test_task_ignores_marks_of_other_tasks "tâche : écarte les marques des autres tâches"
run_test test_task_unmeasured_without_start_mark "tâche : non mesurée sans marque de début"
run_test test_task_unmeasured_without_done_mark "tâche : non mesurée sans marque de fin"
run_test test_task_unmeasured_with_late_start "tâche : non mesurée sur un journal à départ tardif"
run_test test_task_started_after_late_start_is_measured "tâche commencée après le départ tardif : mesurée"
run_test test_task_started_before_late_start_stays_unmeasured "tâche commencée avant le départ tardif : non mesurée"
run_test test_task_unmeasured_without_log "tâche : non mesurée sans journal"
run_test test_task_counts_ordinary_subagent_inside_window "tâche : compte un sous-agent ordinaire dans la fenêtre"
run_test test_task_ignores_agent_delegated_to_another_branch "tâche : écarte un agent délégué à une autre branche"
run_test test_task_unmeasured_when_started_with_another_task "tâche : non mesurée quand une autre tâche démarre en même temps"
run_test test_task_measured_when_tasks_follow_each_other "tâche : mesurée quand les tâches se suivent"
run_test test_task_unmeasured_when_another_task_runs_inside_it "tâche : non mesurée quand une autre tâche s'exécute pendant elle"
run_test test_task_restarted_before_its_end_leaves_no_phantom_open_task "tâche : une autre tâche redémarrée avant sa fin ne reste pas ouverte pour toujours"
run_test test_task_ignores_open_task_of_another_branch "tâche : écarte une tâche ouverte d'une autre branche"
run_test test_task_measures_delegate_from_parent_log "tâche : mesure un délégué depuis le journal du parent"
run_test test_task_counts_delegate_still_running_up_to_done_mark "tâche : compte un délégué encore en cours jusqu'à la marque de fin"
run_test test_task_ignores_main_session_marks_for_delegate "tâche : écarte les marques sans branche pour un délégué"
run_test test_task_rejects_malformed_task "tâche : refuse un identifiant de tâche mal formé"
run_test test_task_marks_keep_full_branch_measure_unchanged "tâche : les marques laissent la mesure de la branche inchangée"
run_test test_task_measures_linked_project_delegate_from_parent_log "tâche : mesure un délégué de projet lié depuis le journal du parent"
run_test test_task_sums_child_tasks_of_a_parent_task "tâche : additionne les tâches enfant d'une tâche parente"
run_test test_task_sum_unmeasured_when_one_child_is_unmeasured "tâche : somme non mesurée dès qu'une tâche enfant ne l'est pas"
run_test test_task_rejects_malformed_task_list "tâche : refuse une liste de tâches mal formée"

echo "$PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ]
