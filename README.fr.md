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

Une fois actif, forge ne s'arrête pas au code : il délègue des tâches à des sous-agents étanches — projet lié ou branche du même dépôt — en te relayant chaque question, grave la branche (commit, push, merges, livraison relayée, release) sous une confirmation unique, et la clôt avec un rapport, un commentaire ClickUp et une réponse client.

Le résultat : moins de mauvaises surprises, des implémentations qui restent dans le périmètre défini, et un historique par branche qui survit aux compactions de contexte. Cela facilite aussi grandement le travail en équipe de plusieurs développeurs : chacun travaille sur sa propre branche, et reprendre une branche commencée par un autre, c'est hériter de tout ce qu'il faut pour poursuivre le développement — les actions déjà faites, le contexte et la documentation — puisque tout ce que forge génère (brief, plan, log, livrables) vit avec la branche et voyage avec elle dans git.

### Ce que Claude_forge apporte concrètement

- **Zéro code sans validation** — la règle absolue : silence ≠ accord. Le skill attend une validation explicite avant d'écrire quoi que ce soit, posée en choix et jamais en texte libre.
- **Contexte persistant par branche** — `brief.md` et `plan.md` sont stockés dans `.forge/branch/<BRANCH>/`, suivis en git, et relus à chaque `/forge`.
- **Pensé pour l'équipe** — les développeurs travaillent sur des branches différentes, et chacun peut reprendre une branche commencée par un autre avec les actions déjà faites, le contexte et la documentation nécessaires à la suite : brief, plan, log et livrables générés sont partagés via git, sans passation à rédiger à côté.
- **Contenu généré rangé avec la branche** — toute doc, script SQL, export, explication ou livrable client demandé est écrit dans `.forge/branch/<BRANCH>/output/`, jamais à la racine du projet, nommé `AAAAMMJJ-` suivi d'un intitulé en kebab-case anglais, sans exception : `20260910-db-migration.sql`. Les fichiers propres à forge — `brief.md`, `plan.md`, `log.md`, `report.txt` — restent au niveau du dessus, intacts.
- **Brief vivant & log** — le cadre (règles, contraintes, périmètre) va silencieusement dans la section `## Scope & rules` du brief ; les décisions et choix utilisateur sont enregistrés silencieusement dans `log.md`, sans interrompre le flux de travail.
- **Résumé "Last session"** — à la reprise, si `log.md` contient des entrées, un récapitulatif des 10 dernières en une ligne est affiché avant le tableau d'avancement.
- **Décomposition des tâches L/XL** — les grandes tâches sont découpées en micro-étapes dans `plan.md` avant de démarrer l'implémentation.
- **Étapes de mise en production dans le plan** — tout ce qui se joue à la main hors du déploiement git — migration SQL, réglage de configuration, procédure d'exploitation — est listé dans la section `## Deployment` de `plan.md` avec son moment et sa copie dans `output/`, renseigné dès que le script est écrit.
- **Détection hors périmètre** — une demande hors du plan courant devient une tâche du plan : forge la formule, tu valides la formulation, rien de plus.
- **Branche en argument** — `/forge <nom-de-branche>` bascule sur cette branche, créée depuis la branche par défaut à jour (`master`, sinon `main`) si elle n'existe pas — jamais depuis la branche courante. L'argument est toujours un nom de branche git, jamais un identifiant de ticket.
- **Garde main/master** — sans argument, sur les branches protégées, forge demande soit un identifiant de ticket, soit un nom de branche avant de continuer.
- **Raccourcis de livraison** — `"grave master"` / `"engrave master"` (ou avec `"dev"`) commit, push et merge en une étape confirmée.
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

