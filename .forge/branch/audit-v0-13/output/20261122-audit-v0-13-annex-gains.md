# T1 — Apports de la 0.13.0 en fluidité et vitesse (vs 0.12.6)

Sources : `git diff v0.12.6 v0.13.0 -- skills/ hooks/ install/` (20 fichiers, +1930 / −58), `git show v0.12.6:…`, `CHANGELOG.md` § 0.13.0.
Temps des scripts **mesurés** sous Git Bash 5.2.26 (Windows 11), dans un dépôt jetable du scratchpad (supprimé ensuite) et, en lecture seule, sur ce dépôt. Volume d'instructions = `wc -w` des fichiers chargés sur le parcours (proxy du coût en tokens, avant cache).

---

## 1. Tableau avant / après par parcours

| Parcours | Fichiers lus | Mots 0.12.6 → 0.13.0 | Questions 0.12.6 → 0.13.0 | Appels Bash 0.12.6 → 0.13.0 | Autres appels d'outil ajoutés |
|---|---|---|---|---|---|
| Démarrage `/forge` (Détection d'état) | SKILL.md | 2468 → 2563 (+4 %) | 0–1 (`Resume` sur master, `update`) → idem | 1 → 1 (status + update + checks en un appel) | — |
| Reprise branche active | SKILL.md + p5-resume.md | 5025 → 5898 (+17 %) | `Mode` (+`Task`) → idem ; plan de branches : `Mode` remplacé par `Swarm`/`Resume` | 1 → 2 (+ `time-calibrate.sh` pour la ligne « Remaining », p5-resume.md:50) ; +1 `swarm-status.sh` si plan de branches | — |
| Brief | SKILL.md + p2-brief.md | 2836 → 2931 (+3 %) — p2 inchangé | 1–2 (objectif libre + `Objective`) → idem | 0 → 0 | — |
| Plan | p4-plan.md (+ p2 en amont) | 693 → 1644 (**+137 %**) ; +2979 (swarm.md) si plan de branches | `Approach` (cond.) + `Plan` → idem ; 4e option `Validate and launch the swarm` si plan de branches | 0 → 1 (`time-calibrate.sh --files`) ; +1 (`--groups`) si plan de branches | — |
| Exécution d'une tâche | p5-resume.md (déjà chargé) | 2557 → 3335 (+30 %) | 0 par tâche en mode enchaîné → idem | 0 → **2 par tâche** (start ; done + aggregate) — p5-resume.md:80-81 | +1 Edit `**Actual time:**` par tâche (p5-resume.md:82) |
| Entrée LOG | — | — | — | 0 → 1 (`log-entry.sh`) | **−1 Read** de log.md (avant : Read + Edit obligatoires pour l'outil Edit) |
| Grave | engrave.md | 1579 → 1957 (+24 %) | 0 (+2 par projet lié) → idem | 1 → 2 (+ `time-aggregate.sh`, engrave.md:33) | +1 Write `metrics.json` |
| Clôture | closure.md (+ **engrave.md** désormais, closure.md:9) | 918 → 962 ; **918 → 2919** si engrave.md pas encore lu dans la session (+218 %) | 2–4 (`Closure`, `Tasks`, `ClickUp`, `Email`) → idem | 0 → 1 (`time-aggregate.sh`) | +1 Write `metrics.json` |

### Branche type complète (brief → plan de 4 tâches enchaînées → 1 grave → 1 clôture, 2 entrées LOG)

| Indicateur | 0.12.6 | 0.13.0 | Écart |
|---|---|---|---|
| Questions `AskUserQuestion` | 4–6 | 4–6 | **0** |
| Appels Bash du skill | 2 | 16 (1+1+1+8+2+1+2) | **+14** |
| Autres appels d'outil (Read/Edit/Write) | 4 (LOG : 2 × Read+Edit) | 8 (4 Edit `Actual time` + 2 Write `metrics.json` + 0 Read LOG ; LOG passe en Bash) | +4 |
| Mots d'instructions (SKILL+p2+p4+p5+engrave+closure) | 8 583 | 10 829 | **+26 %** |
| Temps d'exécution mesuré des scripts ajoutés | — | ≈ 4,5 s (8 marques ≈ 0,2 s, 4 agrégations de tâche ≈ 0,16 s, 2 calibrages ≈ 0,27 s, 2 agrégations de branche ≈ 0,73 s, 2 log-entry ≈ 0,14 s) | +4,5 s |
| Événements hook (asynchrones) | 0 | 1 par prompt, fin de tour, sous-agent, question et **chaque** Bash | non bloquant |

L'aller-retour modèle de chaque appel d'outil supplémentaire (+18) s'ajoute aux 4,5 s de script ; sa durée n'a pas été mesurée ici.

---

## 2. Gains réels pour l'utilisateur

| Nouveauté | Gain | Nature |
|---|---|---|
| `log-entry.sh` (SKILL.md:68-73, scripts/log-entry.sh) | Horodatage réel (les heures écrites par le modèle étaient inventées — CHANGELOG) ; supprime la lecture de `log.md` qu'imposait l'outil Edit, alors que p5 interdit déjà sa lecture « pour le coût » (p5-resume.md:10). 1 appel au lieu de 2. | **Réel, fiabilité + tokens** |
| Essaim (`commands/swarm.md`, `swarm-status.sh`) | Seul levier de **vitesse** réelle : jusqu'à 3 délégués en parallèle, worktree et port séparés. | Réel mais **rarement déclenché** (voir C5) |
| Estimation (`time-calibrate.sh`, `**Estimate:**`, `**Estimated time:**`) | Ordre de grandeur affiché au plan et en reprise. | Informatif ; fiable seulement après 20 tâches mesurées avec fichiers (time-calibrate.sh:5-12) |
| Mesure (`time-hook.sh`, `time-mark.sh`, `time-aggregate.sh`, `metrics.json`) | Temps agent / humain / vérifications / questions par branche et par tâche, versionné. | Observabilité ; aucun gain de vitesse direct, alimente le calibrage |
| `**Check pattern:**` (p0-project.md:34-36) | Compte le temps de vérification. | Mesure seulement |
| Effort sans durée, colonne fichiers | Lisibilité. | Neutre |

---

## 3. Coûts ajoutés

- **+2 appels Bash + 1 Edit par tâche**, dans tous les modes (p5-resume.md:76-83), qui ne servent qu'à la mesure ; en mode enchaîné ils s'intercalent entre les tâches.
- **+26 % d'instructions** sur une branche complète, p4-plan.md plus que doublé (règle de branche, plan de branches, format tâche-branche) même quand aucun essaim n'est possible : la règle est évaluée à chaque plan (p4-plan.md:34).
- **Hook global** sur 6 événements (install/install.ps1:12-16, install/install.sh:45-49), déclaré `async: true` : pas d'attente pour l'utilisateur, mais un processus `bash` + `cat` + `git rev-parse` à chaque événement retenu, **dans tous les projets** (sortie silencieuse seulement après `git rev-parse`, time-hook.sh:47-56). Coût mesuré : 140–170 ms hors projet forgé, 160–200 ms dans un projet forgé, **554 ms** pour une sortie d'outil de 400 Ko (lecture entière par `$(cat)` puis regex bash, time-hook.sh:131-137). Volume observé : 60 lignes dans `.forge/branch/audit-v0-13/time-log.jsonl` (52 `PostToolUse`) dès le début de cette session d'audit.
- `metrics.json` réécrit et commité à chaque grave.

---

## 4. Constats

| # | Gravité | Constat | Preuve |
|---|---|---|---|
| C1 | **gênant** | L'estimation par nombre de fichiers est inadaptée aux tâches sans code (audit, analyse, rédaction) : référence 0,5 min/fichier, plancher 1 min. Le plan de **cette** branche affiche 5 tâches à « ≈ 1 min (1-1) », dont une d'effort L, et un en-tête « ≈ 5 files · ≈ 2 min ». L'effort (M/L) et l'estimation se contredisent à l'écran. | `.forge/branch/audit-v0-13/plan.md:4,10-39` ; `references/estimation.json` (`minutes_per_file: 0.5`) ; `scripts/time-calibrate.sh:143` (`rounded < 1 ? 1`) ; `phases/p4-plan.md:91-93` |
| C2 | **gênant** | Un livrable écrit sous `.forge/` (OUTPUT) n'est jamais compté comme fichier réel : l'empreinte exclut `.forge`. Prévu = 1, réel = 0 pour toute tâche d'audit ; ces tâches sortent du calcul min/fichier (`$5 > 0`) mais **restent** dans la fourchette (rapport réel ÷ estimé avec un estimé plancher à 1 min) et la déforment. | `scripts/time-mark.sh:84` (`':(exclude).forge'`) ; `scripts/time-calibrate.sh:61-64,95-96` |
| C3 | gênant | En-tête `**Estimate:**` : somme des fichiers par tâche, un même fichier listé dans 5 tâches compte 5 fois (« ≈ 5 files » pour 1 fichier distinct). | `.forge/branch/audit-v0-13/plan.md:4` ; `phases/p4-plan.md:30-32` |
| C4 | gênant | Coût de mesure par tâche (+2 Bash, +1 Edit) sans bénéfice visible pendant la tâche ; la marque `start` est un appel isolé « avant toute autre action ». | `phases/p5-resume.md:80-82` |
| C5 | mineur | Seuil de branche = 15 min ÷ 0,5 min/fichier = **30 fichiers par groupe**, deux groupes requis : l'essaim, seul gain de vitesse, n'est presque jamais proposé tant que le calibrage reste sur la référence ; la règle est pourtant relue et évaluée à chaque plan. | `phases/p4-plan.md:98-101` ; `references/estimation.json` |
| C6 | mineur | La clôture renvoie désormais à une section de `engrave.md` (+1957 mots si non lu) et écrit un `metrics.json` qu'elle déclare elle-même écrasé à la prochaine grave ; sans grave ultérieure, le fichier reste modifié hors commit. | `commands/closure.md:9` ; `commands/engrave.md:16,28-42` |
| C7 | mineur | Hook lancé dans tous les projets (pas seulement ceux sous forge) pour chaque Bash / prompt / fin de tour ; 140–200 ms CPU par événement, 0,5 s sur grosse sortie. Asynchrone : aucune latence perçue. | `install/install.ps1:12-16` ; `scripts/time-hook.sh:12-56,126-146` |
| C8 | mineur | `time-aggregate.sh` d'une branche : 0,73 s sur un journal de 60 lignes ; le CHANGELOG annonce 1 s pour 50 000 lignes (non re-mesuré ici). | mesure locale ; `CHANGELOG.md` § 0.13.0 |
| P1 | positif | `log-entry.sh` : heure réelle, entrée en tête, 1 appel au lieu de Read + Edit, `log.md` jamais lu. | `SKILL.md:68-73` ; `scripts/log-entry.sh:70-88` |

---

## 5. Conclusion chiffrée

Sur le parcours standard (brief → plan → tâches enchaînées → grave → clôture), la 0.13.0 n'enlève **aucune question** et en ajoute aucune ; elle ajoute **+14 appels Bash et +4 appels d'outil** pour une branche de 4 tâches (≈ 4,5 s de scripts mesurés, plus les allers-retours modèle non mesurés), et **+26 % d'instructions** (+137 % sur le plan). Le seul gain de fluidité net est `log-entry.sh` (−1 Read par entrée LOG, heure fiable). Le seul gain de vitesse réel, l'essaim, ne se déclenche qu'au-delà de ~30 fichiers par groupe avec les valeurs de référence.

**Bilan : perte nette modérée en fluidité et en vitesse sur le parcours courant** (≈ +18 appels d'outil et +2 250 mots par branche type), compensée par un gain d'**observabilité** (mesure par tâche et par branche, `metrics.json`) qui ne rapporte qu'à terme, après ~20 tâches mesurées. Pour les tâches sans code (audit, analyse), l'estimation actuelle est trompeuse (1 min par tâche) et la mesure des fichiers nulle : gain nul, coût entier.

Pistes (non appliquées) : fusionner la marque `start` avec la première commande de la tâche ou la faire porter par le hook ; ne lancer `time-calibrate.sh` en reprise que si le plan a changé ; un champ d'estimation explicite en minutes pour les tâches sans fichier de code (ou exclure `.forge/branch/*/output` de l'exclusion) ; limiter le hook aux dépôts contenant `.forge/` avant tout appel à `git`.
