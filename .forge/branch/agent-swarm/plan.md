# Plan — agent-swarm
**Objective:** Doter forge d'un essaim de délégués en parallèle, appuyé sur une mesure automatique du temps par branche et sur une estimation en nombre de fichiers.
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

### T20 — Motif de vérification sans ancrage
**Effort:** XS
**Estimated files:** 4
**Files:** `skills/forge/phases/p0-project.md`, `.forge/project.md`, `tests/time-hook.test.sh`, `CHANGELOG.md`
**Description:** Demande utilisateur : `check_minutes` à 0 alors que les tests ont tourné. Le motif `^bash tests/` ne reconnaissait pas une commande enchaînée après `cd … &&` ni lancée dans une boucle. Motif reconnu n'importe où dans la commande ; hook inchangé.
[x] p0-project.md (règle et exemple sans `^`), project.md (`bash tests/`), 2 tests du hook (27 verts), CHANGELOG. Temps de vérification de cette branche non récupérable : le journal ne garde pas les commandes.

### T21 — Ratio de tokens tiré des seules branches déléguées
**Effort:** XS
**Estimated files:** 3
**Files:** `skills/forge/scripts/time-calibrate.sh`, `tests/time-calibrate.test.sh`, `CHANGELOG.md`
**Description:** Demande utilisateur. `tokens_per_file` divise les tokens des seuls délégués par tous les fichiers de la branche : sur une branche mixte (parent + délégués), les fichiers du parent diluent le ratio, trop bas, et la règle de branche (150 000 tokens) se déclenche trop tard. Le calibrage ne retient pour ce ratio que les synthèses `mode: delegated` ; minutes par fichier et erreur sur les fichiers inchangées. Tests : branche mixte écartée du ratio de tokens, branche déléguée retenue.
[x] Champ `mode` lu par le calibrage, ratio de tokens limité à `mode: delegated` ; 2 tests (17 verts) ; CHANGELOG.

### T22 — Seuil de branche à 300 000 tokens
**Effort:** XS
**Estimated files:** 5
**Files:** `skills/forge/references/estimation.json`, `tests/time-calibrate.test.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Demande utilisateur : 150 000 tokens trop bas. Fenêtre de contexte d'un million ; délégués réels de la proposition entre 278 k et 632 k par exécution. `branch_tokens` porté à 300 000, à réajuster après quelques branches mesurées (sens exact de `subagent_tokens` non vérifié).
[x] estimation.json, test du calibrage, README EN/FR, CHANGELOG.

### T23 — En-tête du plan réparé et règle de coche
**Effort:** XS
**Estimated files:** 2
**Estimated time:** ≈ 1 min (1-1)
**Actual time:** ≈ 0.2 min
**Files:** `.forge/branch/agent-swarm/plan.md`, `skills/forge/phases/p5-resume.md`
**Description:** Audit 2026-11-21. Lignes 1-2 du plan rétablies (`# Plan — agent-swarm`, `**Objective:** …`), corrompues depuis `517c749` par un remplacement regex de `[ ]`. « Règles de mise à jour du plan » : coche par l'outil Edit sur la ligne de statut exacte, jamais par sed ni regex.
[x] En-tête rétabli, aucune autre ligne corrompue ; règle de coche par Edit ajoutée sous « Silencieuse » de p5-resume.md.

### T24 — Calibrage robuste et estimations arrondies
**Effort:** XS
**Estimated files:** 3
**Estimated time:** ≈ 2 min (1-2)
**Actual time:** ≈ 0.7 min
**Files:** `skills/forge/scripts/time-calibrate.sh`, `tests/time-calibrate.test.sh`, `CHANGELOG.md`
**Description:** Audit B1. Garde `$3 != "null"` sur les ratios minutes/fichier et tokens/fichier (division par zéro, JSON tronqué en code 0). Estimation au minimum 1 min, fourchette comprise. Aucune correction d'erreur sur les fichiers sous 3 branches mesurées. Tests : `actual_files: null`, 1 fichier, 1 et 2 branches sans correction.
[x] Garde null, `whole_minutes` (≥ 1), `FILE_ERROR_MIN_BRANCHES=3` ; 3 tests ajoutés, 1 adapté (20 verts) ; CHANGELOG.

