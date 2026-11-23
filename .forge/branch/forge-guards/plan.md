# Plan — forge-guards
**Objective:** Ajouter au skill forge deux garde-fous (script de déploiement SQL toujours écrit et complet ; session parente qui n'écrit jamais dans un projet lié), nommer la branche liée d'après la tâche déléguée sans jamais nommer le parent, et documenter le hook `linked-write-guard.sh`.
**Date:** 2026-11-23
**Estimate:** ≈ 52 files · ≈ 41 min (11-73) · indicative
**Origin:** T7, T8, T9, T10

## Tasks

### T1 — Garde-fou du script de déploiement SQL ← parent T7
**Effort:** S
**Estimated time:** ≈ 6 min (1-10)
**Actual time:** —
**Files:** `skills/forge/hooks/plan-hook.sh`, `tests/plan-hook.test.sh`, `skills/forge/commands/deployment-sql.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Ajouter `check_deployment_script` dans `plan-hook.sh`, appelée à chaque écriture de `plan.md` : relever les chemins `output/….sql` cités sous `## Deployment`, sauf le script de déploiement lui-même, puis ne garder que les fichiers qui existent. Aucun `output/*-deployment-script.sql` → `forge plan-hook: deployment script missing — SQL step files written: … — apply commands/deployment-sql.md now.` Fichier écrit absent du script → `forge plan-hook: deployment script incomplete — SQL step files not referenced: … — apply commands/deployment-sql.md now.` Le message part même sans réécriture du plan, à côté du compte rendu habituel. Tests écrits en parallèle (dépôts jetables, `bash tests/plan-hook.test.sh`) : « missing » signalé ; « missing » encore signalé sans réécriture ; rien quand le script cite tous les fichiers écrits ; rien quand le fichier d'étape n'existe pas encore ; « incomplete » avec le seul fichier non cité. Remplacer la section « Format » de `deployment-sql.md` par le texte du mandat (sommaire exécutable : formes `script` / `query`, colonne « script ou objet » dans l'en-tête, étape sans script écrit citée « sans script à ce jour »). Étendre le déclencheur de « Script de déploiement SQL » dans `p5-resume.md` : fichier SQL d'une étape déjà listée écrit, ou message `deployment script missing` / `… incomplete` du hook. Ajouter la puce README en français et en anglais, puis les entrées `### Changed` et `### Fixed` du CHANGELOG sous `[Unreleased]`, textes du mandat.
[x] check_deployment_script ajouté, 5 tests (36/36 verts), format et déclencheur du script de déploiement, README, CHANGELOG

### T2 — Garde-fou : le parent n'écrit jamais dans un projet lié ← parent T8
**Effort:** M
**Estimated time:** ≈ 6 min (2-11)
**Actual time:** —
**Files:** `skills/forge/hooks/linked-write-guard.sh`, `tests/linked-write-guard.test.sh`, `skills/forge/commands/delegation.md`, `skills/forge/phases/p5-resume.md`, `install/install.sh`, `install/install.ps1`, `tests/install.test.sh`, `CHANGELOG.md`
**Description:** Créer le hook `linked-write-guard.sh`, en `PreToolUse` sur `Edit|Write|MultiEdit|NotebookEdit`, qui lit le JSON du hook par `../scripts/json.sh`. Appel d'un sous-agent (`agent_id` présent) → autorisé. ROOT = racine git du `cwd` qui contient `.forge/`, sinon autorisé. Fichier visé hors de ROOT, dans un dossier dont un parent contient `.forge/project.md` → refusé (`permissionDecision: deny`), raison `forge: <fichier> belongs to the forged project <dossier>, outside ROOT — the parent never writes there: add the task to the plan, then delegate (« Délégation — projet lié »).` Exceptions : `.forge/branch/*/brief.md` et `.forge/branch/*/log.md` de ce projet. La limite est documentée dans l'en-tête du hook : une écriture par commande shell (`sed -i`, `git worktree add`) n'est pas couverte. Tests écrits en parallèle (`tests/linked-write-guard.test.sh`, dossiers jetables) : écriture dans un autre projet forgé refusée ; `brief.md` / `log.md` du projet lié autorisés ; sous-agent autorisé ; fichier sous ROOT autorisé ; dossier hors ROOT non forgé autorisé. Déclaration du hook dans les deux installeurs, de façon idempotente (ancienne entrée retirée avant ajout). La logique vit dans `install/install.sh` et `install/install.ps1` : les lanceurs racine `install-unix.sh` / `install-windows.bat` cités par le mandat ne font que les appeler. `tests/install.test.sh` vérifie la déclaration et l'absence de doublon à la réinstallation. Ajouter la règle sous les INVARIANT de « Délégation — projet lié » dans `delegation.md`, et la même règle en une ligne dans le déclencheur de `p5-resume.md`. Ajouter l'entrée `### Added` du CHANGELOG, texte du mandat.
[x] linked-write-guard.sh et 7 tests verts, déclaré dans install.sh / install.ps1 (47/47), règle dans delegation.md et p5-resume.md, CHANGELOG

### T3 — Branche liée nommée d'après la tâche, lien tenu par le plan parent, enfant sans référence au parent ← parent T9
**Effort:** M
**Estimated time:** ≈ 6 min (2-12)
**Actual time:** —
**Files:** `skills/forge/commands/delegation.md`, `skills/forge/commands/delegated-mode.md`, `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `skills/forge/commands/engrave.md`, `skills/forge/SKILL.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Nommage de `<LINKED_BRANCH>` par la règle de l'étape 3 de la « Garde de sécurité » de `SKILL.md` (objectif = titre de la tâche déléguée ou objet commun du mandat, collision vérifiée dans le projet lié), sans préfixe `<PARENT_FOLDER>/`. Champ de tâche `**Linked branch:** <LINKED_REL> @ <branche>` sous `**Files:**`, écrit à l'entrée de la tâche au plan, affiché dans le gabarit de la question `Plan`, écrit à `mark` pour une tâche ancienne, lu par la délégation, partagé = `reuse`. Mandat réduit à `## Origin` + `**Tasks:**` + tâches déléguées, sans `**Parent:**`, `**Branch:**` ni brief parent. Règle « l'enfant ne nomme jamais le parent » (exception : référence strictement nécessaire, écrite dans la tâche) dans `delegation.md`, `delegated-mode.md`, `p4-plan.md`, `p5-resume.md`. Log enfant `Opened by delegation · T…`. `**Origin:**` du plan lié réduit aux tâches. Vérification de `engrave.md`, `swarm.md`, scripts, tests. README fr/en, CHANGELOG `### Changed` (texte du mandat). Nettoyage du plan et du log de cette branche.
[x] Branche liée nommée par la règle de la garde, champ **Linked branch:**, mandat sans parent, invariant « le lié ne nomme jamais le parent », README fr/en, CHANGELOG ; plan/log nettoyés ; tests plan-hook 36, time-calibrate 37, status 33 verts

### T4 — Documenter le hook linked-write-guard dans la structure du projet ← parent T10
**Effort:** XS
**Estimated time:** ≈ 4 min (1-6)
**Actual time:** —
**Files:** `.forge/project.md`, `README.md`, `README.fr.md`
**Description:** Arborescence de `.forge/project.md` et des deux README : ajout de `skills/forge/hooks/linked-write-guard.sh` (écriture de la session parente dans un projet lié refusée) et de `tests/linked-write-guard.test.sh`, au même format que les hooks et tests existants.
[x] linked-write-guard.sh et son test ajoutés aux arborescences de project.md, README.md, README.fr.md

### T5 — Worktree d'un projet lié retiré automatiquement une fois sa branche fusionnée ← parent T11
**Effort:** S
**Estimated time:** ≈ 6 min (2-11)
**Actual time:** —
**Files:** `skills/forge/scripts/linked-worktree-cleanup.sh`, `tests/linked-worktree-cleanup.test.sh`, `skills/forge/commands/engrave.md`, `skills/forge/commands/closure.md`, `skills/forge/commands/delegation.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Nouveau script `linked-worktree-cleanup.sh --linked <dossier> --branch <branche>`, sortie JSON `{"worktree":…,"status":"removed|kept","reason":…}` : retire le worktree de la branche seulement si ce n'est pas `<LINKED>` lui-même, si son working tree est propre et si la branche est fusionnée dans la branche par défaut du projet lié, locale ou `origin/<défaut>` après `fetch` ; `git worktree remove` sans `--force`. Sinon gardé, raison `not merged`, `uncommitted changes`, `main working tree`, `git error`. Appel automatique dans `engrave.md` (livraison relayée, après un `run` du projet lié qui a fusionné sa branche, ligne `worktree` au compte rendu) et `closure.md` (clôture de la branche parente, chaque branche liée des notes `delegated to`, worktrees gardés listés). Consigne manuelle `git worktree remove …` retirée de `delegation.md`. Tests écrits en parallèle (`tests/linked-worktree-cleanup.test.sh`, dépôts jetables) : fusionnée et propre → retiré ; non fusionnée → `not merged` ; modifications non commitées → gardé ; dossier principal → jamais retiré ; fusion seulement distante → retiré. README fr/en, CHANGELOG `### Added` (texte du mandat).
[x] linked-worktree-cleanup.sh (statut absent ajouté : aucun worktree pour la branche), 7 tests verts ; « Retrait du worktree lié » dans engrave.md, étape 4 de closure.md, rappel manuel retiré de delegation.md ; README fr/en, CHANGELOG

### T6 — Temps réel détaillé par poste, en tête du plan et par tâche ← parent T12
**Effort:** S
**Estimated time:** ≈ 6 min (1-10)
**Actual time:** —
**Files:** `skills/forge/hooks/plan-hook.sh`, `tests/plan-hook.test.sh`, `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Option C retenue et précisée (agent en tête, aucun script testé touché hors du hook). En-tête `**Actual:**` sous `**Estimate:**`, écrit par `plan-hook.sh` à chaque écriture du plan depuis `time-aggregate.sh` sur la branche : `≈ <total> min · agent <a> min (dont <c> min checks) · human <h> min (<n> questions, <q> min) · fixed <f> min (delegate setup <s> min, merge <m> min) · delegates <d> min in parallel`, total = agent + humain (vérifications et fusion comprises dans le temps d'agent, mise en route dans celui des délégués, hors total) ; poste sans mesure → `—` ; ` · partial (<raison>)` ; sans journal → aucune ligne. Par tâche : `**Actual time:** ≈ <agent> min agent (dont <c> min checks) · human <h> min (<n> questions) · <f> files · total ≈ <agent + human> min`, premier nombre et motif `min checks` lus par `time-calibrate.sh` inchangé. `**Total**` du `## Summary` à 0 tâche mesurée → `see **Actual:**`. Tests en parallèle, gabarits p4/p5, README fr/en, CHANGELOG `### Added`.
[x] En-tête **Actual:** ventilé et réel par tâche ventilé écrits par plan-hook.sh, Total renvoyant à Actual ; 8 tests ajoutés (plan-hook 44/44, time-calibrate 37, time-aggregate 84, metrics 9, status 33 verts) ; p4, p5, README fr/en, CHANGELOG

### T7 — Ligne Actual de la branche calculée à la livraison, même forme que la ligne de tâche, libellés en anglais ← parent T13
**Effort:** S
**Estimated time:** ≈ 7 min (2-13)
**Actual time:** —
**Files:** `skills/forge/hooks/plan-hook.sh`, `tests/plan-hook.test.sh`, `skills/forge/scripts/engrave.sh`, `tests/engrave.test.sh`, `skills/forge/commands/engrave.md`, `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** `plan-hook.sh` n'écrit plus la ligne de branche `**Actual:**` (ligne existante gardée, renvoi `see **Actual:**` du `**Total**` conservé quand elle existe). `engrave.sh run` l'écrit dans `plan.md` au moment où il écrit `metrics.json`, avant le `git add` ; la clôture fait de même via `metrics.sh --event closure` ; remplacée sans doublon, sous `**Estimate:**` à défaut sous `**Date:**`. Format : `≈ <a> min agent (incl. <c> min checks) · human <h> min (<n> questions, <q> min) · fixed <f> min (delegate setup, merge) · delegates <d> min in parallel · total ≈ <a + h> min`, poste non mesuré `—`, ` · partial (<raison>)`, sans journal aucune ligne. Ligne de tâche : `dont` → `incl.`. `time-calibrate.sh` inchangé, test de lecture avec `incl.`. Tests plan-hook et engrave en parallèle ; engrave.md, p4, p5, README fr/en, CHANGELOG (entrée `### Added` de T12 réécrite, texte du mandat).
[x] Ligne **Actual:** écrite par metrics.sh (livraison avant git add, clôture), plus par plan-hook.sh ; « incl. » ; tests plan-hook 41, metrics 19, engrave 40, time-calibrate 37 verts

## Risks
- `p5-resume.md` et `CHANGELOG.md` sont touchés par T1 et T2 : ils sont édités l'un après l'autre, dans le même plan, sans conflit.
- Les noms de fichiers des installeurs diffèrent du mandat (`install/install.sh`, `install/install.ps1` au lieu des lanceurs racine) : même intention, fichiers où vit la fusion de `settings.json`.
- `linked-write-guard.sh` s'exécute avant chaque écriture de fichier : coût en processus à garder minimal sous Git Bash (sortie immédiate sans `.forge/` dans le `cwd`).
- `README.md` et `README.fr.md` sont touchés par T3 et T4 : édités l'un après l'autre, dans le même plan.
- Le chemin du worktree change avec le nom : les worktrees ouverts sous l'ancien nom préfixé restent lus par `engrave.md` via la note `delegated to`.

## Deployment
None

## Summary
| Task | Effort | Files | Estimated | Actual | Status |
|---|---|---|---|---|---|
| T1 — Garde-fou script de déploiement SQL | S | 7 | ≈ 6 min | — | [x] |
| T2 — Garde-fou écriture dans un projet lié | M | 8 | ≈ 6 min | — | [x] |
| T3 — Branche liée nommée d'après la tâche, lien tenu par le plan parent, enfant sans référence au parent ← parent T9 | M | 9 | ≈ 6 min | — | [x] |
| T4 — Documenter le hook linked-write-guard dans la structure du projet ← parent T10 | XS | 3 | ≈ 4 min | — | [x] |
| T5 — Worktree d'un projet lié retiré automatiquement une fois sa branche fusionnée ← parent T11 | S | 8 | ≈ 6 min | — | [x] |
| T6 — Temps réel détaillé par poste, en tête du plan et par tâche ← parent T12 | S | 7 | ≈ 6 min | — | [x] |
| T7 — Ligne Actual de la branche calculée à la livraison, même forme que la ligne de tâche, libellés en anglais ← parent T13 | S | 10 | ≈ 7 min | — | [x] |
| **Total** (0/7 measured) | | | — | — | |
