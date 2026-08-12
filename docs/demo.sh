#!/usr/bin/env bash
# Replays forge's own output for the README demo, with chosen timings.
# Regenerate the GIF with: vhs docs/demo.tape   (see docs/README.md for prerequisites)
#
# Every line printed below is reproduced verbatim from the skill's phases.
# Never embellish: a reconstructed demo is fine, a demo showing behaviour the
# tool does not have is not.

set -u

BLUE=$'\033[38;5;39m'
GREY=$'\033[38;5;245m'
GREEN=$'\033[38;5;114m'
BOLD=$'\033[1m'
OFF=$'\033[0m'

prompt() {
  printf '\n%s>%s ' "$BLUE" "$OFF"
  local text="$1" i
  for (( i = 0; i < ${#text}; i++ )); do
    printf '%s' "${text:i:1}"
    sleep 0.07
  done
  printf '\n\n'
  sleep 0.6
}

line() { printf '%s\n' "$1"; sleep 0.16; }
pause() { sleep "$1"; }

clear
pause 0.8

prompt "/forge"

line "${BOLD}Last session :${OFF} decision log split out of the brief; State 3 migrates"
line "dated entries automatically, on resume only the last 10 are read."
pause 0.5
line ""
line "  ${GREY}Task                              Effort   Status${OFF}"
line "  ${GREY}────────────────────────────────  ──────   ──────${OFF}"
line "  T1 — Bounded log read             S        ${GREEN}[x]${OFF}"
line "  T2 — Root installers              XS       [ ]"
line "  T3 — MIT licence                  XS       [ ]"
line ""
pause 1.6
line "Ready to start with T2?"
pause 1.4

prompt "go"

line "T2 forged."
pause 0.3
line ""
line "  • ${BOLD}install-windows.bat${OFF} — carries the -ExecutionPolicy Bypass that is the"
line "    real friction on Windows, exit code propagated."
line "  • ${BOLD}install-unix.sh${OFF} — executable bit versioned, so ./install-unix.sh works"
line "    straight after a clone."
line ""
pause 1.2
line "  ${GREY}Task                              Effort   Status${OFF}"
line "  ${GREY}────────────────────────────────  ──────   ──────${OFF}"
line "  T2 — Root installers              XS       ${GREEN}[x]${OFF}"
line ""
pause 1.8

prompt "grave master"

line "${BOLD}Shipping — grave master${OFF}"
line ""
line "  ${GREY}#   Action     Detail${OFF}"
line "  ${GREY}──  ────────   ─────────────────────────────────────────────${OFF}"
line "  1   add        branch dev"
line "  2   commit     \"Root launchers install-windows.bat and install-unix.sh\""
line "  3   push       origin/dev"
line "  4   merge      dev → master"
line "  5   push       origin/master"
line "  6   checkout   back to dev"
line ""
pause 1.6
line "No git command — git add included — runs before you confirm."
line ""
line "Run this sequence? OK?"
pause 3.5
