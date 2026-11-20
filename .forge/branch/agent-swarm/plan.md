#[x]Plan[x]—[x]agent-swarm
**Objective:**[x]Doter forge d'un essaim de délégués en parallèle, appuyé sur une mesure automatique du temps par branche et sur une estimation en nombre de fichiers.
**Date:** 2026-11-20

## Tasks

### T1 — Vérifier le comportement des hooks Claude Code
**Effort:** S
**Files:** `.forge/branch/agent-swarm/output/20261120-hook-behavior-check.md`
**Description:** Vérifier, par la documentation et par un essai réel (hook jetable qui journalise son entrée), les points du §7 de la proposition de hook : hook déclaré dans le frontmatter d'un skill actif toute la session une fois le skill chargé, déclenché pour les événements des sous-agents ; `cwd` des événements d'un délégué = son worktree ; absence d'`agent_id` dans la session principale ; délai d'appel ; lancement par Git Bash sous Windows. Conclusion dans OUTPUT ; décision (frontmatter ou repli par les installeurs) notée dans LOG et soumise avant T4.
[x] Frontmatter inopérant (sous-agents, reprise, tour d'invocation) → hook par les installeurs ; cwd des délégués = dossier du parent → correspondance `agent_id` → branche. `output/20261120-hook-behavior-check.md`

### T2 — Script de hook `time-hook.sh`
**Effort:** M
**Files:** `skills/forge/scripts/time-hook.sh`, `tests/time-hook.test.sh`
**Description:** Lit le JSON du hook sur l'entrée standard, extrait les champs simples sans `jq` (`hook_event_name`, `session_id`, `agent_id`, `tool_name`, `duration_ms`, `cwd`), détermine la branche extraite dans `cwd` (un appel git), ajoute une ligne horodatée en millisecondes dans `<racine>/.forge/branch/<branche>/time-log.jsonl` (local, exclu de git), événements des délégués compris (leur `cwd` est celui du parent ; `agent_id` conservé). `UserPromptSubmit` → champ `origin` : `agent` si le prompt commence par `<agent-message` ou `<task-notification`, sinon `human` ; seul ce préfixe est lu, aucun contenu gardé. Dossier de branche absent (projet non forgé, hook global) → rien écrit, sortie immédiate. `PostToolUse` sur `Bash` : `check: true` si la commande correspond au motif de vérification du projet (lu dans `project.md`, sinon aucun). Toujours code 0, rien sur la sortie standard, jamais de contenu de prompt, de fichier ni de commande. Tests sur dépôts jetables : chaque événement, projet non forgé, entrée invalide, `SubagentStop` à `agent_type` vide ignoré.
[x] 23 tests verts ; ~120 ms par appel sous Git Bash ; motif de vérification lu dans une ligne `**Check pattern:**` de `project.md` (génération par p0 en T4).

### T3 — Script d'agrégation `time-aggregate.sh`
**Effort:** M
**Files:** `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`
**Description:** `--branch <X>` → JSON : `parent_minutes` (tours `UserPromptSubmit` → `Stop`, questions retirées), `delegated_minutes` (paires `SubagentStart` → `SubagentStop` par `agent_id`, reprises additionnées ; branche fille → événements de ses délégués lus dans le journal de la parente, par les lignes `{"event":"delegate","agent_id":…,"branch":<X>}`, option `--parent-log <chemin>`), `human_minutes` (prompts `origin: human` seulement), `questions`, `question_minutes`, `check_minutes`, `delegates`, `mode` (`parent` / `delegated` / `mixed`), plus `files`, `lines_added`, `lines_deleted` par `git diff --shortstat` depuis le point de départ de la branche, hors `.forge/` et fichier de verrouillage. Aucune mise en forme. Journal absent → durées vides, fichiers et lignes seulement. Tests : tours imbriqués avec questions, délégués multiples, journal vide, paire incomplète.
[x] 24 tests verts ; volume = numstat depuis le point de départ + fichiers non suivis, hors `.forge` et verrous.

### T4 — Déclaration et installation du hook
**Effort:** M
**Files:** `install/install.sh`, `install/install.ps1`, `tests/install.test.sh` ; `skills/forge/scripts/checks.sh`, `tests/checks.test.sh` ; `skills/forge/phases/p0-project.md`
**Description:** Décision T1 : déclaration par les installeurs seulement, aucun bloc `hooks` dans le frontmatter de `SKILL.md`. `install.sh` et `install.ps1` fusionnent dans `settings.json` les six entrées (`UserPromptSubmit`, `Stop`, `SubagentStart`, `SubagentStop`, `PreToolUse` et `PostToolUse` sur `AskUserQuestion|Bash`) vers `time-hook.sh`, même mécanique que `PreCompact`, idempotente, testée. `checks.sh` ajoute `time-log.jsonl` au `.gitignore`, comme la ligne `input/`. `p0-project.md` affiche une ligne d'information si le hook est absent des réglages ; aucune écriture du skill dans les réglages.
[x] Installeurs : six entrées `time-hook.sh` fusionnées, idempotentes (25 tests sh + ps1) ; `checks.sh` ignore `/.forge/branch/**/time-log.jsonl` (14 tests) ; p0 génère `**Check pattern:**` et signale un hook absent.

### T5 — Synthèse au `grave` et à la clôture
**Effort:** S
**Files:** `skills/forge/commands/engrave.md`, `skills/forge/commands/closure.md`
**Description:** Avant le commit : appeler `time-aggregate.sh`, écrire `.forge/branch/<BRANCH>/metrics.json` (versionné, un seul objet réécrit, valeurs cumulées depuis le début de la branche ; historique des synthèses par git) : `event` (`engrave` / `closure`), `date`, `branch`, `mode`, `model`, `planned_files`, `actual_files`, `lines_added`, `lines_deleted`, `agent_minutes`, `human_minutes`, `questions`, `check_minutes`, `tokens` (`subagent_tokens` des délégués, vide pour la session principale). `planned_files` lu dans le plan (T7). Estimé et réel côte à côte dans le compte rendu.
[x] Section « Synthèse de mesure — `metrics.json` » dans engrave.md (étape 0), appelée par la clôture ; tokens des délégués par lignes `delegate_usage` du journal parent, additionnées par `time-aggregate.sh` (26 tests).

### T6 — Référence et calibration de l'estimation
**Effort:** M
**Files:** `skills/forge/references/estimation.json`, `skills/forge/scripts/time-calibrate.sh`, `tests/time-calibrate.test.sh`
**Description:** `estimation.json` : r = 0,5 min/fichier, t = 5 k tokens/fichier, fourchette ×0,75–×1,3, coûts fixes (délégué + 8 min, fusion ≈ 5 min, 50 k tokens par délégué), seuils de la règle de branche (4/5 critères, 15 min, 150 k tokens, 3 couches). `time-calibrate.sh` lit chaque `.forge/branch/*/metrics.json` → JSON : r et t (médiane des 5 dernières branches mesurées), erreur de prévision des fichiers (appliquée si écart > 20 %), fiabilité (part dans la fourchette sur les 10 dernières), `indicative` (< 5 mesures ou < 7/10). Sans mesure → valeurs de référence. Seuils surchargeables par `coding-standards.md` du projet. r et t réécrits dans `project.md` à chaque mesure, ancienne valeur dans LOG (§3.3).
[x] `references/estimation.json` et `time-calibrate.sh` (14 tests), option `--files <n>` pour l'estimation chiffrée ; report de r et t dans `**Estimation ratios:**` de project.md par la synthèse de mesure.

### T7 — Estimation dans le plan, la reprise et la livraison
**Effort:** M
**Files:** `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `skills/forge/commands/engrave.md`
**Description:** `p4-plan` : champ `**Estimated files:**` par tâche (un nombre, jamais un motif) ; total du plan en minutes d'agent avec fourchette, via `time-calibrate.sh` ; ligne des durées humaines des lettres retirée, lettres et « XL → découper » conservés. `p5-resume` : reste à faire recalculé sur les tâches ouvertes. Toujours un ordre de grandeur, marqué « indicatif » selon la calibration.
[x] p4 : champ `**Estimated files:**`, en-tête `**Estimate:**` via `time-calibrate.sh --files`, colonne Files du Summary, durées humaines des lettres retirées ; p5 : colonne Fichiers et ligne Remaining ; gabarit de tâche ajoutée avec fichiers estimés.

### T8 — Script d'état de l'essaim `swarm-status.sh`
**Effort:** M
**Files:** `skills/forge/scripts/swarm-status.sh`, `tests/swarm-status.test.sh`
**Description:** Lit le `plan.md` de la parente (tâches `### Tn — Branch <x>`, ligne `**Depends on:**`), `git worktree list --porcelain` et `swarm.md` (N, défaut 3) → JSON : branches en cours (avec `Tk/Tn` lu dans le plan du worktree), lançables, en attente (dépendance manquante), tâches ordinaires prenables par le parent ; pour chaque lançable, simulation `git merge-tree` (conflit oui/non, fichiers). Tests : dépendances en chaîne, branche en cours, N atteint, conflit simulé, plan sans tâche-branche.
[x] `swarm-status.sh` (14 tests) : en cours avec avancement, lançables avec fusion simulée `merge-tree`, en attente, tâches ordinaires du parent (`is_last`), N lu dans `swarm.md`.

### T9 — Plan de branches à la création du plan
**Effort:** L
**Files:** `skills/forge/phases/p4-plan.md`
**Description:** Règle de branche du §7.2 (4 critères sur 5, ou > 150 k tokens estimés), tableau des critères présenté avant le plan ; format `### Tn — Branch <x>` avec `**Depends on:**`, estimation fichiers · durée · risque, brief d'une ligne ; règles de découpage du §7.4 (module ou tranche verticale, producteur avant consommateur, socle des points d'extension en tête, 3 à 20 tâches) ; tâche finale de vérification d'ensemble ; option `Validate and launch the swarm` → création des branches filles `<parente>-<slug>` depuis BRANCH avec brief prérempli, puis lancement de l'essaim.
[x] p4-plan : « Règle de branche » (seuils de `time-calibrate.sh`), « Plan de branches » (tableau des critères, découpage, socle, vérification d'ensemble), format de tâche-branche, option `Validate and launch the swarm` ; brief des filles écrit au lancement, dans le worktree.

### T10 — Lancement et relais de l'essaim
**Effort:** L
**Files:** `skills/forge/commands/swarm.md` (nouveau), `skills/forge/phases/p5-resume.md` (déclencheur)
**Description:** §5.1 + §8.1 : sélection par `swarm-status.sh`, branche à conflit simulé écartée sans accord, `git worktree add`, fusion de la parente dans le worktree, installation propre au worktree par la commande d'installation figée du projet, port propre à la branche sur la boucle locale, tableau de délégation, délégués lancés dans le même tour ; pour chaque délégué lancé ou relancé, ligne `{"event":"delegate","agent_id":"…","branch":"<X>"}` ajoutée au `time-log.jsonl` du parent (identifiant tiré du retour de l'outil `Agent`). Boucle de relais (§5, §8.3, §8.5) : préfixe de branche, questions en attente groupées dans une même `AskUserQuestion` (4 max), contenu entier, question sans contexte de décision renvoyée au délégué, notes de coordination, rappel des choix voisins, « enchaîne » transmis. Fichier d'état `swarm.md` (§8.4) réécrit à chaque événement.
[x] `commands/swarm.md` : lancement (sélection par `swarm-status.sh`, worktree, fusion de la parente, brief écrit dans le worktree, installation propre, port), prompt du délégué, boucle de relais (préfixe, contexte de décision, questions groupées, coordination, mesure `delegate` / `delegate_usage`), `swarm.md` ; déclencheurs dans p5-resume.md.

