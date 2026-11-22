# Audit T3 — non-régression v0.12.6 → v0.13.0 (lecture seule)

Dépôt : `D:/www/perso/claude skills/forge`, branche `audit-v0-13`, Git Bash sous Windows 11. Les deux tags ont été comparés : `v0.12.6` et `v0.13.0` (= HEAD).
Aucun fichier suivi n'a été modifié, et aucune commande `git add`, `commit`, `checkout` ou `stash` n'a été lancée. Les dossiers temporaires `v0126` et `cross` ont été supprimés. Les sorties brutes des tests sont dans `res013/` et `res0126/`.

## 1. Résultats des tests

### Suites de v0.13.0 (lancées depuis la racine du dépôt)

| Suite | Résultat | Cas | Durée |
|---|---|---|---|
| checks | OK | 14 | 6 s |
| engrave | OK | 33 | 81 s |
| install (install.sh + install.ps1) | OK | 25 (0 ignoré) | 34 s |
| log-entry | OK | 15 | 4 s |
| status | OK | 30 | 20 s |
| swarm-status | OK | 24 | 22 s |
| time-aggregate | OK | 73 | 72 s |
| time-calibrate | OK | 27 | 9 s |
| time-hook | OK | 28 | 22 s |
| time-mark | OK | 15 | 5 s |
| update | OK | 29 | 34 s |
| **Total** | **11/11 OK** | **313** | **≈ 309 s** |

Aucun échec. Rien n'a été ignoré : `node`, `powershell` et `git` sont tous présents.

### Suites de v0.12.6 (extraites dans `audit/v0126`)

`git archive` ne suffit pas pour cette extraction. Le `.gitattributes` de v0.12.6 marque `tests/`, `docs/`, `.forge/` et `.gitattributes` en `export-ignore`. Ces fichiers ont donc été extraits par `git show v0.12.6:<fichier>`.

| Suite | v0.12.6 : cas / durée | v0.13.0 : cas / durée | Écart |
|---|---|---|---|
| checks | 12 / 5 s | 14 / 6 s | +2 cas (journal `time-log.jsonl`) |
| engrave | 33 / 90 s | 33 / 81 s | identique, bruit de mesure |
| install | 19 / 24 s | 25 / 34 s | +6 cas (hook de mesure ×2 installeurs), +10 s |
| status | 30 / 21 s | 30 / 20 s | identique |
| update | 29 / 35 s | 29 / 34 s | identique |
| **Total des 5 suites communes** | **123 / 175 s** | **131 / 175 s** | durée stable |

Six suites sont nouvelles (`log-entry`, `swarm-status`, `time-*`) : 190 cas, environ 134 s.

### Tests croisés : tests de v0.12.6 sur les scripts de v0.13.0

| Suite | Résultat |
|---|---|
| engrave | 33/33 OK |
| install | 19/19 OK |
| status | 30/30 OK |
| update | 29/29 OK |
| checks | 7/12. Les 5 échecs sont **attendus** : chaque assertion du bloc `.gitignore` reçoit désormais en plus la règle `/.forge/branch/**/time-log.jsonl`. C'est voulu, et c'est couvert par les tests de v0.13.0. |

Conclusion : aucun comportement testé de v0.12.6 n'a régressé dans les scripts.

## 2. Comportements modifiés (fonctions existantes, hors essaim et mesure)

Chaque parcours a été rejoué à sec sur les instructions des deux versions.

