#!/bin/bash
# Hook de nouvelle version : UserPromptExpansion sur forge|forge-clickup, déclaré asyncRewake par les installeurs.
#   Lancé en arrière-plan à chaque /forge, il ne retarde rien ; il cherche le dernier tag publié
#   Version plus récente que l'installée et non ignorée (update.sh dismiss) → sortie 2 : Claude Code réveille Claude,
#   qui écrit les lignes reçues (règle « Message du hook update-notice » de SKILL.md)
#   Rien de nouveau, version ignorée, hors réseau → sortie 0, rien d'écrit, Claude n'est pas réveillé
# Entrée : JSON du hook sur l'entrée standard, jamais lu
# Usage : update-notice.sh [--install-dir <dossier de install.json>] (défaut : dossier du skill, parent de hooks/)

readonly WAKE_CLAUDE=2
readonly SKILL_FOLDER="$(dirname "${BASH_SOURCE[0]}")/.."
INSTALL_DIR="$SKILL_FOLDER"
[ "${1:-}" = "--install-dir" ] && INSTALL_DIR=$2

source "$SKILL_FOLDER/scripts/json.sh" 2>/dev/null || exit 0
source "$SKILL_FOLDER/scripts/latest-version.sh" 2>/dev/null || exit 0

write_notice() {
  local installed=""
  [ -n "$INSTALLED_VERSION" ] && installed=" (installed: $INSTALLED_VERSION)"
  cat >&2 <<END
forge update-notice — before any other action of this turn, write these three lines to the user, in their language, then go on:
New forge version available: $LATEST_VERSION$installed.
To update, type: \`update the forge\` (French: \`mets à jour la forge\`)
To stop seeing this message, type: \`ignore this version\` (French: \`ignore cette version\`)
Write each command in the user's language only.
END
}

main() {
  load_install_file
  refresh_latest_version || exit 0
  is_newer_version "$LATEST_VERSION" "$INSTALLED_VERSION" || exit 0
  [ "$LATEST_VERSION" = "$DISMISSED_VERSION" ] && exit 0
  write_notice
  exit $WAKE_CLAUDE
}

main
