# Project — Claude_forge

**Generated:** 2026-07-30 · updated 2026-11-06

## Stack
- Langage : Markdown (instructions du skill) + PowerShell / Bash (installeurs et hook)
- Framework / CMS : aucun — système de skill pour Claude Code
- Runtime / version : Claude Code CLI (skill invoqué via `/forge`), PowerShell 5.1 / bash côté scripts
- DB : aucune
- Serveur / runtime : aucun — fichiers déployés localement dans `~/.claude/skills/<skill>/`, hooks compris (`~/.claude/skills/forge/hooks/`)

## Key structure
```
forge/
├── skills/                        → chaque dossier copié vers ~/.claude/skills/<nom>/
│   ├── forge/
│   │   ├── SKILL.md               (machine à états : branche → garde main/master → détection d'état ; mode délégué)
│   │   ├── commands/              (commandes chargées à la demande, déclencheurs dans p5-resume.md)
│   │   │   ├── branch-rename.md      (Renommage de branche)
│   │   │   ├── closure.md            (Clôture de tâche)
│   │   │   ├── deployment-sql.md     (Script de déploiement SQL)
│   │   │   ├── email.md              (Mail rédigé, déclencheur dans SKILL.md)
│   │   │   ├── help.md               (Aide, /forge help, argument réservé dans SKILL.md)
│   │   │   ├── delegated-mode.md     (règles du sous-agent délégué, condition dans SKILL.md)
│   │   │   ├── delegation.md         (Délégation — projet lié, branche du même dépôt)
│   │   │   ├── engrave.md            (Livraison, synthèse metrics.json)
│   │   │   ├── rule-propagation.md   (Correction ou choix d'infrastructure → propagation vers CLAUDE.md)
│   │   │   ├── swarm.md              (Essaim de branches filles et de branches liées d'autres dépôts : lancement, relais, fin, fusion des seules branches filles, retrait, état, reprise, plan mixte)
│   │   │   ├── teacher.md            (Mode professeur, déclencheur dans SKILL.md)
│   │   │   └── update.md             (Mise à jour du skill : installation sans question, version ignorée)
│   │   ├── phases/
│   │   │   ├── p0-project.md         (État 0 — Project Init)
│   │   │   ├── p1-coding-standards.md (État 1)
│   │   │   ├── p2-brief.md           (État 2 — Brief)
│   │   │   ├── p4-plan.md            (État 4 — Plan)
│   │   │   └── p5-resume.md          (État 5 — Actif)
│   │   ├── references/
│   │   │   └── estimation.json       (valeurs de référence de l'estimation : minutes par fichier, fourchette, seuil de branche)
│   │   ├── scripts/
│   │   │   ├── checks.sh             (contrôles de démarrage, lancés détachés par SKILL.md sans attente : ligne input/ de branche dans le .gitignore)
│   │   │   ├── engrave.sh            (séquence git de la livraison : preview / run, appelée par p5-resume.md ; run --model écrit d'abord metrics.json par metrics.sh)
│   │   │   ├── metrics.sh            (synthèse de mesure : écrit metrics.json, rend la ligne estimé / réel en JSON ; livraison, clôture, fusion d'essaim)
│   │   │   ├── json.sh               (rendu JSON sans jq et lecture des champs du JSON des hooks, chargé par les scripts du skill)
│   │   │   ├── latest-version.sh     (fonctions bash communes à update.sh et update-notice.sh : install.json, dernier tag publié, comparaison de versions)
│   │   │   ├── log-entry.sh          (seule écriture d'une entrée LOG : horloge locale, entrée en tête de log.md, fins de ligne gardées ; règle « Entrée LOG » de SKILL.md)
│   │   │   ├── status.sh             (état au lancement en JSON, lecture seule, appelé par SKILL.md ; peu de processus, Git Bash les paie cher)
│   │   │   ├── task-files.sh         (fonctions awk communes, chargées par time-aggregate.sh, time-calibrate.sh, status.sh et plan-hook.sh : statut d'une tâche, fichiers prévus, fichiers changés entre deux empreintes)
│   │   │   ├── task-marks.sh         (fonctions bash communes à time-mark.sh et plan-hook.sh : horloge, empreinte du dossier, ligne de marque)
│   │   │   ├── swarm-status.sh       (état de l'essaim en JSON : unités child et linked en cours, lançables, en attente, fusion simulée des branches filles, projet lié forgé ou non, tâches du parent ; --plan lit un plan rédigé)
│   │   │   ├── time-aggregate.sh     (mesure d'une branche en JSON : journal du hook + git, lu par la synthèse metrics.json)
│   │   │   ├── time-calibrate.sh     (ratios du projet et estimation d'un nombre de fichiers, en JSON ; références dans references/estimation.json)
│   │   │   ├── time-mark.sh          (marques de délégué et de tokens dans time-log.jsonl ; marques de tâche à la main, le hook de coche les pose sinon)
│   │   │   └── update.sh             (mise à jour du skill : run installe le dernier tag publié, dismiss ignore la version annoncée, en JSON)
│   │   └── hooks/                 (hooks déclarés dans settings.json par les installeurs, copiés avec le skill ; bibliothèques chargées par ../scripts/)
│   │       ├── forge-precompact.sh   (hook d'état : PreCompact, SessionStart compact|resume)
│   │       ├── linked-write-guard.sh (garde d'écriture, PreToolUse sur Edit|Write|MultiEdit|NotebookEdit : écriture de la session parente dans un projet lié refusée, hors brief.md et log.md du mandat)
│   │       ├── plan-hook.sh          (hook de coche, PostToolUse synchrone : marques de tâche, réel, estimations, ## Summary ; état = lignes plan_checkpoint du journal)
│   │       ├── update-notice.sh      (hook de nouvelle version, UserPromptExpansion sur forge|forge-clickup, asyncRewake : recherche à chaque lancement, réveille Claude si une version plus récente et non ignorée existe)
│   │       └── time-hook.sh          (hook de mesure : une ligne par événement dans time-log.jsonl)
│   └── forge-clickup/
│       └── SKILL.md               (guichet ClickUp : ouvre la tâche, crée la branche, passe la main à forge)
├── install/
│   ├── install.sh             (déploiement Unix, idempotent)
│   └── install.ps1            (déploiement Windows, idempotent)
├── install-unix.sh            (lanceur racine → install/install.sh)
├── install-windows.bat        (lanceur racine → install/install.ps1)
├── CHANGELOG.md               (format Keep a Changelog, une section par version)
├── LICENSE                    (MIT, Jean-Christophe Malaval)
├── docs/
│   ├── demo.sh                (rejoue les sorties du skill pour la démo)
│   ├── demo.tape              (pilote l'enregistrement vhs)
│   ├── demo.gif               (généré — jamais édité à la main)
│   └── README.md              (prérequis de régénération, WSL requis)
├── tests/
│   ├── run-all.sh             (suite complète : chaque fichier de test l'un après l'autre, une ligne par fichier vert : bash tests/run-all.sh)
│   ├── test-runner.sh         (lanceur commun sourcé par chaque fichier de test : 12 cas à la fois, TEST_JOBS pour régler le nombre)
│   ├── test-runner.test.sh    (tests du lanceur et de la suite complète, fichiers jetables : bash tests/test-runner.test.sh)
│   ├── engrave.test.sh        (tests du script de livraison, dépôts jetables : bash tests/engrave.test.sh)
│   ├── forge-precompact.test.sh (tests du hook d'état, dépôts jetables : bash tests/forge-precompact.test.sh)
│   ├── install.test.sh        (tests des deux installeurs, HOME jetable : bash tests/install.test.sh)
│   ├── checks.test.sh         (tests des contrôles de démarrage, dépôts jetables : bash tests/checks.test.sh)
│   ├── linked-write-guard.test.sh (tests de la garde d'écriture dans un projet lié, dossiers jetables : bash tests/linked-write-guard.test.sh)
│   ├── log-entry.test.sh      (tests des entrées de LOG, dossiers jetables : bash tests/log-entry.test.sh)
│   ├── metrics.test.sh        (tests de la synthèse de mesure, dépôts jetables : bash tests/metrics.test.sh)
│   ├── plan-hook.test.sh      (tests du hook de coche, dépôts jetables : bash tests/plan-hook.test.sh)
│   ├── status.test.sh         (tests de l'état au lancement, dépôts jetables : bash tests/status.test.sh)
│   ├── swarm-status.test.sh   (tests de l'état de l'essaim, dépôts jetables : bash tests/swarm-status.test.sh)
│   ├── time-aggregate.test.sh (tests de l'agrégation de la mesure, dépôts jetables : bash tests/time-aggregate.test.sh)
│   ├── time-calibrate.test.sh (tests de la calibration, dossiers jetables : bash tests/time-calibrate.test.sh)
│   ├── time-hook.test.sh      (tests du hook de mesure, dépôts jetables : bash tests/time-hook.test.sh)
│   ├── time-mark.test.sh      (tests des marques de tâche, dossiers jetables : bash tests/time-mark.test.sh)
│   ├── update-notice.test.sh  (tests du hook de nouvelle version, dépôts jetables : bash tests/update-notice.test.sh)
│   └── update.test.sh         (tests de la mise à jour du skill, dépôts jetables : bash tests/update.test.sh)
├── README.md                  (documentation, anglais)
└── README.fr.md               (même documentation, français)
```

