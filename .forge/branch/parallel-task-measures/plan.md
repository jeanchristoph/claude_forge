# Plan — parallel-task-measures
**Objective:** Des tâches menées ensemble puis cochées à la suite s'affichent `—` pour tout le groupe, sans fausse durée ; formule d'estimation et somme des sous-agents inchangées.
**Date:** 2026-11-25
**Estimate:** ≈ 22 files · ≈ 39 min (16-83)
**Actual:** ≈ 43.9 min agent (incl. 23.5 min checks) · human 165.8 min (14 questions, 124.9 min) · delegates 0.0 min in parallel · total ≈ 209.7 min

## Tasks

### T1 — Rafale de coches reconnue par le hook
**Effort:** M
**Estimated time:** ≈ 6 min (2-12)
**Actual time:** ≈ 0.0 min agent (incl. 3.5 min checks) · human 0.0 min (0 questions) · 3 files · total ≈ 0.0 min
**Files:** `skills/forge/hooks/plan-hook.sh`, `skills/forge/scripts/task-marks.sh`, `tests/plan-hook.test.sh`
**Description:** Une coche est une rafale quand les quatre conditions sont vraies : le point d'étape date de la coche précédente (même branche, même projet lié) ; moins de 1 min s'est écoulée depuis ; l'empreinte du dossier est identique ; la tâche a des fichiers prévus. La nouvelle tâche reprend alors le début et l'empreinte de départ de la précédente : les fenêtres se chevauchent, `time-aggregate.sh` rend `overlapping_tasks` sans modification. Tout le groupe passe à `—`, première comprise : seule exception à « un réel mesuré n'est jamais remplacé par `—` ». Tests : rafale de deux et de six, coche rapprochée avec fichiers changés, coche à plus de 1 min, tâche sans fichier prévu, délégué d'une branche fille et d'un projet lié ; `test_sequential_tasks_are_not_overlapping` adapté.
[x] 11 tests ajoutés, chaque condition vérifiée par mutation

### T2 — Fichiers d'une rafale hors du total de la branche
**Effort:** S
**Estimated time:** ≈ 5 min (2-11)
**Actual time:** ≈ 0.0 min agent (incl. 1.4 min checks) · human 0.0 min (0 questions) · 6 files · total ≈ 0.0 min
**Files:** `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`
**Description:** `TASK_FILES_PROGRAM` écarte les tâches qui se chevauchent : sans cela, les mêmes fichiers compteraient une fois par tâche du groupe dans `metrics.json`.
[x] 1 test ajouté, vérifié par mutation

