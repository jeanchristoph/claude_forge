# Plan — task-time
**Objective:** Donner à chaque tâche d'un plan forge un temps estimé figé et un temps réel mesuré entre deux marques, en s'appuyant sur la mesure livrée par `agent-swarm`.
**Date:** 2026-11-20
**Estimate:** ≈ 13 files · ≈ 2 min (1-2) · indicative

## Tasks

### T1 — Script `time-mark.sh` et ses tests
**Effort:** S
**Estimated files:** 2
**Files:** `skills/forge/scripts/time-mark.sh`, `tests/time-mark.test.sh`
**Description:** `time-mark.sh --root <ROOT> --branch <BRANCH> --task T<n> --event start|done [--time-log <fichier>]`. Journal cible : `<ROOT>/.forge/branch/<BRANCH>/time-log.jsonl` ; `--time-log` le remplace (délégué → journal du parent) et ajoute `"branch":"<BRANCH>"` à la ligne. Ligne : `{"ts":<ms>,"event":"task_start"|"task_done","task":"T<n>"[,"branch":"<X>"]}` (horodatage en tête, comme le hook, pour le tri de `time-aggregate.sh`). Journal absent → rien ; arguments invalides → rien ; sortie 0 toujours, rien sur stdout, aucun transcript lu ; `json.sh` pour l'échappement, horloge `EPOCHREALTIME` comme `time-hook.sh`. Tests en dépôts jetables : start puis done, journal absent → rien écrit, `--time-log` ajoute `branch`, argument manquant / événement inconnu → code 0 et rien écrit, stdout vide dans tous les cas.
[x] 8 tests verts.

### T2 — `time-aggregate.sh --task T<n>` et ses tests
**Effort:** M
**Estimated files:** 2
**Files:** `skills/forge/scripts/time-aggregate.sh`, `tests/time-aggregate.test.sh`
**Description:** Option `--task T<n>` : fenêtre = dernière marque `task_start` de la tâche → `task_done` qui suit. Marques lues dans le journal de la branche (session principale, marques sans `branch`) ou, avec `--parent-log`, dans le journal du parent (marques portant `"branch":"<BRANCH>"`). Durées découpées à la fenêtre : un tour (prompt → `Stop`) ou une exécution de délégué (`SubagentStart` → `SubagentStop`, ou → marque `done` si encore ouverte) ne compte que sa part dans la fenêtre ; attentes de question dans la fenêtre retirées et comptées en humain ; absence > 6 h écartée comme aujourd'hui. Sortie JSON d'une ligne : `{"branch":…,"task":"T<n>","agent_minutes":…,"human_minutes":…,"questions":…,"measured":true|false,"reason":null|"no_log"|"late_start"|"missing_start"|"missing_done"}`. Sans `--task`, sortie inchangée à l'octet près. Tests `--task` : fenêtre normale, question dans la fenêtre, marque de début manquante, délégué (marques + événements dans le journal du parent), absence > 6 h, journal `late_start` → `measured:false` ; tests existants verts.
[x] 18 cas --task, 54 tests verts ; tour ou délégué encore ouvert compté jusqu'à task_done (le plus récent seul) ; AWK_HELPERS et run_on_logs partagés.