Fichiers générés dans **chaque projet cible** par le skill (pas dans ce dépôt) :
```
.forge/
├── project.md
├── coding-standards.md
├── clickup.json          (écrit par forge-clickup : liste cible, branche de base, code de branche)
└── branch/<BRANCH>/
    ├── brief.md          (## Origin en tête quand la branche est un projet lié : parent, branche, mandat)
    ├── log.md
    ├── plan.md
    ├── metrics.json      (synthèse de mesure, réécrite à chaque grave et à la clôture, versionnée)
    ├── time-log.jsonl    (événements bruts du hook de mesure, locaux, ignorés par git)
    ├── swarm.md          (état de l'essaim d'une branche parente)
    ├── ticket.json       (écrit par forge-clickup : tracker, code, url ; lu par la clôture, lien affiché à la reprise)
    └── output/           (tout contenu généré : AAAAMMJJ-<intitulé>.*, dont AAAAMMJJ-explanation-<sujet>.md)
```

## Entry points
- `skills/forge/SKILL.md` — point d'entrée lu par Claude Code à chaque invocation `/forge` (state machine)
- `skills/forge-clickup/SKILL.md` — point d'entrée de `/forge-clickup`, en amont de forge
- `install/install.ps1` / `install/install.sh` — déploient skills + hooks vers `~/.claude/` et fusionnent `settings.json`
- `skills/forge/hooks/forge-precompact.sh` — hook d'état `PreCompact` et `SessionStart` (`compact|resume`), injecte objectif du brief, plan et dernières entrées LOG ; toute évolution passe par ce script et `tests/forge-precompact.test.sh`
- `skills/forge/phases/p5-resume.md` — reprise, règles de mise à jour, surveillance, et déclencheurs des commandes de `skills/forge/commands/` : Délégation, Livraison (`grave` / `engrave`, projets liés compris) et Clôture de tâche
- `skills/forge/scripts/status.sh` — état de la branche en JSON, lu une fois par « Détection d'état » ; toute évolution passe par ce script et `tests/status.test.sh`
- `skills/forge/scripts/checks.sh` — contrôles de démarrage lancés détachés, jamais attendus : ajoute `/.forge/branch/*/input/` et `/.forge/branch/**/time-log.jsonl` au `.gitignore` hors main / master ; toute évolution passe par ce script et `tests/checks.test.sh`
- `skills/forge/hooks/update-notice.sh` — hook de nouvelle version, lancé par `/forge` et `/forge-clickup` en arrière-plan, sortie 2 pour réveiller Claude ; toute évolution passe par ce script et `tests/update-notice.test.sh`
- `skills/forge/scripts/update.sh` — mise à jour du skill : `run` (dernier tag `vX.Y.Z` publié, clone, installeur de la plateforme) et `dismiss` (version annoncée ignorée, retenue dans `install.json`) ; toute évolution passe par ce script et `tests/update.test.sh`
- `skills/forge/scripts/engrave.sh` — séquence git de la Livraison, `preview` puis `run`, tous deux en JSON mis en page par le skill (compte rendu : une ligne par opération git, statut `done` / `skipped` / `failed` / `not_run`) ; toute évolution de la séquence passe par ce script et `tests/engrave.test.sh`

