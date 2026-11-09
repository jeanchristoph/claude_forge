#!/bin/bash
# Tests des installeurs install/install.sh et install/install.ps1 — chaque test installe
# une copie jetable du dépôt dans un HOME jetable, jamais le HOME réel ni ~/.claude.
# install.sh exige node, install.ps1 exige powershell.exe : sans eux, les tests sont sautés.
# Usage : bash tests/install.test.sh

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPDATE_SCRIPT="$REPO_ROOT/skills/forge/scripts/update.sh"
SYSTEM_TMPDIR=${TMPDIR:-/tmp}
PASSED=0
FAILED=0
SKIPPED=0

# ── Bac à sable ───────────────────────────────────────────────────────────────

# Copie du dépôt hors de tout dépôt git, et HOME jetable où installer.
setup_sandbox() {
  SANDBOX=$(TMPDIR=$SYSTEM_TMPDIR mktemp -d)
  SOURCE="$SANDBOX/forge"
  HOME_DIR="$SANDBOX/home"
  CLAUDE_DIR="$HOME_DIR/.claude"
  mkdir -p "$SOURCE" "$HOME_DIR"
  cp -r "$REPO_ROOT/install" "$REPO_ROOT/skills" "$REPO_ROOT/hooks" "$SOURCE/"
}

teardown_sandbox() {
  rm -rf "$SANDBOX"
}

# Copie publiée : dépôt git avec un tag de version et un dépôt d'origine.
make_tagged_git_copy() {
  git init -q "$SOURCE"
  git -C "$SOURCE" config user.name "Forge Test"
  git -C "$SOURCE" config user.email "forge@test.local"
  git -C "$SOURCE" config commit.gpgsign false
  git -C "$SOURCE" config core.autocrlf false
  git -C "$SOURCE" add .
  git -C "$SOURCE" commit -q -m "release"
  git -C "$SOURCE" tag v1.2.3
  git -C "$SOURCE" remote add origin git@example.com:owner/forge.git
}

# INVARIANT : l'installeur ne voit que le HOME jetable, variable limitée au processus lancé.
run_installer() {
  case $INSTALLER in
    sh) HOME="$HOME_DIR" bash "$SOURCE/install/install.sh" ;;
    ps1) USERPROFILE="$(cygpath -w "$HOME_DIR")" powershell.exe -NoProfile -ExecutionPolicy Bypass \
           -File "$(cygpath -w "$SOURCE/install/install.ps1")" ;;
  esac > /dev/null
}

hook_file_name() {
  case $INSTALLER in
    sh) printf 'forge-precompact.sh' ;;
    ps1) printf 'forge-precompact.ps1' ;;
  esac
}

seed_settings() {
  mkdir -p "$CLAUDE_DIR"
  printf '{"model":"opus","permissions":{"allow":["Bash(ls:*)"]}}\n' > "$CLAUDE_DIR/settings.json"
}

settings() {
  cat "$CLAUDE_DIR/settings.json"
}

install_record() {
  cat "$CLAUDE_DIR/skills/forge/install.json"
}

