# T4 — Angles d'amélioration et piste plugin Claude Code (forge v0.13.0)

Étude en lecture seule du dépôt `D:/www/perso/claude skills/forge`, branche `audit-v0-13`. Références `fichier:ligne` relatives à la racine du dépôt.
Légende : coût **S** (< 1 h, un fichier), **M** (quelques fichiers + tests), **L** (refonte, plusieurs versions) · priorité **P1** (à faire en premier), **P2**, **P3**.

---

## Synthèse

| # | Piste | Gain | Coût | Risque | Prio |
|---|---|---|---|---|---|
| A1 | Pré-approuver les scripts du skill (`allowed-tools`) et supprimer la règle morte `bash -c "git branch…"` | Plus de demande de permission à chaque appel de script hors mode auto | S | Faible | **P1** |
| A2 | Différer `project.md` + `coding-standards.md` au démarrage de la première tâche | ≈ 18 Ko (≈ 5 k tokens) de moins sur chaque reprise sans code (`grave`, consultation, clôture) | S | Faible | **P1** |
| A3 | Sortir de SKILL.md / p5 les sections rares (SQL, CLAUDE.md, renommage, mail, professeur) vers `commands/` | ≈ 12-15 Ko (≈ 4 k tokens) de moins à chaque reprise | M | Moyen (déclencheurs à garder) | **P1** |
| A4 | Ligne de reste à faire calculée par `status.sh` (plus d'appel `time-calibrate.sh` séparé) | −1 appel Bash par reprise (Git Bash ≈ 100-300 ms + aller-retour modèle) | S | Faible | P2 |
| A5 | Supprimer la colonne `Status` du `## Summary` du plan (double saisie) | −1 Edit par tâche cochée, plus de dérive entre les deux | S | Faible | P2 |
| A6 | Ligne d'état enrichie (tâche suivante, reste ≈ min, fichiers non commités, avance/retard distant, ticket) | Information utile avant `grave` sans commande git | S-M | Faible | P2 |
| A7 | Proposition de mise à jour non bloquante au démarrage | −1 question bloquante en tête de reprise | S | Faible | P2 |
| A8 | Aide et découvrabilité (`/forge help`, rappel des commandes au premier lancement) | Onboarding, moins de commandes à retenir | S | Nul | P2 |
| A9 | Hook PreCompact unique en bash + réinjection `SessionStart` (compact / resume) | Moins de code ps1, meilleur réancrage après compaction | S | Faible | P2 |
| A10 | Mode professeur : écriture du fichier d'explication sur demande | −1 sous-agent par question de compréhension | S | Faible | P3 |
| A11 | Estimation : surcharge explicite `(≈ n min)` pour les tâches de lecture/audit | Estimations crédibles hors code | S | Faible | P3 |
| A12 | Corriger la dérive README ↔ installeurs (règles `permissions.allow`) | Documentation juste | S | Nul | P2 |
| B | Migration en plugin Claude Code (marketplace dans le dépôt) | Installation/maj natives, hooks portés par le plugin, commandes `/forge:*` découvrables, agent délégué dédié, ~700 lignes d'installeurs + `update.sh` retirées | L (en 2 versions) | Moyen (doublons de hooks à la transition, permissions par tour) | **P1 à décider** |

---

## A. Améliorations dans le format actuel

### A1 — Permissions des scripts : pré-approbation et règle morte — P1
**Constats**
- Chaque reprise appelle `bash <SKILL_DIR>/scripts/status.sh` + `update.sh check` + `checks.sh` (`skills/forge/SKILL.md:185-188`), puis `time-calibrate.sh` (`phases/p5-resume.md:50`), `time-mark.sh` / `time-aggregate.sh` à chaque tâche (`p5-resume.md:80-81`), `engrave.sh` au grave (`commands/engrave.md:65`). Aucune règle `Bash(...)` ne couvre ces scripts : les installeurs n'ajoutent que `Bash(bash -c "git branch --show-current*)` (`install/install.sh:66`, `install/install.ps1:74`). Hors mode auto, chaque appel déclenche une demande de permission.
- Cette règle est morte : aucune instruction du skill n'appelle `bash -c "git branch --show-current"` (seuls `status.sh:82`, `checks.sh:50`, `engrave.sh:92`, `swarm-status.sh:100` l'utilisent, à l'intérieur du script). L'appel réellement émis est `bash -c "git rev-parse --verify --quiet refs/heads/<argument>…"` (`SKILL.md:19`), non couvert.
- Le README documente encore une autre forme, `Bash(git branch --show-current*)` (`README.fr.md:279`, `:298`) — voir A12.

**Proposition**
- Frontmatter de `skills/forge/SKILL.md` : `allowed-tools: Bash(bash ${CLAUDE_SKILL_DIR}/scripts/*), Read(${CLAUDE_SKILL_DIR}/**)` — la doc skills indique que `${CLAUDE_SKILL_DIR}` est substitué dans les règles `allowed-tools`. Limite : la pré-approbation ne vaut que pour le tour qui invoque le skill (cf. B, risques) ; pour les tours suivants, garder une règle `permissions.allow` installée.
- Ajouter à `status.sh` une option `--target <argument>` qui renvoie `"target_exists": true|false` : la vérification de `SKILL.md:19` disparaît, −1 appel Bash sur `/forge <branche>`.
- Retirer `Bash(bash -c "git branch --show-current*)` des installeurs (purge en `stale` pour l'idempotence).

**Gain** : fluidité majeure hors mode auto · **Coût** S · **Risque** faible (tests `install.test.sh`, `status.test.sh`).

### A2 — Lectures différées à la reprise — P1
**Constats**
- `p5-resume.md:5-7` lit `project.md`, `coding-standards.md` et `brief.md` à chaque reprise, avant même de savoir ce que veut l'utilisateur. Dans ce dépôt : `project.md` 12 Ko, `coding-standards.md` 5,9 Ko.
- Volume d'instructions d'une reprise type (État 5) : `SKILL.md` 17,5 Ko + `p5-resume.md` 21,9 Ko + `project.md` 12 Ko + `coding-standards.md` 5,9 Ko + brief + plan (2-5 Ko) ≈ **62-65 Ko ≈ 17-19 k tokens** avant la première réponse utile. Un `grave` ajoute `commands/engrave.md` 12,7 Ko.
- Une reprise sert souvent à `grave`, à consulter l'avancement ou à clore — aucun de ces parcours n'a besoin des standards de code.

**Proposition** : ne lire `project.md` et `coding-standards.md` qu'au démarrage de la première tâche du tour (déclencheur « Mesure d'une tâche », `p5-resume.md:77`) ou d'une action directe qui modifie du code (`p5-resume.md:180-186`). Le brief reste lu (objectif pour la ligne « Last session »).
**Gain** ≈ 5 k tokens par reprise sans code · **Coût** S · **Risque** faible : une action directe sur du code doit bien déclencher la lecture — à écrire dans « Action directe ».

### A3 — Alléger SKILL.md et p5-resume.md (chargement à la demande) — P1
**Constats** — sections lues à chaque invocation mais rarement utiles :
- `SKILL.md:70-81` (Mail rédigé), `:85-91` (Fichiers de référence), `:127-142` (Mode professeur), `:162-178` (Mise à jour manuelle / du skill).
- `p5-resume.md:89-106` (Script de déploiement SQL), `:127-154` (Propagation vers CLAUDE.md), `:231-242` (Renommage de branche), `:212-227` (Gabarit question Plan, utile seulement hors périmètre).
- Le modèle « commande rare → `commands/` chargée à la demande, déclencheur gardé dans p5 » existe déjà (`.forge/project.md:106`, `p5-resume.md:246-283`) : il suffit de l'étendre.
- Le mode délégué lit aussi tout `SKILL.md` (`SKILL.md:110-114`) alors que `commands/delegated-mode.md` en neutralise une large part (mail, professeur, mise à jour, CLAUDE.md).

**Proposition** : créer `commands/generated-content.md` (Contenu généré + Mail rédigé), `commands/teacher.md`, `commands/deployment-sql.md`, `commands/rule-propagation.md`, `commands/branch-rename.md` ; ne laisser dans SKILL.md/p5 qu'un déclencheur d'une ligne par commande. Cible : SKILL.md < 10 Ko, p5 < 13 Ko.
**Gain** ≈ 12-15 Ko (≈ 4 k tokens) par reprise, délégués d'essaim compris (×N délégués) · **Coût** M · **Risque** moyen : un déclencheur mal recopié fait « oublier » une règle ; à valider par rejeu des parcours.

### A4 — Un appel Bash de moins à la reprise — P2
**Constat** : la ligne `Remaining ≈ …` exige un second appel, `time-calibrate.sh --files <somme>` (`p5-resume.md:50`), après `status.sh` qui a déjà parsé le plan (`status.sh:26-38`).
**Proposition** : `status.sh` renvoie `open_files` (somme des fichiers des tâches ouvertes, via `task-files.sh`) et, en source de `time-calibrate.sh`, `remaining` ({files, minutes, low, high, indicative}) ; même chose pour `tasks[]` avec effort / fichiers / estimé / réel par tâche, de quoi produire le tableau d'avancement sans relire le plan si l'utilisateur ne travaille pas (cf. A2).
**Gain** −1 appel Bash (Git Bash : coût de processus noté `status.sh:5`) et un tour de modèle · **Coût** S · **Risque** faible (tests `status.test.sh`).

### A5 — Double saisie du statut dans le plan — P2
**Constat** : le statut d'une tâche vit sous son titre (`[ ]`/`[x]`, `p4-plan.md:70`) et dans `## Summary` (`p4-plan.md:84-89`, `commands/closure.md:18`). Chaque coche = deux Edit, et `status.sh` ne lit que le premier : le second peut dériver sans que rien ne le voie.
**Proposition** : garder `## Summary` sans colonne `Status` (récapitulatif figé à la validation), ou le supprimer — le tableau d'avancement est déjà produit à la reprise (`p5-resume.md:40-51`).
**Gain** −1 Edit par tâche, une source de vérité · **Coût** S · **Risque** faible (anciens plans lisibles tels quels).

### A6 — Niveau d'information : ligne d'état et suivi — P2
**Constats**
- Ligne d'état minimale : `<branch> · <state> · <done>/<total>` (+ bloquées) (`SKILL.md:194`).
- Rien n'indique, avant un `grave`, s'il reste du travail non commité, si la branche est en avance/retard sur le distant, ni quelle tâche vient ensuite.
- Après chaque coche, aucun format de progression n'est prescrit (`p5-resume.md:57-58`) : l'utilisateur ne voit l'avancement qu'à la reprise suivante.

**Proposition**
- `status.sh` ajoute `dirty` (nombre de fichiers modifiés), `ahead`/`behind` (si amont suivi, via `git rev-list --count` — un seul processus de plus, ou `git status --porcelain=v2 --branch` qui donne les deux d'un coup), `next_task`.
- Ligne d'état : `audit-v0-13 · active · 2/5 · next T3 · ≈ 12 min left · 4 uncommitted · ↑2` ; ticket en lien si `ticket.json`.
- Après chaque coche en mode enchaîné : une ligne `T3 ✓ ≈ 4 min · 3/5 · ≈ 8 min left`.
- Option : statusline Claude Code (`statusLine` dans settings) alimentée par un script de lecture pure — à proposer dans le README, jamais écrite par le skill.

**Gain** information continue sans commande · **Coût** S-M · **Risque** faible.

### A7 — Mise à jour : ne plus interrompre la reprise — P2
**Constat** : `update_available` vrai → `AskUserQuestion` `Update` avant toute reprise (`SKILL.md:190`, `commands/update.md:30-45`) ; l'utilisateur venu travailler doit d'abord trancher.
**Proposition** : une ligne en fin de ligne d'état « forge v0.14.0 available — say "update the forge" » ; question seulement sur le contrôle manuel. Devient sans objet avec le plugin (B).
**Gain** −1 question en tête de session · **Coût** S · **Risque** faible.

### A8 — Découvrabilité et onboarding — P2
**Constats**
- Commandes en langage naturel à retenir : `grave`/`engrave` + branches (`p5-resume.md:277`), « ranger la forge » / « clean the forge » (`SKILL.md:164`), « mettre à jour la forge » (`SKILL.md:174`), « lance l'essaim » (`p5-resume.md:253`), termes de clôture (`p5-resume.md:283`), « lance un agent sur la branche X » (`p5-resume.md:273`). Aucun point d'entrée ne les liste.
- Le rappel de `grave` n'apparaît que lorsqu'il y a du travail à enregistrer (`SKILL.md:123`).
- Premier lancement : exploration p0 puis p1 puis question d'objectif (`phases/p0-project.md:75-80`), sans présentation du cycle.

**Proposition**
- `/forge help` (argument réservé, avant la détection de branche `SKILL.md:17`) : 8 lignes — cycle brief → plan → actif, commandes ci-dessus, fichiers `.forge/`.
- Premier `project.md` écrit : 3 lignes de présentation du cycle + « tape `/forge help` ».
- Avec le plugin : ces commandes deviennent des `/forge:*` auto-complétées (B4).

**Gain** onboarding, moins de mémoire exigée · **Coût** S · **Risque** nul (attention : « help » ne doit pas devenir un nom de branche — à exclure dans « Branche de travail »).

### A9 — Hooks : PreCompact unique et réancrage — P2
**Constats**
- Deux implémentations du même hook : bash (`hooks/bash/forge-precompact.sh`) et PowerShell (`hooks/ps1/forge-precompact.ps1`), choisies par installeur (`install.ps1:92-95`). Or Git Bash est déjà requis sous Windows pour tous les scripts et pour le hook de mesure (`install.ps1:97-100`, `README.fr.md:62`) : la version ps1 ne sert plus et coûte un démarrage `powershell` (lent) à chaque compaction.
- Le hook injecte le plan brut (`forge-precompact.sh:14`) mais ni l'objectif du brief ni les dernières entrées de LOG ; rien n'est réinjecté après `/clear` ou à la reprise d'une session.

**Proposition** : hook bash seul, réutilisant `status.sh` (objectif + tâches ouvertes + 3 dernières entrées LOG, plus court que le plan entier) ; même script branché sur `SessionStart` (matcher `compact|resume`) pour réancrer l'état forge.
**Gain** moins de code à maintenir, meilleure survie de contexte · **Coût** S · **Risque** faible (contrat `hookSpecificOutput` à garder, `.forge/project.md:117`).

### A10 — Mode professeur : coût d'un sous-agent par question — P3
**Constat** : chaque question de compréhension lance un agent de fond qui écrit un fichier d'explication (`SKILL.md:133`, `:142`).
**Proposition** : écrire le fichier sur demande (« garde cette explication ») ou une fois par sujet au `grave`.
**Gain** tokens de sous-agent économisés · **Coût** S · **Risque** faible (perte d'un automatisme apprécié ? à trancher).

### A11 — Estimation des tâches sans fichiers de code — P3
**Constat** : le plan de cette branche estime 5 tâches d'audit à ≈ 1 min chacune (`.forge/branch/audit-v0-13/plan.md`, section Risks le relève) : l'estimation par fichiers (`p4-plan.md:30-34`, `:91`) ne voit pas la lecture.
**Proposition** : surcharge explicite `**Estimated time:** (≈ n min)` qui prime, comme `(≈ n)` prime pour les fichiers ; ou un « poids lecture » (fichiers lus) dans `time-calibrate.sh`.
**Gain** estimations crédibles pour audits, analyses, SQL · **Coût** S · **Risque** faible (tâche exclue du calibrage).

### A12 — Dérive documentation ↔ installeurs — P2
**Constat** : `README.fr.md:271-311` documente `Bash(git branch --show-current*)` et ne mentionne pas les six hooks de mesure dans le bloc JSON ; les installeurs écrivent `Bash(bash -c "git branch --show-current*)` (`install.sh:66`) et les hooks `time-hook.sh` (`install.sh:84-94`).
**Proposition** : aligner (ou générer le bloc depuis l'installeur en test) ; à faire avec A1.
**Coût** S · **Risque** nul.

### Note — hook de mesure global
Le hook `time-hook.sh` est déclaré au niveau utilisateur sur `PostToolUse` `AskUserQuestion|Bash`, `UserPromptSubmit`, `Stop`, `SubagentStart/Stop` (`install.sh:84-94`) : il lance un processus Git Bash à chaque appel Bash de **toutes** les sessions, projets non forgés compris (il sort sans écrire, `time-hook.sh:1-4`). Asynchrone donc sans latence perçue, mais coût CPU permanent. Le plugin activé au niveau projet le résout (B3).

---

## B. Piste plugin Claude Code

### B1 — Format actuel (documentation officielle, lue le 2026-11-22)
- **Manifeste** `.claude-plugin/plugin.json` : seul `name` requis (kebab-case) ; champs utiles ici `version`, `description`, `author`, `repository`, `license`, `keywords`, `engines` (`{"claude-code": "<plage>"}`), `skills`, `agents`, `hooks`, `mcpServers`, `userConfig`, `dependencies`. **Aucune clé `permissions`** : un plugin ne peut pas déclarer de règles `allow`. Validation : `claude plugin validate <dir> --strict`.
- **Arborescence par défaut** : `skills/<nom>/SKILL.md`, `commands/*.md` (hérité, fusionné dans les skills), `agents/*.md`, `hooks/hooks.json`, `.mcp.json`, `bin/` (ajouté au PATH de l'outil Bash tant que le plugin est actif). Chemins en `./`, jamais `..` ni lien hors du dossier : le plugin est **copié dans un cache** et ne voit rien hors de son dossier.
- **Nommage** : skills et commandes en `/<plugin>:<skill>` ; le `/skill` nu reste utilisable s'il n'y a pas de conflit. Agents en `<plugin>:<nom>`.
- **Variables** : `${CLAUDE_PLUGIN_ROOT}` (dossier de la version installée, change à chaque mise à jour), `${CLAUDE_PLUGIN_DATA}` (`~/.claude/plugins/data/<id>/`, persistant entre versions), `${CLAUDE_PROJECT_DIR}`. Substituées dans les commandes de hooks, les serveurs MCP stdio et **le corps Markdown des skills/commandes/agents** ; `${CLAUDE_SKILL_DIR}` substitué dans le corps d'un skill et dans ses règles `allowed-tools`. **Absentes de l'environnement des commandes Bash** lancées par Claude.
- **Pré-approbation** : `allowed-tools` du frontmatter d'un skill — « outils pré-approuvés pendant le tour qui invoque le skill », pas au-delà.
- **Hooks** : `hooks/hooks.json` au même format que `settings.json` (`{"hooks": {...}}`), événements `PreCompact`, `SessionStart`, `UserPromptSubmit`, `Stop`, `SubagentStart/Stop`, `PreToolUse`, `PostToolUse`… ; sous Windows, Git Bash s'il est présent, sinon PowerShell, forçable par `"shell": "bash"`. Les hooks de plugin tournent hors bac à sable avec les droits de l'utilisateur (comme aujourd'hui).
- **Agents de plugin** : frontmatter `name`, `description`, `model`, `effort`, `maxTurns`, `tools`, `disallowedTools`, `skills`, `background`, `isolation`, `omitClaudeMd`… ; `hooks`, `mcpServers`, `permissionMode` **ignorés**.
- **Marketplace** `.claude-plugin/marketplace.json` : `name`, `owner`, `plugins[]` (`name`, `source` : chemin relatif `"./"`, `github`, `url` git avec `ref`/`sha`, `git-subdir`…). Installation : `/plugin marketplace add jeanchristoph/claude_forge` puis `/plugin install forge@claude-forge` (ou `claude plugin install … --scope user|project|local`). Équipe : `extraKnownMarketplaces` + `enabledPlugins` dans `.claude/settings.json` du projet.
- **Mises à jour** : version = `version` du manifeste, sinon SHA git ; cache `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. **Mise à jour automatique désactivée par défaut pour les marketplaces tierces** (activable par marketplace via `/plugin` ou `autoUpdate`) ; manuelle par `claude plugin update forge@claude-forge` / `/plugin marketplace update`.
- **MCP** : `.mcp.json` du plugin, outils `mcp__plugin_<plugin>_<server>__<outil>`.

### B2 — Comparaison avec le mécanisme actuel

| Besoin | Aujourd'hui | En plugin |
|---|---|---|
| Déploiement | `install-windows.bat` → `install.ps1` (122 l.), `install-unix.sh` → `install.sh` (100 l.) : copie vers `~/.claude/skills/`, `~/.claude/hooks/forge/` | `/plugin install` ; copie en cache gérée par Claude Code |
| Hooks | Fusion idempotente dans `~/.claude/settings.json` (`install.sh:71-94`), PreCompact ps1 ou bash selon OS | `hooks/hooks.json` du plugin, actif seulement si le plugin l'est ; retrait propre à la désinstallation |
| Permissions | Règles `Read(~/.claude/skills/forge/**)`, `Read/Edit(/.forge/**)` écrites dans settings (`install.sh:59-69`) | Impossible par le manifeste → `allowed-tools` (tour d'invocation) + règles documentées à ajouter une fois |
| Version / mise à jour | `install.json` + `update.sh` (301 l. : tag distant toutes les 24 h, clone, réinstalle) + `commands/update.md` + question au démarrage | `version` du manifeste ; mise à jour native (auto si activée) ; `/plugin` liste les mises à jour |
| Chemin des scripts | `SKILL_DIR` = « Base directory for this skill » (`SKILL.md:43`) ; hook en dur `~/.claude/skills/forge/scripts/time-hook.sh` (`install.sh:84`) | `${CLAUDE_SKILL_DIR}` / `${CLAUDE_PLUGIN_ROOT}` substitués |
| Portée | Utilisateur uniquement, hooks globaux à toutes les sessions | `user`, `project` (partagé en git) ou `local` |
| Commandes | `/forge`, `/forge-clickup` + mots-clés en langage naturel | `/forge`, plus `/forge:grave`, `/forge:status`… auto-complétées |
| Délégués | Sous-agent « type général » + prompt figé (`commands/swarm.md:39-58`, `delegation.md:95`) | Agent `forge:delegate` déclaré, modèle/outils/`maxTurns` maîtrisés |
| Tests | `install.test.sh`, `update.test.sh` | `claude plugin validate --strict` en test |

### B3 — Arborescence cible

```
claude_forge/
├── .claude-plugin/
│   ├── plugin.json            name "forge", version "0.14.0", engines, repository, license MIT
│   └── marketplace.json       name "claude-forge", owner, plugins: [{ name "forge", source "./" }]
├── skills/
│   ├── forge/                 SKILL.md, phases/, commands/ (procédures internes, inchangées), references/, scripts/
│   ├── forge-clickup/SKILL.md
│   ├── grave/SKILL.md         /forge:grave [branches…]   (disable-model-invocation: true, argument-hint)
│   ├── status/SKILL.md        /forge:status              (lecture seule : status.sh + tableau, aucune question)
│   ├── help/SKILL.md          /forge:help
│   ├── tidy/SKILL.md          /forge:tidy  (= « ranger la forge », phases/p0-project.md)
│   └── swarm/SKILL.md         /forge:swarm (lancer / relancer / reprendre l'essaim)
├── agents/
│   └── delegate.md            agent forge:delegate (délégué étanche, essaim / branche / projet lié)
├── hooks/
│   ├── hooks.json             PreCompact + SessionStart(compact|resume) + 6 événements de mesure, "shell": "bash"
│   └── forge-precompact.sh
├── tests/                     + plugin-manifest.test.sh (claude plugin validate --strict)
├── README.md / README.fr.md / CHANGELOG.md / LICENSE / docs/
```

`hooks/hooks.json` (extrait) :
```json
{ "hooks": {
  "PreCompact":  [{ "hooks": [{ "type": "command", "shell": "bash",
                   "command": "bash \"${CLAUDE_PLUGIN_ROOT}/hooks/forge-precompact.sh\"" }] }],
  "PostToolUse": [{ "matcher": "AskUserQuestion|Bash", "hooks": [{ "type": "command", "shell": "bash", "async": true,
                   "command": "bash \"${CLAUDE_PLUGIN_ROOT}/skills/forge/scripts/time-hook.sh\"" }] }]
} }
```

Note : `skills/forge/commands/` est interne au skill, pas le dossier `commands/` racine du plugin — aucun conflit, mais le renommer `procedures/` éviterait la confusion de vocabulaire.

### B4 — Commandes slash utiles
- **`/forge:grave [branches…]`** — remplace la mémorisation de `grave`/`engrave` ; corps : `status.sh` puis « Livraison » (`commands/engrave.md`). `disable-model-invocation: true` (jamais déclenché par le modèle : c'est l'autorisation de livrer). Le mot-clé `grave` reste reconnu.
- **`/forge:status`** — ligne d'état + tableau d'avancement + essaim, lecture seule, aucune question (consultation sans charger p5 complet ni les standards).
- **`/forge:help`** — A8.
- **`/forge:tidy`** — « ranger la forge ».
- **`/forge:swarm`** — lancement/reprise de l'essaim.
- **`/forge:close`** — clôture (`commands/closure.md`) ; optionnel, les termes de clôture restent.
- Disparaît : « mettre à jour la forge » (`SKILL.md:172-178`) → `/plugin`.

### B5 — Sous-agent dédié : `agents/delegate.md`
- `name: delegate`, `description` : délégué forge étanche ; `skills: [forge]` (préchargé), `background: true`, `maxTurns` borné, `tools` complets sauf `AskUserQuestion` en `disallowedTools` (l'invariant « jamais d'AskUserQuestion » de `delegated-mode.md` devient une contrainte technique, plus une consigne).
- Corps de l'agent = règles communes de `commands/delegated-mode.md` : le prompt figé (`commands/swarm.md:41-56`) se réduit aux lignes de valeurs (`ROOT`, `BRANCH`, `SCOPE`, `TIME_LOG`, `SWARM`, `PORT`, `RESUME`).
- Lancement : `subagent_type: "forge:delegate"` dans `swarm.md` et `delegation.md`.
- **Ne pas** utiliser `isolation: worktree` : forge crée et nomme lui-même ses worktrees (`swarm.md:22-27`).
- `model` : laisser hériter par défaut ; option `userConfig` « modèle des délégués » pour les essaims coûteux.
- Gain : délégués moins verbeux à briefer, invariant appliqué par l'outil, choix de modèle possible.

### B6 — Ce qui disparaît / reste
**Disparaît** : `install/install.ps1`, `install/install.sh`, `install-windows.bat`, `install-unix.sh`, `install.json`, `skills/forge/scripts/update.sh`, `commands/update.md`, `tests/install.test.sh`, `tests/update.test.sh`, `hooks/ps1/`, sections `SKILL.md:162-178` (mise à jour) et `:187`, `:190` (contrôle au démarrage), `p0-project.md:82-87` (« Contrôle — hook de mesure » : le hook vient avec le plugin). Environ 650 lignes de code et de tests en moins.
**Reste** : toute la machine à états, les scripts bash (dont `status.sh`, `engrave.sh`, `time-*.sh`), `checks.sh`, les tests des scripts, le hook PreCompact (bash), `forge-clickup` (le connecteur MCP ClickUp reste un OAuth claude.ai, non embarquable).
**Reste à documenter** : les règles de permission (B7, risque 2) et l'activation de la mise à jour automatique.

### B7 — Risques
1. **Doublons à la transition (élevé)** : un utilisateur qui installe le plugin sans retirer l'ancienne installation aura deux hooks de mesure (deux lignes par événement dans `time-log.jsonl` → durées faussées) et deux PreCompact, plus deux skills `forge`. Parade : dernière version des installeurs en mode « désinstallation » (retire `~/.claude/skills/forge*`, `~/.claude/hooks/forge/`, entrées `forge-precompact` / `time-hook.sh` de settings — la logique de purge existe déjà, `install.sh:75-93`) ; `status.sh` signale `legacy_install: true` si `~/.claude/skills/forge` existe alors que le skill tourne depuis le cache plugin.
2. **Permissions par tour** : `allowed-tools` ne couvre que le tour d'invocation ; les tours suivants (« ok », `grave` en langage naturel, cochage) redemandent la permission pour `bash …/scripts/*.sh` et la lecture des phases dans `~/.claude/plugins/cache/...` (hors dossier projet). Parade : README avec le bloc à ajouter une fois (`Read(~/.claude/plugins/cache/claude-forge/forge/**)`, `Bash(bash *forge/skills/forge/scripts/*)`) ; les `/forge:*` réinvoquent un skill et rouvrent la pré-approbation ; mode auto inchangé.
3. **`SKILL_DIR` et chemins Windows** : `${CLAUDE_SKILL_DIR}` n'est substitué que dans le corps du skill, pas dans `phases/` ni `commands/` lus ensuite → poser `SKILL_DIR = ${CLAUDE_SKILL_DIR}` une fois dans SKILL.md, garder `<SKILL_DIR>` ailleurs. Sous Windows la valeur peut contenir des `\` et des espaces (profil utilisateur) : chaque appel `bash "<SKILL_DIR>/scripts/…"` doit être cité et passé en barres obliques ; à couvrir par un test sur un chemin avec espace (le dépôt lui-même en contient : `claude skills`).
4. **Git Bash obligatoire** : sans Git Bash, les hooks basculent en PowerShell et `bash …` échoue → forcer `"shell": "bash"` et documenter le prérequis (déjà requis aujourd'hui, `README.fr.md:62`). `engines` pour exiger une version de Claude Code récente.
5. **Mises à jour non automatiques par défaut** (marketplace tierce) : les utilisateurs restent sur l'ancienne version sans le savoir — l'actuelle proposition au démarrage disparaît. Parade : README « activer la mise à jour auto » ; option : `status.sh` compare `version` du manifeste à un tag distant (réutilise la logique de contrôle détaché de `update.sh` sans la partie installation).
6. **Version** : sans `version` dans `plugin.json`, chaque commit de la branche par défaut est une nouvelle version → toujours renseigner `version` au commit « Prépare la version » (y ajouter un test de cohérence tag ↔ manifeste).
7. **Nommage** : plugin `forge` + skill `forge` → `/forge:forge` dans la liste ; `/forge` nu reste valable tant qu'aucun autre plugin ne le revendique.
8. **Délégués en mode projet lié** : le délégué d'un projet lié travaille dans un autre dépôt ; si le plugin est installé en portée `project`, il n'y est peut-être pas actif → recommander la portée `user` pour forge, ou vérifier l'activation avant de déléguer.

### B8 — Étapes de migration
1. **v0.14.0 — double voie** : ajouter `.claude-plugin/plugin.json`, `marketplace.json` (`source: "./"`), `hooks/hooks.json` ; `SKILL_DIR` via `${CLAUDE_SKILL_DIR}` (fonctionne aussi hors plugin) ; `time-hook.sh` référencé par `${CLAUDE_PLUGIN_ROOT}` ; test `claude plugin validate . --strict`. Installeurs conservés, avec option `--uninstall` et détection du plugin (refus de réinstaller par-dessus).
2. **v0.14.x** : agent `forge:delegate`, skills `/forge:grave`, `/forge:status`, `/forge:help` ; `swarm.md`/`delegation.md` passent `subagent_type: "forge:delegate"`.
3. **Dernière version de `update.sh`** : à la proposition de mise à jour, annoncer la migration (« installe le plugin : `/plugin marketplace add jeanchristoph/claude_forge` puis `/plugin install forge@claude-forge`, puis lance `install-windows.bat --uninstall` »).
4. **v0.15.0** : retrait des installeurs, `update.sh`, `commands/update.md`, `hooks/ps1/`, tests associés ; README FR/EN réécrits (installation, permissions à ajouter, mise à jour auto), CHANGELOG.
5. Rejeu des parcours sous Windows (Git Bash) et Unix : `/forge` neuf, reprise, `grave`, essaim à 2 branches, compaction.

### B9 — Piste ultérieure : serveur MCP local (P3, L)
Un serveur MCP stdio en Node embarqué (`.mcp.json`, `${CLAUDE_PLUGIN_ROOT}`) exposant `forge_status`, `forge_mark_task`, `forge_engrave` remplacerait les appels `bash script.sh` : un seul processus vivant au lieu d'un processus Git Bash par appel, outils typés, pré-approuvables par nom (`mcp__plugin_forge_state__*`). Coût élevé (réécriture des scripts et de leurs tests), à n'envisager que si la latence Git Bash reste le premier irritant après A1-A4.

### Recommandation
Faire A1, A2, A3, A12 tout de suite (gains immédiats, coût S-M, indépendants du plugin). Engager la migration plugin en deux versions (B8) : elle supprime la partie la plus fragile du dépôt (fusion de `settings.json` en deux langages, mise à jour maison) et apporte découvrabilité et agent délégué ; son seul vrai point dur est la transition (doublons de hooks) et les permissions par tour, tous deux parables.

---

## Sources consultées
- https://code.claude.com/docs/en/plugins
- https://code.claude.com/docs/en/plugins/manifest-reference (servie via /plugins-reference)
- https://code.claude.com/docs/en/plugins/components
- https://code.claude.com/docs/en/plugins/create-marketplace (servie via /plugin-marketplaces)
- https://code.claude.com/docs/en/plugins/marketplace-reference
- https://code.claude.com/docs/en/plugins/loading
- https://code.claude.com/docs/en/plugins/security
- https://code.claude.com/docs/en/plugins/cli-reference
- https://code.claude.com/docs/en/hooks
- https://code.claude.com/docs/en/skills
- https://code.claude.com/docs/en/sub-agents