### T25 — Hook et marqueurs sûrs sous bash < 5, heure prise en premier
**Effort:** S
**Estimated files:** 8
**Estimated time:** ≈ 4 min (3-5)
**Actual time:** ≈ 2.5 min
**Files:** `skills/forge/scripts/time-hook.sh`, `skills/forge/scripts/time-mark.sh`, `skills/forge/scripts/log-entry.sh`, `tests/time-hook.test.sh`, `tests/time-mark.test.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Audit I2. Sans `EPOCHREALTIME`, hook et `time-mark.sh` sortent en 0 sans rien écrire ; `log-entry.sh` signale clairement l'exigence bash ≥ 4.2. Heure prise en premier dans le hook, avant analyse du JSON et git. Exigence de version documentée. Test : bash sans `EPOCHREALTIME`.
[x] `current_time_ms` rend 1 sans horloge ; heure du hook prise avant `cat` (`EVENT_TIME`) ; `log-entry.sh` sort en 2 sous bash 4.2 ; 2 tests (28 · 9 verts). Constat corrigé : sous bash 5.2, l'ancien hook sortait déjà en 0 sans écrire (erreur d'expansion qui abandonne `main`) — l'« exit 1 » de l'audit ne vaut qu'en exécution en ligne ; le test garde le contrat. README EN/FR, CHANGELOG.

### T26 — Estimation des tâches ajoutées, fichiers comptés depuis `**Files:**`
**Effort:** M
**Estimated files:** 7
**Estimated time:** ≈ 4 min (3-5)
**Files:** `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `skills/forge/scripts/time-calibrate.sh`, `tests/time-calibrate.test.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Audit I4 et S3. Champ `**Estimated files:**` supprimé : nombre de chemins de `**Files:**`, nombre explicite `(≈ n)` en fin de `**Files:**` seulement pour un motif ou des fichiers inconnus. `time-calibrate.sh --files 3,5,8` : toutes les estimations d'un plan en un appel. Tâche ajoutée par la « Surveillance des demandes complémentaires » → `**Estimated time:**` écrit, affiché dans le gabarit `Plan`. Ligne `Remaining` et règle de branche sur le même compte ; anciens plans avec `**Estimated files:**` toujours lus.
**Actual time:** ≈ 1.5 min
[x] `--files 3,5,8` → `estimate` (somme) + `estimates` (3 tests, 23 verts) ; p4 : estimation en un appel, « Fichiers d'une tâche » défini une fois, champ retiré des formats (tâche-branche : `**Files:** … (≈ n)`) ; p5 : colonne Fichiers, Remaining, temps estimé des tâches ajoutées et gabarit `Plan` ; engrave `planned_files` ; README EN/FR, CHANGELOG.

### T27 — Tour interrompu par un nouveau prompt compté
**Effort:** S
**Estimated files:** 3
**Estimated time:** ≈ 2 min (1-2)
**Files:** `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`, `CHANGELOG.md`
**Description:** Audit I1 (temps d'agent sous-mesuré d'environ ×2). Un `UserPromptSubmit` sur un tour ouvert ferme ce tour au dernier événement observé au lieu de l'effacer, pour la branche et pour `--task`. `test_ignores_turn_without_stop` remplacé par trois tests : prompt en file, interruption, `task-notification` en plein tour.
**Actual time:** ≈ 2.6 min
[x] `last_activity` par session, tour ouvert fermé au prompt suivant (branche et `--task`) ; `test_ignores_turn_without_stop` gardé pour le tour ouvert en fin de journal, 4 tests ajoutés (échouent sur l'ancien code ; 62 verts). Journal réel : parent 18,1 min (7,5 avant). CHANGELOG.

### T28 — Agrégation rapide
**Effort:** S
**Estimated files:** 3
**Estimated time:** ≈ 2 min (1-2)
**Files:** `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`, `CHANGELOG.md`
**Description:** Audit I3. `field()` réécrit par `index()`/`substr()`, sans regex recompilée ; `--task` filtre d'abord la fenêtre de la tâche. Résultats identiques sur la suite ; mesure avant/après sur un journal de 50 000 lignes notée ici (20 s aujourd'hui).
**Actual time:** ≈ 2.1 min
[x] `field()` par `index()`/`substr()` : 50 002 lignes → 19,6 s à 1,0 s (branche), 23,5 s à 0,8 s (`--task`), sorties identiques ; filtre de fenêtre inutile, écarté (il couperait les tours ouverts avant la fenêtre). 62 verts, CHANGELOG.

### T29 — Lignes de délégué écrites par script, micro-étapes marquées
**Effort:** S
**Estimated files:** 5
**Estimated time:** ≈ 2 min (2-3)
**Files:** `skills/forge/scripts/time-mark.sh`, `tests/time-mark.test.sh`, `skills/forge/commands/delegation.md`, `skills/forge/commands/swarm.md`, `CHANGELOG.md`
**Description:** Audit I5. `time-mark.sh --event delegate|delegate_usage`, seul chemin d'écriture de ces lignes : sans `ts` pour `delegate`, UTF-8, JSON contrôlé ; plus d'ajout à la main par le modèle. `--task` accepte `T2.1`.
**Actual time:** ≈ 1.7 min
[x] time-mark.sh réécrit (`has_required_arguments`, `build_delegate_line`), 4 tests (13 verts) ; `time-aggregate.sh --task` accepte aussi `T2.1` (62 verts) ; delegation.md « Mesure d'un délégué » par script + invariant ; swarm.md inchangé (renvoie à delegation.md) ; CHANGELOG.

### T30 — Essaim : écriture du plan, questions, aucun lancement sans accord
**Effort:** M
**Estimated files:** 6
**Estimated time:** ≈ 3 min (2-4)
**Files:** `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `skills/forge/commands/swarm.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Audit B2, B3, B5. Plan écrit aussi sur `Validate and launch the swarm`. Question `Next` à 4 options au plus : une seule `Merge and launch <Y>`, les autres lançables citées dans sa description. Seul `Validate and launch the swarm` lance sans question ; à la reprise, question `Swarm` (`Launch <X>, <Y>` / `Work on parent tasks` / `Later`). Impasses levées : aucune branche lançable ni en cours → tâches ordinaires par le mode habituel ; contradiction plan mixte entre `swarm.md` et étape 8 de p5 tranchée. Renvoi « Relance de l'essaim » corrigé, `N` défini là où il sert.
**Actual time:** ≈ 0.8 min
[x] p4 étape 8 ; p5 étape 8 en quatre cas (reprise, question `Swarm`, tâches ordinaires, attente), « Relance de l'essaim » devenue une question `Swarm` définie dans p5 avec N ; swarm.md : déclencheurs = choix de l'utilisateur, `Next` à quatre options, plan mixte par l'étape 9 ; README EN/FR, CHANGELOG.

### T31 — Essaim : un seul délégué par branche, reprise sur question, ports conservés
**Effort:** M
**Estimated files:** 6
**Estimated time:** ≈ 3 min (2-4)
**Files:** `skills/forge/commands/swarm.md`, `skills/forge/commands/delegated-mode.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Audit B4, I9, I13. Colonnes `Agent` (`agent_id`) et `Port` dans `swarm.md`. Reprise seulement après une question `Resume` listant les branches ; plus de déclenchement d'office ni de phrase contraire. Branche `waiting for merge` → question `Next` reposée à la reprise. Port = plus petit libre parmi base + 1 à base + N, conservé dans `RESUME`. `Check before merging` proposé seulement si `**Dev port:**` existe.
**Actual time:** ≈ 0.8 min
[x] swarm.md : colonnes `Agent` et `Port`, port libre le plus petit gardé à la relance, reprise = `Next` reposée puis question `Resume` (`Relaunch` / `Still running` / `Later`), phrase contraire retirée ; p5 : déclencheur « délégué non lancé dans cette conversation » ; delegated-mode.md inchangé (PORT déjà transmis) ; README EN/FR, CHANGELOG.