### T11 — Fin, fusion et retrait d'une branche fille
**Effort:** L
**Files:** `skills/forge/commands/swarm.md`
**Description:** « Fin d'une branche fille » (§5.3 + `Vérifier avant de fusionner` du §8.1 + §9.5) : compte rendu, une seule question `Suite`. « Fusion d'une branche fille » (§5.2) : synthèse `metrics.json` avant le commit, avance rapide sinon fusion inverse dans le worktree, règles de résolution des conflits (CRLF compris), vérification complète, tâche cochée avec hashes et estimé/réel, sans push. Retrait : `git status` vide puis `git worktree remove` (plus de lien, §8.1). Relance vers N.
[x] « Fin d’une branche fille » (question `Next`, `Check before merging`), « Fusion d’une branche fille » (synthèse, avance rapide ou fusion inverse, règles de conflit), « Retrait d’un worktree ».

### T12 — Mode délégué en essaim et reprise
**Effort:** M
**Files:** `skills/forge/commands/delegated-mode.md`, `skills/forge/commands/swarm.md`, `skills/forge/phases/p5-resume.md`
**Description:** Lignes du prompt délégué (§5.5 : `SCRATCHPAD:`, port attribué, LOG « task <n> started ») ; questions `Promotion` et rétrogradation (§7.5) ; reprise (§6.5) par `swarm.md` et ligne `RESUME:` ; `p5-resume` : affichage de l'essaim à la reprise, « Relance de l'essaim », plan mixte (§9 : le parent exécute les tâches ordinaires prenables, priorité aux relais, jamais de fusion avec des modifications non commitées).
[x] delegated-mode.md : règles `SWARM:` (pas de livraison ni de fusion, scratchpad, port, task started, RESUME, Promotion) ; swarm.md : reprise et plan mixte ; p5-resume.md étape 8 « Plan de branches ».

