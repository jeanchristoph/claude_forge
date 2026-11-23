# Délégation

## Mesure d'un délégué

**Déclencheur :** lancement d'un sous-agent forge délégué — projet lié, branche du même dépôt, branche fille d'essaim (`commands/swarm.md`) — puis chacun de ses retours. Projet courant ou projet externe : même mesure.

**Réaction :**
- `<DELEGATED_BRANCH>` = branche du délégué : `<LINKED_BRANCH>` pour un projet lié, `<X>` sinon. `<TIME_LOG>` = `.forge/branch/<BRANCH>/time-log.jsonl` sous ROOT, journal de la branche parente.
- Prompt : ligne `TIME_LOG: <chemin absolu de <TIME_LOG>>` juste sous `SCOPE:` — le délégué y écrit ses marques de tâche (`commands/delegated-mode.md`) — chemin absolu permis dans le prompt seulement (invariant de « Délégation — projet lié »).
- Lancement : `bash <SKILL_DIR>/scripts/time-mark.sh --time-log <chemin absolu de <TIME_LOG>> --event delegate --agent-id <identifiant> --branch <DELEGATED_BRANCH>` — identifiant tiré du retour de l'outil `Agent`.
- Chaque retour : `bash <SKILL_DIR>/scripts/time-mark.sh --time-log <chemin absolu de <TIME_LOG>> --event delegate_usage --agent-id <identifiant> --tokens <subagent_tokens de la notification>`.
- **INVARIANT :** ces lignes s'écrivent par `time-mark.sh`, jamais à la main — le script garde le format que lit `time-aggregate.sh`.
- Synthèse et mesure par tâche de `<DELEGATED_BRANCH>` → `time-aggregate.sh --root <worktree du délégué> --branch <DELEGATED_BRANCH> --parent-log <chemin absolu de <TIME_LOG>>`, le journal parent pouvant vivre dans un autre dépôt.

⚠️ `<TIME_LOG>` absent (hook de mesure non installé) → `time-mark.sh` n'écrit rien, ligne `TIME_LOG:` gardée dans le prompt : les marques du délégué n'écrivent alors rien non plus.

## Délégation — projet lié

**Vocabulaire :** projet *parent* = ROOT de la session · projet *lié* = `<LINKED>`, chemin absolu du dossier visé · *mandat* = les tâches parentes déléguées · *branche liée* = `<LINKED_BRANCH>`, lue dans le champ `**Linked branch:** <LINKED_REL> @ <LINKED_BRANCH>` des tâches du mandat, jamais recalculée quand il est présent · `<LINKED_WORKTREE>` = chemin absolu du worktree de `<LINKED_BRANCH>`, rangé à côté de `<LINKED>` : `<LINKED>.worktrees/<LINKED_BRANCH>` (`../my-api.worktrees/export-csv` depuis ROOT). · `<LINKED_REL>` = chemin de `<LINKED>` relatif à ROOT (`../my-api`).

**Nommage de la branche liée :** règle de l'étape 3 de la « Garde de sécurité » de `SKILL.md`, l'objectif étant le titre de la tâche déléguée, ou l'objet commun des tâches qui partagent la branche ; collision vérifiée dans `<LINKED>` (`git -C "<LINKED>" show-ref --verify --quiet refs/heads/<slug>`). Nom écrit dans `**Linked branch:**` dès l'entrée de la tâche au plan (« Branche liée » de `phases/p4-plan.md`) ; tâche sans ce champ → nom calculé ici, écrit à l'action `mark`. Tâches au même champ → même branche, même worktree (`reuse`).

**INVARIANT :** jamais de chemin absolu dans un fichier écrit — brief, log, plan : le projet lié s'y nomme `<LINKED_REL>`. Un chemin absolu ne vit que dans les commandes et le prompt du sous-agent.

**INVARIANT :** le projet lié ne nomme jamais le parent — ni dossier, ni branche, ni ticket, ni client, ni donnée du parent dans la branche liée : nom de branche, brief, plan, log, code, CHANGELOG, commits. Le projet lié peut être public quand le parent est privé. Exception : une référence nécessaire pour exécuter la tâche (son but, un identifiant cité) est gardée, limitée au strict nécessaire et écrite dans la tâche elle-même — jamais le brief parent recopié.

**INVARIANT :** le working tree de `<LINKED>` n'est jamais touché — ni checkout, ni écriture : le projet lié se travaille dans `<LINKED_WORKTREE>`, l'utilisateur garde `<LINKED>` pour lui. Le parent n'écrit dans `<LINKED_WORKTREE>` que `.forge/branch/<LINKED_BRANCH>/brief.md` et `.forge/branch/<LINKED_BRANCH>/log.md` — jamais de code, jamais de plan. Le parent ne lit jamais le code du projet lié.