### T3 — Texte du skill : estimé figé, marques, réel, tableau
**Effort:** M
**Estimated files:** 5
**Files:** `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `skills/forge/commands/delegated-mode.md`, `skills/forge/commands/delegation.md`, `skills/forge/commands/swarm.md`
**Description:** `p4-plan.md` : étape 6 → chaque tâche reçoit `**Estimated time:** ≈ <min> min (<bas>-<haut>)` par `time-calibrate.sh --files <Estimated files>` ; champ ajouté au format sous `**Estimated files:**` ; valeur figée, jamais recalculée (règle énoncée une fois). `p5-resume.md` : au démarrage de chaque tâche `time-mark.sh --event start`, à la coche `--event done` puis `time-aggregate.sh --task` → `**Actual time:** ≈ <min> min` sous `**Estimated time:**` (`measured:false` → `**Actual time:** —`), dans tous les modes ; tableau d'avancement Task | Effort | Files | Estimated | Actual | Status (colonnes Estimated / Actual omises si aucune tâche ne porte `**Estimated time:**`) ; `Remaining ≈ …` inchangé. `delegated-mode.md` : entrée LOG « task <n> started » gardée ; les marques passent `--time-log` avec la valeur de la ligne `TIME_LOG:` du prompt (ligne absente → sans `--time-log`). `delegation.md` et `swarm.md` : le prompt du délégué gagne `TIME_LOG: <dépôt principal>/.forge/branch/<PARENT>/time-log.jsonl`. `swarm.md` : à la fusion d'une branche fille, `agent_minutes` de `metrics.json` reporté dans `**Actual time:**` de la tâche-branche.
[x] Section « Mesure d'une tâche » dans p5 ; TIME_LOG: dans les prompts de délégation de branche et d'essaim (pas en projet lié) ; fins de ligne CRLF gardées.

### T4 — Documentation
**Effort:** S
**Estimated files:** 4
**Files:** `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:** Arborescence (`time-mark.sh`, `time-mark.test.sh`) et paragraphe de mesure dans les deux README, même plan de section ; entrée CHANGELOG ; `## Key structure` de `project.md` (script et test) et mention de `TIME_LOG:` dans la convention du mode délégué.
[x] Arborescences, paragraphe « Per task » / « Par tâche », entrée CHANGELOG, project.md.

### T5 — Une seule mesure pour tout délégué rattaché à une tâche du plan parent
**Effort:** M
**Estimated files:** 6
**Files:** `skills/forge/commands/delegation.md`, `skills/forge/commands/delegated-mode.md`, `skills/forge/commands/swarm.md`, `tests/time-aggregate.test.sh`, `README.md` / `README.fr.md`, `CHANGELOG.md`
**Description:** Principe utilisateur : que le délégué soit sur le projet courant ou un projet externe ne change rien si une tâche au plan du parent existe. 1. Règle commune écrite une seule fois dans `delegation.md`, reprise par renvoi depuis « Délégation — projet lié », « Délégation — branche du même dépôt » et `swarm.md` : ligne `delegate` au lancement dans le journal de la branche parente, `delegate_usage` à chaque retour, ligne `TIME_LOG:` (chemin absolu du journal parent) dans le prompt. 2. Projet lié : marques portant `"branch":"<LINKED_BRANCH>"` ; journal parent éventuellement dans un autre dépôt, lu par `--parent-log` ; chemin absolu seulement dans le prompt, jamais dans un fichier écrit. 3. `FORGE_DONE` : chaque ligne `done` porte le réel de la tâche enfant (`actual ≈ <min> min` ou `—`). 4. Coche d'une tâche parente déléguée (« Retour — application de `FORGE_DONE` ») : `**Actual time:**` = somme des réels de ses tâches `← parent T<n>` ; un enfant non mesuré → `—`, jamais de somme partielle présentée comme complète. Tâche-branche d'essaim inchangée (réel tiré de `metrics.json`). 5. Tests : `time-aggregate --task` pour un délégué de projet lié (marques `<parent>/<branche>` et événements dans le journal parent) ; somme au retour avec un enfant non mesuré → `—`.
[x] Section « Mesure d'un délégué » dans delegation.md, renvois depuis projet lié, même dépôt et swarm.md ; `--task T1,T2` somme les enfants (non mesurée dès qu'un enfant ne l'est pas) ; tâche déléguée exclue des marques du parent dans p5 ; 58 tests verts.