### T3 — Règle et documentation
**Effort:** S
**Estimated time:** ≈ 6 min (2-13)
**Actual time:** ≈ 0.0 min agent (incl. 0.0 min checks) · human 0.0 min (0 questions) · 0 files · total ≈ 0.0 min
**Files:** `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Étendre à la rafale la ligne « Plusieurs tâches cochées d'un même coup », décrire l'affichage et l'effet sur `**Unplanned**`, section `[Unreleased]`.
[x] p5-resume, deux README et CHANGELOG

### T4 — Tâches de relecture au calibrage
**Effort:** S
**Estimated time:** ≈ 6 min (2-12)
**Actual time:** ≈ 5.5 min agent (incl. 3.0 min checks) · human 0.0 min (0 questions) · 4 files · total ≈ 5.5 min
**Files:** `skills/forge/scripts/time-calibrate.sh`, `skills/forge/scripts/task-files.sh`, `tests/time-calibrate.test.sh`
**Description:** Lire le champ `**Kind:** review` par une seule règle partagée (`task-files.sh`) ; sans champ, la tâche est du code. Écarter les tâches `review` du taux, de la fourchette, de l'erreur de fichiers et du coût de vérification des autres tâches, sans qu'elles prennent une des 40 places. `--files` accepte `review` comme valeur : médiane des durées réelles des 40 dernières tâches `review` mesurées du projet, fourchette 20e-80e centile, dès 2 mesures ; sinon `null`. Une valeur `null` n'entre pas dans la somme.
[x] 7 tests ajoutés, sortie identique sans relecture ; test de format de `plan-hook` adapté

### T5 — Tâches de relecture au plan
**Effort:** M
**Estimated time:** ≈ 5 min (2-11)
**Actual time:** ≈ 6.7 min agent (incl. 6.2 min checks) · human 0.0 min (0 questions) · 2 files · total ≈ 6.7 min
**Files:** `skills/forge/hooks/plan-hook.sh`, `tests/plan-hook.test.sh`
**Description:** Avant 2 mesures : écrire `**Estimated time:** —` ; l'en-tête, `**Remaining**` et les tâches groupées additionnent les autres tâches. À partir de 2 mesures : remplacer `—` par l'estimation, pour les tâches encore ouvertes seulement, puis la figer. `**Total**` : une tâche `review` à `—` n'y compte ni en estimé ni en réel, qui portent sur les mêmes tâches ; son réel reste affiché sur sa ligne. Une ligne `—` compte comme déjà au plan : la mesure d'une autre tâche n'est pas redémarrée à chaque écriture.
[x] 10 tests ajoutés, conditions principales vérifiées par mutation

### T6 — Règle du type et documentation
**Effort:** S
**Estimated time:** ≈ 6 min (3-13)
**Actual time:** ≈ 0.7 min agent (incl. 0.2 min checks) · human 0.0 min (0 questions) · 5 files · total ≈ 0.7 min
**Files:** `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Définir `**Kind:** review`, sous `**Effort:**` : tâche dont le travail est surtout de lire ou d'exécuter l'existant (documentation, vérification d'ensemble, audit, analyse), quel que soit le nombre de fichiers écrits. Passer `review` à `time-calibrate.sh` pour présenter un plan ou une tâche ajoutée. Écrire la raison de cette variante à côté de la règle, comme `coding-standards.md` l'exige.
[x] p4-plan, p5-resume, deux README et CHANGELOG ; textes sans test

### T7 — Tour sans début dans le journal
**Effort:** S
**Estimated time:** ≈ 5 min (3-11)
**Actual time:** ≈ 10.9 min agent (incl. 9.1 min checks) · human 0.0 min (0 questions) · 4 files · total ≈ 10.9 min
**Files:** `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`, `CHANGELOG.md`
**Description:** Événement de la session principale (avec session, sans `agent_id`, ni `UserPromptSubmit` ni `Stop`) alors qu'aucun tour de cette session n'est ouvert → il ouvre un tour à son heure. Une seule règle, partagée par la mesure de la branche et celle d'une tâche. Les attentes de questions restent retirées du temps d'agent et le temps humain est inchangé. Les marques et `late_start`, sans session, n'ouvrent jamais de tour. Tests : branche créée en cours de tour ; retour sur la branche après un `Stop` ; question posée dans ce tour ; tâche cochée avant le `Stop` ; marques seules ; `Stop` seul ; événement d'un sous-agent.
[x] 9 tests ajoutés, conditions vérifiées par mutation sauf la garde « sans session » ; données d'un test de `plan-hook` complétées (fin de tour)

## Risks
- Deux sessions ouvertes en même temps sur la branche : la mesure d'une tâche prend le tour commencé en dernier, pas forcément celui de la session qui coche ; réel alors trop court.
- Fausse rafale : une tâche finie sans modifier de fichier et cochée en moins de 1 min efface aussi la mesure de la précédente.
- Rafale étalée : coches espacées de plus de 1 min, fichier modifié ou commit entre deux coches → non détectée.
- Estimations toujours basses, formule gardée.

## Deployment
None

## Summary
| Task | Effort | Files | Estimated | Actual | Status |
|---|---|---|---|---|---|
| T1 — Rafale de coches reconnue par le hook | M | 3 | ≈ 6 min | ≈ 0.0 min agent (incl. 3.5 min checks) · human 0.0 min (0 questions) · 3 files · total ≈ 0.0 min | [x] |
| T2 — Fichiers d'une rafale hors du total | S | 2 | ≈ 5 min | ≈ 0.0 min agent (incl. 1.4 min checks) · human 0.0 min (0 questions) · 6 files · total ≈ 0.0 min | [x] |
| T3 — Règle et documentation | S | 4 | ≈ 6 min | ≈ 0.0 min agent (incl. 0.0 min checks) · human 0.0 min (0 questions) · 0 files · total ≈ 0.0 min | [x] |
| T4 — Tâches de relecture au calibrage | S | 3 | ≈ 6 min | ≈ 5.5 min agent (incl. 3.0 min checks) · human 0.0 min (0 questions) · 4 files · total ≈ 5.5 min | [x] |
| T5 — Tâches de relecture au plan | M | 2 | ≈ 5 min | ≈ 6.7 min agent (incl. 6.2 min checks) · human 0.0 min (0 questions) · 2 files · total ≈ 6.7 min | [x] |
| T6 — Règle du type et documentation | S | 5 | ≈ 6 min | ≈ 0.7 min agent (incl. 0.2 min checks) · human 0.0 min (0 questions) · 5 files · total ≈ 0.7 min | [x] |
| T7 — Tour sans début dans le journal | S | 3 | ≈ 5 min | ≈ 10.9 min agent (incl. 9.1 min checks) · human 0.0 min (0 questions) · 4 files · total ≈ 10.9 min | [x] |
| **Total** (7/7 measured) | **5S, 2M** | **22** | **≈ 39 min** | **≈ 23.8 min** | |
| **Unplanned** | | | | **≈ 20.1 min** | |