Demande hors plan qui vise le projet lié → d'abord « Demande hors périmètre » de `p5-resume.md` (tâche ajoutée au plan parent), puis cette délégation. Jamais de worktree créé ni de code écrit par le parent à la place, même pour une petite modification. Le hook `linked-write-guard.sh` refuse toute écriture de la session parente hors de ROOT dans un projet forgé, sauf ce `brief.md` et ce `log.md`.

⚠️ Aucune écriture, aucune commande git avant la confirmation de l'étape 6.

**Réaction — dans l'ordre :**
1. `<LINKED>/.forge/` absent → "`<LINKED>` is not forged — run `/forge` there first." STOP — ne pas continuer. Jamais d'initialisation à la place de l'utilisateur.
2. `<BRANCH>` est un nom de code hors git → "Delegation needs a real branch — create one first." STOP — ne pas continuer.
3. Constituer le mandat : tâches citées dans la demande → elles seules ; aucune citée → poser le choix avec `AskUserQuestion` en multi-sélection — `header` : `Delegate`, une option par tâche `[ ]` du plan (label `T<n> — titre`, description = son effort), quatre par question, enchaînées si besoin. Mandat vide → "Nothing to delegate." STOP — ne pas continuer.
   - `<LINKED_BRANCH>` = champ `**Linked branch:**` des tâches du mandat ; aucun champ → « Nommage de la branche liée » ci-dessus. Tâches du mandat à branches liées différentes → "T3 and T5 carry different linked branches — delegate them separately." STOP — ne pas continuer.
4. Retenir l'action de worktree, première condition remplie :
   - `git -C <LINKED> worktree list --porcelain` : un worktree porte `branch refs/heads/<LINKED_BRANCH>` → `<LINKED_WORKTREE>` = son chemin, action `reuse`. Ce worktree est `<LINKED>` lui-même → "`<LINKED_BRANCH>` is checked out in `<LINKED>` — switch that folder to another branch first." STOP — ne pas continuer.
   - `git -C "<LINKED>" rev-parse --verify --quiet refs/heads/<LINKED_BRANCH>` réussit → action `create from <LINKED_BRANCH>` : `git -C "<LINKED>" worktree add "<LINKED_WORKTREE>" <LINKED_BRANCH>`.
   - Sinon → action `create <LINKED_BRANCH> from <base>` : branche par défaut détectée comme dans « Branche de travail » de `SKILL.md` ; branche distante suivie → `git -C <LINKED> fetch`, `<base>` = `origin/<défaut>`, sinon `<base>` = `<défaut>` ; commande `git -C <LINKED> worktree add --no-track -b <LINKED_BRANCH> <LINKED_WORKTREE> <base>`.
   - Action `create` et `.forge/project.md` absent du commit de départ (`git -C <LINKED> cat-file -e <départ>:.forge/project.md`) → "`.forge/` of `<LINKED>` is not committed — commit it first." STOP — ne pas continuer. Le worktree ne porte que les fichiers versionnés.
