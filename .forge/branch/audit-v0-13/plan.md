# Plan — audit-v0-13
**Objective:** Auditer la 0.13.0 face à la 0.12.6 (fluidité, swarm, non-régression) et proposer des améliorations, plugin Claude Code compris.
**Date:** 2026-11-22
**Estimate:** ≈ 5 files · ≈ 2 min (2-3) · indicative

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

## Risks
- Estimation par fichiers inadaptée à un audit (1 min par tâche irréaliste : le travail est de la lecture, pas de l'écriture) — constat à intégrer à T1/T4.
- Le rejeu à sec (T3) est une lecture d'instructions, pas une exécution réelle de `/forge` : une régression de comportement du modèle peut échapper.

## Deployment
None

## Summary
| Task | Effort | Files | Status |
|---|---|---|---|
| T1 — Apports 0.13 | M | 1 | [x] |
| T2 — Audit swarm | L | 1 | [x] |
| T3 — Non-régression | M | 1 | [x] |
| T4 — Améliorations & plugin | M | 1 | [x] |
| T5 — Rapport consolidé | S | 1 | [x] |
| T6 — A1 Permissions des scripts | M | 8 | [x] |
| T7 — A2 Lectures différées | S | 1 | [x] |
| T8 — A3 Sections rares à la demande | M | 9 | [x] |
| T9 — A7 Mise à jour non bloquante | S | 3 | [x] |
| T10 — A8 /forge help | S | 3 | [x] |
| T11 — A9 Hook PreCompact bash + SessionStart | M | 6 | [x] |
| T12 — A12 Documentation alignée | S | 4 | [x] |
| T13 — Ajout de tâches : options d'un plan neuf | S | 1 | [x] |
| T14 — Sous-agents ordinaires mesurés | M | 5 | [x] |
| T15 — Tâches simultanées non attribuables | M | 5 | [x] |
| **Total** | **6S, 8M, L** | **50** | |
