# Plan — forge-guards
**Objective:** Ajouter au skill forge deux garde-fous (script de déploiement SQL toujours écrit et complet ; session parente qui n'écrit jamais dans un projet lié), nommer la branche liée d'après la tâche déléguée sans jamais nommer le parent, et documenter le hook `linked-write-guard.sh`.
**Date:** 2026-11-23
**Estimate:** ≈ 240 files · ≈ 161 min (44-301) · indicative
**Actual:** ≈ 231.2 min agent (incl. 133.4 min checks) · human 406.5 min (54 questions, 227.0 min) · delegates 2.4 min in parallel · total ≈ 637.7 min · partial (log started after the branch, 13 unmeasured tasks)
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

### T8 — Délégation vers un projet lié non forgé : le délégué le forge sans poser de question
**Effort:** S
**Estimated time:** ≈ 4 min (1-8)
**Actual time:** —
**Files:** `skills/forge/commands/delegation.md`, `skills/forge/commands/delegated-mode.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Étape 1 de « Délégation — projet lié » : `<LINKED>/.forge/` absent ne bloque plus, le projet est noté non forgé (message « is not forged — run `/forge` there first » retiré). Étape 4 : le contrôle « `.forge/project.md` absent du commit de départ » ne s'applique plus à un projet non forgé, worktree créé depuis la branche par défaut. Le délégué forge dans `<LINKED_WORKTREE>` (p0 puis p1, sans `FORGE_QUESTION`) avant le mandat : le parent ne lit jamais le code lié et ne touche pas son working tree. `project.md` et `coding-standards.md` versionnés avec la branche liée. Plusieurs délégations parallèles sur un même projet non forgé : seule la première part, les suivantes attendent sa livraison ou réutilisent sa branche (sinon conflit sur `project.md`). Tableau de délégation : ligne `forge` quand le projet n'est pas forgé. `delegated-mode.md` : `SCOPE: linked` et état `project_init` / `coding_standards_init` → enchaîné sans question, puis le mandat. README fr/en corrigés, CHANGELOG `### Changed` sous `[Unreleased]`.
[x] Projet lié non forgé forgé par le délégué (section dédiée dans delegation.md, puce dans delegated-mode.md, ligne forge du tableau), README fr/en, CHANGELOG ; 16 suites de tests vertes

### T9 — Essaim multi-dépôts : les tâches de projets liés partent en parallèle, proposition imposée par le script
**Effort:** M
**Estimated time:** ≈ 6 min (2-12)
**Actual time:** —
**Files:** `skills/forge/scripts/swarm-status.sh`, `tests/swarm-status.test.sh`, `skills/forge/commands/swarm.md`, `skills/forge/commands/delegation.md`, `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** `swarm-status.sh` : tâche ouverte avec `**Linked branch:**` = unité d'essaim `linked` (même champ = une unité), dans `launchable` / `waiting` / `invalid`, sans simulation de fusion ; deux unités sur un même projet non forgé → seule la première lançable. Tests en parallèle : dépôts différents lançables ensemble, même branche liée = une unité, `**Depends on:**` respecté, tâche déjà déléguée en cours, plan mixte branches filles + liées. `swarm.md` : unité `linked` lancée par les étapes de « Délégation — projet lié » sans confirmation par délégué ; `FORGE_DONE` → « Retour » sans fusion, place libérée → suivante ; colonne `Type` (`child` / `linked`) ; « le parent seul fusionne » pour `child` seulement. Règle de branche : seuil `branch_files` sans objet pour les tâches liées. `p4-plan.md` : `swarm-status.sh` sur le plan rédigé ; ≥ 2 unités lançables → `Validate and launch the swarm` obligatoire en tête, `Validate and chain` décrit « in series ». `p5-resume.md` : étape 8 étendue aux tâches liées ; jamais de tâche liée enchaînée en série quand une place est libre. `delegation.md` : plusieurs tâches vers des projets liés différents → essaim. README fr/en, CHANGELOG `### Changed` sous `[Unreleased]`.
[x] Unités linked dans swarm-status.sh (type, linked, tasks, forged ; --plan pour le brouillon ; type child ajouté aux branches filles), 10 tests ajoutés (34/34) ; swarm.md, p4, p5, delegation.md, README fr/en, CHANGELOG ; 16 suites vertes

### T10 — Livraison : règles .gitignore forge garanties et fichiers locaux retirés de l'index avant tout commit
**Effort:** S
**Estimated time:** ≈ 6 min (1-10)
**Actual time:** —
**Files:** `skills/forge/scripts/engrave.sh`, `tests/engrave.test.sh`, `skills/forge/scripts/checks.sh`, `skills/forge/commands/engrave.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** `engrave.sh run`, action `ignore` avant `add` : appelle `checks.sh` en synchrone — règles `time-log.jsonl` et `input/` ajoutées au `.gitignore` si absentes, `.gitignore` commité avec la livraison ; plus de dépendance à la branche de démarrage de `/forge`. Action `untrack` ensuite : `git rm --cached` de tout `time-log.jsonl` et de tout fichier de `.forge/branch/*/input/` encore suivis, fichiers gardés sur disque. Statuts `done` / `skipped` (`rules present`, `nothing tracked`) ; `preview` `planned` / `skipped`. Livraison relayée des projets liés : même script. `checks.sh` : garde main/master conservée au démarrage, en-tête complété. Hook inchangé. Tests en parallèle : `.gitignore` sans règle → règles commitées, journal et `input/` absents du commit ; déjà suivis → retirés de l'index, présents sur disque ; plus rien à commiter après ajout au journal ; projet sain → `skipped` ; `metrics.json` toujours commité. `engrave.md` : actions `ignore` et `untrack`. README fr/en, CHANGELOG `### Fixed` ; historique déjà poussé jamais réécrit.
[x] Actions ignore / untrack dans engrave.sh, présentes seulement quand elles ont à faire (projet sain : séquence inchangée) ; checks.sh --dry-run ; tests engrave 46, checks 16 ; engrave.md, README fr/en, CHANGELOG

### T11 — Mesure : une tâche commencée après l'ouverture du journal est mesurée malgré late_start
**Effort:** S
**Estimated time:** ≈ 4 min (1-6)
**Actual time:** —
**Files:** `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`, `CHANGELOG.md`
**Description:** `TASK_WINDOW_PROGRAM` : `late_start` retient son horodatage ; tâche déclarée `late_start` seulement si son `task_start` est antérieur ou égal. Tâche commencée après → mesurée normalement ; mesure de la branche toujours ` · partial (log started after the branch)`. Tests en parallèle : test existant vert (même horodatage → non mesurée) ; tâche après `late_start` → mesurée ; tâche avant → `late_start`. CHANGELOG `### Fixed`.
[x] late_start limité aux tâches commencées avant l'ouverture du journal ; 2 tests ajoutés (time-aggregate 86/86, plan-hook 41, metrics 19) ; CHANGELOG

### T12 — Tests : seuls ceux des fichiers modifiés pendant une tâche, suite complète à la livraison
**Effort:** S
**Estimated time:** ≈ 6 min (1-10)
**Actual time:** —
**Files:** `skills/forge/phases/p5-resume.md`, `skills/forge/commands/engrave.md`, `skills/forge/phases/p0-project.md`, `.forge/project.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** `p5-resume.md` : après chaque tâche, seuls les tests qui couvrent les fichiers modifiés (test du même nom ou qui appelle le fichier) ; jamais la suite complète pendant le développement. `engrave.md` : étape avant `run` — suite complète du projet (ligne `**Full check:**` de `project.md`) ; rouge → échecs affichés, aucune livraison, STOP ; ligne absente → demandée une fois en texte libre, écrite dans `project.md`. `p0-project.md` : `**Full check:**` déduite des scripts de contrôle, à côté de `**Check pattern:**`. `.forge/project.md` de ce dépôt : `**Full check:**` qui lance toutes les suites `tests/*.test.sh`. README fr/en, CHANGELOG `### Changed`.
[x] « Tests d'une tâche » dans p5, « Vérification complète » avant la séquence de livraison dans engrave.md, **Full check:** dans p0 et project.md, README fr/en, CHANGELOG ; texte seul, aucun test ne couvre ces fichiers

### T13 — Worktree lié : retiré aussi quand la branche est fusionnée dans une branche cible de la livraison, commande de retrait affichée quand il est gardé
**Effort:** S
**Estimated time:** ≈ 6 min (1-10)
**Actual time:** —
**Files:** `skills/forge/scripts/linked-worktree-cleanup.sh`, `tests/linked-worktree-cleanup.test.sh`, `skills/forge/commands/engrave.md`, `skills/forge/commands/closure.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** `linked-worktree-cleanup.sh` : option `--merged-into <branche>[,…]` — fusionnée dans la branche par défaut ou dans l'une d'elles, locale ou `origin` après `fetch` → retirée ; toujours sans `--force`, working tree propre obligatoire. `engrave.md` : livraison relayée → `--merged-into` avec les branches cibles du projet lié. Worktree gardé → une ligne toujours affichée : `worktree: kept — <reason> · remove: git -C "<LINKED>" worktree remove "<worktree>"` ; `uncommitted changes` → « commit or discard the changes first » ; `main working tree` → aucune commande. `closure.md` : même ligne à la clôture. Tests en parallèle : fusionnée dans `dev` seule + `--merged-into dev` → retiré ; sans l'option → `not merged` ; fusion sur `origin/dev` seulement → retiré ; non commité + `--merged-into` → gardé. README fr/en, CHANGELOG `### Changed`.
[x] --merged-into dans linked-worktree-cleanup.sh (4 tests, 11/11) ; retrait appelé après tout run lié réussi, fusion ou non, ligne kept avec commande de retrait (engrave.md, closure.md) ; README fr/en, CHANGELOG

### T14 — Vérification complète confiée à la CI quand le projet en a une
**Effort:** S
**Estimated time:** ≈ 4 min (1-8)
**Actual time:** ≈ 7.4 min agent (incl. 7.1 min checks) · human 2.5 min (1 questions) · 21 files · total ≈ 9.9 min
**Files:** `skills/forge/commands/engrave.md`, `skills/forge/phases/p0-project.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** `**Full check:** ci` dans `project.md` : aucune suite lancée en local à la livraison, ligne `Full check: left to CI` au compte rendu. `p0-project.md` : pipeline qui lance les tests à chaque push (`.github/workflows`, `.gitlab-ci.yml`, `Jenkinsfile`…) → `ci` écrit d'office ; pipeline sans tests ou limité aux pull requests → commande locale gardée. `engrave.md` : ligne absente → même détection avant de poser la question, posée seulement sans pipeline de tests. Garde-fou : avec `ci`, livraison qui fusionne dans `master` / `main` → ligne « CI not awaited: `master` was pushed before its result », information seule, jamais bloquante. Tests ciblés par tâche inchangés. README fr/en, CHANGELOG `### Changed`.
[x] Valeur `ci` de **Full check:** (engrave.md, détection dans p0), avertissement sur push done de master / main ; README fr/en, CHANGELOG ; texte seul, aucun test ne couvre ces fichiers

### T15 — Réel d'une tâche liée : mesuré et écrit par le hook, jamais par le modèle
**Effort:** L
**Estimated time:** ≈ 8 min (2-15)
**Actual time:** ≈ 16.7 min agent (incl. 8.3 min checks) · human 2.3 min (1 questions) · 19 files · total ≈ 19.0 min
**Files:** `skills/forge/scripts/task-files.sh`, `skills/forge/scripts/task-marks.sh`, `skills/forge/hooks/plan-hook.sh`, `tests/plan-hook.test.sh`, `skills/forge/scripts/metrics.sh`, `tests/metrics.test.sh`, `skills/forge/scripts/swarm-status.sh`, `tests/swarm-status.test.sh`, `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`, `skills/forge/commands/delegation.md`, `skills/forge/commands/swarm.md`, `skills/forge/commands/delegated-mode.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** `plan-hook.sh`, premier `plan.md` écrit par un délégué : écrit lui-même l'association agent → projet lié (chemin relatif) + branche dans le journal parent ; la marque posée par le modèle n'est plus nécessaire, les anciennes restent lues. Marques de tâche et points d'étape d'un délégué rattachés à son projet : dix dépôts sur la même branche ne se mélangent plus (temps, marques, fichiers). Coche d'une tâche liée dans le plan parent : le hook lit `**Linked branch:**`, mesure les seuls délégués de ce projet (`time-aggregate.sh --project`) et écrit `**Actual time:**` ; sans mesure → `—`, jamais 0.0 ni le temps du parent. Règle unique « tâche déléguée » dans `task-files.sh`, lue par `plan-hook.sh`, `metrics.sh` et `swarm-status.sh` : `**Linked branch:**` ou note de délégation sur toute ligne hors champ. Question à cheval sur deux tours : attente déduite du tour qui l'a ouverte, jamais de durée négative. Ligne `**Actual:**` de la branche : les délégués liés comptent aussi, hors calibrage et hors total. `delegation.md`, `swarm.md`, `delegated-mode.md` : plus aucun réel ni association écrits par le modèle (tokens exceptés). Tests en parallèle : association par le hook, note sur ligne suivante, `Linked branch` sans note, plusieurs dépôts même branche, question coupée par un retour de délégué, ancien journal encore lu. README fr/en, CHANGELOG `### Fixed`.
[x] Association, réel d'une tâche liée et d'une tâche-branche écrits par le hook ; tests plan-hook 50, time-aggregate 93, metrics 21, swarm-status 35, time-calibrate 38 ; hors liste : time-calibrate.sh et p5-resume.md alignés
[x] T15.1 — règle partagée (task-files.sh) et projet d'un délégué (task-marks.sh)
[x] T15.2 — time-aggregate.sh : --project, délégués liés, question à cheval
[x] T15.3 — plan-hook.sh : association, marques par projet, réel d'une tâche liée
[x] T15.4 — metrics.sh, swarm-status.sh, time-calibrate.sh sur la règle partagée
[x] T15.5 — instructions, README, CHANGELOG

### T16 — Temps hors tâche visible, livraison hors de la tâche suivante, estimation issue du plan du délégué
**Effort:** M
**Estimated time:** ≈ 8 min (2-14)
**Actual time:** ≈ 7.3 min agent (incl. 6.2 min checks) · human 0.0 min (0 questions) · 12 files · total ≈ 7.3 min
**Files:** `skills/forge/hooks/plan-hook.sh`, `tests/plan-hook.test.sh`, `skills/forge/scripts/engrave.sh`, `tests/engrave.test.sh`, `skills/forge/scripts/metrics.sh`, `tests/metrics.test.sh`, `skills/forge/commands/delegation.md`, `skills/forge/phases/p4-plan.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Livraison : nouveau point d'étape posé dans le journal après le commit → suite complète et livraison n'entrent plus dans la tâche suivante, ni en temps ni en fichiers. Ligne `**Unplanned**` sous `**Total**` du Summary : temps d'agent de la branche moins celui des tâches mesurées (conflits, correctifs, livraison, travail jamais mis au plan) ; jamais négative, `—` sans mesure. Plan du délégué validé → son nombre de fichiers remonte et remplace l'estimation de la tâche liée parente, gelée seulement à ce moment ; avant : estimation marquée indicative. Tests en parallèle : tâche après livraison, Unplanned avec et sans mesure, estimation liée remplacée une seule fois. `delegation.md`, `p4-plan.md`, README fr/en, CHANGELOG `### Changed`.
[x] Point d'étape après livraison (heure gardée si tâche en cours), ligne Unplanned par metrics.sh, estimation liée reprise une fois ; tests plan-hook 54, engrave 50, metrics 25 ; task-marks.sh partagé (hors liste)

### T17 — Dossier input/ créé aussi pour une branche liée ou fille
**Effort:** S
**Estimated time:** ≈ 4 min (1-6)
**Actual time:** ≈ 3.7 min agent (incl. 0.0 min checks) · human 5.7 min (2 questions) · 3 files · total ≈ 9.4 min
**Files:** `skills/forge/commands/delegation.md`, `skills/forge/commands/swarm.md`, `CHANGELOG.md`
**Description:** `delegation.md` étape 8 : dossier vide `input/` de la branche liée créé avec le mandat, dans son worktree. `swarm.md` étape 5 : même dossier créé avec le brief d'une branche fille. `linked-write-guard` inchangé : un dossier vide n'est pas une écriture de fichier. `output/` inchangé : créé au premier fichier généré. CHANGELOG `### Fixed`.
[x] Dossier vide `input/` créé avec le mandat (delegation.md) et avec le brief d'une branche fille (swarm.md), CHANGELOG ; texte seul, aucun test ne couvre ces fichiers

### T18 — Mesure : un message reçu pendant une commande ne coupe plus le tour
**Effort:** S
**Estimated time:** ≈ 3 min (1-6)
**Actual time:** ≈ 5.6 min agent (incl. 2.0 min checks) · human 157.7 min (1 questions) · 3 files · total ≈ 163.3 min
**Files:** `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`, `CHANGELOG.md`
**Description:** Un message arrivé sur un tour ouvert ne le coupe plus quand une commande commencée avant lui (heure de fin moins `duration_ms`) se termine après : le temps entre la dernière activité et le message est rendu au tour. Plusieurs messages pendant la même commande : chaque intervalle compté une seule fois. Échap et message sans commande en cours : comportement actuel gardé, tests d'interruption existants inchangés. Même règle dans les deux calculs (branche et tâche), écrite une seule fois dans les fonctions communes ; temps des questions toujours retiré. Tests en parallèle : un message, deux messages, Échap, calcul par tâche, commande de délégué ignorée. Contrôle sur le journal réel : T8 doit passer de 5,1 à environ 6,9 min. CHANGELOG `### Fixed`. Les réels déjà écrits dans le plan ne changent pas.
[x] Écart avant un prompt rendu quand une commande commencée avant lui se termine après ; journal réel : T8 5,1 → 6,9 min ; tests time-aggregate 99, metrics 25, plan-hook 54, time-mark 15

### T19 — Projet lié : le délégué lance la suite complète une fois, avant FORGE_DONE
**Effort:** S
**Estimated time:** ≈ 5 min (2-9)
**Actual time:** ≈ 0.8 min agent (incl. 0.0 min checks) · human 0.0 min (0 questions) · 8 files · total ≈ 0.8 min
**Files:** `skills/forge/commands/delegated-mode.md`, `skills/forge/commands/delegation.md`, `skills/forge/commands/engrave.md`, `skills/forge/phases/p0-project.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** `SCOPE: linked` seulement : toutes les tâches traitées → commande `**Full check:**` du projet lié lancée une fois sous ROOT, avant `FORGE_DONE` ; `ci` ou `none` → rien n'est lancé. Ligne absente → détection de `p0-project.md`, écrite dans le `project.md` du projet lié ; rien trouvé → `none` pour ce retour, aucune question. Échec causé par les tâches du mandat → corrigé, suite relancée ; impossible à corriger ou extérieur au mandat → rien n'est touché hors mandat, l'échec remonte. `FORGE_DONE` gagne une ligne `full_check:` (`passed`, `left to CI`, `none` ou `failed — <échec en une ligne>`), recopiée par le parent dans la note de la tâche. Livraison relayée : un échec noté s'affiche dans la question `Linked`, l'utilisateur décide ; jamais bloquant d'office. Textes corrigés dans `engrave.md`, `p5-resume.md`, `p0-project.md`. Branches filles du même dépôt inchangées. README fr/en, CHANGELOG `### Fixed`. Texte seul : aucun test ne couvre ces fichiers.
[x] Suite complète du projet lié lancée une fois par le délégué, résultat `full_check` gardé dans la note et rappelé à la livraison ; suite impossible à lancer → `failed — not run` ; texte seul, aucun test ne couvre ces fichiers, non essayé avec un vrai délégué

### T20 — Mesure : pause humaine de plus de 60 min comptée 3 min, de plus de 6 h comptée 0
**Effort:** S
**Estimated time:** ≈ 4 min (1-7)
**Actual time:** ≈ 2.9 min agent (incl. 1.5 min checks) · human 4.0 min (2 questions) · 5 files · total ≈ 6.9 min
**Files:** `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Écart avant un message humain, ou attente de réponse à une question : jusqu'à 60 min inclus → durée réelle ; plus de 60 min et jusqu'à 6 h incluses → 3 min ; plus de 6 h → 0 (règle actuelle gardée). Les 3 min sont placées juste avant la réponse : une pause à cheval sur deux tâches n'est comptée qu'une fois. Question : toujours comptée dans le nombre de questions, son attente toujours retirée en entier du temps d'agent. Même règle pour la branche et pour la tâche, écrite une seule fois. Les tests « plus de 6 h → 0 » restent inchangés ; seul le test « 6 h tout juste » change de résultat (360 → 3 min). Nouveaux tests : 60 min tout juste, plus de 60 min, question, pause à cheval sur deux tâches. README fr/en, CHANGELOG `### Changed`. Les réels déjà écrits dans le plan ne changent pas.
[x] Plus de 60 min et jusqu'à 6 h → 3 min juste avant la réponse, plus de 6 h → 0 ; tests time-aggregate 104, metrics 25, plan-hook 54, time-mark 15

### T21 — Règles de tests retirées du skill, portées par les fichiers du projet
**Effort:** M
**Estimated time:** ≈ 7 min (2-13)
**Actual time:** ≈ 17.9 min agent (incl. 10.5 min checks) · human 165.5 min (3 questions) · 11 files · total ≈ 183.4 min
**Files:** `skills/forge/commands/engrave.md`, `skills/forge/commands/delegated-mode.md`, `skills/forge/commands/delegation.md`, `skills/forge/commands/swarm.md`, `skills/forge/phases/p0-project.md`, `skills/forge/phases/p5-resume.md`, `skills/forge/scripts/engrave.sh`, `skills/forge/scripts/metrics.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/coding-standards.md`, `.forge/project.md`
**Description:** Livraison : « Vérification complète » retirée de `engrave.md`, avec la détection de CI, la question sur la commande et les lignes du compte rendu ; `grave` ne lance plus aucun test. Tâche : « Tests d'une tâche » retirée de `p5-resume.md` ; le skill applique les règles du projet, lues au démarrage d'une tâche. Projet lié : « Suite complète du projet lié » retirée de `delegated-mode.md`, ainsi que `full_check` du `FORGE_DONE`, de la note parente et de la question `Linked`. Essaim : à la fusion avec conflit, « vérification complète verte » devient « vérifications demandées par le projet vertes ». `p0-project.md` : `**Full check:**` n'est plus détectée, demandée ni écrite ; une ligne existante reste, sans effet ; `**Check pattern:**` gardée (mesure seule). README fr/en alignés, commentaires de `engrave.sh` et `metrics.sh` mis à jour, CHANGELOG `### Removed` sous `[Unreleased]`, entrées publiées inchangées. Dépôt forge : section `## Tests` dans `.forge/coding-standards.md`, ligne `**Full check:**` de `.forge/project.md` remplacée par une puce « Suite complète des tests (à la demande) ».
[x] Règles de tests retirées du skill, écrites dans coding-standards.md et project.md du dépôt forge ; tests engrave 50, metrics 25 ; fichiers .md du skill sans test qui les couvre

### T22 — Tâche-branche et tâche liée : estimation et réel = somme de leurs tâches
**Effort:** M
**Estimated time:** ≈ 5 min (1-11)
**Actual time:** ≈ 11.7 min agent (incl. 4.3 min checks) · human 34.0 min (6 questions) · 9 files · total ≈ 45.7 min
**Files:** `skills/forge/hooks/plan-hook.sh`, `tests/plan-hook.test.sh`, `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `skills/forge/commands/swarm.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/coding-standards.md`
**Description:** Réel à la coche = somme des réels des tâches du plan de la branche fille ou liée, vérifications comprises, même format qu'une tâche classique ; une tâche faite mais non mesurée → `—` ; le temps total du délégué n'est plus utilisé. Estimation avant le plan de la branche : calcul classique sur les fichiers déclarés, `· indicative` ; plan écrit → somme des estimations de ses tâches, une seule fois, puis figée, même mécanisme pour les deux formes. Estimation déjà écrite sans `· indicative` → inchangée. Règle ajoutée à « Règles et mesures universelles » de `.forge/coding-standards.md` : une tâche = vérifications + fichiers × minutes par fichier, réel entre son départ et sa coche, vérifications comprises, plan jamais compris ; une tâche qui en regroupe d'autres = somme de ses tâches, vérifications comprises, rien d'autre ; lancement, fusion et confection du plan ni estimés, ni mesurés à part.
[x] Estimation et réel des tâches-branches et liées = somme des tâches de leur plan ; reste à faire compté à leur estimation écrite ; tests plan-hook 60 ; `delegation.md` touché aussi (nom de la règle) ; textes .md sans test

### T23 — Départ d'une tâche : plan et livraison n'y entrent plus
**Effort:** S
**Estimated time:** ≈ 5 min (1-9)
**Actual time:** ≈ 17.8 min agent (incl. 16.2 min checks) · human 0.0 min (0 questions) · 8 files · total ≈ 17.8 min
**Files:** `skills/forge/hooks/plan-hook.sh`, `skills/forge/scripts/engrave.sh`, `tests/plan-hook.test.sh`, `tests/engrave.test.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Tâche ajoutée au plan sans code modifié depuis le dernier point d'étape → le point d'étape avance à cette écriture, la formulation va dans `**Unplanned**` ; code déjà modifié → heure gardée. Livraison : aucun code non commité → le point d'étape avance, même quand l'empreinte diffère du dernier point d'étape. Limite : une tâche en cours qui n'a encore rien modifié perd son temps d'exploration si une autre entre au plan à ce moment-là.
[x] Point d'étape avancé à l'entrée d'une tâche et à la livraison sans code non commité ; règle commune `is_code_untouched` dans `task-marks.sh` (hors liste) ; tests plan-hook 63, engrave 51, time-mark 15 ; le réel comprend un chronométrage de la suite demandé par l'utilisateur

### T24 — Coûts fixes retirés partout, mesure de lancement et de fusion arrêtée
**Effort:** M
**Estimated time:** ≈ 7 min (2-15)
**Actual time:** ≈ 7.4 min agent (incl. 0.0 min checks) · human 0.0 min (0 questions) · 15 files · total ≈ 7.4 min
**Files:** `skills/forge/commands/swarm.md`, `skills/forge/phases/p4-plan.md`, `skills/forge/references/estimation.json`, `skills/forge/scripts/metrics.sh`, `skills/forge/scripts/time-aggregate.sh`, `skills/forge/scripts/time-calibrate.sh`, `skills/forge/scripts/time-mark.sh`, `tests/metrics.test.sh`, `tests/time-aggregate.test.sh`, `tests/time-calibrate.test.sh`, `tests/time-mark.test.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:** Retirés : `delegate_minutes`, `merge_minutes`, `delegate_setup_minutes`, marques `merge_start` / `merge_done`, partie `fixed` de `**Actual:**`, coût fixe du gain de l'essaim, avec leurs tests. Toutes les autres mesures continuent (agent, vérifications, humain, questions, fichiers, `**Actual:**`, `**Unplanned**`). Gain de l'essaim gardé, sur le travail seul. Seuil d'une branche inchangé à 15 min de travail d'agent, justification réécrite. Anciens `metrics.json` lisibles, champs ignorés.
[x] Coûts fixes retirés (référence, mesure, marques, affichage, gain de l'essaim) ; `time-calibrate.sh` ne lit plus aucun `metrics.json` ; seuil 15 min gardé ; tests metrics 25, time-aggregate 100, time-calibrate 34, time-mark 14, plan-hook 63, engrave 51

### T25 — Vérifications : départ à 0
**Effort:** S
**Estimated time:** ≈ 4 min (1-8)
**Actual time:** ≈ 3.4 min agent (incl. 2.7 min checks) · human 0.0 min (0 questions) · 7 files · total ≈ 3.4 min
**Files:** `skills/forge/references/estimation.json`, `skills/forge/scripts/time-calibrate.sh`, `tests/time-calibrate.test.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** `check_minutes` de référence : 2 → 0 ; dès 20 tâches mesurées, la médiane des vérifications s'ajoute et suit les mesures. Estimations déjà figées inchangées.
[x] `check_minutes` de référence à 0, médiane ajoutée dès 20 tâches mesurées ; tests time-calibrate 34, plan-hook 63

### T26 — Tests en parallèle
**Effort:** M
**Estimated time:** ≈ 11 min (4-23)
**Actual time:** ≈ 50.9 min agent (incl. 43.9 min checks) · human 32.0 min (9 questions) · 22 files · total ≈ 82.9 min
**Files:** `tests/test-runner.sh`, `tests/run-all.sh`, `tests/test-runner.test.sh`, `tests/checks.test.sh`, `tests/engrave.test.sh`, `tests/forge-precompact.test.sh`, `tests/install.test.sh`, `tests/linked-worktree-cleanup.test.sh`, `tests/linked-write-guard.test.sh`, `tests/log-entry.test.sh`, `tests/metrics.test.sh`, `tests/plan-hook.test.sh`, `tests/status.test.sh`, `tests/swarm-status.test.sh`, `tests/time-aggregate.test.sh`, `tests/time-calibrate.test.sh`, `tests/time-hook.test.sh`, `tests/time-mark.test.sh`, `tests/update.test.sh`, `.forge/project.md`, `.forge/coding-standards.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Multiprocessus : les cas d'un même fichier tournent 12 à la fois, chacun dans son processus et son dossier jetable (`TEST_JOBS` pour régler le nombre). `tests/test-runner.sh` : un seul lanceur partagé remplace le `run_test` recopié dans chaque fichier, résultats affichés dans l'ordre, échec si le résultat d'un cas manque. Préparation des dépôts d'essai inchangée, aucun dépôt modèle. `tests/run-all.sh` : lance tous les fichiers l'un après l'autre, sort en échec si l'un est rouge ; devient la commande « Suite complète » de `project.md`. `Check pattern` élargi pour reconnaître `bash "tests/…"`. Contrôle : mêmes 519 tests, trois passages complets sans échec aléatoire, durée avant/après relevée.
[x] Cas lancés 12 à la fois par `tests/test-runner.sh`, suite par `tests/run-all.sh` ; 530 tests verts (les 519 d'avant, tous retrouvés, et 11 du lanceur), trois passages complets sans échec ; 522 s → 110, 151 et 239 s, l'écart venant de la machine (36 à 99 ms par commande git selon le moment, cause non trouvée) ; `engrave` mesuré au même moment : 160 s en série, 34-37 s en parallèle

### T27 — Temps humain et nombre de questions rattachés à la branche du délégué
**Effort:** M
**Estimated time:** ≈ 4 min (1-8)
**Actual time:** ≈ 3.8 min agent (incl. 2.2 min checks) · human 0.0 min (0 questions) · 10 files · total ≈ 3.8 min
**Files:** `skills/forge/hooks/time-hook.sh`, `skills/forge/scripts/time-aggregate.sh`, `skills/forge/commands/swarm.md`, `skills/forge/commands/delegation.md`, `tests/time-hook.test.sh`, `tests/time-aggregate.test.sh`, `tests/metrics.test.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** `time-hook.sh` note dans le journal le nombre de questions de la fenêtre et l'unité déléguée de chacune, lue dans le préfixe `[…]`, jamais le texte. `time-aggregate.sh` : une question d'une branche déléguée compte (temps et nombre) dans cette branche et dans sa tâche en cours, plus jamais dans la branche parente ni dans sa tâche en parallèle. Fenêtre groupée : temps partagé à parts égales entre ses questions, chaque question comptée 1 ; la somme parente + filles reste exacte. Brief, plan et mode de la fille : dans sa ligne `**Actual:**`, hors de ses tâches. Message libre, question sans préfixe et ancien journal : inchangés. Préfixe ajouté à la délégation simple.
[x] Champ `units` journalisé, questions des délégués comptées une seule fois ; écart : question d'un projet lié gardée dans la branche parente, seule à avoir un journal, mais comptée dans la tâche du délégué et non plus dans celle de la parente ; tests time-hook 35, time-aggregate 111, metrics 26, plan-hook 63 ; non essayé dans un essaim réel

### T28 — Nouvelle version annoncée par un hook dès la réponse de GitHub
**Effort:** M
**Estimated time:** ≈ 9 min (4-20)
**Actual time:** ≈ 9.0 min agent (incl. 0.6 min checks) · human 18.7 min (9 questions) · 14 files · total ≈ 27.7 min
**Files:** `skills/forge/hooks/update-notice.sh`, `tests/update-notice.test.sh`, `skills/forge/scripts/latest-version.sh`, `skills/forge/scripts/update.sh`, `tests/update.test.sh`, `install/install.sh`, `install/install.ps1`, `tests/install.test.sh`, `skills/forge/SKILL.md`, `skills/forge/commands/update.md`, `skills/forge/commands/help.md`, `.forge/project.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Hook `update-notice.sh` sur `/forge` et `/forge-clickup` (`UserPromptExpansion`, `asyncRewake`) : cherche le dernier tag à chaque lancement, en arrière-plan ; version plus récente et non ignorée → Claude écrit la ligne, avec les commandes « mets à jour la forge » et « ignore cette version » ; sinon, ou hors réseau, rien. `/forge` ne s'occupe plus des mises à jour : `update.sh check`, délai de 24 h et mention de la ligne d'état retirés. « mets à jour la forge » installe directement ; « ignore cette version » enregistre le refus (`update.sh dismiss`). Règle `SKILL.md` : message du hook écrit avant toute autre action, STOP compris. Essais réels faits avant le code : `asyncRewake` à l'arrêt et après une question, concluants ; `FileChanged` écarté (message d'une seconde).
[x] Hook, bibliothèque `latest-version.sh`, `update.sh` réduit à `run` et `dismiss`, installeurs et textes ; tests update-notice 12, update 15, install 51 ; hook lancé sur le vrai dépôt : 0,9 s, sortie 2 ; `help.md` et `latest-version.sh` ajoutés aux fichiers ; pas encore essayé dans un vrai `/forge`

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
| T8 — Délégation vers un projet lié non forgé : le délégué le forge sans poser de question | S | 5 | ≈ 4 min | — | [x] |
| T9 — Essaim multi-dépôts : les tâches de projets liés partent en parallèle, proposition imposée par le script | M | 9 | ≈ 6 min | — | [x] |
| T10 — Livraison : règles .gitignore forge garanties et fichiers locaux retirés de l'index avant tout commit | S | 7 | ≈ 6 min | — | [x] |
| T11 — Mesure : une tâche commencée après l'ouverture du journal est mesurée malgré late_start | S | 3 | ≈ 4 min | — | [x] |
| T12 — Tests : seuls ceux des fichiers modifiés pendant une tâche, suite complète à la livraison | S | 7 | ≈ 6 min | — | [x] |
| T13 — Worktree lié : retiré aussi quand la branche est fusionnée dans une branche cible de la livraison, commande de retrait affichée quand il est gardé | S | 7 | ≈ 6 min | — | [x] |
| T14 — Vérification complète confiée à la CI quand le projet en a une | S | 5 | ≈ 4 min | ≈ 7.4 min agent (incl. 7.1 min checks) · human 2.5 min (1 questions) · 21 files · total ≈ 9.9 min | [x] |
| T15 — Réel d'une tâche liée : mesuré et écrit par le hook, jamais par le modèle | L | 16 | ≈ 8 min | ≈ 16.7 min agent (incl. 8.3 min checks) · human 2.3 min (1 questions) · 19 files · total ≈ 19.0 min | [x] |
| T16 — Temps hors tâche visible, livraison hors de la tâche suivante, estimation issue du plan du délégué | M | 11 | ≈ 8 min | ≈ 7.3 min agent (incl. 6.2 min checks) · human 0.0 min (0 questions) · 12 files · total ≈ 7.3 min | [x] |
| T17 — Dossier input/ créé aussi pour une branche liée ou fille | S | 3 | ≈ 4 min | ≈ 3.7 min agent (incl. 0.0 min checks) · human 5.7 min (2 questions) · 3 files · total ≈ 9.4 min | [x] |
| T18 — Mesure : un message reçu pendant une commande ne coupe plus le tour | S | 3 | ≈ 3 min | ≈ 5.6 min agent (incl. 2.0 min checks) · human 157.7 min (1 questions) · 3 files · total ≈ 163.3 min | [x] |
| T19 — Projet lié : le délégué lance la suite complète une fois, avant FORGE_DONE | S | 8 | ≈ 5 min | ≈ 0.8 min agent (incl. 0.0 min checks) · human 0.0 min (0 questions) · 8 files · total ≈ 0.8 min | [x] |
| T20 — Mesure : pause humaine de plus de 60 min comptée 3 min, de plus de 6 h comptée 0 | S | 5 | ≈ 4 min | ≈ 2.9 min agent (incl. 1.5 min checks) · human 4.0 min (2 questions) · 5 files · total ≈ 6.9 min | [x] |
| T21 — Règles de tests retirées du skill, portées par les fichiers du projet | M | 13 | ≈ 7 min | ≈ 17.9 min agent (incl. 10.5 min checks) · human 165.5 min (3 questions) · 11 files · total ≈ 183.4 min | [x] |
| T22 — Tâche-branche et tâche liée : estimation et réel = somme de leurs tâches | M | 9 | ≈ 5 min | ≈ 11.7 min agent (incl. 4.3 min checks) · human 34.0 min (6 questions) · 9 files · total ≈ 45.7 min | [x] |
| T23 — Départ d'une tâche : plan et livraison n'y entrent plus | S | 7 | ≈ 5 min | ≈ 17.8 min agent (incl. 16.2 min checks) · human 0.0 min (0 questions) · 8 files · total ≈ 17.8 min | [x] |
| T24 — Coûts fixes retirés partout, mesure de lancement et de fusion arrêtée | M | 15 | ≈ 7 min | ≈ 7.4 min agent (incl. 0.0 min checks) · human 0.0 min (0 questions) · 15 files · total ≈ 7.4 min | [x] |
| T25 — Vérifications : départ à 0 | S | 6 | ≈ 4 min | ≈ 3.4 min agent (incl. 2.7 min checks) · human 0.0 min (0 questions) · 7 files · total ≈ 3.4 min | [x] |
| T26 — Tests en parallèle | M | 24 | ≈ 11 min | ≈ 50.9 min agent (incl. 43.9 min checks) · human 32.0 min (9 questions) · 22 files · total ≈ 82.9 min | [x] |
| T27 — Temps humain et nombre de questions rattachés à la branche du délégué | M | 10 | ≈ 4 min | ≈ 3.8 min agent (incl. 2.2 min checks) · human 0.0 min (0 questions) · 10 files · total ≈ 3.8 min | [x] |
| T28 — Nouvelle version annoncée par un hook dès la réponse de GitHub | M | 15 | ≈ 9 min | ≈ 9.0 min agent (incl. 0.6 min checks) · human 18.7 min (9 questions) · 14 files · total ≈ 27.7 min | [x] |
| **Total** (15/28 measured) | **7S, 7M, 1L** | **150** | **≈ 88 min** | **≈ 166.3 min** | |
| **Unplanned** | | | | **≈ 67.3 min** | |
