# Test report — linked-project (T7)

**Date:** 2026-09-16
**Fixtures:** three throwaway repositories in the session scratchpad — `parent-repo` (branch `feat-greeting`, plan of three tasks, T1 done), `linked-repo` (forged, `master`, shell library with `test.sh`), `unforged-repo` (no `.forge/`).
**Mandate:** T2 (`greet` function, feasible) and T3 (`config/settings.yaml` key — file absent in the linked repo, expected to block).

## Checks

| # | Check | Result |
|---|---|---|
| 1 | Refusal when `.forge/` is absent (`unforged-repo`) | pass |
| 2 | Real branch required on the parent (`feat-greeting`) | pass |
| 3 | Branch `feat-greeting` created in the linked repo from `master` | pass |
| 4 | Child brief: `## Origin` + `### Delegated tasks` copied verbatim + parent brief unchanged | pass |
| 5 | Child log opened with `Opened from <parent> · T2, T3` | pass |
| 6 | Parent tasks annotated `delegated to <linked> @ feat-greeting`, status untouched | pass |
| 7 | Sub-agent launched with the fixed prompt only | pass |
| 8 | Child plan derived from the mandate only, `**Origin:**` header, `← parent T<n>` titles | pass |
| 9 | Relay loop: 3 `FORGE_QUESTION` (Approach, Plan, Mode) relayed verbatim, answered via `FORGE_ANSWER` | pass |
| 10 | `Hammer the plan` absent from the Mode question | pass |
| 11 | `FORGE_DONE`: one task done, one blocked with reason, `out_of_mandate: none`, files listed | pass |
| 12 | Code written under ROOT only (`lib/greet.sh`, `test.sh`), `bash test.sh` green, no commit | pass |
| 13 | Isolation: nothing written in the session's own repo, nothing read from the parent | pass |
| 14 | Parent return: T2 `[x] delegated · done`, T3 `[!] blocked — <reason>`, one log entry per task | pass |

## Not exercised

- `out_of_mandate` with a real item — the run produced `none`; the format is defined, the parent-side handling (Surveillance des demandes complémentaires) is untested.
- Relay of an open question (`options: none`).
- Sub-agent ending a turn without either block (reminder path, two retries).

## Finding

The child plan's `**Objective:**` came out in English while the user works in French: the sub-agent's only interlocutor is the English fixed prompt. Fixed by adding a `LANGUAGE:` line to the prompt and the matching rule in « Mode délégué ».

## Round-trips

Four sub-agent turns for two delegated tasks: Approach question (T3 file absent), Plan validation, Mode choice, final report. ~60k sub-agent tokens.

## T9 — relayed shipping (added later)

Finding before the first question: the return rule replaced `delegated to <LINKED> @ <BRANCH>` with `delegated · done`, erasing the linked path — the shipping trigger found no linked project. Fixed: the return note keeps `delegated to <LINKED> @ <BRANCH>` in every case (done, blocked, not addressed).