### T13 — Sous-tâches ClickUp des branches filles
**Effort:** S
**Files:** `skills/forge/commands/swarm.md`, `skills/forge-clickup/SKILL.md`
**Description:** Projet lié à ClickUp : question au lancement pour créer une sous-tâche par branche fille, code dans `ticket.json`, statut « en cours » au lancement, « terminée » à la fusion (§10).
[x] Section « Sous-tâches ClickUp des branches filles » de swarm.md ; forge-clickup/SKILL.md inchangé (création par `clickup_create_task` depuis swarm.md).

### T14 — Documentation et version
**Effort:** S
**Files:** `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:** Essaim, mesure et estimation dans les deux README ; section CHANGELOG ; structure de `project.md` (nouveaux scripts, `commands/swarm.md`, `references/`, `time-log.jsonl`, `metrics.json`, `swarm.md`).
[x] README.md et README.fr.md (arborescence, fichiers générés, bloc .gitignore, sections « Time measurement and estimate » et « Swarm of child branches », format du plan), CHANGELOG [Unreleased], project.md (arborescence, `**Check pattern:**`).

### T15 — Vérification d'ensemble
**Effort:** S
**Files:** `tests/*`
**Description:** Toutes les suites de `tests/` vertes ; essai réel d'un essaim sur un dépôt jetable (2 branches filles dépendantes, mesure écrite, synthèse au `grave`, fusion inverse, worktrees retirés).
[x] 9 suites vertes (208 tests) ; essaim de 2 branches rejoué sur dépôt jetable : sélection, worktrees, mesure attribuée aux délégués, avance rapide puis fusion inverse avec conflit d'ajout résolu, worktrees retirés. Essai avec de vrais délégués forge : à faire en usage réel.

### T16 — Absence exclue du temps humain
**Effort:** S
**Estimated files:** 5
**Files:** `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Demande utilisateur : un écart de plus de 6 h avant un prompt, ou une question restée plus de 6 h sans réponse, ne compte pas en temps humain (zéro, pas de plafond) ; la question reste comptée et retirée du tour.
[x] Constante `HUMAN_ABSENCE_MS` (6 h, après 3 h et 1 h) passée à awk, fonction `human_share` ; 3 tests (absence, 6 h tout juste, question délaissée) ; 29 tests verts ; README, README.fr, CHANGELOG.

### T17 — Hook de mesure asynchrone
**Effort:** S
**Estimated files:** 7
**Files:** `install/install.sh`, `install/install.ps1`, `tests/install.test.sh`, `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`, `README.md`, `README.fr.md`
**Description:** Demande utilisateur : ne plus attendre le hook (~120 ms par événement). `"async": true` sur les 6 entrées des installeurs ; l'agrégation trie chaque journal par heure (tri stable), l'ordre d'écriture des hooks asynchrones n'étant pas garanti. Script du hook inchangé (alléger sans git jugé plus risqué que le gain).
[x] `async: true` dans install.sh et install.ps1, test d'installation étendu ; `sort_by_time` dans time-aggregate.sh, journal parent repéré par son rang ; 2 tests (désordre, délégué associé après son démarrage — cas réel, corrigé par le tri) ; README, README.fr, CHANGELOG.

### T18 — Aucun chemin absolu dans les fichiers écrits par forge
**Effort:** S
**Estimated files:** 12
**Files:** `skills/forge/commands/delegation.md`, `skills/forge/commands/engrave.md`, `skills/forge/commands/swarm.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/branch/client-api/TASK-1/*` (ex dossier de la délégation client), 3 fiches d'explication de `output/`
**Description:** Demande utilisateur : le chemin du parent ne doit jamais être écrit en clair. Brief et log liés → `<PARENT>` (nom du dossier) ; notes du plan parent → `<LINKED_REL>`, relatif à ROOT, résolu par la livraison relayée (ancienne note absolue toujours lue) ; colonne Worktree de `swarm.md` relative ; exemples génériques (`../my-api`, `~/projects/…`). Dossier de la délégation client anonymisé en `client-api/TASK-1`, brief client retiré. Historique git non réécrit.
[x] Règles et exemples corrigés dans delegation.md, engrave.md, swarm.md, README EN/FR, CHANGELOG ; dossier anonymisé ; plus aucun nom client ni chemin de la machine dans les fichiers suivis.

### T19 — Mesure partielle repérée et écartée du calibrage
**Effort:** S
**Estimated files:** 9
**Files:** `skills/forge/scripts/time-hook.sh`, `skills/forge/scripts/time-aggregate.sh`, `skills/forge/scripts/time-calibrate.sh`, `tests/time-hook.test.sh`, `tests/time-aggregate.test.sh`, `tests/time-calibrate.test.sh`, `skills/forge/commands/engrave.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/branch/agent-swarm/metrics.json`
**Description:** Demande utilisateur (metrics.json de la branche rempli à la main de null, mode incohérent). Le hook écrit `late_start` en tête d'un journal créé alors que plan.md existe ; l'agrégation rend `partial` (marqueur, ou premier commit de la branche antérieur au premier événement) ; le calibrage écarte les synthèses partielles ; metrics.json réécrit selon la règle.
[x] Hook, agrégation, calibrage et leurs tests (25 · 36 · 15) ; engrave.md (champ `partial`, mention « partial measure ») ; README EN/FR, CHANGELOG ; metrics.json de la branche réécrit depuis le script.

## Risks
- Hooks de frontmatter qui ne couvriraient pas les sous-agents → T4 bascule sur les installeurs (hook global, actif aussi hors forge : le script sort sans rien écrire hors projet forgé).
- Commande d'installation par worktree (§8.1) : absente de `project.md` aujourd'hui → T10 la lit dans `## Tools & access`, sinon la demande une fois et la note dans `project.md`.
- Écarts à la proposition : lien du dossier des dépendances (§2.3, §3, §5.4, §5.5) abandonné au profit de §8.1 ; essaim dans `commands/swarm.md` plutôt que `delegation.md` ; sélection et simulation de fusion par `swarm-status.sh` ; événements bruts dans `time-log.jsonl` local (option B), non versionné ; synthèse unique `metrics.json`, versionnée, au lieu des lignes `engrave` / `closure` ajoutées au journal.
- Lecture JSON en bash sans `jq` : champs simples uniquement.

## Deployment
None

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — Vérifier les hooks Claude Code | S | [x] |
| T2 — `time-hook.sh` | M | [x] |
| T3 — `time-aggregate.sh` | M | [x] |
| T4 — Déclaration du hook | M | [x] |
| T5 — Synthèse au grave et à la clôture | S | [x] |
| T6 — Référence et calibration | M | [x] |
| T7 — Estimation dans plan / reprise / livraison | M | [x] |
| T8 — `swarm-status.sh` | M | [x] |
| T9 — Plan de branches | L | [x] |
| T10 — Lancement et relais de l'essaim | L | [x] |
| T11 — Fin, fusion, retrait | L | [x] |
| T12 — Mode délégué et reprise | M | [x] |
| T13 — Sous-tâches ClickUp | S | [x] |
| T14 — Documentation et version | S | [x] |
| T15 — Vérification d'ensemble | S | [x] |
| T16 — Absence exclue du temps humain | S | [x] |
| T17 — Hook de mesure asynchrone | S | [x] |
| T18 — Aucun chemin absolu dans les fichiers écrits | S | [x] |
| T19 — Mesure partielle écartée du calibrage | S | [x] |
| **Total** | **9 S · 7 M · 3 L** | |