Les archives de release (« Source code » zip / tar.gz sur la [page des releases](https://github.com/jeanchristoph/claude_forge/releases)) ne contiennent que ce dont les installeurs ont besoin : `.forge/`, `docs/` et les fichiers `.git*` en sont exclus.

L'extension `/forge-clickup` requiert en plus le connecteur MCP ClickUp authentifié (`/mcp` dans Claude Code). Aucun script ne peut faire cette étape à ta place : c'est un OAuth navigateur.

---

## Usage

```
/forge                  # travaille sur la branche courante (garde main/master)
/forge <nom-de-branche> # bascule sur <nom-de-branche>, créée depuis master/main si absente
/forge-clickup          # extension : demande l'objectif, ouvre la tâche ClickUp (titre et description déduits), crée la branche, enchaîne sur forge
```

---

## Structure du repo

```
forge/
├── skills/                   → chaque sous-dossier est copié dans ~/.claude/skills/<nom>/
│   ├── forge/
│   │   ├── SKILL.md
│   │   └── phases/
│   │       ├── p0-project.md          (État 0 — Project Init)
│   │       ├── p1-coding-standards.md (État 1 — Coding Standards Init)
│   │       ├── p2-brief.md            (État 2 — Brief)
│   │       ├── p3-log.md              (État 3 — Log)
│   │       ├── p4-plan.md             (État 4 — Plan)
│   │       └── p5-resume.md           (État 5 — Actif)
│   └── forge-clickup/        → extension : ouverture de tâche ClickUp
│       └── SKILL.md
├── hooks/
│   ├── bash/                 → copié dans ~/.claude/hooks/forge/ par install.sh (Unix)
│   │   └── forge-precompact.sh
│   └── ps1/                  → copié dans ~/.claude/hooks/forge/ par install.ps1 (Windows)
│       └── forge-precompact.ps1
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
├── .gitattributes
└── .gitignore
```

Fichiers générés dans chaque projet :

```
.forge/                  ← suivi en git, ajouté automatiquement au premier lancement
├── project.md
├── coding-standards.md  ← conventions de code (structure, nommage, principes), complétées au fil du projet
├── clickup.json         ← écrit par `/forge-clickup` : liste cible, branche de base, code de branche
└── branch/<BRANCH>/
    ├── brief.md         ← `## Objective` + `## Scope & rules`
    ├── log.md           ← Journal des décisions (vivant, 10 dernières entrées lues à la reprise)
    ├── plan.md
    ├── report.txt       ← généré à la clôture de tâche
    └── output/          ← tout fichier généré, nommé `AAAAMMJJ-`
        ├── 20260910-explanation-*.md ← écrit en tâche de fond lors d'une explication de concept
        ├── 20260910-db-migration.sql ← docs, scripts SQL, exports, notes
        └── 20260910-user-documentation-map.md ← livrable client, nommé comme tous les autres
```

Garde `.forge/` suivi en git — le bloc `.gitignore` ci-dessous s'en charge :

```
###> claude/forge ###
!/.forge/
###< claude/forge ###
```

---

## Comportement par état

### État 0 — Project Init
**Condition :** `.forge/project.md` absent

- Projet vide (hors dotfiles/dotfolders) → `project.md` placeholder créé, enchaîne.
- Sinon → explore stack, structure, conventions, écrit `project.md` après validation.
- `coding-standards.md` est écrit au même moment (uniquement s'il n'existe pas déjà) — voir ci-dessous.

### État 1 — Coding Standards Init
**Condition :** `.forge/coding-standards.md` absent

Écrit `coding-standards.md` dans la langue de l'utilisateur, puis enchaîne sur le brief.

### État 2 — Brief
**Condition :** brief absent

Lit `coding-standards.md`. Crée `.forge/branch/<BRANCH>/brief.md` avec une section `## Objective` et une section `## Scope & rules` vide, clarifie l'objectif, enchaîne sur le plan.

### État 3 — Log
**Condition :** brief présent, `log.md` absent

Crée un `log.md` vide en silence et continue vers le plan.

### État 4 — Plan
**Condition :** brief présent, `log.md` présent, plan absent

Lit `coding-standards.md`, génère `plan.md`, attend validation avant toute implémentation.  
Les tâches L/XL incluent un bloc de décomposition commenté (`T1.1`, `T1.2`, …) à remplir avant de démarrer.

### État 5 — Actif
**Condition :** brief + plan présents

Lit `coding-standards.md` et les fichiers en silence. Si `log.md` contient des entrées, affiche d'abord un récapitulatif "**Last session :**" des 10 dernières en une ligne, puis le tableau d'avancement. Propose ensuite les deux modes — enchaîner les tâches ouvertes ou en choisir une — et attend. Aucune tâche ouverte : aucun mode proposé, la question est ouverte.

---

## coding-standards.md

Créé en même temps que `project.md` (État 0), dans la langue de l'utilisateur : un titre (nom du projet) et une courte explication précisant que le fichier contient les conventions de code (structure, nommage, principes) à appliquer au moment d'écrire du code — une norme continue, pas un audit ponctuel — à compléter au fil du projet.

Il est lu à chaque phase qui touche au code (Bootstrap, Plan, Actif) pour que les conventions restent appliquées tout au long du workflow.

---

## Détection de branche

Via `bash -c "git branch --show-current 2>/dev/null"` — fonctionne sur Unix et Windows.  
Erreur ou résultat vide (pas de dépôt git) : demande un nom de code utilisé comme `<BRANCH>`. Sans réponse : STOP.

---

## Confirmations

Toute confirmation bloquante, tout choix fermé est posé sous forme de question à choix, jamais en
texte libre : mode d'exécution, approche architecturale, validation du plan, mise à jour
substantielle, demande hors périmètre, propagation d'une règle globale, livraison, livraison du projet
lié, clôture, publication ClickUp, réponse client. Le refus est toujours une option explicite, et
l'absence de réponse vaut STOP — jamais accord. La question, ses options et leurs descriptions sont
rédigées dans ta langue — les libellés anglais cités dans ce document sont les références internes du
skill, pas ce que tu vois à l'écran.

Les questions ouvertes restent en texte libre, là où une liste figée ne ferait que gêner : objectif
de la tâche, nom de code de branche, identifiant de ticket, mail à coller, quoi faire ensuite.

Valider un contenu — l'objectif du brief, le plan, le rapport de clôture — n'offre que deux options :
valider, ou annuler. Pas d'option « à retravailler » : une demande de changement passe par le champ de
texte libre de la question, avec son explication, et le contenu revient retravaillé sous la même
question. Un simple « non » n'est pas une demande de changement — forge demande en une ligne ce qui
doit changer, et ne re-présente jamais un contenu inchangé.

---

## Garde de sécurité — main / master

Sans argument, sur `main` ou `master`, forge pose le choix — pas une question en texte libre :
1. Rester sur la branche → fournir un identifiant ticket (ex: `CU-123`)
2. Créer une branche → fournir un nom

Avec un argument (`/forge <nom-de-branche>`), la garde ne s'applique pas : forge est déjà positionné sur `<nom-de-branche>`.

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
      "Bash(git branch --show-current*)"
    ]
  },
  "hooks": {
    "PreCompact": [{
      "hooks": [{ "type": "command", "command": "bash ~/.claude/hooks/forge/forge-precompact.sh", "shell": "bash" }]
    }]
  }
}
```

**Windows (`install.ps1`) :**
```json
{
  "permissions": {
    "allow": [
      "Read(//c/Users/{USER}/.claude/skills/forge/**)",
      "Read(//c/Users/{USER}/.claude/skills/forge-clickup/**)",
      "Read(/.forge/**)", "Edit(/.forge/**)",
      "Bash(git branch --show-current*)"
    ]
  },
  "hooks": {
    "PreCompact": [{
      "hooks": [{ "type": "command", "command": "powershell -File C:\\Users\\{USER}\\.claude\\hooks\\forge\\forge-precompact.ps1", "shell": "powershell" }]
    }]
  }
}
```

---

## Hook PreCompact

Injecte l'état forge dans la compaction du contexte pour préserver branche, objectif et statut des tâches.

- `install.sh` → déploie `forge-precompact.sh` dans `~/.claude/hooks/forge/`, ajoute uniquement l'entrée bash dans `settings.json`
- `install.ps1` → déploie `forge-precompact.ps1` dans `~/.claude/hooks/forge/`, ajoute uniquement l'entrée powershell dans `settings.json`

Chaque installeur retire toutes les entrées forge existantes avant d'ajouter la sienne — pas de doublon même en cas de réinstall.

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

**Décision ponctuelle** (choix acté et clos à un instant donné) → écrite silencieusement dans `log.md` (format : `- [AAAA-MM-JJ HH:MM] [1 ligne]`, heure locale) :
- Choix d'implémentation mineur acté sans discussion
- Choix utilisateur quand Claude a proposé plusieurs options (ex : "Option B retenue — raison")

---

## Détection hors périmètre

Après chaque input utilisateur, forge vérifie si la demande est dans le plan courant ou non.

Une **action directe** ne devient jamais une tâche : un ordre précis — quoi, où — qui tient en une commande ou une modification locale et n'appelle aucune décision de conception (supprimer ou renommer un fichier, corriger une formulation, ajouter un mot, lancer une commande) est exécuté sur-le-champ, l'ordre valant confirmation, et journalisé en une ligne quand le dépôt change. Il en va de même pour toute demande dont le résultat est un contenu généré — documentation, export, script SQL, classeur de contrôle, analyse, livrable client — quelle que soit sa taille : il est produit dans `output/` et journalisé, jamais planifié, car le plan ne trace que les tâches qui implémentent l'objectif du brief. Dans le doute — action directe ou demande complémentaire, livrable ou fonctionnalité — forge y voit une action directe : une action de trop ne coûte rien, une question de trop coûte un aller-retour.

**Détecté si la demande :**
- Concerne une fonctionnalité absente du plan
- Introduit un nouveau cas d'usage, module ou comportement
- Modifie une contrainte technique ou fonctionnelle implicitement acceptée

**Réaction :** une nouvelle demande est toujours une nouvelle tâche du plan — forge ne demande jamais s'il faut l'ajouter ou la traiter hors plan.
1. Signaler : `"This request isn't in the current plan."`, puis formuler la tâche telle qu'elle entre au plan — titre, effort, fichiers, description — avec l'entrée `## Scope & rules` qu'elle implique, si le périmètre change durablement.
2. Poser une seule question : valider, ou annuler. Un changement de formulation passe par le champ de texte libre, comme pour toute validation de contenu.
3. Validée → la tâche entre au plan (et au brief, si son périmètre a changé) et s'exécute selon le mode en cours. Annulée → rien n'entre au plan, la demande n'est pas traitée.

