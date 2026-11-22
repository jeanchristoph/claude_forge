# Plan — audit-v0-13
**Objective:** Auditer la 0.13.0 face à la 0.12.6 (fluidité, swarm, non-régression) et proposer des améliorations, plugin Claude Code compris.
**Date:** 2026-11-22
**Estimate:** ≈ 134 files · ≈ 73 min (28-112) · indicative

## Tasks

### T1 — Apports de la 0.13 en fluidité et vitesse
**Effort:** M
**Estimated time:** ≈ 1 min (1-1)
**Actual time:** —
**Files:** `.forge/branch/audit-v0-13/output/20261122-audit-v0-13.md`
**Description:** Diff `v0.12.6..v0.13.0` et CHANGELOG. Pour chaque parcours (démarrage, brief, plan, tâche, grave, clôture) : questions posées, appels de scripts, fichiers lus avant/après. Gains (estimation, mesure, essaim, log-entry.sh) et coûts ajoutés (latence Git Bash, tokens lus, étapes en plus). Conclusion chiffrée gain net / perte.
[x] Perte nette modérée sur le parcours courant ; notes dans scratchpad/audit/t1.md

### T2 — Audit d'intégration du swarm
**Effort:** L
**Estimated time:** ≈ 1 min (1-1)
**Actual time:** —
**Files:** `.forge/branch/audit-v0-13/output/20261122-audit-v0-13.md`
**Description:** `commands/swarm.md`, `scripts/swarm-status.sh`, `p4-plan.md` (Règle de branche, Plan de branches), `p5-resume.md`, `delegated-mode.md`, `delegation.md`. Vérifier : déclencheur atteignable (seuil `branch_minutes` vs `minutes_per_file`), nombre d'actions utilisateur du plan à la fusion finale, relais `FORGE_QUESTION`, reprise après interruption, conflits de fusion, cohérence instructions ↔ champs JSON des scripts. Constats avec fichier:ligne et gravité.
[x] 2 bloquants, verdict non sur les 3 critères ; notes dans scratchpad/audit/t2.md

### T3 — Non-régression des autres fonctions
**Effort:** M
**Estimated time:** ≈ 1 min (1-1)
**Actual time:** —
**Files:** `.forge/branch/audit-v0-13/output/20261122-audit-v0-13.md`
**Description:** Lancer toutes les suites `tests/*.test.sh`. Relire le diff des fonctions existantes : garde master, brief, plan sans essaim, mode `Validate and chain`, délégation projet lié, grave, clôture, forge-clickup, hook PreCompact, installeurs. Rejouer à sec les parcours types sur les instructions 0.12.6 vs 0.13.0 pour repérer tout comportement modifié ou cassé.
[x] 11 suites OK (313 cas), 3 régressions moyennes ; notes dans scratchpad/audit/t3.md

