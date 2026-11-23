## Origin
**Tasks:** T13

### Delegated tasks

#### T13 — Ligne Actual de la branche calculée à la livraison, même forme que la ligne de tâche, libellés en anglais (dépôt forge)
**Effort:** S
**Files:** `skills/forge/hooks/plan-hook.sh`, `tests/plan-hook.test.sh`, `skills/forge/scripts/engrave.sh`, `tests/engrave.test.sh`, `skills/forge/commands/engrave.md`, `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Constat : la ligne `**Actual:**` de branche, recalculée par `plan-hook.sh` à chaque écriture du plan, fait annoncer « plan.md rewritten » presque à chaque modification et lance `time-aggregate.sh` à chaque fois ; son format diffère de la ligne de tâche ; le mot « dont » est en français dans des libellés anglais.
- Moment du calcul : la ligne de branche n'est plus écrite par `plan-hook.sh`. `engrave.sh run` l'écrit dans `plan.md` au moment où il écrit `metrics.json`, avant le `git add` (elle part avec le commit) ; la clôture fait de même via `metrics.sh --event closure`. Entre deux livraisons, la ligne garde la valeur de la dernière livraison.
- Format aligné sur la ligne de tâche, total à la fin : `**Actual:** ≈ <a> min agent (incl. <c> min checks) · human <h> min (<n> questions, <q> min) · fixed <f> min (delegate setup, merge) · delegates <d> min in parallel · total ≈ <a + h> min`. Poste non mesuré → `—` ; ` · partial (<raison>)` en fin de ligne si la mesure est incomplète ; sans journal de mesure, ligne absente.
- Ligne de tâche : `(dont … checks)` devient `(incl. … checks)` ; le reste inchangé : `≈ <a> min agent (incl. <c> min checks) · human <h> min (<n> questions) · <f> files · total ≈ <a + h> min`.
- Calibrage : `time-calibrate.sh` non modifié ; un test vérifie qu'il lit toujours le premier nombre, `<f> files` et `<c> min checks` avec `incl.`.
- Tests : `plan-hook.test.sh` — l'écriture du plan ne touche plus la ligne `**Actual:**`, la ligne de tâche porte `incl.` ; `engrave.test.sh` — ligne écrite à la livraison et présente dans le commit, remplacée sans doublon à la livraison suivante, absente sans journal, `partial` si mesure incomplète.
- `engrave.md` (synthèse de mesure), `p4-plan.md` (gabarit, qui écrit quoi), `p5-resume.md` (tableau d'avancement), README français et anglais. `CHANGELOG.md`, `[Unreleased]` — entrée `### Added` de T12 réécrite : « The branch's actual time — same shape as the task line, total last (agent incl. checks, human with questions, fixed costs, delegates in parallel) — is written into the plan header at engrave and closure time, not on every plan write. »


## Objective
Écrire la ligne de temps réel de la branche au moment de la livraison et de la clôture plutôt qu'à chaque écriture du plan, sous la même forme que la ligne de tâche (total à la fin), avec des libellés entièrement en anglais (« incl. » au lieu de « dont »).

## Scope & rules
- Le projet lié peut être public et le parent privé : aucune donnée du parent dans ce dépôt, sauf une référence strictement nécessaire à une tâche, écrite dans la tâche.