| Parcours | v0.12.6 | v0.13.0 | Verdict |
|---|---|---|---|
| Garde main/master (`SKILL.md` §« Garde de sécurité ») | — | Inchangé (aucun diff dans cette section) | OK |
| Brief p2 | — | `p2-brief.md` inchangé | OK |
| État 0, `project.md` (p0) | Écrit, puis enchaîne | Ajoute en plus la section « Vérifications » (`**Check pattern:**`), puis le « Contrôle — hook de mesure » : un Grep dans `~/.claude/settings.json` et une ligne affichée si le hook est absent (`p0-project.md:84`). En mode mise à jour, propose d'ajouter `Check pattern` s'il manque (`:95`). | Modifié, aucune question en plus. Une lecture hors projet peut déclencher une demande de permission (voir R6). |
| Plan p4 sans essaim | Étape 6 : génère et présente. Étape 7 : `Validate and chain` / `Validate` / `Cancel`. | Étape 6 : un appel Bash `time-calibrate.sh`, puis `**Estimate:**` et `**Estimated time:**` par tâche. Le tableau Summary passe à 4 colonnes. Effort XS…XL sans durée. Étape 7 : mêmes trois options. | Options inchangées. Un appel de script en plus. |
| Renvoi p4 → p5 | « étape 8 de `p5-resume.md` » | « étape 9 de `p5-resume.md` » (`p4-plan.md:48`), cohérent avec la nouvelle étape 8 de p5 | OK, renuméroté correctement |
| Reprise p5 | Étapes 1 à 8 | Nouvelle étape 8, « Plan de branches », qui ne s'applique que si une tâche `### Tn — Branch` est ouverte. L'ancienne étape 8 devient la 9. Tableau d'avancement à 6 colonnes, réduit à 3 si le plan n'a pas d'`**Estimated time:**`. Ligne « Remaining » sous le tableau. | Rétrocompatible avec les anciens plans |
| Mode enchaîné | `Validate and chain` → aucune question | Identique pour un plan ordinaire. Plan de branches : voir R1. | R1 |
| Tâche (démarrage et coche) | Coche par édition | `time-mark.sh` au démarrage. À la coche : `time-mark.sh`, puis `time-aggregate.sh`, puis écriture de `**Actual time:**`. Coche imposée par l'outil Edit (jamais `sed`). | Deux appels Bash de plus par tâche |
| Entrées LOG | Édition directe de `log.md` (`- [AAAA-MM-JJ HH:MM] …`) | Uniquement par `log-entry.sh` (INVARIANT `SKILL.md:55`). Plus aucune consigne de format manuel : grep `HH:MM` → 0 occurrence hors des scripts. | Modifié, voir R2 et R3 |
| Délégation, projet lié | `<LINKED>` absolu dans les notes, le brief et le log | `<LINKED_REL>` et `<PARENT_FOLDER>` (relatifs). Les anciennes notes absolues restent lues (`engrave.md:48`). Ligne `TIME_LOG:` dans le prompt. Entrées LOG via le script, `--root <LINKED_WORKTREE>`. | Rétrocompatible |
| Délégation, branche | — | Ligne `TIME_LOG:` et « Mesure d'un délégué ». Aucune écriture dans PLAN ou LOG parent (inchangé). | OK |
| `delegated-mode.md` | — | Écriture hors ROOT permise pour `TIME_LOG` et `SCRATCHPAD`. Chaque ligne `done` de `FORGE_DONE` porte `· actual ≈ n min`. Règles `SWARM:` ajoutées. | OK |
| Grave (`engrave.md`, `engrave.sh`) | Étapes 1 à 5 | Nouvelle étape 0 : écrire `metrics.json`, qui part avec le commit. Une ligne « Estimated … actual … » sous le tableau. `engrave.sh` inchangé (aucun diff). | Modifié : un fichier versionné de plus par branche |
| Clôture (`closure.md`) | `Solved` → étape 2 | `Solved` → écrit `metrics.json` (`event: closure`), puis étape 2 | Modifié, voir R4 |
| forge-clickup | — | Aucun diff | OK |
| Hook PreCompact (`hooks/`) | — | Aucun diff. Il injecte le plan entier, ce qui reste compatible avec les nouveaux champs. | OK |
| Installeurs | Fusion permissions + PreCompact | Ajoutent `time-hook.sh` (asynchrone) sur 6 événements. Une entrée `time-hook` déjà présente est retirée avant l'ajout. Les hooks étrangers sont gardés. Testé sur les deux installeurs (3 cas chacun). | Idempotent et vérifié |
| `checks.sh` | Règle `input/` | Ajoute aussi `/.forge/branch/**/time-log.jsonl` | Voir R5 |

### Renvois « section X de fichier Y »

Toutes les références `« … »` des fichiers de `skills/` ont été extraites, puis cherchées en titre `#` par grep. Chaque renvoi de section pointe vers une section qui existe : « Mesure d'un délégué », « Mesure d'une tâche », « Règle de branche », « Prompt du délégué », « Synthèse de mesure — `metrics.json` », « Relance de l'essaim », « Reprise de l'essaim », « Fusion d'une branche fille », « Entrée LOG », « Gabarit — compte rendu de livraison », etc.
Deux renvois désignent un libellé en gras plutôt qu'un titre, et ils existent aussi :
- « Fichiers d'une tâche » : `p4-plan.md:91` ;
- « Validation d'un contenu » : `SKILL.md:104`.

Aucun renvoi cassé n'a été trouvé.

### Numéros d'étape