count_occurrences() {
  grep -o -F "$1" "$2" | wc -l | tr -d ' '
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

assert_file_exists() {
  [ -f "$1" ] && return 0
  printf '    missing file: %s\n' "$1"
  exit 1
}

# ── Copie des fichiers ────────────────────────────────────────────────────────

test_copies_skills_and_hook_into_home() {
  run_installer || exit 1
  assert_file_exists "$CLAUDE_DIR/skills/forge/SKILL.md"
  assert_file_exists "$CLAUDE_DIR/skills/forge-clickup/SKILL.md"
  assert_file_exists "$CLAUDE_DIR/hooks/forge/$(hook_file_name)"
}

# ── Fusion de settings.json ───────────────────────────────────────────────────

test_adds_forge_rule_and_precompact_hook() {
  run_installer || exit 1
  assert_contains '"Read(/.forge/**)"' "$(settings)"
  assert_contains "$(hook_file_name)" "$(settings)"
  assert_contains '"PreCompact"' "$(settings)"
}

test_keeps_unrelated_settings() {
  seed_settings
  run_installer || exit 1
  assert_contains '"model":' "$(settings)"
  assert_contains '"opus"' "$(settings)"
  assert_contains '"Bash(ls:*)"' "$(settings)"
}

test_second_install_adds_nothing_twice() {
  seed_settings
  run_installer && run_installer || exit 1
  local file="$CLAUDE_DIR/settings.json"
  assert_equals 1 "$(count_occurrences '"Read(/.forge/**)"' "$file")"
  assert_equals 1 "$(count_occurrences '"Edit(/.forge/**)"' "$file")"
  assert_equals 1 "$(count_occurrences '"Bash(ls:*)"' "$file")"
  assert_equals 1 "$(count_occurrences 'skills/forge/**)' "$file")"
  assert_equals 1 "$(count_occurrences 'forge-precompact' "$file")"
}

# ── install.json ──────────────────────────────────────────────────────────────

test_records_tag_and_origin_from_git_copy() {
  make_tagged_git_copy
  run_installer || exit 1
  local record
  record=$(install_record)
  assert_contains '"version":"v1.2.3"' "$record"
  assert_contains '"repository":"git@example.com:owner/forge.git"' "$record"
  assert_contains '"latest":"v1.2.3"' "$record"
  assert_contains '"last_check":' "$record"
  assert_not_contains '"last_check":0' "$record"
}

test_writes_install_record_without_bom() {
  make_tagged_git_copy
  run_installer || exit 1
  assert_equals '{' "$(head -c 1 "$CLAUDE_DIR/skills/forge/install.json")"
}

test_writes_settings_without_bom() {
  seed_settings
  run_installer || exit 1
  assert_equals '{' "$(head -c 1 "$CLAUDE_DIR/settings.json")"
}

# Fichier laissé par une ancienne version de install.ps1 : BOM UTF-8 en tête.
test_keeps_unrelated_settings_from_file_with_bom() {
  mkdir -p "$CLAUDE_DIR"
  printf '\xEF\xBB\xBF{"model":"opus","permissions":{"allow":["Bash(ls:*)"]}}\n' > "$CLAUDE_DIR/settings.json"
  run_installer || exit 1
  local content
  content=$(settings)
  assert_contains '"opus"' "$content"
  assert_contains '"Bash(ls:*)"' "$content"
}

test_records_null_version_outside_git() {
  git -C "$SOURCE" rev-parse 2>/dev/null && { echo "    copy is inside a git repository"; exit 1; }
  run_installer || exit 1
  local record
  record=$(install_record)
  assert_contains '"version":null' "$record"
  assert_contains '"repository":null' "$record"
  assert_contains '"last_check":0' "$record"
  assert_contains '"latest":null' "$record"
}

test_install_record_is_read_by_update_check() {
  make_tagged_git_copy
  run_installer || exit 1
  local output
  output=$(bash "$UPDATE_SCRIPT" check --install-dir "$CLAUDE_DIR/skills/forge")
  assert_contains '"installed":"v1.2.3"' "$output"
  assert_contains '"check":"skipped"' "$output"
}

# ── Exécution ─────────────────────────────────────────────────────────────────

# Outil requis par l'installeur courant : node pour install.sh, powershell.exe pour install.ps1.
required_tool() {
  case $INSTALLER in
    sh) printf 'node' ;;
    ps1) printf 'powershell.exe' ;;
  esac
}

run_test() {
  local label="install.$INSTALLER — $2"
  if ! command -v "$(required_tool)" > /dev/null 2>&1; then
    SKIPPED=$((SKIPPED + 1))
    echo "  skip $label ($(required_tool) absent)"
    return
  fi
  setup_sandbox
  if ( set -u; $1 ); then
    PASSED=$((PASSED + 1))
    echo "  ok   $label"
  else
    FAILED=$((FAILED + 1))
    echo "  FAIL $label"
  fi
  teardown_sandbox
}

run_common_tests() {
  run_test test_copies_skills_and_hook_into_home "copie les skills et le hook dans le HOME jetable"
  run_test test_adds_forge_rule_and_precompact_hook "ajoute la règle .forge et le hook PreCompact à settings.json"
  run_test test_keeps_unrelated_settings "garde les réglages et règles étrangers à forge"
  run_test test_second_install_adds_nothing_twice "une seconde installation n'ajoute ni règle ni hook en double"
  run_test test_records_tag_and_origin_from_git_copy "enregistre le tag et le dépôt d'origine d'une copie git"
  run_test test_records_null_version_outside_git "enregistre une version et un dépôt nuls hors dépôt git"
  run_test test_install_record_is_read_by_update_check "update.sh check lit l'install.json produit"
  run_test test_writes_settings_without_bom "écrit settings.json sans BOM UTF-8"
  run_test test_keeps_unrelated_settings_from_file_with_bom "garde les réglages étrangers d'un settings.json écrit avec BOM"
}

INSTALLER=sh
run_common_tests

INSTALLER=ps1
run_common_tests
run_test test_writes_install_record_without_bom "écrit install.json sans BOM UTF-8"

echo "$PASSED passed, $FAILED failed, $SKIPPED skipped"
[ $FAILED -eq 0 ]