5. Afficher le tableau de délégation (format ci-dessous).
6. Poser une confirmation unique avec `AskUserQuestion` — `header` : `Delegate`, options `Open the linked project` / `Cancel`.
7. **Sur `Cancel`** → n'exécuter aucune action. STOP — ne pas continuer.
8. **Sur `Open the linked project`** → dans l'ordre :
   - Exécuter l'action de worktree retenue à l'étape 4 (`reuse` → rien). Échec → afficher l'erreur telle quelle, STOP.
   - Écrire `<LINKED_WORKTREE>/.forge/branch/<LINKED_BRANCH>/brief.md` — format du mandat ci-dessous. Fichier déjà présent → le remplacer : le mandat parent fait foi.
   - Entrée LOG de la branche liée, `--root <LINKED_WORKTREE> --branch <LINKED_BRANCH>` (`log.md` créé s'il est absent) : `Opened by delegation · T3, T5`.
   - PLAN parent : chaque tâche du mandat sans `**Linked branch:**` → champ écrit sous `**Files:**` ; sous chaque tâche du mandat, note `delegated to <LINKED_REL> @ <LINKED_BRANCH>` — statut inchangé. Entrée LOG parent : `Delegated T3, T5 to <LINKED_REL> @ <LINKED_BRANCH>`.
   - Lancer le sous-agent (prompt ci-dessous), « Mesure d'un délégué » ci-dessus appliquée, puis entrer dans la boucle de relais.

### Boucle de relais

À chaque rapport du sous-agent :
- Rapport contenant `FORGE_QUESTION` → afficher `content` **intégralement** à l'utilisateur, tel quel, jamais résumé (`none` → rien à afficher), puis poser la question avec `AskUserQuestion`, `header` et options recopiés tels quels ; `header` `Plan` → `content` recopié en tête de `question` selon le « Gabarit — question `Plan` » ; `options: none` → question en texte libre. Renvoyer la réponse au même sous-agent par `SendMessage`, message `FORGE_ANSWER: <réponse>`. Reprendre la boucle.
- Rapport contenant `FORGE_DONE` → sortir de la boucle, appliquer le retour ci-dessous.
- Rapport sans aucun des deux blocs → le renvoyer au sous-agent par `SendMessage` : `FORGE_ANSWER: end your turn with a FORGE_QUESTION or a FORGE_DONE block.` Deux rappels au maximum, puis marquer chaque tâche du mandat `[!] blocked — delegated run ended without report` et sortir.

⚠️ Jamais de réponse inventée à la place de l'utilisateur — chaque `FORGE_QUESTION` lui est posée.

### Retour — application de `FORGE_DONE`

Pour chaque tâche parente du mandat, dans l'ordre du plan :
- Toutes ses tâches enfant dans `done` → cocher `[x]`, note `delegated to <LINKED_REL> @ <LINKED_BRANCH> · done` ; `**Actual time:**` tiré de `time-aggregate.sh --root <LINKED_WORKTREE> --branch <LINKED_BRANCH> --parent-log <chemin absolu de <TIME_LOG>> --task <tâches enfant, séparées par des virgules>` (somme ; un enfant non mesuré → `measured` faux), écrit comme à la coche (« Mesure d'une tâche » de `phases/p5-resume.md`, étape 3).
- Au moins une dans `blocked` → marquer `[!] blocked — <raison de la première> · delegated to <LINKED_REL> @ <LINKED_BRANCH>`.
- Absente de `done` et de `blocked` → marquer `[!] blocked — not addressed by the delegated run · delegated to <LINKED_REL> @ <LINKED_BRANCH>`.

⚠️ La note conserve toujours `delegated to <LINKED_REL> @ <LINKED_BRANCH>` : la livraison relayée s'appuie dessus pour retrouver le projet lié et sa branche.
- Une entrée LOG parent par tâche : `T3 delegated to <LINKED_REL> — done` / `— blocked: <raison>`.

`out_of_mandate` non vide → présenter chaque besoin à l'utilisateur, puis appliquer la « Surveillance des demandes complémentaires » de `phases/p5-resume.md` à chacun. Rendre compte : tâches vertes, tâches bloquées avec leur raison, fichiers touchés dans `<LINKED_WORKTREE>`, puis rappeler : "`git -C "<LINKED>" worktree remove "<LINKED_WORKTREE>"` once the linked branch is engraved." Le worktree reste en place.

⚠️ `<LINKED_WORKTREE>` ne porte que les fichiers versionnés : ni dépendances installées (`node_modules`, `vendor`), ni `.env`, ni configuration locale. Une tâche déléguée qui les exige → le sous-agent la remonte `blocked` avec sa raison.

⚠️ Le parent ne coche jamais une tâche déléguée de lui-même — seul `FORGE_DONE` fait foi.

### Format du mandat — `brief.md` du projet lié

`## Origin` porte les seules tâches déléguées — marqueur du mode délégué. Libellés en anglais, tels quels ; `**Effort:**`, `**Files:**` et `**Description:**` des tâches recopiés intégralement depuis PLAN parent, sans reformulation : elles sont rédigées sans référence au parent (« Branche liée » de `phases/p4-plan.md`). Jamais le brief parent, jamais `**Linked branch:**`. `## Objective` et `## Scope & rules` rédigés à partir des seules tâches déléguées (invariant ci-dessus).

```markdown
## Origin
**Tasks:** T3, T5

### Delegated tasks

#### T3 — [Titre parent]
**Effort:** [effort parent]
**Files:** [fichiers parent]
**Description:** [description parent, intégrale]

## Objective
[objectif des tâches déléguées, en 1 phrase]

## Scope & rules
- [règle nécessaire aux tâches déléguées]
```

### Prompt du sous-agent

Un sous-agent, type général, lancé en tâche de fond. Prompt figé — rien d'autre n'est transmis :

```
FORGE_DELEGATED
ROOT: <LINKED_WORKTREE>
BRANCH: <LINKED_BRANCH>
LANGUAGE: <langue de l'utilisateur>
SCOPE: linked
TIME_LOG: <chemin absolu de <TIME_LOG>>
Invoke the `forge` skill with argument `<LINKED_BRANCH>`. Resolve every path and every git command under ROOT.
Delegated mode applies (section « Mode délégué » of the skill): never call AskUserQuestion.
Write every file content and every report in LANGUAGE; structure labels stay in English.
End every turn with a FORGE_QUESTION or a FORGE_DONE block.
```

### Format du tableau de délégation

Une ligne par action prévue, dans l'ordre d'exécution. Trois colonnes, en-têtes générés dans la langue de l'utilisateur : numéro d'ordre, action, détail.

Actions et détail associé — aucune autre :
- `worktree` → `<LINKED_WORKTREE>` : `reuse`, `create from <LINKED_BRANCH>` ou `create <LINKED_BRANCH> from <base>`
- `brief` → `<LINKED_WORKTREE>/.forge/branch/<LINKED_BRANCH>/brief.md` : mandat `T3, T5`
- `log` → `<LINKED_WORKTREE>/.forge/branch/<LINKED_BRANCH>/log.md`
- `mark` → tâches parentes annotées, une ligne
- `agent` → sous-agent délégué, une ligne

⚠️ Jamais de liste de fichiers du projet lié, jamais de décompte de lignes.

---

## Délégation — branche du même dépôt

**Vocabulaire :** `<X>` = branche visée · `<WORKTREE>` = chemin absolu du worktree de `<X>`, rangé à côté du dépôt : `<dossier-du-dépôt>.worktrees/<X>`, chaque `/` de la branche gardé comme sous-dossier (`../forge.worktrees/feature/x` depuis ROOT).

**INVARIANT :** aucun mandat — le parent n'écrit rien dans `<WORKTREE>`, ni brief, ni log, ni plan ; il ne lit jamais son code. Le sous-agent y exécute le skill comme sur toute branche.

⚠️ Aucune commande git avant la confirmation de l'étape 5.

**Réaction — dans l'ordre :**
1. `<X>` = `<BRANCH>` → "Already on `<X>`." STOP — ne pas continuer.
2. `git rev-parse --verify --quiet refs/heads/<X>` échoue → "Branch `<X>` does not exist — create it first." STOP — ne pas continuer. Jamais de création à la place de l'utilisateur.
3. `git worktree list --porcelain` : un worktree porte `branch refs/heads/<X>` → `<WORKTREE>` = son chemin, action `reuse` ; sinon action `create` : `git worktree add "<WORKTREE>" <X>`.
4. Afficher le tableau de délégation (format ci-dessous).
5. Poser une confirmation unique avec `AskUserQuestion` — `header` : `Delegate`, options `Open the branch` / `Cancel`.
6. **Sur `Cancel`** → n'exécuter aucune action. STOP — ne pas continuer.
7. **Sur `Open the branch`** → dans l'ordre :
   - Action `create` → exécuter `git worktree add`. Échec → afficher l'erreur telle quelle, STOP.
   - Lancer le sous-agent (prompt ci-dessous), « Mesure d'un délégué » appliquée, puis entrer dans la « Boucle de relais » de la délégation vers un projet lié — identique.

### Retour — `FORGE_DONE` en `SCOPE: branch`

Aucune écriture dans PLAN ni LOG parent : il n'y a pas de mandat. Rendre compte en une ligne — tâches `done`, tâches `blocked` avec leur raison — puis rappeler : "`git worktree remove "<WORKTREE>"` once the branch is engraved." Le worktree reste en place.

### Prompt du sous-agent

Un sous-agent, type général, lancé en tâche de fond. Prompt figé — rien d'autre n'est transmis :

```
FORGE_DELEGATED
ROOT: <WORKTREE>
BRANCH: <X>
LANGUAGE: <langue de l'utilisateur>
SCOPE: branch
TIME_LOG: <chemin absolu de <TIME_LOG>>
Invoke the `forge` skill with argument `<X>`. Resolve every path and every git command under ROOT.
Delegated mode applies (section « Mode délégué » of the skill): never call AskUserQuestion.
Write every file content and every report in LANGUAGE; structure labels stay in English.
End every turn with a FORGE_QUESTION or a FORGE_DONE block.
```

### Format du tableau de délégation

Une ligne par action prévue, dans l'ordre d'exécution. Trois colonnes, en-têtes générés dans la langue de l'utilisateur : numéro d'ordre, action, détail.

Actions et détail associé — aucune autre :
- `branch` → `<X>`
- `worktree` → `<WORKTREE>` : `reuse` ou `create`
- `agent` → sous-agent délégué, une ligne

⚠️ Jamais de liste de fichiers, jamais de décompte de lignes.