Les renvois par numéro ont été relus dans `p4` (5, 7, 9), `p5` (8, 9), `delegation.md` (4, 5, 6), `engrave.md` (0, 2, 4), `closure.md` (3, 4) et `swarm.md` (étape 9 de p5). Tous sont cohérents. Aucun renvoi vers « étape 8 de p5 » n'est resté en ancienne numérotation.

## 3. Régressions et points de vigilance

| # | Gravité | Fichier:ligne | Constat (vérifié) | Correction proposée |
|---|---|---|---|---|
| R1 | Moyenne | `p4-plan.md:38` et `:43` contre `p5-resume.md:19-24` | **Contradiction.** Sur un plan de branches, l'option `Validate and chain` reste proposée avec la promesse « … without any further question ». Or p5 applique l'étape 8 avant l'étape 9 : une tâche `Branch` ouverte suffit pour qu'il n'y ait pas d'enchaînement. p5 lance `swarm-status`, puis pose la question `Swarm` (« Relance de l'essaim ») ou s'arrête. L'option ne fait donc pas ce qu'elle annonce. En plus, `p4-plan.md:37` dit « Trois options » alors qu'il y en a quatre dans ce cas. | Plan de branches : retirer `Validate and chain` (il reste `Validate and launch the swarm` / `Validate` / `Cancel`). Sinon, en tête de l'étape 8 de p5, ajouter « plan validé dans ce tour par `Validate and chain` → étape 9, tâches ordinaires seulement » et reformuler la description. Corriger aussi « Trois options » en « Trois options (quatre pour un plan de branches) ». |
| R2 | Moyenne (documentée) | `log-entry.sh:63-66`, `SKILL.md:55` | **Perte de fonction sous bash < 4.2** (`/bin/bash` 3.2 de macOS). `log-entry.sh` sort avec le code 2 sans rien écrire, et l'INVARIANT interdit à Claude d'éditer LOG lui-même. Les décisions ponctuelles, `Delegated …`, `Opened from …` et les autres entrées sont donc perdues. En v0.12.6, LOG s'écrivait par Edit, sans dépendance au bash. La limite est documentée (`README.md:65`, CHANGELOG). Non testé ici : bash 3.2 n'est pas disponible. | Ajouter à « Entrée LOG » de `SKILL.md` : « sortie 2 → signaler une fois en une ligne "bash ≥ 4.2 required, LOG entry skipped" », pour que la perte ne soit pas silencieuse. Ou bien accepter un repli par Edit avec l'heure lue par `date`. |
| R3 | Faible à moyenne | `install/install.sh:66` (`projectRules`), `install.ps1` (mêmes règles) | **Demandes de permission possibles en plus.** En v0.12.6, les entrées LOG silencieuses passaient par Edit, couvert par la règle `Edit(/.forge/**)` posée par l'installeur. En v0.13.0, chaque entrée LOG, marque de tâche ou estimation est un appel `bash ~/.claude/skills/forge/scripts/…`. Aucune règle d'installeur ne couvre ces appels (seulement `Bash(bash -c "git branch --show-current*)`). Un utilisateur qui n'est ni en mode auto ni en allow Bash large reçoit une demande par entrée LOG, alors que la consigne dit « écrire silencieusement ». Ce n'est pas nouveau pour `status.sh` et `engrave.sh`, mais la fréquence passe d'un appel au démarrage à plusieurs par tâche. | Ajouter aux `projectRules` des deux installeurs une règle `Bash(bash ~/.claude/skills/forge/scripts/*)`, retirée puis remise à chaque installation comme les autres, avec un test d'idempotence. |
| R4 | Faible | `closure.md:9` | **La clôture salit désormais toujours le working tree.** Sur `Solved`, `metrics.json` est écrit sans condition. En v0.12.6, une clôture sans tâche `[ ]` ni ClickUp et terminée par `Finish` n'écrivait rien. Si la clôture suit le grave, ce fichier reste non commité jusqu'à une prochaine livraison qui n'aura peut-être jamais lieu. Autre effet : la synthèse est écrite avant l'étape 2 (`Mark done` / `Drop`), donc les fichiers par tâche n'en tiennent pas compte. | Écrire la synthèse après l'étape 2. Signaler en une ligne que `metrics.json` attend le prochain `grave`, ou ne l'écrire à la clôture que si une livraison doit suivre. |
| R5 | Faible (attendue) | `checks.sh:15-16` | Sur un projet déjà forgé, le premier démarrage en 0.13.0 ajoute la ligne `time-log.jsonl` au `.gitignore`, qui devient modifié dans le working tree. C'est voulu et testé (`test_adds_only_time_log_rule_when_input_rule_exists`), mais ce n'est pas annoncé à l'utilisateur. | Rien d'obligatoire. Éventuellement, une ligne dans le CHANGELOG « Upgrade notes ». |
| R6 | Faible | `p0-project.md:84` | Le « Contrôle — hook de mesure » lit `~/.claude/settings.json` par Grep. Ce chemin n'est pas couvert par `Read(~/.claude/skills/<n>/**)`, ce qui peut déclencher une demande de permission à l'État 0 et en mode « clean the forge ». | Faire le contrôle dans un script du skill (par exemple un champ `time_hook_installed` du JSON de `status.sh`), ou documenter la demande. |
| R7 | Faible | `engrave.md:39` | L'étape 4 de « Synthèse de mesure » (la ligne du compte rendu de livraison) est aussi déclenchée depuis la clôture (`closure.md:9`), où il n'y a ni tableau ni livraison. C'est ambigu. | Préciser « étape 4 : Livraison seulement ». |
| R8 | Faible (non régressive) | `delegation.md:32-34` | Les guillemets ont été ajoutés sur seulement 2 des commandes `git -C <LINKED>` de l'étape 4. `worktree list`, `fetch`, `worktree add --no-track` et `cat-file` restent sans guillemets, ce qui pose problème pour un chemin à espace, comme ce dépôt (« claude skills »). C'était déjà le cas en v0.12.6 : la correction est partielle. | Mettre `"<LINKED>"` et `"<LINKED_WORKTREE>"` entre guillemets dans toute l'étape 4. |
| R9 | Faible (mesure) | `engrave.md:31`, `delegated-mode.md:10` | En délégation de branche du même dépôt (`SCOPE: branch`, hors essaim), le délégué qui grave lance `time-aggregate.sh` sans `--parent-log`. Le passage de `--parent-log` n'est prévu que pour « Mesure d'une tâche ». Ses marques sont pourtant dans le journal du parent, donc son `metrics.json` aura probablement des durées `null` ou partielles. Ce point relève de la mesure (hors périmètre strict) et n'a pas été exécuté. | Étendre la règle `TIME_LOG:` de `delegated-mode.md` à la « Synthèse de mesure » (`--parent-log <TIME_LOG>`). |

Aucune régression trouvée sur la garde main/master, le brief, les options `Validate and chain` / `Validate` d'un plan ordinaire, la reprise d'un plan ordinaire, forge-clickup, le hook PreCompact, `engrave.sh` et la fusion idempotente de `settings.json`.

## 4. Cohérence de `.forge/project.md`

- La liste des tests est complète et exacte : les 11 suites sont listées, et il n'en existe pas d'autre.
- Commandes (`commands/`) et phases (`phases/`) : la liste est exacte.
- Écarts :
  - `scripts/task-files.sh` est **absent** de la liste. C'est un fichier awk partagé, chargé par `time-aggregate.sh:30` et `time-calibrate.sh:27`.
  - Le dossier `skills/forge/references/` (`estimation.json`) n'a **pas sa propre entrée** dans l'arborescence. Il n'est cité qu'entre parenthèses sur la ligne de `time-calibrate.sh`.
  - Section « Detected conventions », ligne « Idempotence » : elle cite « hooks `PreCompact` » mais pas les entrées `time-hook` sur 6 événements. Section « Entry points » : « déploient skills + hook » est au singulier.
  - Section « Detected conventions », ligne « Projet lié / mode délégué » : le prompt y est décrit avec « (ROOT, BRANCH, LANGUAGE) », sans `SCOPE`. Cet oubli existait déjà avant 0.13.0.

## 5. Observation hors périmètre

`skills/forge/install.json` est apparu **non suivi dans le dépôt** pendant l'audit, à 15:08:50. Il contient `"latest":"v0.13.0"` et le dépôt GitHub réel.
- Mes suites ne l'ont pas écrit. Les tests d'`update` et d'`install` utilisent un `--install-dir` ou un HOME jetables, et ils ont tourné à 15:10 et 15:12. À 15:08:50, seule la suite `engrave` tournait, et elle n'appelle pas `update.sh`.
- Cause probable, non vérifiée : un autre agent a lancé `skills/forge/scripts/update.sh check` depuis le dépôt (`INSTALL_DIR` par défaut = dossier du skill, `update.sh:37`).
- Le fichier n'est pas ignoré par git (`git check-ignore` → 1). Je ne l'ai pas supprimé.