## Detected conventions
- Nommage : phases numérotées `pN-<nom>.md`, sections `##`/`###` avec mots-clés stricts (« Condition », « Réaction », « STOP »)
- Architecture : machine à états explicite (États 0, 1, 2, 4, 5 — l'État 3 a disparu, numéros conservés) — chaque phase se termine par un renvoi à la détection d'état ou un `STOP` ; jamais de saut direct entre phases. Commande rare → fichier de `commands/` chargé à la demande, déclencheur gardé dans `p5-resume.md`
- Projet lié / mode délégué : un sous-agent étanche exécute le skill dans un autre dépôt forgé — prompt `FORGE_DELEGATED` (ROOT, BRANCH, LANGUAGE), marqueur `## Origin` dans le brief, questions relayées par `FORGE_QUESTION` / `FORGE_ANSWER`, rapport final `FORGE_DONE` ; tout délégué (projet lié, même dépôt, essaim) : ligne `TIME_LOG:` (journal de mesure du parent, où le délégué écrit ses marques de tâche), règle unique « Mesure d'un délégué » de `commands/delegation.md` ; le parent n'écrit là-bas que brief et log, et livre en `git -C`
- Questions à choix : toujours dans la langue de l'utilisateur, libellés anglais du skill = références internes ; validation d'un contenu = `Validate` / `Cancel` + texte libre expliqué, jamais d'option « à retravailler »
- Gestion d'erreurs : scripts PowerShell en `$ErrorActionPreference = "Stop"` ; hooks silencieux (`exit 0`) si branche/plan absents
- Idempotence : les installeurs retirent systématiquement les anciennes entrées (règles `permissions.allow` dont les formes abandonnées, hooks `PreCompact` / `SessionStart` dont l'ancien hook PowerShell, hook de mesure `time-hook.sh` sur ses six événements, hook de coche `plan-hook.sh`, chemins et dossier `~/.claude/hooks/forge/` d'avant `skills/forge/hooks/`) avant d'ajouter les nouvelles — jamais de doublon en settings.json
- Emplacement des hooks : un hook déclaré dans `settings.json` vit dans `skills/forge/hooks/` et charge ses bibliothèques par `../scripts/` ; `scripts/` ne contient que ce qu'appellent le modèle et les hooks
- Documentation : un fichier par langue — `README.md` (anglais) et `README.fr.md` (français), même plan de section à section. Sélecteur de langue en badges juste sous le titre, langue courante en bleu, l'autre en gris. Toute évolution de l'un est répercutée sur l'autre dans le même commit
- Règles non négociables du skill lui-même : pas de code sans confirmation explicite, pas de mention/copyright Claude, message de commit ≤150 caractères

## Critical files
- `skills/forge/SKILL.md` — toute modification du comportement du skill passe par ce fichier (routage d'état, mode délégué)
- `install/install.ps1` et `install/install.sh` — logique de fusion `settings.json` à préserver lors de tout changement de permissions/hooks (idempotence critique)
- `skills/forge/hooks/forge-precompact.sh` — contrat de sortie JSON (`hookSpecificOutput.hookEventName` = événement reçu, `additionalContext`) attendu par Claude Code pour `PreCompact` et `SessionStart`

## Tools & access
- MCPs disponibles : claude-in-chrome, datagrip, phpstorm, webstorm (non utilisés par ce dépôt en l'état)
- Documentation externe : aucune référence externe identifiée dans le dépôt
**Check pattern:** `bash "?[^";|&]*tests/|tests/\*\.test\.sh`
- Suite complète des tests (à chaque `grave`, ou à la demande) : `bash tests/run-all.sh`