### T32 — `swarm-status.sh` : dépendances invalides, branches bloquées, worktrees périmés
**Effort:** M
**Estimated files:** 4
**Estimated time:** ≈ 2 min (2-3)
**Files:** `skills/forge/scripts/swarm-status.sh`, `tests/swarm-status.test.sh`, `skills/forge/commands/swarm.md`, `CHANGELOG.md`
**Description:** Audit I6, I7 et mineurs du script. Champs `invalid` (cycle, tâche inconnue, dépendance `[!]`/`[-]`, texte libre dans `Depends on`), `blocked` (tâches-branches `[!]`), `stale` (worktree `prunable`, `git worktree prune` proposé). Statut lu sur la ligne de statut, pas sur une note `[x]` ; nom de branche invalide refusé ; parente absente = erreur, pas conflit. Option `--assume-done <X>` pour la suite d'une fusion. Un test par cas.
**Actual time:** ≈ 3.7 min
[x] Champs `invalid` / `blocked` / `stale`, `--assume-done`, statut sur la première ligne, `check-ref-format`, parente sans branche git → usage, `conflict: null` hors code 1 ; 9 tests (24 verts) ; swarm.md (affichage des nouveaux champs, `--assume-done` dans « Fin d'une branche fille ») ; CHANGELOG. Conflits entre filles toujours non simulés (hors description).

### T33 — Essaim : commits annoncés, règles ciblées, limites documentées
**Effort:** M
**Estimated files:** 6
**Estimated time:** ≈ 3 min (2-4)
**Files:** `skills/forge/commands/swarm.md`, `skills/forge/commands/delegated-mode.md`, `skills/forge/phases/p4-plan.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Audit I10 à I14. Option `Merge` : annonce le commit de la tâche du parent et du worktree, `git status` affiché avant `add -A`. « Contexte de décision » hors questions `Plan`, `Mode`, `Task`, `Brief`, `Promotion`. Pas de plan de branches en mode délégué. Procédure de `Turn into a task`. Limites documentées : relais entre deux tours seulement, permissions du dossier `.worktrees` (`/add-dir`), fichiers ignorés et base de données non isolés, `core.longpaths` sous Windows. `git -C "<WORKTREE>"` guillemeté.
**Actual time:** ≈ 0.8 min
[x] swarm.md : commits annoncés dans `Next`, `status --porcelain` avant `add -A`, contexte de décision limité aux questions de choix (aussi delegated-mode.md), procédure `Turn into a task`, relais entre deux tours (une tâche ordinaire par tour), chemins de worktree guillemetés ; p4 : pas de plan de branches en mode délégué ; puce « Limits » README EN/FR ; CHANGELOG. Guillemets de delegation.md laissés à T34.

### T34 — Cohérence des instructions et de la documentation
**Effort:** M
**Estimated files:** 12
**Estimated time:** ≈ 6 min (4-8)
**Files:** `skills/forge/SKILL.md`, `skills/forge/commands/delegation.md`, `skills/forge/commands/delegated-mode.md`, `skills/forge/commands/engrave.md`, `skills/forge/commands/closure.md`, `skills/forge/commands/swarm.md`, `skills/forge/phases/p0-project.md`, `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Audit, mineurs des instructions. `<PARENT_FOLDER>` / `<PARENT_BRANCH>` au lieu de `<PARENT>` à double sens. `**Estimation ratios:**` retiré (écrit, jamais lu). `metrics.json` de clôture non écrasé par le `grave` suivant, ou règle écrite. Surcharge des seuils par `coding-standards.md` retirée (sans format). Branches filles créées à un seul endroit (`swarm.md`). Invariants répétés (chemin absolu, heure, fusion par le parent) énoncés une fois. `SKILL.md` cite l'essaim dans le mode délégué. Exception d'écriture hors ROOT (`TIME_LOG`, `SCRATCHPAD`) écrite. Mode mise à jour de p0 : `**Check pattern:**` généré pour un projet existant. README : exemples de plan à jour, libellés figés en anglais dans `README.fr.md` ; CHANGELOG : `**Dev port:**` corrigé.
**Actual time:** ≈ 1.3 min
[x] `<PARENT_FOLDER>` / `<PARENT_BRANCH>` ; `**Estimation ratios:**` retiré (engrave étape 4) ; règle de la synthèse de clôture écrite ; surcharge par coding-standards retirée ; création des filles au lancement seulement ; invariants renvoyés à leur source ; SKILL.md cite l'essaim ; exception TIME_LOG / SCRATCHPAD ; p0 mise à jour : `**Check pattern:**` et contrôle du hook ; guillemets dans delegation.md ; exemples de plan README (libellés anglais, `Objective`) ; CHANGELOG. 17 renvois « section de fichier » vérifiés.

### T35 — Vérification d'ensemble
**Effort:** XS
**Estimated files:** 1
**Estimated time:** ≈ 1 min (0-1)
**Files:** `.forge/branch/agent-swarm/plan.md`
**Description:** Toutes les suites de `tests/` vertes. Journal réel de la branche réagrégé : minutes d'agent avant et après T27 notées. Estimation sur un dépôt sans `master` ni `main`. Reprise rejouée sur un plan de branches jetable : question `Swarm` posée, aucun lancement automatique.
**Actual time:** ≈ 4.8 min
[x] 11 suites vertes (297 tests). Journal réel : parent 9,5 min avec l'ancien script, 18,1 avec le nouveau. Dépôt `develop` sans master ni main : `files: null`, calibrage en JSON valide (code 0). Reprise de l'essaim vérifiée à la lecture seulement (étape 8 de p5, déclencheurs de swarm.md) : rejouer des instructions demande une vraie session.


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
| T20 — Motif de vérification sans ancrage | XS | [x] |
| T21 — Ratio de tokens des seules branches déléguées | XS | [x] |
| T22 — Seuil de branche à 300 000 tokens | XS | [x] |
| T23 — En-tête du plan et règle de coche | XS | [x] |
| T24 — Calibrage robuste et estimations arrondies | XS | [x] |
| T25 — Hook et marqueurs sûrs sous bash < 5 | S | [x] |
| T26 — Estimation des tâches ajoutées, fichiers depuis Files | M | [x] |
| T27 — Tour interrompu par un nouveau prompt compté | S | [x] |
| T28 — Agrégation rapide | S | [x] |
| T29 — Lignes de délégué écrites par script | S | [x] |
| T30 — Essaim : plan, questions, aucun lancement sans accord | M | [x] |
| T31 — Essaim : un délégué par branche, reprise, ports | M | [x] |
| T32 — `swarm-status.sh` : dépendances, bloquées, périmés | M | [x] |
| T33 — Essaim : commits annoncés, règles, limites | M | [x] |
| T34 — Cohérence des instructions et de la documentation | M | [x] |
| T35 — Vérification d'ensemble | XS | [x] |
| **Total** | **6 XS · 13 S · 13 M · 3 L** | |