---

## Mise à jour de project.md

```
"ranger la forge" / "clean the forge"
```

Met à jour `project.md` — uniquement ce qui a changé, après validation.

---

## Délégation vers un projet lié

```
"fais T3 et T5 dans ../autre-projet"    → ces tâches seulement
"fais ça dans ../autre-projet"          → forge demande quelles tâches ouvertes déléguer
```

Une demande qui vise un dossier hors du projet courant ouvre un **projet lié** : un dépôt déjà forgé
(`.forge/` présent — sinon forge refuse et demande d'y lancer `/forge` d'abord ; il n'initialise jamais un
projet de lui-même). Il faut une vraie branche côté parent : une session restée sur `main`/`master` sous
un identifiant de ticket ne peut pas déléguer.

Le parent prépare le terrain, rien de plus : il positionne la branche **`<parent>/<BRANCH>`** dans le dépôt
lié — le nom du dossier parent en préfixe, la branche parente inchangée à droite : `forge/linked-project`,
`forge/CU-123` — créée depuis son `master`/`main` à jour si elle manque. Dans le dépôt lié, la branche dit
d'un coup d'œil d'où elle vient, se regroupe sous `git branch --list 'forge/*'` et n'entre jamais en collision
avec les branches propres du projet lié, identifiants de ticket compris ; le nom nu de la branche parente
n'est jamais utilisé. Il écrit ensuite le brief lié — le brief parent recopié à l'identique, précédé d'un
bloc `## Origin` portant le chemin du parent, la branche parente et le **mandat** : les tâches déléguées
recopiées intégralement — et ouvre le `log.md` lié. Le plan du parent est annoté
(`delegated to <chemin> @ <parent>/<BRANCH>`) et son log enregistre le passage de relais. Un tableau récapitulatif
liste ces actions ; rien ne s'exécute avant une confirmation unique.

L'exécution se fait ensuite dans un **contexte forge étanche** : un sous-agent qui ne reçoit que le chemin
du projet lié, `<parent>/<BRANCH>`, ta langue et l'ordre d'y exécuter le skill forge. Aucun `project.md`, aucun
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
dans un **worktree** : un worktree existant pour `X` est réutilisé, sinon forge crée `<dossier-du-dépôt>-X`
à côté du dépôt (`git worktree add`). Deux refus, jamais contournés : `X` est la branche courante (« déjà
dessus »), ou `X` n'existe pas — forge ne crée jamais une branche à ta place. Un tableau récapitulatif
liste la branche, le chemin du worktree et l'agent ; rien ne s'exécute avant une confirmation unique.

Aucun mandat ici : le parent n'écrit rien dans le worktree, ni brief, ni log, ni plan, et ne lit jamais
son code. Le sous-agent reçoit le chemin du worktree, la branche, ta langue et `SCOPE: branch`, puis y
exécute le skill forge exactement comme tu le ferais sur cette branche — project, brief, log et plan lus
comme les phases le prescrivent. La différence avec un projet lié : **chaque choix t'est relayé** —
l'objectif du brief, la validation du plan, le mode d'exécution, le feu vert avant chaque tâche, la
confirmation de gravure. « Le plan validé vaut accord » ne s'applique pas dans cette portée.

L'exécution se termine par un `FORGE_DONE` d'une ligne : rien n'est écrit dans le plan ni le log du
parent, puisque rien n'a été délégué. Le worktree reste en place — forge te rappelle
`git worktree remove <chemin>` pour quand la branche sera gravée.

---

## Livraison — commit, push, merge

```
"grave <branche(s)>" / "engrave <branche(s)>"
```

Une ou plusieurs branches existantes, citées dans l'ordre voulu (ex : `"grave dev"`, `"grave master"`, `"grave dev master"`). `<BRANCH>` est mergée tour à tour dans chaque branche citée, toujours depuis la branche de départ — jamais en enchaînant une branche citée dans la suivante.

**INVARIANT :** git opère uniquement sur le dépôt courant — jamais sur un autre dépôt ouvert en parallèle. Unique
exception : un projet lié, pour le positionnement de branche à la délégation et pour la livraison relayée ci-dessous.

Quand le plan porte des tâches déléguées, graver le parent propose aussi de livrer chaque projet lié qui a des
modifications non commitées : d'abord s'il faut le livrer, puis sur quelles branches — les mêmes que le parent,
`<parent>/<BRANCH>` seule (commit et push, aucun merge), ou une liste de ton choix. Son message de commit est généré
depuis les tâches déléguées cochées, jamais depuis son code, que le parent ne lit pas. Les actions du projet lié
ont leur propre tableau récapitulatif sous celui du parent, et la confirmation unique couvre tout ; une branche
cible absente du dépôt lié est ignorée, jamais créée. Le sous-agent délégué n'intervient jamais : la livraison
relayée est du git pur, exécuté par le parent.

Tout ce qui est publié sur la forge distante après une livraison — titre et notes de release, description de tag ou de PR — est rédigé en **anglais**, quelle que soit ta langue. Le message de commit suit la langue des commits du dépôt.

Le message de commit est généré automatiquement — pas de confirmation dédiée sur le message lui-même. Avant toute exécution, Forge affiche un tableau récapitulatif des actions git prévues : add, commit avec son message, push, puis une ligne par merge (`<BRANCH>` → cible), et une dernière ligne pour le retour sur `<BRANCH>`. Les changements de branche intermédiaires ne sont jamais listés. Aucune commande git — `git add` compris — n'est lancée avant la confirmation. Une seule confirmation couvre toute la séquence : add, commit, push, puis chaque merge, sans validation intermédiaire. Une fois la séquence exécutée, Forge n'écrit plus rien — ni entrée de log, ni note de plan : le compte rendu est du texte seul et le working tree reste tel que la livraison l'a laissé.

---

## Clôture de tâche — rapport & réponse client

Déclenchée quand toutes les tâches sont `[x]` et que tu as validé les tests, ou dès que tu annonces
que c'est terminé.

Forge confirme d'abord que le problème initial est bien résolu, puis écrit `report.txt` dans le
dossier de la branche : texte brut, structuré et schématique, dans ta langue — labels compris.
C'est le seul fichier généré exempté des libellés de structure figés en anglais.

Si `.forge/clickup.json` existe, Forge propose ensuite de publier ce rapport en commentaire sur la
tâche ClickUp dont le code est le nom de la branche. La tâche est relue avant tout envoi, jamais
devinée, et rien ne part sans accord explicite. Sans ce fichier, l'étape reste entièrement
silencieuse.

Enfin, il propose de rédiger une réponse à un mail client — rédigée dans la langue du mail reçu,
jamais la tienne si elles diffèrent.

---

## Format du plan

```markdown
# Plan — <BRANCH>
**Objectif :** ...
**Date :** ...

## Tâches

### T1 — Titre
**Effort :** S
**Fichiers :** `src/...`
**Description :** ...
[ ]

<!-- Tâche L ou XL : décomposer en micro-étapes avant de démarrer
[ ] T1.1 — ...
[ ] T1.2 — ...
-->

## Récapitulatif
| Tâche | Effort | Statut |
|---|---|---|
| T1 | S | [ ] |
| **Total** | **2h** | |
```

**Statuts :** `[ ]` à faire · `[x]` terminé · `[!]` bloqué  
**Effort :** XS <30min · S 30min-2h · M 2-4h · L 4h-1j · XL >1j → découper

---

## Licence

MIT — voir [LICENSE](LICENSE).
