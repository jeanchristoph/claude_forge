# Plan — fast-launch
**Objective:** Rendre le lancement de forge plus rapide et plus intuitif.
**Date:** 2026-11-05

## Tasks

### T1 — Découper `p5-resume.md` et le mode délégué
**Effort:** M
**Files:** `skills/forge/phases/p5-resume.md`, `skills/forge/SKILL.md`, `skills/forge/commands/delegation.md`, `skills/forge/commands/engrave.md`, `skills/forge/commands/closure.md`, `skills/forge/commands/delegated-mode.md`
**Description:** Déplacer la délégation, la livraison, la clôture et le mode délégué dans `commands/`, sans changer leur contenu. `p5-resume.md` et `SKILL.md` gardent chaque déclencheur et un renvoi vers le fichier à lire. Mettre à jour tous les renvois croisés entre sections. Dossier `commands/` et non `pN-` : ces fichiers sont des commandes, pas des états.
[x]

### T2 — Lecture unique et suppression de `p3-log.md`
**Effort:** S
**Files:** `skills/forge/SKILL.md`, `skills/forge/phases/p2-brief.md`, `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`
**Description:** Poser une fois la règle « fichier déjà lu dans ce tour → ne pas le relire » et retirer les relectures de p2, p4 et p5. `p2-brief.md` crée `log.md` avec le brief. La table d'états perd l'État 3 ; un brief sans log reste géré, le log étant alors créé à la première écriture.
[x]

### T3 — Script `status.sh` et ses tests
**Effort:** M
**Files:** `skills/forge/scripts/status.sh`, `tests/status.test.sh`
**Description:** Script en lecture seule, appelé avec `--root` et `--branch` optionnel. Il renvoie en JSON la branche, l'état, l'avancement (tâches faites, ouvertes, bloquées), les 10 dernières entrées du log, et les branches locales qui ont des tâches ouvertes. Il gère les branches contenant `/`. Tests dans des dépôts jetables, sur le modèle de `tests/temp-branch.test.sh` : aucun `.forge`, chaque état, plan vide, tâches bloquées, branche absente.
[x]

### T4 — Brancher `status.sh` sur le démarrage
**Effort:** S
**Files:** `skills/forge/SKILL.md`, `skills/forge/phases/p5-resume.md`
**Description:** « Détection d'état » s'appuie sur le JSON au lieu de plusieurs commandes, et l'IA affiche une ligne du type `fix · actif · 2/5 tâches`. Sur `master`, la garde propose de reprendre une branche qui a des tâches ouvertes, dans une question séparée pour respecter le plafond de quatre options.
[x]

### T5 — Résolution de l'argument de `/forge`
**Effort:** M
**Files:** `skills/forge/SKILL.md`, `skills/forge/phases/p2-brief.md`
**Description:** Ordre de résolution : branche existante → bascule ; argument avec espaces → objectif pré-rempli ; `clickup.json` présent et tâche trouvée par `clickup_get_task` → passage à `forge-clickup` avec le code ; sinon → nouvelle branche. Sur `master`, sans argument ou avec un objectif, l'objectif vient d'abord, puis la question `Branch` avec un nom proposé d'après lui. Avec un objectif sur une branche qui a déjà un brief, la demande suit la « Surveillance des demandes complémentaires ».
[x]

### T6 — `forge-clickup` : argument code ou objectif, fin des alias
**Effort:** S
**Files:** `skills/forge-clickup/SKILL.md`
**Description:** Argument avec espaces → objectif : l'étape 1 ne le redemande pas, titre et description restent à valider, puis la tâche est créée. Argument sans espace → lecture de la tâche existante, sans création ; tâche introuvable → le signaler, STOP. La branche est reprise si elle existe, créée sinon, puis la main passe à forge avec l'objectif tiré de la tâche. Retirer l'argument alias et la clé `aliases` ; une clé restante dans un ancien `clickup.json` est ignorée.
[x]

### T7 — Mode express et question `Mode`
**Effort:** XS
**Files:** `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`
**Description:** Plan d'une seule tâche XS → la question `Plan` se réduit à `Validate and chain` / `Cancel`. À la reprise, une seule tâche ouverte → question `Start T<n>` / `Cancel` à la place de `Mode`. Le feu vert reste obligatoire dans les deux cas.
[x]

### T8 — Documentation
**Effort:** S
**Files:** `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:** Mettre à jour les deux README dans le même commit : arborescence, commandes, État 3 retiré. Ajouter l'entrée `[Unreleased]` du `CHANGELOG.md`, en signalant la suppression des alias comme changement cassant. Mettre à jour `project.md`.
[x]

### T9 — Extraire `json_string` dans un script partagé
**Effort:** S
**Files:** `skills/forge/scripts/json.sh`, `skills/forge/scripts/engrave.sh`, `skills/forge/scripts/temp-branch.sh`, `skills/forge/scripts/status.sh`
**Description:** Créer `json.sh` avec `json_escape`, qui écrit dans `REPLY` sans lancer de processus, et `json_string`, qui l'affiche. Le charger dans les trois scripts à la place de leurs copies, `status.sh` utilisant `json_escape` pour garder sa vitesse. Relancer les trois suites de tests, sans changer les sorties JSON.
[x]

### T10 — Branche automatique sur `master`
**Effort:** S
**Files:** `skills/forge/SKILL.md`, `skills/forge/phases/p5-resume.md`, `skills/forge/scripts/temp-branch.sh`, `tests/temp-branch.test.sh`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:** Remplacer la question `Branch` par une création directe depuis l'objectif : nom court en kebab-case, suffixé `-2`, `-3`… s'il existe déjà. Retirer les options branche temporaire, rester sur master et créer une branche. Ajouter à `p5-resume.md` le renommage à la demande : `git branch -m`, déplacement du dossier `.forge/branch/`, signalement si l'ancien nom existe sur le distant. Supprimer `temp-branch.sh` et ses tests, mettre à jour la documentation.
[x]

## Risks
- Le découpage de T1 peut casser un renvoi croisé sans que rien ne le signale : relire chaque renvoi par recherche dans tout le skill.
- Seul `status.sh` a des tests automatiques. Les fichiers Markdown se vérifient à l'usage, après installation.
- Une erreur ClickUp autre que « introuvable » ne doit pas créer de branche par erreur : erreur affichée, STOP.

## Deployment
- [ ] Relancer `install-windows.bat` — after deploy · [T1, T2, T3, T4, T5, T6, T7]

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — Découper `p5-resume.md` et le mode délégué | M | [x] |
| T2 — Lecture unique et suppression de `p3-log.md` | S | [x] |
| T3 — Script `status.sh` et ses tests | M | [x] |
| T4 — Brancher `status.sh` sur le démarrage | S | [x] |
| T5 — Résolution de l'argument de `/forge` | M | [x] |
| T6 — `forge-clickup` : argument code ou objectif, fin des alias | S | [x] |
| T7 — Mode express et question `Mode` | XS | [x] |
| T8 — Documentation | S | [x] |
| T9 — Extraire `json_string` dans un script partagé | S | [x] |
| T10 — Branche automatique sur `master` | S | [x] |
| **Total** | **3 M, 6 S, 1 XS** | |
