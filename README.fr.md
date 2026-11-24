# Claude_forge

[![English](https://img.shields.io/badge/lang-English-6e7681?style=for-the-badge)](README.md)
[![Français](https://img.shields.io/badge/lang-Fran%C3%A7ais-1f6feb?style=for-the-badge)](README.fr.md)

[![Release](https://img.shields.io/github/v/release/jeanchristoph/claude_forge?sort=semver)](https://github.com/jeanchristoph/claude_forge/releases)
[![Licence](https://img.shields.io/github/license/jeanchristoph/claude_forge)](LICENSE)
[![Changelog](https://img.shields.io/badge/changelog-keep%20a%20changelog-orange)](CHANGELOG.md)

![Forge en action](docs/demo.gif)

<sub>Session reconstituée — les sorties sont reproduites à l'identique depuis le skill. Régénération par `vhs docs/demo.tape`, voir [docs/README.md](docs/README.md).</sub>

**Claude_forge** est un système pour Claude Code composé du skill **forge** (invoqué via `/forge`), de son compagnon `forge-clickup` et d'un hook `PreCompact`. Ensemble, ils orchestrent tout le cycle de vie d'une branche de développement — du brief validé à la release livrée — sur un ou plusieurs dépôts.

Là où Claude Code part directement dans le code dès qu'on lui décrit un problème, le skill forge intercale trois étapes obligatoires avant la moindre ligne :

1. **Brief** — clarifier l'objectif, le cadre : règles, contraintes, périmètre
2. **Plan** — décomposer en tâches estimées, attendre une validation explicite
3. **Actif** — exécuter avec suivi d'avancement en temps réel

Une fois actif, forge ne s'arrête pas au code : il délègue des tâches à des sous-agents étanches — projet lié ou branche du même dépôt — en te relayant chaque question, grave la branche (commit, push, merges, livraison relayée, release) en une seule commande, et la clôt avec un rapport publié dans ClickUp et une réponse client.

Le résultat : moins de mauvaises surprises, des implémentations qui restent dans le périmètre défini, et un historique par branche qui survit aux compactions de contexte. Cela facilite aussi grandement le travail en équipe de plusieurs développeurs : chacun travaille sur sa propre branche, et reprendre une branche commencée par un autre, c'est hériter de tout ce qu'il faut pour poursuivre le développement — les actions déjà faites, le contexte et la documentation — puisque tout ce que forge génère (brief, plan, log, livrables) vit avec la branche et voyage avec elle dans git.

### Ce que Claude_forge apporte concrètement

- **Zéro code sans validation** — la règle absolue : silence ≠ accord. Le skill attend une validation explicite avant d'écrire quoi que ce soit, posée en choix et jamais en texte libre.
- **Contexte persistant par branche** — `brief.md` et `plan.md` sont stockés dans `.forge/branch/<BRANCH>/`, suivis en git, et relus à chaque `/forge`.
- **Pensé pour l'équipe** — les développeurs travaillent sur des branches différentes, et chacun peut reprendre une branche commencée par un autre avec les actions déjà faites, le contexte et la documentation nécessaires à la suite : brief, plan, log et livrables générés sont partagés via git, sans passation à rédiger à côté.
- **Contenu généré rangé avec la branche** — toute doc, script SQL, export, explication ou livrable client demandé est écrit dans `.forge/branch/<BRANCH>/output/`, jamais à la racine du projet, nommé `AAAAMMJJ-` suivi d'un intitulé en kebab-case anglais, sans exception : `20260910-db-migration.sql`. Les fichiers propres à forge — `brief.md`, `plan.md`, `log.md` — restent au niveau du dessus, intacts.
- **Brief vivant & log** — le cadre (règles, contraintes, périmètre) va silencieusement dans la section `## Scope & rules` du brief ; les décisions et choix utilisateur sont enregistrés silencieusement dans `log.md`, sans interrompre le flux de travail.
- **Résumé "Last session"** — à la reprise, si `log.md` contient des entrées, un récapitulatif des 10 dernières en une ligne est affiché avant le tableau d'avancement.
- **Décomposition des tâches L/XL** — les grandes tâches sont découpées en micro-étapes dans `plan.md` avant de démarrer l'implémentation.
- **Étapes de mise en production dans le plan** — tout ce qui se joue à la main hors du déploiement git — migration SQL, réglage de configuration, procédure d'exploitation — est listé dans la section `## Deployment` de `plan.md` avec son moment, ses tâches d'origine et sa copie dans `output/`, renseigné dès que le script est écrit.
- **Script SQL de déploiement généré** — toutes les étapes SQL de `## Deployment` sont listées, sans question, dans un seul `output/AAAAMMJJ-deployment-script.sql` par branche, réécrit sur place, à dérouler dans l'ordre : une section `-- STEP` par étape — le chemin du script à exécuter avec son moment, son contrôle et son retour arrière, ou une petite requête autonome écrite en clair avec sa requête de contrôle — jamais le contenu d'un script recopié.
- **Détection hors périmètre** — une demande hors du plan courant devient une tâche du plan : forge la formule, tu valides la formulation, rien de plus.
- **Branche, objectif ou code ClickUp en argument** — `/forge <nom-de-branche>` bascule sur cette branche, créée depuis la branche par défaut à jour (`master`, sinon `main`) si elle n'existe pas — jamais depuis la branche courante. Un objectif en mots évite la question d'objectif ; avec `.forge/clickup.json`, un code de tâche (`PRJ-1133` ou id brut) ouvre la tâche existante.
- **Question au lieu d'un objectif** — sur toute branche, une question sur le projet qui n'appelle aucune action (« où l'utilisateur règle-t-il X ? »), donnée en argument ou en réponse à la question d'objectif, reçoit une réponse en lecture seule : aucune branche, aucun brief, rien d'écrit.
- **Garde main/master** — sans branche en argument, sur les branches protégées, forge propose de reprendre une branche qui a des tâches ouvertes, demande l'objectif, puis crée une branche nommée d'après lui — après `project.md` et `coding-standards.md`, communs à toutes les branches. `/forge master` travaille directement sur `master`.
- **Raccourci de livraison** — `"grave master"` / `"engrave master"` (ou avec `"dev"`) commit, push et merge directement : la commande vaut feu vert, aucune confirmation demandée.
- **Survie à la compaction** — le hook `PreCompact` injecte l'état forge (branche, objectif, statut des tâches) dans le résumé de contexte compacté.
- **Cross-platform** — détection automatique Unix/Windows, installeurs séparés.

---

## Installation

**Windows :**
```
install-windows.bat
```

**Unix (bash) :**
```bash
./install-unix.sh
```

Les deux lanceurs sont à la racine du dépôt et délèguent à `install/install.ps1` / `install/install.sh` — appeler ces derniers directement reste possible.

Les scripts sont idempotents — relancer après une mise à jour écrase proprement sans doublon.

Les scripts du skill demandent bash 5 (Git Bash sous Windows, un bash récent via Homebrew sous macOS, dont `/bin/bash` est en 3.2). Avec un bash plus ancien, le hook de mesure du temps et les marques de tâche n'écrivent rien et `log-entry.sh` s'arrête sur une erreur : aucune durée n'est jamais enregistrée fausse.

Les archives de release (« Source code » zip / tar.gz sur la [page des releases](https://github.com/jeanchristoph/claude_forge/releases)) ne contiennent que ce dont les installeurs ont besoin : `.forge/`, `docs/` et les fichiers `.git*` en sont exclus.

Les installeurs écrivent `~/.claude/skills/forge/install.json` (version installée, URL du dépôt, dernier contrôle de mise à jour), lu par la mise à jour du skill ci-dessous.

L'extension `/forge-clickup` requiert en plus le connecteur MCP ClickUp authentifié (`/mcp` dans Claude Code). Aucun script ne peut faire cette étape à ta place : c'est un OAuth navigateur.

---

## Usage

```
/forge                  # travaille sur la branche courante (garde main/master)
/forge help             # aide : cycle, commandes en langage naturel, fichiers .forge/
/forge <nom-de-branche> # bascule sur <nom-de-branche>, créée depuis master/main si absente
/forge <objectif en mots> # prend le texte comme objectif, sans question d'objectif
/forge <code-clickup>   # avec .forge/clickup.json : lit la tâche existante (PRJ-1133 ou id brut), puis passe la main à forge-clickup
/forge-clickup          # extension : demande l'objectif, ouvre la tâche ClickUp (titre et description déduits), crée la branche, enchaîne sur forge
/forge-clickup <objectif> # idem, avec l'objectif donné en texte
/forge-clickup <code>   # lit la tâche existante (PRJ-1133 ou id brut), crée ou reprend sa branche, enchaîne sur forge
```

---

## Structure du repo

```
forge/
├── skills/                   → chaque sous-dossier est copié dans ~/.claude/skills/<nom>/
│   ├── forge/
│   │   ├── SKILL.md
│   │   ├── commands/          (commandes chargées à la demande)
│   │   │   ├── branch-rename.md       (renommage de branche)
│   │   │   ├── closure.md             (clôture de tâche)
│   │   │   ├── delegated-mode.md      (règles du mode délégué)
│   │   │   ├── delegation.md          (projet lié, branche du même dépôt)
│   │   │   ├── deployment-sql.md      (script de déploiement SQL)
│   │   │   ├── email.md               (mail rédigé)
│   │   │   ├── engrave.md             (livraison, synthèse metrics.json)
│   │   │   ├── help.md                (aide, /forge help)
│   │   │   ├── rule-propagation.md    (propagation d'une règle vers CLAUDE.md)
│   │   │   ├── swarm.md               (essaim de branches filles : lancement, relais, fusion, reprise)
│   │   │   ├── teacher.md             (mode professeur)
│   │   │   └── update.md              (mise à jour du skill : contrôle manuel)
│   │   ├── phases/
│   │   │   ├── p0-project.md          (État 0 — Project Init)
│   │   │   ├── p1-coding-standards.md (État 1 — Coding Standards Init)
│   │   │   ├── p2-brief.md            (État 2 — Brief)
│   │   │   ├── p4-plan.md             (État 4 — Plan)
│   │   │   └── p5-resume.md           (État 5 — Actif)
│   │   ├── references/
│   │   │   └── estimation.json        (minutes par fichier tant que le projet n'a pas ses mesures, fourchette, seuil de branche)
│   │   ├── hooks/                (déclarés dans settings.json par les deux installeurs, copiés avec le skill)
│   │   │   ├── forge-precompact.sh   (hook d'état : PreCompact, SessionStart après compaction ou reprise)
│   │   │   ├── linked-write-guard.sh  (garde d'écriture, PreToolUse : la session parente n'écrit jamais dans un projet lié, hors brief.md et log.md du mandat)
│   │   │   ├── time-hook.sh           (hook de mesure : une ligne par événement dans le time-log.jsonl de la branche)
│   │   │   └── plan-hook.sh           (hook de coche : marques de tâche, réel, estimations et tableau récapitulatif de plan.md)
│   │   └── scripts/              (appelés par le modèle et par les hooks)
│   │       ├── checks.sh              (contrôles de démarrage, lancés détachés, et repris à la livraison : lignes input/ et time-log.jsonl dans le .gitignore)
│   │       ├── engrave.sh             (séquence de livraison : preview / run ; run --model écrit d'abord metrics.json)
│   │       ├── metrics.sh             (synthèse de mesure de la branche : écrit metrics.json et la ligne **Actual:** du plan, rend la ligne estimé / réel en JSON)
│   │       ├── json.sh                (rendu JSON et lecture des champs du JSON des hooks, partagés par les scripts)
│   │       ├── linked-worktree-cleanup.sh (retire un worktree lié une fois sa branche fusionnée, working tree propre seulement, en JSON)
│   │       ├── log-entry.sh           (entrée de LOG : horodatage lu sur l'horloge locale, entrée écrite en tête de log.md)
│   │       ├── status.sh              (état au lancement : état, avancement, branches à reprendre, en JSON)
│   │       ├── swarm-status.sh        (état de l'essaim : branches en cours, lançables, en attente, fusion simulée, en JSON)
│   │       ├── time-aggregate.sh      (mesure d'une branche : minutes d'agent, humaines, de vérification, fichiers et lignes, en JSON)
│   │       ├── time-calibrate.sh      (ratios du projet tirés des tâches mesurées, estimation d'un nombre de fichiers, en JSON)
│   │       ├── time-mark.sh           (marques de délégué et de tokens dans le time-log.jsonl)
│   │       ├── task-marks.sh          (fonctions bash communes : horloge, empreinte du dossier, ligne de marque)
│   │       ├── task-files.sh          (fonctions awk communes : statut d'une tâche, fichiers prévus d'une tâche, fichiers changés entre deux empreintes)
│   │       └── update.sh              (mise à jour du skill : check / run, en JSON)
│   └── forge-clickup/        → extension : ouverture de tâche ClickUp
│       └── SKILL.md
├── install/
│   ├── install.sh
│   └── install.ps1
├── install-unix.sh           → lanceur racine, délègue à install/install.sh
├── install-windows.bat       → lanceur racine, délègue à install/install.ps1
├── CHANGELOG.md              (format Keep a Changelog, une section par version)
├── README.fr.md              (version française)
├── LICENSE                   (MIT)
├── docs/
│   ├── demo.gif              → README demo, generated by vhs
│   ├── demo.sh
│   ├── demo.tape
│   └── README.md             (how to regenerate)
├── tests/
│   ├── run-all.sh            → bash tests/run-all.sh, suite complète
│   ├── test-runner.sh        → lanceur commun, 12 cas à la fois (TEST_JOBS)
│   ├── test-runner.test.sh   → bash tests/test-runner.test.sh, fichiers de test jetables uniquement
│   ├── engrave.test.sh       → bash tests/engrave.test.sh, dépôts jetables uniquement
│   ├── forge-precompact.test.sh → bash tests/forge-precompact.test.sh, dépôts jetables uniquement
│   ├── install.test.sh       → bash tests/install.test.sh, HOME jetable uniquement
│   ├── checks.test.sh        → bash tests/checks.test.sh, dépôts jetables uniquement
│   ├── linked-worktree-cleanup.test.sh → bash tests/linked-worktree-cleanup.test.sh, dépôts jetables uniquement
│   ├── linked-write-guard.test.sh → bash tests/linked-write-guard.test.sh, dossiers jetables uniquement
│   ├── log-entry.test.sh     → bash tests/log-entry.test.sh, dossiers jetables uniquement
│   ├── status.test.sh        → bash tests/status.test.sh, dépôts jetables uniquement
│   ├── swarm-status.test.sh  → bash tests/swarm-status.test.sh, dépôts jetables uniquement
│   ├── time-aggregate.test.sh → bash tests/time-aggregate.test.sh, dépôts jetables uniquement
│   ├── time-calibrate.test.sh → bash tests/time-calibrate.test.sh, dossiers jetables uniquement
│   ├── time-hook.test.sh     → bash tests/time-hook.test.sh, dépôts jetables uniquement
│   ├── time-mark.test.sh     → bash tests/time-mark.test.sh, dossiers jetables uniquement
│   ├── metrics.test.sh       → bash tests/metrics.test.sh, dépôts jetables uniquement
│   ├── plan-hook.test.sh     → bash tests/plan-hook.test.sh, dépôts jetables uniquement
│   └── update.test.sh        → bash tests/update.test.sh, dépôts jetables uniquement
├── .gitattributes
└── .gitignore
```

Fichiers générés dans chaque projet :

```
.forge/                  ← suivi en git, ajouté automatiquement au premier lancement
├── project.md
├── coding-standards.md  ← conventions de code (structure, nommage, principes), complétées au fil du projet
├── clickup.json         ← écrit par `/forge-clickup` : liste cible, branche de base, code de branche
├── input/               ← fichiers de référence (exports, dumps SQL, structures de base), un sous-dossier par source
└── branch/<BRANCH>/
    ├── brief.md         ← `## Objective` + `## Scope & rules`
    ├── log.md           ← Journal des décisions (vivant, 10 dernières entrées lues à la reprise)
    ├── plan.md
    ├── metrics.json     ← mesure de la branche, réécrite à chaque grave et à la clôture : fichiers prévus et réels, lignes, minutes d'agent et humaines, tokens
    ├── time-log.jsonl   ← événements bruts du hook de mesure, locaux, non suivis en git
    ├── swarm.md         ← état de l'essaim d'une branche parente : N, branches filles, choix transmis, notes de coordination
    ├── input/           ← fichiers apportés pour la tâche de la branche (exports CSV/XLSX, dumps ou extraits SQL, données reçues en fichier), lus à la place d'un accès base, créé vide avec le brief, non suivi en git
    ├── ticket.json      ← écrit par `/forge-clickup` : tracker, code, url ; lien affiché à la reprise et à la clôture
    └── output/          ← tout fichier généré, nommé `AAAAMMJJ-`
        ├── 20260910-explanation-*.md ← écrit en tâche de fond lors d'une explication de concept
        ├── 20260910-db-migration.sql ← docs, scripts SQL, exports, notes
        └── 20260910-user-documentation-map.md ← livrable client, nommé comme tous les autres
```

Garde `.forge/` suivi en git, sauf les dossiers `input/` des branches et le `time-log.jsonl` du hook — le bloc `.gitignore` ci-dessous s'en charge ; forge ajoute lui-même chaque ligne manquante, par un contrôle de démarrage lancé en arrière-plan, et vérifie de nouveau à chaque livraison avant de commiter : règle manquante ajoutée, `.gitignore` parti avec le commit, journal ou fichier `input/` déjà suivi retiré de l'index (`git rm --cached`, gardé sur disque). Les fichiers déjà poussés restent dans l'historique, jamais réécrit :

```
###> claude/forge ###
!/.forge/
/.forge/branch/*/input/
/.forge/branch/**/time-log.jsonl
###< claude/forge ###
```

---

## Comportement par état

### État 0 — Project Init
**Condition :** `.forge/project.md` absent

- Projet vide (hors dotfiles/dotfolders) → `project.md` placeholder créé, enchaîne.
- Sinon → explore stack, structure, conventions, écrit `project.md` sans question, puis enchaîne ; « ranger la forge » l'ajuste ensuite.
- `coding-standards.md` est écrit au même moment (uniquement s'il n'existe pas déjà) — voir ci-dessous.

### État 1 — Coding Standards Init
**Condition :** `.forge/coding-standards.md` absent

Écrit `coding-standards.md` dans la langue de l'utilisateur, puis enchaîne sur le brief.

### État 2 — Brief
**Condition :** brief absent

Lit `coding-standards.md`. Crée `.forge/branch/<BRANCH>/brief.md` avec une section `## Objective` et une section `## Scope & rules` vide, clarifie l'objectif, enchaîne sur le plan.

### État 4 — Plan
**Condition :** brief présent, plan absent

Lit `coding-standards.md`, génère `plan.md`, attend validation avant toute implémentation. La validation propose trois options : valider et enchaîner — le plan est écrit et toutes les tâches ouvertes s'exécutent dans l'ordre, sans autre question —, valider — le mode d'exécution est demandé ensuite —, ou annuler.  
Les tâches L/XL incluent un bloc de décomposition commenté (`T1.1`, `T1.2`, …) à remplir avant de démarrer.

### État 5 — Actif
**Condition :** brief + plan présents

Lit le brief et le plan en silence ; `project.md` et `coding-standards.md` ne sont lus qu'au démarrage de la première tâche du tour, ou d'une modification directe du code — une reprise pour livrer, consulter ou clore ne les charge pas. Si `log.md` contient des entrées, affiche d'abord un récapitulatif "**Last session :**" des 10 dernières en une ligne, puis le tableau d'avancement — `## Summary` du plan, tel que le hook le tient. Propose ensuite les deux modes — enchaîner les tâches ouvertes ou en choisir une — et attend. Aucune tâche ouverte : aucun mode proposé, la question est ouverte.

---

## coding-standards.md

Créé en même temps que `project.md` (État 0), dans la langue de l'utilisateur : un titre (nom du projet) et une courte explication précisant que le fichier contient les conventions de code (structure, nommage, principes) à appliquer au moment d'écrire du code — une norme continue, pas un audit ponctuel — à compléter au fil du projet.

Il est lu à chaque phase qui touche au code — Bootstrap, Plan, et en État Actif au démarrage de la première tâche du tour — pour que les conventions restent appliquées tout au long du workflow.

---

## Détection de branche

Via `scripts/status.sh`, qui lit la branche git courante et, pour `/forge <argument>`, vérifie aussi que la branche visée existe (`--target`) — fonctionne sur Unix et Windows.  
Erreur ou résultat vide (pas de dépôt git) : demande un nom de code utilisé comme `<BRANCH>`. Sans réponse : STOP.

---

## Confirmations

Toute confirmation bloquante, tout choix fermé est posé sous forme de question à choix, jamais en
texte libre : mode d'exécution, approche architecturale, validation du plan, mise à jour
substantielle, demande hors périmètre, propagation d'une règle vers `CLAUDE.md`, livraison, livraison du projet
lié, clôture, publication ClickUp, réponse client. Le refus est toujours une option explicite, et
l'absence de réponse vaut STOP — jamais accord. La question, ses options et leurs descriptions sont
rédigées dans ta langue — les libellés anglais cités dans ce document sont les références internes du
skill, pas ce que tu vois à l'écran.

Les questions ouvertes restent en texte libre, là où une liste figée ne ferait que gêner : objectif
de la tâche, nom de code de branche, mail à coller, quoi faire ensuite.

Valider un contenu — l'objectif du brief, le plan, le rapport de clôture — n'offre jamais d'option
« à retravailler » ni « modifier » : une demande de changement passe par le champ de
texte libre de la question, avec son explication, et le contenu revient retravaillé sous la même
question. Un simple « non » n'est pas une demande de changement — forge demande en une ligne ce qui
doit changer, et ne re-présente jamais un contenu inchangé.

---

## Garde de sécurité — main / master

Sans branche en argument, sur `main` ou `master`, forge propose d'abord de reprendre une branche locale qui a des tâches ouvertes. Il demande ensuite l'objectif, sauf s'il a été donné en argument, et crée une branche nommée d'après lui, sans question : nom court en kebab-case, suffixé `-2`, `-3`… s'il existe déjà. Demande à tout moment de renommer la branche : forge exécute `git branch -m` et déplace `.forge/branch/<nom>/`. Pour travailler directement sur `master`, lance `/forge master`.

La garde s'exécute avant l'État 2 — Brief, jamais avant les États 0 et 1 : `project.md` et `coding-standards.md` sont communs à toutes les branches et ne résolvent jamais `<BRANCH>`. Dans un projet neuf, forge apprend ce qu'est le projet avant de demander sous quelle branche travailler.

Avec une branche en argument (`/forge <nom-de-branche>`), la garde ne s'applique pas : forge est déjà positionné sur `<nom-de-branche>`.

---

## Clés ajoutées à settings.json

**Unix (`install.sh`) :**
```json
{
  "permissions": {
    "allow": [
      "Read(~/.claude/skills/forge/**)",
      "Read(~/.claude/skills/forge-clickup/**)",
      "Read(/.forge/**)", "Edit(/.forge/**)",
      "Bash(bash \"/home/{USER}/.claude/skills/forge/scripts/*)",
      "Bash(bash /home/{USER}/.claude/skills/forge/scripts/*)"
    ]
  },
  "hooks": {
    "PreCompact": [{
      "hooks": [{ "type": "command", "command": "bash ~/.claude/skills/forge/hooks/forge-precompact.sh", "shell": "bash" }]
    }],
    "SessionStart": [{
      "matcher": "compact|resume",
      "hooks": [{ "type": "command", "command": "bash ~/.claude/skills/forge/hooks/forge-precompact.sh", "shell": "bash" }]
    }]
  }
}
```

**Windows (`install.ps1`) :** mêmes hooks, lancés par Git Bash ; règles de lecture en chemin POSIX, règles des scripts en chemin Windows à barres obliques.
```json
{
  "permissions": {
    "allow": [
      "Read(//c/Users/{USER}/.claude/skills/forge/**)",
      "Read(//c/Users/{USER}/.claude/skills/forge-clickup/**)",
      "Read(/.forge/**)", "Edit(/.forge/**)",
      "Bash(bash \"C:/Users/{USER}/.claude/skills/forge/scripts/*)",
      "Bash(bash C:/Users/{USER}/.claude/skills/forge/scripts/*)"
    ]
  }
}
```

Les six hooks de mesure du temps s'y ajoutent (section « Mesure du temps et estimation » ci-dessous). Chaque installation retire d'abord les règles et hooks forge déjà présents, formes abandonnées comprises (`Bash(bash -c "git branch --show-current*)`, ancien hook PowerShell) : jamais de doublon.

**Permissions des scripts :** le skill appelle ses scripts sous une forme unique, `bash "<dossier du skill>/scripts/<script>.sh" …`, couverte par les deux règles `Bash(…)` ci-dessus et, pour le tour qui invoque `/forge`, par le `allowed-tools` de `SKILL.md`. Hors mode auto, aucune demande de permission n'interrompt donc une entrée de LOG, une marque de tâche ou une estimation.

---

## Hook d'état — PreCompact et SessionStart

Injecte l'état forge — objectif du brief, plan, trois dernières entrées de LOG — avant chaque compaction du contexte (`PreCompact`), puis de nouveau après une compaction ou à la reprise d'une session (`SessionStart`, `compact|resume`). Le hook lit le dossier du projet dans l'entrée JSON de Claude Code ; hors dépôt git ou sans plan, il n'écrit rien.

Un seul hook, en bash, pour les deux plateformes : Git Bash est déjà requis sous Windows par les scripts du skill. L'installeur Windows remplace l'ancien `forge-precompact.ps1`, fichier et entrée de `settings.json` compris.

---

## Mesure du temps et estimation

Les deux installeurs ajoutent aussi `bash ~/.claude/skills/forge/hooks/time-hook.sh` (shell `bash`, Git Bash sous Windows, `async` : Claude Code ne l'attend jamais) à six événements : `UserPromptSubmit`, `Stop`, `SubagentStart`, `SubagentStop`, `PreToolUse` sur `AskUserQuestion`, `PostToolUse` sur `AskUserQuestion|Bash`. Hors projet forgé (aucun dossier `.forge` dans le dossier de session ni ses parents), il sort aussitôt, sans processus git. Ils ajoutent aussi `bash ~/.claude/skills/forge/hooks/plan-hook.sh` sur `PostToolUse` pour `Edit|Write|MultiEdit`, synchrone : il n'agit que sur un `.forge/branch/<branche>/plan.md` et sort aussitôt pour tout autre fichier. Les hooks déclarés dans le frontmatter d'un skill ne sont pas utilisés : ils ne voient pas les sous-agents et disparaissent à la reprise d'une session.

- **Mesure :** le hook ajoute une ligne par événement au `.forge/branch/<branche>/time-log.jsonl` de la branche extraite dans le dossier de la session — horodatages, identifiants, durées, jamais un prompt, une commande ni une sortie d'outil. Hors projet forgé, il n'écrit rien. Les événements d'un délégué portent le dossier du parent : le parent associe chaque délégué à sa branche fille.
- **Synthèse :** à chaque grave (`engrave.sh run --model <id>`, avant le `git add`) et à la clôture, `metrics.sh` — jamais le modèle — fait totaliser le journal et git par `time-aggregate.sh` et écrit `metrics.json` : minutes d'agent (session principale + délégués, sous-agents ordinaires compris : tout agent lancé par la session et non délégué à une autre branche compte pour sa durée, agents parallèles additionnés), minutes humaines (une attente de plus de 60 min avant un prompt ou une réponse compte 3 min, placées juste avant ; plus de 6 h compte zéro), un drapeau `partial` quand le journal manque le début de la branche (hook installé en cours de route), questions, minutes de vérification, tokens des délégués, fichiers et lignes modifiés.
- **Fichiers par tâche :** chaque marque de tâche porte l'empreinte du dossier de travail (chemin et hash du contenu de chaque fichier modifié ou nouveau, hors `.forge`, rien d'écrit dans le dépôt) ; les fichiers réels d'une tâche sont ceux qui apparaissent, changent ou disparaissent entre ses deux marques — un fichier modifié par trois tâches compte dans chacune —, écrits `**Actual time:** ≈ <min> min agent … · <n> files …`. Dès vingt tâches ainsi mesurées, minutes par fichier et correction des fichiers prévus viennent des quarante dernières tâches plutôt que des branches entières, les deux côtés comptés par tâche.
- **Estimation :** chaque tâche du plan compte les chemins listés dans son `**Files:**` (un `(≈ n)` explicite en fin de ligne pour un motif ou des fichiers encore inconnus) ; un seul appel `time-calibrate.sh --files 3,5,8` convertit chaque tâche et le total en minutes d'agent avec une fourchette (`≈ 120 files · ≈ 60 min (45-78)`), à partir des quarante dernières tâches mesurées du projet dès vingt mesurées avec leurs fichiers, sinon de `references/estimation.json` (0,5 min par fichier) — jamais des branches entières. La fourchette vient des 20e et 80e centiles du rapport durée réelle ÷ durée estimée des quarante dernières tâches mesurées, lues dans les plans des branches (branches filles d'un essaim comprises), dès vingt mesurées (0,75–1,3 avant) ; chaque estimation se recalcule sur les dernières mesures. Marquée *indicative* tant que ratios ou fourchette viennent des valeurs de référence. Les lettres d'effort restent une taille relative, sans durée.
- **Écrit par le hook :** à chaque écriture de `plan.md`, `plan-hook.sh` estime chaque tâche qui a `**Files:**` sans `**Estimated time:**` (un seul appel `time-calibrate.sh`), recalcule l'en-tête `**Estimate:**` (fichiers de toutes les tâches, somme de leurs estimations figées) et reconstruit `## Summary` depuis les tâches : `Task | Effort | Files | Estimated | Actual | Status`, titres courts gardés, `**Total**` sur les seules tâches mesurées — estimé et réel des mêmes tâches —, et `**Remaining**` pour les tâches ouvertes. Un réel mesuré n'est jamais remplacé par `—`. À la reprise, ce tableau est le tableau d'avancement, affiché tel quel, sans appel de script.
- **Coût des vérifications par tâche :** chaque tâche paie ses vérifications, quelle que soit sa taille — sous Git Bash un passage complet des tests peut coûter plusieurs minutes pour un seul fichier modifié. L'estimation d'une tâche vaut `check_minutes + fichiers × minutes par fichier` : `check_minutes` est la médiane de la part `· <c> min checks` des réels dès que vingt tâches la portent, `0` avant — un projet part sans temps de vérification, ses mesures le fixent ensuite ; les minutes par fichier se calculent alors sur le réel moins ses vérifications. Une liste de tâches compte un coût de vérification par tâche. Les réels écrits avant cette part restent lus.
- **Branche entière :** sous `**Estimate:**` (à défaut sous `**Date:**`), `metrics.sh` écrit la mesure de la branche tirée de `time-aggregate.sh` à la livraison — avant le `git add`, la ligne part avec le commit — et à la clôture, jamais à chaque écriture du plan ; entre deux livraisons, la ligne garde la dernière valeur. Même forme que la ligne de tâche, total à la fin : `**Actual:** ≈ 14.0 min agent (incl. 3.0 min checks) · human 7.0 min (4 questions, 2.5 min) · delegates 0.0 min in parallel · total ≈ 21.0 min`. Total = agent + humain : les vérifications sont une part du temps d'agent ; les délégués, simultanés, sont affichés à part, hors total. Poste sans mesure → `—`, jamais une estimation ; ` · partial (log started after the branch, 3 unmeasured tasks)` signale une mesure incomplète. Sans journal de mesure → aucune ligne. Sans tâche mesurée, la ligne `**Total**` y renvoie (`see **Actual:**`).
- **Temps hors tâche :** `metrics.sh` écrit aussi une ligne `**Unplanned**` sous `**Total**` — temps d'agent de la branche moins les tâches mesurées (travail jamais mis au plan, conflits, livraison, tâche en cours ou non mesurée), jamais négative, `—` sans mesure. Une livraison réussie avance le point d'étape de la mesure après son commit, l'entrée d'une tâche au plan aussi : ni la livraison ni la formulation d'une tâche n'entrent dans le réel suivant. Une tâche en cours (code non commité, modifié depuis le dernier point d'étape) garde son heure de départ ; celle qui n'a encore rien modifié perd son temps d'exploration si une autre entre au plan à ce moment-là.
- **Tâches groupées (tâche-branche, tâche liée) :** même règle que toute tâche — une tâche qui en regroupe d'autres vaut la somme de ses tâches, vérifications comprises, rien d'autre. Estimation : calculée sur les fichiers déclarés et marquée `· indicative` tant que son délégué n'a pas de plan ; le hook reprend ensuite la somme des estimations et des fichiers des tâches de ce plan (`**Estimated files:**`) à la prochaine écriture du plan parent, une seule fois, figée. Une estimation sans `· indicative` n'est jamais reprise.
- **Par tâche :** chaque tâche porte aussi `**Estimated time:**`, figé à sa première écriture par le hook. Le modèle ne pose aucune marque : `plan-hook.sh` voit la coche dans `plan.md`, écrit le début de la tâche (dernier point d'étape : coche précédente ou première écriture du plan, ligne `plan_checkpoint` du journal) et sa fin, mesure les minutes d'agent entre les deux par `time-aggregate.sh --task` (attentes de question retirées, même règle d'absence) et écrit `**Actual time:**` ventilé par poste (`≈ 10.2 min agent (incl. 2.3 min checks) · human 1.5 min (2 questions) · 9 files · total ≈ 11.7 min` : le premier nombre est le temps d'agent, vérifications comprises, comparé à l'estimation ; total = agent + humain, vérifications jamais ajoutées), ou `—` sans mesure (pas de journal, hook installé en cours de route, premier passage). Une tâche prise hors ordre est mesurée depuis la coche précédente ; deux tâches cochées d'une même édition sont simultanées. Pour tout délégué, même dépôt ou projet lié, le hook écrit les marques dans le journal du parent (ligne `TIME_LOG:` de son prompt), où arrivent déjà ses événements ; le délégué et rend le réel de chaque tâche dans `FORGE_DONE` ; le même hook rattache chaque délégué à sa branche et à son projet lié (ligne `delegate`, première écriture de son `plan.md`) : deux dépôts sur un même nom de branche ne se mélangent jamais ; une tâche-branche ou une tâche déléguée à un projet lié reçoit, à sa coche, la somme des réels des tâches de son plan (ses seules tâches enfant quand plusieurs tâches parentes partagent la branche liée), au même format qu'une tâche ordinaire, et `—` sans plan ou avec une tâche faite non mesurée — jamais le temps de la session parente ni le temps total du délégué. Le tableau d'avancement affiche Estimé et Réel côte à côte. Un sous-agent ordinaire compte dans la tâche pour sa part comprise dans la fenêtre ; deux tâches ouvertes en même temps ne sont pas mesurées (`—`, raison `overlapping_tasks`) : aucune part ne leur est attribuable sans l'inventer, et leur temps reste compté dans la mesure de la branche.
- **Commandes de vérification :** la ligne `**Check pattern:**` de `project.md` (expression régulière) désigne les commandes Bash comptées comme vérifications.
- **Tests :** le skill n'en impose aucun. Quoi lancer et quand est une décision du projet, écrite dans son `coding-standards.md` ou son `project.md`, lus avant le démarrage d'une tâche.

---

## Mise à jour du plan

**Silencieuse** (automatique) : cocher `[x]`, note courte, `[!]` si bloqué.  
**Substantielle** (confirmation requise) : ajout/suppression de tâche, ordre, effort, description.

---

## Mise à jour du brief et du log

Le brief est un document vivant. Les changements de scope passent par la **Détection hors périmètre** (voir ci-dessous).

**Élément de cadre** (valable pour toute la durée de la branche) → écrit silencieusement dans la section `## Scope & rules` du brief :
- Contrainte technique découverte en cours de tâche
- Règle immuable posée par l'utilisateur
- Remarque utilisateur précisant durablement le périmètre ou le hors périmètre

**Décision ponctuelle** (choix acté et clos à un instant donné) → écrite silencieusement dans `log.md` (format : `- [AAAA-MM-JJ HH:MM] [1 ligne]`, écrit par `log-entry.sh` depuis l'horloge locale — le modèle n'écrit jamais une date ni une heure) :
- Choix d'implémentation mineur acté sans discussion
- Choix utilisateur quand Claude a proposé plusieurs options (ex : "Option B retenue — raison")

---

## Propagation d'une règle vers CLAUDE.md

Quand tu demandes une correction de syntaxe, de structure ou de convention de code (nommage, format, organisation) sur un contenu produit par Claude, forge l'applique, la journalise, puis rédige une règle générale au format `Quand [cas] → [conduite]`, pour que Claude agisse ainsi d'emblée la prochaine fois. Il en va de même pour les choix d'infrastructure et pour les choix de Claude que tu invalides. Un bug fonctionnel ou un changement de besoin ne déclenche rien.

La règle est affichée en entier, puis forge demande où l'écrire : dans le `~/.claude/CLAUDE.md` global, dans le `CLAUDE.md` à la racine du projet (créé s'il est absent), ou nulle part. **Aucun `CLAUDE.md` n'est écrit sans ta réponse.** Rien n'est proposé pour un cas ponctuel ou déjà couvert par l'un des deux fichiers, et une règle gardée en local n'est jamais reproposée. Une exécution déléguée ne propose rien.

---

## Détection hors périmètre

Après chaque input utilisateur, forge vérifie si la demande est dans le plan courant ou non.

Une **action directe** ne devient jamais une tâche : un ordre précis — quoi, où — qui tient en une commande ou une modification locale et n'appelle aucune décision de conception (supprimer ou renommer un fichier, corriger une formulation, ajouter un mot, lancer une commande) est exécuté sur-le-champ, l'ordre valant confirmation, et journalisé en une ligne quand le dépôt change. Il en va de même pour toute demande dont le résultat est un contenu généré — documentation, export, script SQL, classeur de contrôle, analyse, livrable client — quelle que soit sa taille : il est produit dans `output/` et journalisé, jamais planifié, car le plan ne trace que les tâches qui implémentent l'objectif du brief. Dans le doute — action directe ou demande complémentaire, livrable ou fonctionnalité — forge y voit une action directe : une action de trop ne coûte rien, une question de trop coûte un aller-retour.

Une **demande de vérification** — lancer des tests, contrôler un comportement, reproduire un cas — passe en premier. Un test rapide (une commande ou une lecture, sans test à écrire ni scénario en plusieurs étapes) est une action directe, sans question. Au-delà, ou dans le doute, forge formule la vérification comme une tâche du plan et pose une seule question : l'ajouter au plan et l'exécuter, vérifier sans tâche (journalisé en une ligne), ou annuler.

**Détecté si la demande :**
- Concerne une fonctionnalité absente du plan
- Introduit un nouveau cas d'usage, module ou comportement
- Modifie une contrainte technique ou fonctionnelle implicitement acceptée

**Réaction :** une nouvelle demande est toujours une nouvelle tâche du plan — forge ne demande jamais s'il faut l'ajouter ou la traiter hors plan.
1. Signaler : `"This request isn't in the current plan."`, puis formuler la tâche telle qu'elle entre au plan — titre, effort, fichiers, description — avec l'entrée `## Scope & rules` qu'elle implique, si le périmètre change durablement.
2. Poser une seule question, avec les options de la validation d'un plan neuf : valider et enchaîner, valider, ou annuler. La tâche est recopiée en texte brut en tête de la question elle-même, sur un gabarit figé — titre, effort et description entière en puces, numérotées quand l'ordre compte ; fichiers et entrée de périmètre restent dans la réponse — : elle reste à l'écran même quand le texte au-dessus de la boîte de dialogue est masqué. Un changement de formulation passe par le champ de texte libre, comme pour toute validation de contenu.
3. Validée → la tâche entre au plan (et au brief, si son périmètre a changé). Valider et enchaîner l'exécute aussitôt, avec les autres tâches ouvertes, sans autre question ; valider l'écrit seulement, puis demande comment exécuter les tâches, comme pour un plan neuf. Annulée → rien n'entre au plan, la demande n'est pas traitée.

---

## Mode professeur

```
"c'est quoi X" / "explique-moi Y" / "je ne comprends pas Z"
```

Une question de compréhension sur un concept technique — pas une question de décision ni de périmètre — fait passer forge en mode pédagogique : une explication claire, avec un exemple concret tiré du projet quand c'est utile. Un agent en tâche de fond la consigne dans `output/AAAAMMJJ-explanation-<sujet>.md`, en ajoutant une section datée si le sujet a déjà son fichier, pendant que la tâche en cours reprend aussitôt. Une ligne signale le fichier une fois écrit ; aucune confirmation n'est demandée. Sur `main` ou `master`, rien n'est écrit : l'explication reste dans la réponse.

---

## Mise à jour de project.md

```
"ranger la forge" / "clean the forge"
```

Met à jour `project.md` — uniquement ce qui a changé, après validation.

---

## Mise à jour du skill

```
"mettre à jour la forge" / "update the forge"
```

Au plus une fois toutes les 24 heures, `/forge` interroge le dépôt sur son dernier tag `vX.Y.Z` en arrière-plan, sans l'attendre : le démarrage coûte quelques millisecondes, hors réseau tout reste silencieux. Une version plus récente ainsi trouvée est annoncée au `/forge` suivant, en fin de ligne d'état, sans question : le travail commence sans détour.

La phrase ci-dessus contrôle tout de suite, quel que soit le délai, et propose l'installation : sur `Mettre à jour`, forge clone le tag dans un dossier temporaire, lance l'installeur de la plateforme et demande de relancer `/forge` ; `Plus tard` écarte cette version, qui n'est plus annoncée au démarrage — seule une version plus récente l'est. Elle signale aussi une version à jour ou un dépôt injoignable.

Une installation sans `install.json` (antérieure à cette fonction, ou depuis une archive hors git) est contrôlée aussitôt et se voit proposer la dernière version. Un forge délégué ne contrôle jamais.

---

## Délégation vers un projet lié

```
"fais T3 et T5 dans ../autre-projet"    → ces tâches seulement
"fais ça dans ../autre-projet"          → forge demande quelles tâches ouvertes déléguer
```

Une demande qui vise un dossier hors du projet courant ouvre un **projet lié**. Un dépôt pas encore forgé
(`.forge/project.md` absent de sa branche par défaut) l'est sans question par le délégué, dans le worktree de la
branche liée : `project.md` et `coding-standards.md` partent avec cette branche et rejoignent la branche par défaut
à sa fusion ; une seule délégation à la fois vers un même dépôt non forgé. Il faut une vraie branche côté parent :
un nom de code utilisé hors git ne peut pas déléguer.

Le parent prépare le terrain, rien de plus : il ouvre une **branche liée** du dépôt lié dans un worktree
git, nommée selon la même règle qu'une branche forge ordinaire — un slug court en kebab-case tiré de la tâche
déléguée (ou de l'objet commun des tâches déléguées), `-2`, `-3` en cas de collision dans le dépôt lié —
créée depuis son `master`/`main` à jour si elle manque. Le lien n'existe que dans le plan parent : une tâche
qui vise un projet lié porte `**Linked branch:** <chemin relatif à la racine du parent> @ <branche>`
(ex. `../my-api @ export-csv`) dès son entrée au plan, affiché dans la question `Plan` ; des tâches au même
champ partagent la branche et son worktree. Le parent écrit ensuite le brief lié — un bloc `## Origin` qui ne
porte que le **mandat** (les tâches déléguées recopiées intégralement) et un objectif rédigé à partir de ces
seules tâches — et ouvre le `log.md` lié (`Opened by delegation · T3, T5`). Le plan du parent est annoté
(`delegated to ../my-api @ export-csv`) et son log enregistre le passage de relais. Un tableau récapitulatif
liste ces actions ; rien ne s'exécute avant une confirmation unique.

**Le projet lié ne nomme jamais le parent.** Il peut être public quand le parent est privé : aucun dossier,
branche, ticket, client ni donnée du parent n'entre dans la branche liée — nom, brief, plan, log, code,
CHANGELOG, commits. Les tâches qui visent un projet lié sont rédigées ainsi dans le plan parent, puisqu'elles
sont recopiées telles quelles. Seule exception : une référence sans laquelle la tâche ne peut pas s'exécuter,
limitée au strict nécessaire et écrite dans la tâche — jamais le brief parent.

Le worktree est rangé à côté du dépôt lié, dans `<dossier-lié>.worktrees/<branche>` — par exemple
`my-api.worktrees/export-csv` — et réutilisé s'il existe déjà. Le dossier propre du dépôt lié n'est jamais touché — ni checkout, ni écriture : tu
peux continuer à y travailler à la main pendant que le sous-agent tourne. Un worktree ne porte que les fichiers
versionnés : ni dépendances installées, ni `.env`, ni configuration locale — une tâche déléguée qui en a besoin
revient bloquée, et le `.forge/` du lié doit être commité. Le worktree est retiré automatiquement une fois la
branche liée fusionnée dans la branche par défaut du projet lié (`master`, puis `main`, locale ou `origin/` après
un fetch) : après une livraison relayée qui la fusionne, ou à la clôture du parent pour une fusion faite hors
forge — une pull request, par exemple. `linked-worktree-cleanup.sh` décide seul et ne force jamais : un worktree
aux modifications non commitées, une branche non fusionnée (fusion par squash comprise) ou le dossier propre du
dépôt lié sont gardés, et le compte rendu dit pourquoi. La branche liée elle-même n'est jamais supprimée. Une
fusion dans l'une des branches cibles de la livraison compte aussi (`--merged-into` : une livraison limitée à `dev`
retire le worktree une fois la branche dans `dev`), et un worktree gardé a toujours sa ligne au compte rendu, avec la
commande de retrait prête à copier (`worktree: kept — <reason> · remove: git -C "<lié>" worktree remove "<worktree>"`).

L'exécution se fait ensuite dans un **contexte forge étanche** : un sous-agent qui ne reçoit que le chemin
du worktree, la branche liée, ta langue et l'ordre d'y exécuter le skill forge. Aucun `project.md`, aucun
standard, aucun plan, aucun log ne traverse la cloison, dans un sens comme dans l'autre. Le plan lié est
dérivé du seul mandat — chaque tâche porte sa filiation (`T1 — … ← parent T3`), et un besoin hors mandat
ne devient jamais une tâche : il est remonté. Une fois le plan validé, le sous-agent enchaîne toutes les
tâches sans demander de mode d'exécution — la validation du plan vaut accord. Chaque question bloquante
qu'il rencontre (validation du plan, choix d'approche) t'est relayée telle quelle sous forme de
`FORGE_QUESTION` et posée via le même `AskUserQuestion` que d'habitude ; la réponse repart vers le
sous-agent, dont le contexte reste intact. Une question relayée porte le **contenu entier** à trancher —
le plan complet, la description complète de la tâche, l'entrée de brief — jamais un résumé d'une ligne :
le parent te l'affiche tel quel, puis pose la question.

L'exécution se termine par un unique rapport `FORGE_DONE` : tâches faites, tâches bloquées avec leur
raison, besoins hors mandat, fichiers touchés. Le parent coche alors — et seulement alors — chaque tâche
déléguée `[x]` ou la marque `[!] blocked` avec la raison, une entrée de log par tâche. Rien n'est commité
dans le dépôt lié à ce stade : sa livraison est proposée au moment où tu graves le parent (voir plus bas).
---

## Délégation vers une branche du même dépôt

```
"lance un agent forge sur la branche X"   → X ouverte dans un worktree frère, forge s'y exécute
"ouvre la branche X dans un agent"        → même chose
```

Une demande de lancer un agent — ou un forge délégué — sur une branche du dépôt courant ouvre cette branche
dans un **worktree** : un worktree existant pour `X` est réutilisé, sinon forge crée `<dossier-du-dépôt>.worktrees/X`
à côté du dépôt — la branche devient le chemin, par exemple `forge.worktrees/feature/x` (`git worktree add`). Deux refus, jamais contournés : `X` est la branche courante (« déjà
dessus »), ou `X` n'existe pas — forge ne crée jamais une branche à ta place. Un tableau récapitulatif
liste la branche, le chemin du worktree et l'agent ; rien ne s'exécute avant une confirmation unique.

Aucun mandat ici : le parent n'écrit rien dans le worktree, ni brief, ni log, ni plan, et ne lit jamais
son code. Le sous-agent reçoit le chemin du worktree, la branche, ta langue et `SCOPE: branch`, puis y
exécute le skill forge exactement comme tu le ferais sur cette branche — project, brief, log et plan lus
comme les phases le prescrivent. La différence avec un projet lié : **chaque choix t'est relayé** —
l'objectif du brief, la validation du plan, le mode d'exécution, le feu vert avant chaque tâche. « Le plan validé vaut accord » ne s'applique pas dans cette portée, sauf si tu
choisis valider et enchaîner à la validation du plan.

L'exécution se termine par un `FORGE_DONE` d'une ligne : rien n'est écrit dans le plan ni le log du
parent, puisque rien n'a été délégué. Le worktree reste en place — forge te rappelle
`git worktree remove <chemin>` pour quand la branche sera gravée.

---

## Essaim de branches filles

```
plan avec ≥ 1 tâche-branche → « Valider et lancer l'essaim » → branches filles en parallèle du parent
plan avec ≥ 1 branche liée   → « Valider et lancer l'essaim » → délégués liés en parallèle du parent
```

L'essaim ne se limite pas au dépôt courant. Ses délégués sont des **unités** de deux types, lues par
`swarm-status.sh` : `child` (tâche-branche de ce dépôt, fusionnée dans la parente par le parent) et `linked` (tâches
ouvertes au même `**Linked branch:**`, dans un autre dépôt, jamais fusionnées par le parent, livrées par la livraison
relayée). Les deux partagent les N places, le relais groupé, `swarm.md` (nouvelle colonne `Type`) et la reprise. Dès
que le plan rédigé porte une unité lançable — comptée par le script sur le brouillon (`--plan`), jamais par le
modèle —, « Valider et lancer l'essaim » passe en tête et « Valider et enchaîner » est annoncé en série ; une tâche
liée ne passe jamais par la règle de branche (elle est déléguée quelle que soit sa taille) et n'entre jamais dans les
tâches propres du parent. Un délégué lié terminé libère sa place, et l'unité lançable suivante part sans question.

Quand au moins un groupe de tâches mérite sa propre branche — tâches d'un même module ou d'une même tranche
fonctionnelle, ensemble ≥ 15 min d'agent, livrées et testées seules sans fichier partagé avec un autre groupe —, le
plan devient un **plan de branches** : chaque groupe devient une `### Tn — Branch <parente>-<slug>` avec une ligne
`**Depends on:**`, une tâche socle des points d'extension passe en tête et une vérification d'ensemble en dernier.
Sous le tableau des groupes, `time-calibrate.sh --groups` affiche le gain : durée en essaim (travail seul des branches,
réparties sur N délégués) contre durée en série ; avec `--parent`, les tâches ordinaires du parent comptent comme une
voie de plus : une seule branche menée à côté du travail du parent peut être rentable ; lancement, fusions et
dépendances ne sont ni estimés ni mesurés, le chiffre est optimiste.

- **Choix visible :** `time-calibrate.sh` convertit le seuil en fichiers (`branch_files`, 30 aux valeurs de
  référence). Dès que le plan compte ce nombre de fichiers, le tableau des groupes s'affiche toujours, verdict
  `branch` ou `task` pour chacun, même quand aucun groupe n'est retenu.
- **Ajouts et promotion :** des tâches ajoutées en cours de branche qui remplissent la règle sont proposées en
  tâche-branche, avec « Valider et lancer l'essaim ». Une tâche dont la taille réelle apparaît à l'exploration est
  proposée comme branche (`Promotion`), avant tout fichier écrit — chez le parent comme chez un délégué.
- **Sous-agents ordinaires :** lecture seulement (exploration, recherche, revue, vérification). Jamais d'écriture
  parallèle dans le même working tree : l'écriture reste dans la session, en série, ou passe par l'essaim.
- **Lancement :** `swarm-status.sh` liste les branches en cours, lançables et en attente, et simule la fusion de la
  parente. Jusqu'à N branches lançables (3 par défaut, modifié seulement sur demande) reçoivent un worktree, la
  parente fusionnée, un brief, leur propre installation des dépendances et leur port, et un forge délégué chacune,
  toutes dans le même tour. À la reprise, les branches lançables sont proposées par une question `Swarm` (lancer,
  travailler sur les tâches du parent, plus tard) : rouvrir une session ne lance jamais de délégué de lui-même.
- **Relais :** questions préfixées par leur branche, groupées dans une même fenêtre quand plusieurs attendent,
  renvoyées au délégué quand le contexte de décision manque ; notes de coordination quand deux branches touchent le
  même module.
- **Fin d'une branche :** une question — fusionner et lancer la suivante, fusionner, vérifier avant de fusionner
  (l'application tourne depuis le worktree) ou ne rien faire ; une option de fusion commite le travail de la
  branche, et d'abord la tâche du parent en cours. Le parent seul fusionne dans la branche parente :
  avance rapide, ou fusion inverse avec règles de conflit, vérifications demandées par le projet puis avance rapide ; jamais de
  push, jamais de fusion vers la branche par défaut.
- **Parent au travail :** pendant que les délégués travaillent, le parent enchaîne les tâches ordinaires prenables —
  `Mode` demandé une seule fois pour tout l'essaim, gardé dans `swarm.md` — et ne rend la main que lorsqu'il n'en
  reste plus. La notification d'un délégué arrive entre deux appels d'outils, même au milieu d'une tâche du parent :
  le parent termine l'action en cours, relaie aussitôt, puis reprend sa tâche.
- **Limites :** les worktrees vivent à côté du dépôt, hors du dossier de la
  session : autoriser ce dossier (`/add-dir ../<dépôt>.worktrees` ou `additionalDirectories`), sinon les délégués en
  tâche de fond s'arrêtent sur des demandes de permission. Les fichiers ignorés (`.env`, configuration locale) ne
  sont pas copiés dans un worktree et la base de développement reste partagée entre délégués : garder les
  vérifications en base pour la vérification d'ensemble finale. Sous Windows, des `node_modules` profonds peuvent
  demander `git config core.longpaths true`.
- **État :** `swarm.md` garde N, les branches avec l'identifiant de leur délégué et leur port, les choix transmis
  et les notes de coordination ; à la reprise, une question `Resume` relance les délégués arrêtés avec une ligne
  `RESUME:` et le même port — jamais sans réponse, un délégué encore actif ailleurs partagerait son worktree avec
  le nouveau.

---

## Livraison — commit, push, merge

```
"grave <branche(s)>" / "engrave <branche(s)>"
```

Une ou plusieurs branches existantes, citées dans l'ordre voulu (ex : `"grave dev"`, `"grave master"`, `"grave dev master"`). `<BRANCH>` est mergée tour à tour dans chaque branche citée, toujours depuis la branche de départ — jamais en enchaînant une branche citée dans la suivante.

La séquence est exécutée par `skills/forge/scripts/engrave.sh`, jamais recomposée à la main : `run` exécute `add`, `commit`,
`push`, puis pour chaque branche citée `checkout`, `merge` et `push` de cette branche, et un `checkout` final de retour
sur `<BRANCH>`, quel que soit le nombre de branches — une opération git par étape —, puis renvoie du JSON que Forge
met en page en compte rendu, même quand une étape échoue (`preview` liste les mêmes actions sans rien
exécuter ; la livraison ne l'appelle pas). Le script fait le traitement, le modèle fait la mise en page. Une branche égale à `<BRANCH>` est écartée ; une branche absente, ou extraite dans un autre
worktree, est marquée `skipped` ; un working tree propre saute `add` et `commit` et pousse quand même. Sur un conflit de merge ou un push
rejeté, le script s'arrête : l'étape en échec est `failed` avec sa raison (les fichiers en conflit pour un conflit),
chaque étape suivante `not_run` — jamais exécutée, la séquence s'étant arrêtée avant elle — et le conflit reste en
place, résolu seulement à ta demande. Lancer
`bash tests/engrave.test.sh` pour le vérifier.

**Sans confirmation :** `grave` / `engrave` en tête de message, seul ou suivi uniquement de branches
existantes (`grave`, `grave dev master`) — la séquence s'exécute aussitôt, sans récapitulatif
préalable ; tout autre texte dans le message n'est pas une livraison. La commande autorise cette séquence
seulement. Les
questions sur les projets liés restent posées — elles fixent le périmètre, elles ne confirment rien. Un
conflit de merge ou un push rejeté arrête la séquence et affiche l'erreur telle quelle ; rien n'est
jamais forcé.

**INVARIANT :** git opère uniquement sur le dépôt courant — jamais sur un autre dépôt ouvert en parallèle. Unique
exception : un projet lié, pour la création du worktree à la délégation, pour la livraison relayée ci-dessous et
pour le retrait de son worktree une fois sa branche fusionnée.

Quand le plan porte des tâches déléguées, graver le parent propose aussi de livrer chaque projet lié qui a des
modifications non commitées : d'abord s'il faut le livrer, puis sur quelles branches — les mêmes que le parent,
la branche liée seule (commit et push, aucun merge), ou une liste de ton choix. Son message de commit est généré
depuis les tâches déléguées cochées, jamais depuis son code, que le parent ne lit pas, et ne nomme jamais le parent. Les actions du projet lié
ont leur propre tableau de compte rendu sous celui du parent, et la même commande livre tout ; une branche
cible absente du dépôt lié est ignorée, jamais créée. La livraison s'exécute dans le worktree ; une branche
cible extraite dans un autre dossier — dossier propre du dépôt lié compris — est ignorée, la fusion se faisant
depuis ce dossier-là. Le sous-agent délégué n'intervient jamais : la livraison
relayée est du git pur, exécuté par le parent. Quand la livraison d'un projet lié a fusionné sa branche, son
worktree est ensuite retiré si la branche a atteint la branche par défaut et que le working tree est propre ;
une ligne `worktree` sous son tableau indique `removed` ou `kept` avec la raison.

Tout ce qui est publié sur la forge distante après une livraison — titre et notes de release, description de tag ou de PR — est rédigé en **anglais**, quelle que soit ta langue. Le message de commit suit la langue des commits du dépôt.

Le message de commit est généré automatiquement — pas de confirmation dédiée sur le message lui-même. Aucun récapitulatif préalable : toute la séquence s'exécute d'un trait — add, commit, push, puis chaque merge, sans validation intermédiaire. Une fois la séquence exécutée, Forge n'écrit plus rien — ni entrée de log, ni note de plan : le compte rendu est du texte seul, sur un gabarit figé — un tableau par projet, une ligne par opération git, colonnes `#`, branche, opération, résultat dans toutes les langues `DONE`, `SKIPPED`, `FAILED` ou `HALTED` (`done`, `skipped`, `failed`, `not_run` dans le JSON), détail : hash et message du commit, plage poussée ou `up to date`, `fast-forward` / commit de merge / `already up to date`, raison d'un saut ou d'un échec, erreur git sous le tableau en cas d'échec — et le working tree reste tel que la livraison l'a laissé.

---

## Clôture de tâche — rapport & réponse client

Déclenchée quand toutes les tâches sont `[x]` et que tu as validé les tests, ou dès que tu annonces
que c'est terminé.

Forge confirme d'abord que le problème initial est bien résolu, en listant les tâches encore ouvertes.
S'il en reste, chacune est soldée : terminée (`[x]`), abandonnée (`[-]`) ou laissée ouverte. Une tâche
bloquée `[!]` n'est jamais touchée, et `Solved` seul ne coche rien.

Quand le plan porte des tâches déléguées à un projet lié, chaque worktree lié dont la branche est désormais
fusionnée — par une livraison relayée ou hors forge, par une pull request — est retiré, sans question ; ceux qui
restent sont listés avec leur raison (`not merged`, `uncommitted changes`).

Si la branche a une tâche ClickUp ouverte, Forge rédige ensuite un rapport de clôture pour la tâche désignée
par son marqueur `ticket.json`, écrit par `/forge-clickup` : texte brut, structuré et schématique, dans ta langue — labels
compris, seul contenu généré exempté des libellés de structure figés en anglais. Comme tout contenu
généré, il est conservé dans `.forge/branch/<BRANCH>/output/AAAAMMJJ-clickup-report.txt`, réécrit sur
place à chaque modification demandée. La tâche est relue avant tout envoi, jamais devinée, et le
rapport n'est publié en commentaire que sur accord explicite. Sans marqueur, Forge cherche encore une
tâche au nom de la branche, pour les branches ouvertes avant le marqueur ; si aucune ne correspond, aucun rapport n'est rédigé et l'étape reste entièrement silencieuse :
la clôture ne crée jamais de tâche ClickUp et n'en propose jamais.

Enfin, il propose de rédiger une réponse à un mail client — rédigée dans la langue du mail reçu,
jamais la tienne si elles diffèrent, avec la voix d'une équipe support technique : courte, fluide,
professionnelle, directe et naturelle, empathique sans être trop chaleureuse, orientée vers la résolution
du problème. Elle ne répète pas ce que le client vient d'écrire, ne reformule pas toute sa demande sans
nécessité, et écarte les explications techniques inutiles, les phrases trop longues et les tournures
administratives lourdes. Le brouillon est affiché dans la conversation et toujours conservé
aussi, copie exacte en texte brut dans `.forge/branch/<BRANCH>/output/AAAAMMJJ-email-client-reply.txt`,
doublée d'un `.html` aux vrais tableaux, ouvert dans le navigateur pour être collé dans Outlook — prêt à
envoyer ou à joindre au ticket d'où vient le mail — ClickUp, Jira ou tout autre. Tout autre mail rédigé pour
un tiers est conservé de la même façon, sous `AAAAMMJJ-email-<sujet>.txt` et `.html`.

---

## Format du plan

Libellés de structure en anglais, tels que le skill les écrit quelle que soit la langue ; seul le contenu suit la langue de l'utilisateur.

```markdown
# Plan — <BRANCH>
**Objective:** ...
**Date:** ...
**Estimate:** ≈ 3 files · ≈ 2 min (1-2)

## Tasks

### T1 — Titre
**Effort:** S
**Estimated time:** ≈ 2 min (1-2)
**Files:** `src/a.ts`, `src/b.ts`, `tests/a.test.ts`
**Description:** ...
[ ]

<!-- Tâche L ou XL : décomposer en micro-étapes avant de démarrer
[ ] T1.1 — ...
[ ] T1.2 — ...
-->

## Summary
| Task | Effort | Files | Estimated | Actual | Status |
|---|---|---|---|---|---|
| T1 — Titre | S | 3 | ≈ 2 min | — | [ ] |
| **Total** (0/1 measured) | | | — | — | |
| **Remaining** | | **3** | **≈ 2 min (1-2)** | | |
```

**Écrit par le hook :** `**Estimate:**`, chaque `**Estimated time:**`, `**Actual time:**` et tout `## Summary` (cellules recopiées des tâches, raison du blocage comprise, `**Total**` des tâches mesurées, `**Remaining**` des tâches ouvertes) sont tenus par `plan-hook.sh` à chaque écriture de `plan.md` ; le modèle écrit les tâches et le titre court de chaque ligne du tableau. `**Actual:**` (temps réel de la branche par poste, sous `**Estimate:**`, quand un journal de mesure existe) est écrit par `metrics.sh` à la livraison et à la clôture seulement ; le hook le garde tel quel.

**Statuts :** `[ ]` à faire · `[x]` terminé · `[!]` bloqué · `[-]` abandonné  
**Effort :** XS · S · M · L · XL — taille relative, sans durée attachée ; XL → découper en sous-tâches, ou en branche  
**Estimation :** ordre de grandeur du temps d'agent, jamais un délai engageant ; le temps de réponse de l'utilisateur n'y est jamais compté

---

## Licence

MIT — voir [LICENSE](LICENSE).