### T6 — Entrées de LOG horodatées par un script
**Effort:** M
**Estimated files:** 12
**Files:** `skills/forge/scripts/log-entry.sh`, `tests/log-entry.test.sh`, fichiers du skill qui écrivent une entrée LOG (`phases/*.md`, `commands/*.md`, `SKILL.md`, `skills/forge-clickup/SKILL.md` si concerné), `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:** Cause : les horodatages des LOG étaient inventés (l'IA n'a pas d'horloge), et une entrée a été insérée sous la première ligne prise pour un titre. 1. Nouveau script `log-entry.sh --root <ROOT> --branch <BRANCH> --text "<texte>"` : lit l'horloge locale, écrit `- [AAAA-MM-JJ HH:MM] <texte>` en tête de `.forge/branch/<BRANCH>/log.md` (créé s'il est absent), fins de ligne du fichier conservées (CRLF ou LF), texte pris tel quel ; texte vide ou arguments invalides → rien écrit, code 1, erreur sur la sortie d'erreur ; succès → code 0, sortie standard vide. 2. Règle unique, énoncée une fois dans le skill, les autres fichiers y renvoient : toute entrée LOG passe par `log-entry.sh` ; l'IA n'écrit jamais elle-même une date ni une heure dans un LOG. 3. Recensement : chaque endroit du skill qui écrit une entrée LOG appelle le script avec le texte seul ; format `[AAAA-MM-JJ HH:MM]` retiré des consignes, LOG d'une branche liée ou fille écrits par le parent compris (`--root` du worktree). 4. Tests sur dépôts jetables : insertion en tête avec entrées existantes ; création si absent ; CRLF conservé ; accents, backticks, `$`, guillemets tels quels ; texte vide ou argument manquant → code 1, fichier inchangé ; horodatage conforme à l'horloge. 5. Documentation : arborescence des deux README, `CHANGELOG.md`, `## Key structure` de `project.md`.
[x] Règle unique « Entrée LOG » dans SKILL.md ; formats horodatés retirés de p4, p5, delegated-mode, delegation, swarm ; titre `# ` gardé au-dessus de l'entrée ; texte sur plusieurs lignes refusé ; 15 tests verts.

### T7 — Heure du tableau d'état de l'essaim fournie par un script
**Effort:** S
**Estimated files:** 3
**Files:** `skills/forge/scripts/swarm-status.sh`, `tests/swarm-status.test.sh`, `skills/forge/commands/swarm.md`
**Description:** `swarm-status.sh` ajoute à son JSON un champ `"now":"AAAA-MM-JJ HH:MM"`, lu sur l'horloge locale. `swarm.md` : à chaque réécriture de SWARM, la colonne `Since` reprend le `now` du dernier `swarm-status.sh` ; l'IA n'écrit jamais elle-même une heure ; renvoi à « Entrée LOG » de `SKILL.md` (un seul principe : l'heure vient toujours d'un script). Test : champ `now` présent, au bon format, conforme à l'horloge du système ; tests existants verts.
[x] Champ `now` en fin de JSON ; INVARIANT sous le gabarit de swarm.md (Since et date des choix tirés de `now`) ; 15 tests verts.

## Risks
- Découpage d'un tour à la fenêtre : la marque `start` tombe au milieu d'un tour (appel Bash pendant le tour) ; le tour ne compte que sa part postérieure à la marque, sinon le temps d'une tâche absorbe la fin de la précédente.
- Marques répétées (tâche reprise après `[!]`, relancée) : seule la dernière paire `task_start` → `task_done` est retenue ; le temps des tentatives antérieures est perdu, choix assumé.
- Lignes de marque dans le journal : `read_partial` prend le premier `ts` ; une marque est toujours postérieure au brief, donc la détection de départ tardif est inchangée — vérifié par un test.

## Deployment
None

## Summary
| Task | Effort | Files | Status |
|---|---|---|---|
| T1 — Script `time-mark.sh` et ses tests | S | 2 | [x] |
| T2 — `time-aggregate.sh --task` et ses tests | M | 2 | [x] |
| T3 — Texte du skill | M | 5 | [x] |
| T4 — Documentation | S | 4 | [x] |
| T5 — Une seule mesure pour tout délégué | M | 6 | [x] |
| T6 — Entrées de LOG horodatées par un script | M | 12 | [x] |
| T7 — Heure du tableau d'état de l'essaim | S | 3 | [x] |
| **Total** | **3 S · 4 M** | **34** | |