### T4 — Angles d'amélioration et piste plugin Claude Code
**Effort:** M
**Estimated time:** ≈ 1 min (1-1)
**Actual time:** —
**Files:** `.forge/branch/audit-v0-13/output/20261122-audit-v0-13.md`
**Description:** Pistes UX, performance (moins d'appels/lectures), niveau d'information (ligne d'état, compte rendu), fluidité (moins de questions). Étude du format plugin Claude Code (slash commands, hooks, skills, marketplace, mises à jour) face aux installeurs et à update.sh actuels : migration proposée. Chaque piste : gain, coût, risque, priorité.
[x] Pistes P1-P3 et migration plugin en 2 versions ; notes dans scratchpad/audit/t4.md

### T5 — Rapport consolidé
**Effort:** S
**Estimated time:** ≈ 1 min (1-1)
**Actual time:** ≈ 1.5 min · 0 files
**Files:** `.forge/branch/audit-v0-13/output/20261122-audit-v0-13.md`
**Description:** Rassembler T1-T4 dans un rapport local : synthèse en tête, réponses point par point aux quatre questions, constats classés par gravité, feuille de route priorisée.
[x] output/20261122-audit-v0-13.md + 4 annexes

### T6 — A1 · Permissions des scripts du skill
**Effort:** M
**Estimated time:** ≈ 4 min (1-5)
**Files:** `skills/forge/SKILL.md`, `install/install.sh`, `install/install.ps1`, `skills/forge/scripts/status.sh`, `tests/install.test.sh`, `tests/status.test.sh`, `README.md`, `README.fr.md`
**Description:**
- Frontmatter `SKILL.md` : `allowed-tools: Bash(bash ${CLAUDE_SKILL_DIR}/scripts/*)` — couvre le tour d'invocation.
- Installeurs : règle `Bash(bash <chemin des scripts>/*)` à la forme exacte émise par Claude (vérifiée sur un appel réel) — couvre les tours suivants.
- Retirer la règle morte `Bash(bash -c "git branch --show-current*)`, purgée à chaque installation comme les autres règles abandonnées.
- `status.sh --target <argument>` → `target_exists` : l'appel `git rev-parse` de « Branche de travail » disparaît.
- Tests : idempotence des installeurs (nouvelle règle présente, morte purgée), `--target` dans `status.test.sh`.
**Actual time:** ≈ 2.2 min · 6 files
[x] Forme d'appel canonique `bash "<SKILL_DIR>/scripts/…"` dans « Chemins » ; README reporté à T12 ; status 33/33, install 31/31

### T7 — A2 · Lectures différées à la reprise
**Effort:** S
**Estimated time:** ≈ 1 min (1-1)
**Files:** `skills/forge/phases/p5-resume.md`
**Description:**
- Étapes 1-2 de p5 : `project.md` et `coding-standards.md` ne sont plus lus à la reprise.
- Lus au démarrage de la première tâche du tour, ou d'une action directe qui modifie du code — une fois par tour.
- Brief et plan restent lus à la reprise.
**Actual time:** ≈ 0.4 min · 1 files
[x] Section « Contexte du code » dans p5, numérotation des étapes gardée

### T8 — A3 · Sections rares chargées à la demande
**Effort:** M
**Estimated time:** ≈ 4 min (1-6)
**Files:** `skills/forge/SKILL.md`, `skills/forge/phases/p5-resume.md`, `skills/forge/commands/closure.md`, `skills/forge/commands/email.md`, `skills/forge/commands/teacher.md`, `skills/forge/commands/deployment-sql.md`, `skills/forge/commands/rule-propagation.md`, `skills/forge/commands/branch-rename.md`, `.forge/project.md`
**Description:**
- Déplacer « Mail rédigé » et « Mode professeur » (SKILL.md), « Script de déploiement SQL », « Correction ou choix d'infrastructure → propagation vers CLAUDE.md », « Renommage de branche » (p5) dans un fichier `commands/` chacun, texte repris tel quel.
- Laisser un déclencheur d'une ligne par commande dans « Commandes — chargées à la demande ».
- Mettre à jour les renvois (`closure.md:53`, `p5-resume.md:60`) et l'arborescence de `project.md`.
- Vérifier par grep que chaque renvoi « section X de fichier Y » pointe vers une section existante.
**Actual time:** ≈ 1.4 min · 8 files
[x] 5 commandes créées, déclencheurs dans SKILL.md (mail, professeur) et p5 ; SKILL.md 17,5 → 15,6 Ko, p5 21,9 → 19,1 Ko ; 39 renvois vérifiés

### T9 — A7 · Proposition de mise à jour non bloquante
**Effort:** S
**Estimated time:** ≈ 2 min (1-2)
**Files:** `skills/forge/SKILL.md`, `skills/forge/commands/update.md`, `.forge/project.md`
**Description:**
- Démarrage : `update_available` vrai → mention ajoutée à la ligne d'état (« forge `<latest>` disponible — dis "mets à jour la forge" »), aucune question.
- Question `Update` (`Update now` / `Later`) gardée uniquement dans le « Contrôle manuel ».
**Actual time:** ≈ 0.5 min · 2 files
[x] Mention en fin de ligne d'état ; « Proposition » réservée au contrôle manuel, fins explicites en STOP

### T10 — A8 · `/forge help` et découvrabilité
**Effort:** S
**Estimated time:** ≈ 2 min (1-2)
**Files:** `skills/forge/SKILL.md`, `skills/forge/commands/help.md`, `skills/forge/phases/p0-project.md`
**Description:**
- Argument `help` réservé dans « Branche de travail », avant toute détection de branche — jamais une branche nommée `help`.
- `commands/help.md` : cycle brief → plan → actif, commandes en langage naturel (`grave`, « ranger la forge », « mettre à jour la forge », « lance l'essaim », termes de clôture, délégation), fichiers `.forge/`.
- Fin de p0 : une ligne rappelant `/forge help`.
**Actual time:** ≈ 0.3 min · 3 files
[x] Argument `help` réservé avant toute détection de branche ; aide traduite à l'affichage

### T11 — A9 · Hook PreCompact bash unique + SessionStart
**Effort:** M
**Estimated time:** ≈ 3 min (1-4)
**Files:** `hooks/bash/forge-precompact.sh`, `hooks/ps1/forge-precompact.ps1`, `install/install.sh`, `install/install.ps1`, `tests/install.test.sh`, `tests/forge-precompact.test.sh`
**Description:**
- Hook : `hookEventName` selon l'événement reçu ; injecte objectif du brief, plan et 3 dernières entrées LOG.
- Installeurs : hook bash sur `PreCompact` et `SessionStart` (matcher `compact|resume`) ; l'installeur Windows passe au hook bash et purge l'ancienne entrée PowerShell ; idempotence gardée.
- Suppression de `hooks/ps1/forge-precompact.ps1`.
- Tests : sortie JSON du hook par événement, purge de l'entrée PowerShell.
**Actual time:** ≈ 2.2 min · 6 files
[x] Hook lit `hook_event_name` et `cwd` sur stdin ; forge-precompact 9/9, install 35/35

### T12 — A12 · Documentation alignée
**Effort:** S
**Estimated time:** ≈ 2 min (1-3)
**Files:** `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:**
- Blocs `settings.json` du README alignés sur ce que les installeurs écrivent réellement (permissions, hooks de mesure, PreCompact / SessionStart).
- `/forge help`, mise à jour non bloquante, chargement à la demande documentés.
- `CHANGELOG.md` : entrée `[Unreleased]`.
- `project.md` : `task-files.sh`, `references/`, convention « Idempotence ».
**Actual time:** —
[x] README FR (main) + EN (délégué, mêmes sections) ; CHANGELOG [Unreleased] ; project.md ; 12 suites OK, 335 cas

### T13 — Validation d'un ajout de tâches alignée sur un plan neuf
**Effort:** S
**Estimated time:** ≈ 1 min (1-1)
**Files:** `skills/forge/phases/p5-resume.md`
**Description:**
- « Demande hors périmètre », étape 2 : trois options comme la question `Plan` de p4 — `Validate and chain` / `Validate` / `Cancel`.
- `Validate and chain` → tâches écrites au plan puis exécutées dans l'ordre, sans autre question.
- `Validate` → tâches écrites au plan seulement, puis question `Mode` / `Task` comme un plan neuf.
- Gabarit — question `Plan` à trois options ; mêmes options en `FORGE_QUESTION`.
**Actual time:** —
[x] Fait avant T12 pour documenter le README une seule fois ; étape 9 et question `Test` alignées

### T14 — Temps des sous-agents ordinaires compté dans la mesure
**Effort:** M
**Estimated time:** ≈ 2 min (1-3)
**Files:** `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:**
1. Mesure de branche : toute paire `SubagentStart` / `SubagentStop` du journal comptée en minutes déléguées, même sans ligne `delegate`.
2. Agent associé par une ligne `delegate` à une autre branche (branche fille, projet lié) toujours écarté : jamais compté deux fois.
3. `--task` : même règle, intervalle coupé à la fenêtre de la tâche.
4. `delegates` et `mode` tiennent compte des agents ordinaires.
5. Tests : agent ordinaire, agent de branche fille, fenêtre de tâche, agent sans `SubagentStop`.
6. README FR/EN et CHANGELOG `[Unreleased]`.
**Actual time:** ≈ 3.2 min · 5 files
[x] Branche : 14,7 min parent + 29,1 min de sous-agents (7) ; time-aggregate 78/78 ; limite documentée : tâches parallèles à fenêtres superposées comptent chacune les agents de leur fenêtre

### T15 — Tâches simultanées : réel non attribuable, écrit `—` par le script
**Effort:** M
**Estimated time:** ≈ 2 min (1-3)
**Files:** `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:**
1. `time-aggregate.sh --task` : une autre tâche ouverte pendant la fenêtre → `measured: false`, raison `overlapping_tasks`.
2. p5 écrit alors `**Actual time:** —` et la tâche sort du calibrage, sans correction à la main.
3. Aucune répartition inventée entre tâches.
4. Mesure de branche (`metrics.json`) inchangée.
5. Tests : démarrage simultané, tâches successives, tâche démarrée pendant une autre.
6. README FR/EN (limite remplacée par la règle) et CHANGELOG.
**Actual time:** ≈ 1.1 min · 5 files
[x] time-aggregate 82/82 ; la règle classe aussi T12 et T13 (T13 faite pendant T12) en overlapping_tasks → réels passés à —

### T16 — Coche détectée par un hook : réel écrit sans le modèle
**Effort:** L
**Estimated time:** ≈ 6 min (2-8)
**Actual time:** ≈ 18.0 min · 14 files
**Files:** `skills/forge/scripts/plan-hook.sh`, `skills/forge/scripts/task-marks.sh`, `skills/forge/scripts/time-mark.sh`, `skills/forge/scripts/task-files.sh`, `skills/forge/scripts/status.sh`, `tests/plan-hook.test.sh`, `install/install.sh`, `install/install.ps1`, `tests/install.test.sh`, `skills/forge/phases/p5-resume.md`, `skills/forge/commands/delegated-mode.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:**
1. `plan-hook.sh`, hook `PostToolUse` synchrone sur `Edit|Write|MultiEdit`, actif seulement quand le fichier modifié est un `.forge/branch/<b>/plan.md`.
2. État dans le journal de mesure : ligne `plan_checkpoint` (heure, empreinte, tâches cochées) ; pas de `plan-state` ; sans journal → `—`.
3. Premier passage → premier point d'étape. Tâche `### Tn` passée à `[x]` → `task_start` rétroactive (heure et empreinte du dernier point d'étape), `task_done` maintenant, nouveau point d'étape ; réel par `time-aggregate.sh --task`, écrit sous la tâche. Deux coches d'un coup → `—` (règle de T15). Sous-tâches `T2.1` ignorées.
4. Coche retirée → liste mise à jour, point d'étape inchangé.
5. Délégué (`agent_id`) → marques dans le journal du parent, branche lue dans le chemin du plan.
6. `additionalContext` : `plan.md` réécrit, réel donné.
7. `current_time_ms`, `snapshot_files` et ligne de marque extraits de `time-mark.sh` vers `task-marks.sh` ; `time-mark.sh` inchangé en comportement. Lecteur de statut des tâches (`TASKS_PROGRAM`) déplacé de `status.sh` vers `task-files.sh`, partagé avec `plan-hook.sh` ; format de `plan.md` inchangé.
8. Installeurs : hook déclaré, idempotence gardée.
9. p5 « Mesure d'une tâche » réduite à un renvoi au hook ; `delegated-mode.md` allégé.
10. Tests : coche simple, deux coches, plan réécrit sans coche, coche retirée puis remise, tâche hors ordre, délégué, fichier hors plan, sans journal.
[x] plan-hook 17/17, install 39/39 ; 13 suites OK (364 cas)

### T17 — Estimation et tableau récapitulatif tenus par le hook
**Effort:** L
**Estimated time:** ≈ 4 min (1-5)
**Actual time:** ≈ 9.8 min · 7 files
**Files:** `skills/forge/scripts/plan-hook.sh`, `tests/plan-hook.test.sh`, `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:**
1. Écriture du plan → tâche avec `**Files:**` sans `**Estimated time:**` estimée (un seul appel `time-calibrate.sh`) ; en-tête `**Estimate:**` ajouté s'il manque.
2. Estimation existante jamais recalculée.
3. p4 étape 6 et p5 « Demande hors périmètre » : plus de recopie de minutes par le modèle ; un seul appel pour afficher l'estimation avant la question.
4. `## Summary` = `Task | Effort | Files | Estimated | Actual | Status`, tenu à jour par le hook : `Estimated` et `Actual` recopiés de la tâche, `Status` recopié de la ligne de statut (raison du blocage comprise), ligne retrouvée par `T<n> —`, titre court gardé.
5. Ancien tableau sans ces colonnes → colonnes ajoutées ; tâche absente du tableau → ligne ajoutée avec le titre de son en-tête.
6. Ligne `**Total**` : somme des fichiers, des minutes estimées et des réels mesurés.
7. Ligne `**Remaining**` sous le total : fichiers et minutes (fourchette) des tâches ouvertes, par `time-calibrate.sh` ; retirée quand plus rien n'est ouvert.
8. Gabarit `## Summary` de `p4-plan.md` mis à jour.
9. Reprise (p5, étape 6) : `## Summary` affiché tel quel, sans recalcul ; « Format du tableau d'avancement » réduit à un renvoi au gabarit.
10. Tests : plan neuf, tâche ajoutée, estimation gardée, motif `(≈ n)` ; colonnes ajoutées, cellules mises à jour, titre court gardé, tâche absente ajoutée ; raison du blocage, total, reste à faire, reste à faire retiré.
[x] plan-hook 27/27 ; 13 suites OK (374 cas)

### T18 — `metrics.json` écrit par un script, sans le modèle
**Effort:** M
**Estimated time:** ≈ 5 min (1-8)
**Actual time:** ≈ 10.2 min · 9 files
**Files:** `skills/forge/scripts/metrics.sh`, `tests/metrics.test.sh`, `skills/forge/scripts/engrave.sh`, `tests/engrave.test.sh`, `skills/forge/commands/engrave.md`, `skills/forge/commands/closure.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:**
1. Nouveau `metrics.sh --root --branch --event engrave|closure --model <id> [--parent-log --base]` : appelle `time-aggregate.sh`, compte fichiers prévus et réels (par tâche, à défaut branche), écrit `metrics.json` (une ligne, ordre de champs figé actuel), rend en JSON les valeurs de la ligne « Estimated … actual … » ; mise en page par le modèle.
2. `engrave.sh run --model <id>` appelle `metrics.sh` juste avant `git add -A` quand `.forge/branch/<b>/` existe ; son JSON ajouté au rendu sous `metrics`.
3. Clôture → `metrics.sh --event closure` ; fusion d'une branche fille → même script avec `--parent-log` et `--base` (renvoi de `swarm.md` inchangé).
4. « Synthèse de mesure » de `engrave.md` réduite à l'appel et au gabarit de la ligne ; `closure.md` idem.
5. Retiré : `remaining` rendu par `status.sh`, couvert par la ligne `**Remaining**` de T17.
6. Tests : champs et ordre de `metrics.json`, `null` sans journal, fichiers par tâche et repli branche, estimation lue dans `**Estimate:**`, `metrics.json` commité au grave, événement `closure`.
[x] metrics 9/9, engrave 37/37 ; 14 suites OK (387 cas)

### T19 — Hook de mesure allégé hors projets forge
**Effort:** S
**Estimated time:** ≈ 2 min (1-3)
**Actual time:** ≈ 5.0 min · 5 files
**Files:** `skills/forge/scripts/time-hook.sh`, `tests/time-hook.test.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:**
1. Sortie immédiate sans `.forge/` dans le dossier de session ou ses parents, recherche en bash pur, sans processus git.
2. Coût mesuré avant/après, projet sans forge et projet forge.
3. Tests : projet sans forge (rien écrit, aucun git), sous-dossier d'un projet forge (journal écrit).
[x] hors forge ≈ 97 → 70 ms par événement, forge inchangé ≈ 100 ms ; time-hook 30/30 ; 14 suites OK (389 cas)

### T20 — Coût fixe des vérifications par tâche dans l'estimation
**Effort:** M
**Estimated time:** ≈ 6 min (2-11)
**Actual time:** ≈ 12.9 min · 11 files · 8.9 min checks
**Files:** `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`, `skills/forge/scripts/time-calibrate.sh`, `tests/time-calibrate.test.sh`, `skills/forge/references/estimation.json`, `skills/forge/scripts/plan-hook.sh`, `tests/plan-hook.test.sh`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:**
1. `time-aggregate.sh --task` rend `check_minutes` : durée des commandes de vérification dans la fenêtre de la tâche.
2. Le hook écrit le réel avec cette part : `**Actual time:** ≈ <min> min · <n> files · <c> min checks` (trace versionnée pour le calibrage).
3. Temps estimé = coût fixe de vérification + minutes par fichier × fichiers ; coût fixe = médiane des vérifications par tâche, minutes par fichier calculées hors vérifications ; référence dans `estimation.json` sous 20 tâches mesurées.
4. Motif de vérification de ce projet élargi à `tests/[a-z-]*\.test\.sh`, pour compter les boucles.
5. Tests : vérifications comptées dans la fenêtre, réel écrit avec leur part, coût fixe tiré de la référence puis des tâches, minutes par fichier hors vérifications, ancien réel sans part toujours lu.
[x] référence 2 min (choix utilisateur) ; motif retenu `bash tests/|tests/\*\.test\.sh` ; début répété d'une tâche remplacé (fantôme ouvert corrigé) ; 14 suites OK (397 cas)

### T21 — Corrections de fin d'audit : mesure, estimation, tableau
**Effort:** M
**Estimated time:** ≈ 8 min (2-16)
**Actual time:** ≈ 9.6 min · 12 files · 6.9 min checks
**Files:** `skills/forge/scripts/json.sh`, `skills/forge/scripts/time-hook.sh`, `skills/forge/scripts/plan-hook.sh`, `tests/plan-hook.test.sh`, `skills/forge/scripts/time-calibrate.sh`, `tests/time-calibrate.test.sh`, `skills/forge/phases/p4-plan.md`, `skills/forge/commands/closure.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:**
1. Lecture d'un champ du JSON des hooks déplacée dans `json.sh`, chargée par `time-hook.sh` et `plan-hook.sh` (copie supprimée).
2. `closure.md` : plus de report manuel des statuts dans `## Summary`.
3. Essaim : coût fixe des tests par tâche ; `--groups` accepte `<fichiers>/<tâches>` par groupe (1 par défaut), p4 « Plan de branches » passe le nombre de tâches de chaque groupe.
4. Tableau du bas : `**Total**` calculé sur les seules tâches au réel mesuré (nombre, efforts, fichiers, somme des estimés, somme des réels) — estimé et réel comparables ; l'estimé du plan entier reste dans `**Estimate:**`, les tâches ouvertes dans `**Remaining**` (choix utilisateur, à la place d'une ligne `**Measured**`).
5. Un réel déjà mesuré n'est jamais remplacé par « — » (deux coches dans une même modification).
6. En-tête `**Estimate:**` recalculé à chaque écriture du plan : somme des fichiers et des estimés figés de toutes les tâches, avec leur fourchette ; estimés par tâche toujours figés.
7. Tests : lecture partagée du JSON, groupe d'essaim à plusieurs tâches, `**Total**` des seules tâches mesurées, réel gardé face à « — », en-tête qui suit une tâche ajoutée.
[x] plan-hook 31/31, time-calibrate 31/31 ; 14 suites OK (400 cas)

### T22 — Hooks rangés dans `skills/forge/hooks/`
**Effort:** M
**Estimated time:** ≈ 14 min (4-26)
**Actual time:** ≈ 8.4 min · 18 files · 6.6 min checks
**Files:** `skills/forge/hooks/forge-precompact.sh`, `skills/forge/hooks/time-hook.sh`, `skills/forge/hooks/plan-hook.sh`, `hooks/bash/forge-precompact.sh`, `skills/forge/scripts/time-hook.sh`, `skills/forge/scripts/plan-hook.sh`, `install/install.sh`, `install/install.ps1`, `tests/install.test.sh`, `tests/forge-precompact.test.sh`, `tests/time-hook.test.sh`, `tests/plan-hook.test.sh`, `skills/forge/phases/p0-project.md`, `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `skills/forge/commands/closure.md`, `skills/forge/commands/delegated-mode.md`, `skills/forge/scripts/task-files.sh`, `skills/forge/scripts/task-marks.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:**
1. Les trois hooks (`forge-precompact.sh`, `time-hook.sh`, `plan-hook.sh`) passent par `git mv` dans `skills/forge/hooks/` ; bibliothèques chargées par `../scripts/` ; `hooks/bash/` supprimé.
2. Installeurs : `bash ~/.claude/skills/forge/hooks/<hook>.sh` ; anciennes entrées `settings.json` (`~/.claude/hooks/forge/forge-precompact.sh`, `scripts/time-hook.sh`, `scripts/plan-hook.sh`) et ancien dossier `~/.claude/hooks/forge/` retirés ; idempotence gardée.
3. Règle dans `project.md` : un hook déclaré dans `settings.json` vit dans `skills/forge/hooks/`, `scripts/` ne contient que ce qu'appellent le modèle et les hooks.
4. Instructions, commentaires, README (arborescence et bloc `settings.json`) et CHANGELOG suivent les nouveaux chemins.
5. Tests : suites des trois hooks depuis leur nouveau chemin, installation aux nouveaux chemins, réinstallation par-dessus une 0.13.1 (anciennes entrées et ancien dossier retirés, sans doublon).
[x] p0, delegated-mode, task-files.sh, task-marks.sh sans chemin à changer (nom seul) ; ancien dossier gardé s'il contient un fichier étranger ; 14 suites OK (402 cas)

## Risks
- Estimation par fichiers inadaptée à un audit (1 min par tâche irréaliste : le travail est de la lecture, pas de l'écriture) — constat à intégrer à T1/T4.
- Le rejeu à sec (T3) est une lecture d'instructions, pas une exécution réelle de `/forge` : une régression de comportement du modèle peut échapper.

## Deployment
None

## Summary
| Task | Effort | Files | Estimated | Actual | Status |
|---|---|---|---|---|---|
| T1 — Apports 0.13 | M | 1 | ≈ 1 min | — | [x] |
| T2 — Audit swarm | L | 1 | ≈ 1 min | — | [x] |
| T3 — Non-régression | M | 1 | ≈ 1 min | — | [x] |
| T4 — Améliorations & plugin | M | 1 | ≈ 1 min | — | [x] |
| T5 — Rapport consolidé | S | 1 | ≈ 1 min | ≈ 1.5 min · 0 files | [x] |
| T6 — A1 Permissions des scripts | M | 8 | ≈ 4 min | ≈ 2.2 min · 6 files | [x] |
| T7 — A2 Lectures différées | S | 1 | ≈ 1 min | ≈ 0.4 min · 1 files | [x] |
| T8 — A3 Sections rares à la demande | M | 9 | ≈ 4 min | ≈ 1.4 min · 8 files | [x] |
| T9 — A7 Mise à jour non bloquante | S | 3 | ≈ 2 min | ≈ 0.5 min · 2 files | [x] |
| T10 — A8 /forge help | S | 3 | ≈ 2 min | ≈ 0.3 min · 3 files | [x] |
| T11 — A9 Hook PreCompact bash + SessionStart | M | 6 | ≈ 3 min | ≈ 2.2 min · 6 files | [x] |
| T12 — A12 Documentation alignée | S | 4 | ≈ 2 min | — | [x] |
| T13 — Ajout de tâches : options d'un plan neuf | S | 1 | ≈ 1 min | — | [x] |
| T14 — Sous-agents ordinaires mesurés | M | 5 | ≈ 2 min | ≈ 3.2 min · 5 files | [x] |
| T15 — Tâches simultanées non attribuables | M | 5 | ≈ 2 min | ≈ 1.1 min · 5 files | [x] |
| T16 — Coche détectée par un hook | L | 15 | ≈ 6 min | ≈ 18.0 min · 14 files | [x] |
| T17 — Estimation et tableau tenus par le hook | L | 7 | ≈ 4 min | ≈ 9.8 min · 7 files | [x] |
| T18 — metrics.json par script | M | 10 | ≈ 5 min | ≈ 10.2 min · 9 files | [x] |
| T19 — Hook de mesure allégé | S | 5 | ≈ 2 min | ≈ 5.0 min · 5 files | [x] |
| T20 — Coût fixe des vérifications par tâche dans l'estimation | M | 12 | ≈ 6 min | ≈ 12.9 min · 11 files · 8.9 min checks | [x] |
| T21 — Corrections de fin d'audit : mesure, estimation, tableau | M | 12 | ≈ 8 min | ≈ 9.6 min · 12 files · 6.9 min checks | [x] |
| T22 — Hooks rangés dans `skills/forge/hooks/` | M | 23 | ≈ 14 min | ≈ 8.4 min · 18 files · 6.6 min checks | [x] |
| **Total** (16/22 measured) | **5S, 9M, 2L** | **125** | **≈ 66 min** | **≈ 86.7 min** | |
