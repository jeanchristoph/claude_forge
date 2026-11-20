#!/bin/bash
# Tests de skills/forge/scripts/log-entry.sh — chaque test tourne dans un dossier jetable, jamais le dépôt courant.
# Usage : bash tests/log-entry.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENTRY_SCRIPT="$REPO_ROOT/skills/forge/scripts/log-entry.sh"
PASSED=0
FAILED=0

# ── Bac à sable ───────────────────────────────────────────────────────────────

setup_sandbox() {
  SANDBOX=$(mktemp -d)
  WORK="$SANDBOX/work"
  mkdir -p "$WORK/.forge/branch/feature"
  LOG="$WORK/.forge/branch/feature/log.md"
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

log_entry() {
  bash "$ENTRY_SCRIPT" --root "$WORK" --branch feature "$@"
}

# ── Assertions — chaque test tourne dans un sous-shell, un échec en sort ──────

assert_equals() {
  [ "$1" = "$2" ] && return 0
  printf '    expected: %s\n    actual:   %s\n' "$1" "$2"
  exit 1
}

assert_matches() {
  [[ $2 =~ $1 ]] && return 0
  printf '    pattern: %s\n    actual:  %s\n' "$1" "$2"
  exit 1
}

# Retours chariot du journal, comptés octet par octet : grep sous Git Bash ne les voit pas en fin de ligne.
count_carriage_returns() {
  tr -cd '\r' < "$LOG" | wc -c | tr -d ' '
}

readonly STAMP='^- \[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}\] '

# ── Écriture ──────────────────────────────────────────────────────────────────

test_inserts_entry_above_existing_entries() {
  printf -- '- [2026-01-01 10:00] older\n- [2025-12-31 09:00] oldest\n' > "$LOG"
  log_entry --text "newer"
  assert_matches "${STAMP}newer\$" "$(sed -n 1p "$LOG")"
  assert_equals '- [2026-01-01 10:00] older' "$(sed -n 2p "$LOG")"
  assert_equals '- [2025-12-31 09:00] oldest' "$(sed -n 3p "$LOG")"
  assert_equals 3 "$(wc -l < "$LOG" | tr -d ' ')"
}

test_creates_missing_log_and_branch_folder() {
  bash "$ENTRY_SCRIPT" --root "$WORK" --branch forge/linked --text "Opened"
  assert_matches "${STAMP}Opened\$" "$(cat "$WORK/.forge/branch/forge/linked/log.md")"
}

test_writes_into_empty_log() {
  : > "$LOG"
  log_entry --text "first"
  assert_matches "${STAMP}first\$" "$(cat "$LOG")"
  assert_equals 1 "$(wc -l < "$LOG" | tr -d ' ')"
}

test_keeps_crlf_line_endings() {
  printf -- '- [2026-01-01 10:00] older\r\n' > "$LOG"
  log_entry --text "newer"
  assert_equals 2 "$(count_carriage_returns)"
}

test_keeps_lf_line_endings() {
  printf -- '- [2026-01-01 10:00] older\n' > "$LOG"
  log_entry --text "newer"
  assert_equals 0 "$(count_carriage_returns)"
}

test_keeps_title_above_entry() {
  printf '# Log — feature\n\n- [2026-01-01 10:00] older\n' > "$LOG"
  log_entry --text "newer"
  assert_equals '# Log — feature' "$(sed -n 1p "$LOG")"
  assert_equals '' "$(sed -n 2p "$LOG")"
  assert_matches "${STAMP}newer\$" "$(sed -n 3p "$LOG")"
  assert_equals '- [2026-01-01 10:00] older' "$(sed -n 4p "$LOG")"
}

test_writes_text_as_is() {
  local text='Décision : `grave` sur $HOME et "dev" — 100 % \n gardé'
  log_entry --text "$text"
  assert_equals "$text" "$(sed -n 1p "$LOG" | sed 's/^- \[[^]]*\] //')"
}

test_stamps_with_local_clock() {
  local before after line
  before=$(date '+%Y-%m-%d %H:%M')
  log_entry --text "now"
  after=$(date '+%Y-%m-%d %H:%M')
  line=$(sed -n 1p "$LOG")
  [ "$line" = "- [$before] now" ] || [ "$line" = "- [$after] now" ] || { echo "    clock mismatch: $line ($before / $after)"; exit 1; }
}

test_writes_nothing_on_stdout() {
  assert_equals "" "$(log_entry --text "quiet")"
}

# ── Refus ─────────────────────────────────────────────────────────────────────

test_rejects_empty_text_and_keeps_file() {
  printf -- '- [2026-01-01 10:00] older\n' > "$LOG"
  log_entry --text "   " 2>/dev/null
  assert_equals 1 "$?"
  assert_equals '- [2026-01-01 10:00] older' "$(cat "$LOG")"
}

test_rejects_missing_text() {
  printf -- '- [2026-01-01 10:00] older\n' > "$LOG"
  log_entry 2>/dev/null
  assert_equals 1 "$?"
  assert_equals '- [2026-01-01 10:00] older' "$(cat "$LOG")"
}

test_rejects_missing_branch() {
  bash "$ENTRY_SCRIPT" --root "$WORK" --text "x" 2>/dev/null
  assert_equals 1 "$?"
}

test_rejects_value_less_argument() {
  log_entry --text 2>/dev/null
  assert_equals 1 "$?"
}

test_rejects_multiline_text() {
  printf -- '- [2026-01-01 10:00] older\n' > "$LOG"
  log_entry --text $'two\nlines' 2>/dev/null
  assert_equals 1 "$?"
  assert_equals '- [2026-01-01 10:00] older' "$(cat "$LOG")"
}

test_reports_error_on_stderr() {
  local error
  error=$(log_entry --text "" 2>&1 >/dev/null)
  assert_matches '^log-entry: ' "$error"
}

# ── Exécution ─────────────────────────────────────────────────────────────────

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

echo "log-entry.sh"
run_test test_inserts_entry_above_existing_entries "insère l'entrée au-dessus des entrées existantes"
run_test test_creates_missing_log_and_branch_folder "crée log.md et le dossier de branche absents"
run_test test_writes_into_empty_log "écrit dans un log.md vide"
run_test test_keeps_crlf_line_endings "garde les fins de ligne CRLF"
run_test test_keeps_lf_line_endings "garde les fins de ligne LF"
run_test test_keeps_title_above_entry "garde un titre au-dessus de l'entrée"
run_test test_writes_text_as_is "écrit le texte tel quel : accents, backticks, dollar, guillemets"
run_test test_stamps_with_local_clock "horodate avec l'horloge locale"
run_test test_writes_nothing_on_stdout "n'écrit rien sur la sortie standard"
run_test test_rejects_empty_text_and_keeps_file "refuse un texte vide sans toucher au fichier"
run_test test_rejects_missing_text "refuse l'absence de texte sans toucher au fichier"
run_test test_rejects_missing_branch "refuse l'absence de branche"
run_test test_rejects_value_less_argument "refuse un argument sans valeur"
run_test test_rejects_multiline_text "refuse un texte sur plusieurs lignes"
run_test test_reports_error_on_stderr "signale l'erreur sur la sortie d'erreur"

echo "$PASSED passed, $FAILED failed"
[ $FAILED -eq 0 ]
