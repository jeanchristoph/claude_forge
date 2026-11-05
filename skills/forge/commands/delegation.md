# Délégation

## Délégation — projet lié

**Vocabulaire :** projet *parent* = ROOT de la session · projet *lié* = `<LINKED>`, chemin absolu du dossier visé · *mandat* = les tâches parentes déléguées · *branche liée* = `<LINKED_BRANCH>` = `<PARENT>/<BRANCH>`, `<PARENT>` étant le nom du dossier ROOT (`forge/linked-project`, `forge/CU-123`) — jamais le nom nu de `<BRANCH>` : le préfixe dit d'où vient la délégation, la partie droite reste identique pour la correspondance. · `<LINKED_WORKTREE>` = chemin absolu du worktree de `<LINKED_BRANCH>`, rangé à côté de `<LINKED>` : `<LINKED>.worktrees/<LINKED_BRANCH>`, chaque `/` de la branche gardé comme sous-dossier (`D:/www/topdon_api.worktrees/forge/CU-123`).

**INVARIANT :** le working tree de `<LINKED>` n'est jamais touché — ni checkout, ni écriture : le projet lié se travaille dans `<LINKED_WORKTREE>`, l'utilisateur garde `<LINKED>` pour lui. Le parent n'écrit dans `<LINKED_WORKTREE>` que `.forge/branch/<LINKED_BRANCH>/brief.md` et `.forge/branch/<LINKED_BRANCH>/log.md` — jamais de code, jamais de plan. Le parent ne lit jamais le code du projet lié.

⚠️ Aucune écriture, aucune commande git avant la confirmation de l'étape 6.

**Réaction — dans l'ordre :**
1. `<LINKED>/.forge/` absent → "`<LINKED>` is not forged — run `/forge` there first." STOP — ne pas continuer. Jamais d'initialisation à la place de l'utilisateur.
2. `<BRANCH>` est un nom de code hors git → "Delegation needs a real branch — create one first." STOP — ne pas continuer.
3. Constituer le mandat : tâches citées dans la demande → elles seules ; aucune citée → poser le choix avec `AskUserQuestion` en multi-sélection — `header` : `Delegate`, une option par tâche `[ ]` du plan (label `T<n> — titre`, description = son effort), quatre par question, enchaînées si besoin. Mandat vide → "Nothing to delegate." STOP — ne pas continuer.
4. Retenir l'action de worktree, première condition remplie — jamais `<BRANCH>` nue dans `<LINKED>` :
   - `git -C <LINKED> worktree list --porcelain` : un worktree porte `branch refs/heads/<LINKED_BRANCH>` → `<LINKED_WORKTREE>` = son chemin, action `reuse`. Ce worktree est `<LINKED>` lui-même → "`<LINKED_BRANCH>` is checked out in `<LINKED>` — switch that folder to another branch first." STOP — ne pas continuer.
   - `git -C <LINKED> rev-parse --verify --quiet refs/heads/<LINKED_BRANCH>` réussit → action `create from <LINKED_BRANCH>` : `git -C <LINKED> worktree add <LINKED_WORKTREE> <LINKED_BRANCH>`.
   - Sinon → action `create <LINKED_BRANCH> from <base>` : branche par défaut détectée comme dans « Branche de travail » de `SKILL.md` ; branche distante suivie → `git -C <LINKED> fetch`, `<base>` = `origin/<défaut>`, sinon `<base>` = `<défaut>` ; commande `git -C <LINKED> worktree add --no-track -b <LINKED_BRANCH> <LINKED_WORKTREE> <base>`.
   - Action `create` et `.forge/project.md` absent du commit de départ (`git -C <LINKED> cat-file -e <départ>:.forge/project.md`) → "`.forge/` of `<LINKED>` is not committed — commit it first." STOP — ne pas continuer. Le worktree ne porte que les fichiers versionnés.
5. Afficher le tableau de délégation (format ci-dessous).
6. Poser une confirmation unique avec `AskUserQuestion` — `header` : `Delegate`, options `Open the linked project` / `Cancel`.
7. **Sur `Cancel`** → n'exécuter aucune action. STOP — ne pas continuer.
8. **Sur `Open the linked project`** → dans l'ordre :
   - Exécuter l'action de worktree retenue à l'étape 4 (`reuse` → rien). Échec → afficher l'erreur telle quelle, STOP.
   - Écrire `<LINKED_WORKTREE>/.forge/branch/<LINKED_BRANCH>/brief.md` — format du mandat ci-dessous. Fichier déjà présent → le remplacer : le mandat parent fait foi.
   - Écrire `<LINKED_WORKTREE>/.forge/branch/<LINKED_BRANCH>/log.md` s'il est absent, puis insérer en tête : `- [AAAA-MM-JJ HH:MM] Opened from <ROOT> · T3, T5`.
   - PLAN parent : sous chaque tâche du mandat, note `delegated to <LINKED> @ <LINKED_BRANCH>` — statut inchangé. LOG parent : `- [AAAA-MM-JJ HH:MM] Delegated T3, T5 to <LINKED> @ <LINKED_BRANCH>`.
   - Lancer le sous-agent (prompt ci-dessous), puis entrer dans la boucle de relais.

### Boucle de relais

À chaque rapport du sous-agent :
- Rapport contenant `FORGE_QUESTION` → afficher `content` **intégralement** à l'utilisateur, tel quel, jamais résumé (`none` → rien à afficher), puis poser la question avec `AskUserQuestion`, `header` et options recopiés tels quels ; `header` `Plan` → `content` recopié en tête de `question` selon le « Gabarit — question `Plan` » ; `options: none` → question en texte libre. Renvoyer la réponse au même sous-agent par `SendMessage`, message `FORGE_ANSWER: <réponse>`. Reprendre la boucle.
- Rapport contenant `FORGE_DONE` → sortir de la boucle, appliquer le retour ci-dessous.
- Rapport sans aucun des deux blocs → le renvoyer au sous-agent par `SendMessage` : `FORGE_ANSWER: end your turn with a FORGE_QUESTION or a FORGE_DONE block.` Deux rappels au maximum, puis marquer chaque tâche du mandat `[!] blocked — delegated run ended without report` et sortir.

⚠️ Jamais de réponse inventée à la place de l'utilisateur — chaque `FORGE_QUESTION` lui est posée.

### Retour — application de `FORGE_DONE`

Pour chaque tâche parente du mandat, dans l'ordre du plan :
- Toutes ses tâches enfant dans `done` → cocher `[x]`, note `delegated to <LINKED> @ <LINKED_BRANCH> · done`.
- Au moins une dans `blocked` → marquer `[!] blocked — <raison de la première> · delegated to <LINKED> @ <LINKED_BRANCH>`.
- Absente de `done` et de `blocked` → marquer `[!] blocked — not addressed by the delegated run · delegated to <LINKED> @ <LINKED_BRANCH>`.

⚠️ La note conserve toujours `delegated to <LINKED> @ <LINKED_BRANCH>` : la livraison relayée s'appuie dessus pour retrouver le projet lié et sa branche.
- Une entrée LOG parent par tâche : `- [AAAA-MM-JJ HH:MM] T3 delegated to <LINKED> — done` / `— blocked: <raison>`.

`out_of_mandate` non vide → présenter chaque besoin à l'utilisateur, puis appliquer la « Surveillance des demandes complémentaires » de `phases/p5-resume.md` à chacun. Rendre compte : tâches vertes, tâches bloquées avec leur raison, fichiers touchés dans `<LINKED_WORKTREE>`, puis rappeler : "`git -C <LINKED> worktree remove <LINKED_WORKTREE>` once the linked branch is engraved." Le worktree reste en place.

⚠️ `<LINKED_WORKTREE>` ne porte que les fichiers versionnés : ni dépendances installées (`node_modules`, `vendor`), ni `.env`, ni configuration locale. Une tâche déléguée qui les exige → le sous-agent la remonte `blocked` avec sa raison.

⚠️ Le parent ne coche jamais une tâche déléguée de lui-même — seul `FORGE_DONE` fait foi.

### Format du mandat — `brief.md` du projet lié

Brief parent recopié à l'identique, précédé de `## Origin`. Libellés en anglais, tels quels ; contenu des tâches recopié intégralement depuis PLAN parent, sans reformulation. `**Branch:**` porte la branche parente `<BRANCH>` — la branche liée se lit dans le chemin du fichier.

```markdown
## Origin
**Parent:** <ROOT>
**Branch:** <BRANCH>
**Tasks:** T3, T5

### Delegated tasks

#### T3 — [Titre parent]
**Effort:** [effort parent]
**Files:** [fichiers parent]
**Description:** [description parent, intégrale]

## Objective
[brief parent, inchangé]

## Scope & rules
[brief parent, inchangé]
```

### Prompt du sous-agent

Un sous-agent, type général, lancé en tâche de fond. Prompt figé — rien d'autre n'est transmis :

```
FORGE_DELEGATED
ROOT: <LINKED_WORKTREE>
BRANCH: <LINKED_BRANCH>
LANGUAGE: <langue de l'utilisateur>
SCOPE: linked
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

**Vocabulaire :** `<X>` = branche visée · `<WORKTREE>` = chemin absolu du worktree de `<X>`, rangé à côté du dépôt : `<dossier-du-dépôt>.worktrees/<X>`, chaque `/` de la branche gardé comme sous-dossier (`D:/www/forge.worktrees/feature/x`).

**INVARIANT :** aucun mandat — le parent n'écrit rien dans `<WORKTREE>`, ni brief, ni log, ni plan ; il ne lit jamais son code. Le sous-agent y exécute le skill comme sur toute branche.

⚠️ Aucune commande git avant la confirmation de l'étape 5.

**Réaction — dans l'ordre :**
1. `<X>` = `<BRANCH>` → "Already on `<X>`." STOP — ne pas continuer.
2. `git rev-parse --verify --quiet refs/heads/<X>` échoue → "Branch `<X>` does not exist — create it first." STOP — ne pas continuer. Jamais de création à la place de l'utilisateur.
3. `git worktree list --porcelain` : un worktree porte `branch refs/heads/<X>` → `<WORKTREE>` = son chemin, action `reuse` ; sinon action `create` : `git worktree add <WORKTREE> <X>`.
4. Afficher le tableau de délégation (format ci-dessous).
5. Poser une confirmation unique avec `AskUserQuestion` — `header` : `Delegate`, options `Open the branch` / `Cancel`.
6. **Sur `Cancel`** → n'exécuter aucune action. STOP — ne pas continuer.
7. **Sur `Open the branch`** → dans l'ordre :
   - Action `create` → exécuter `git worktree add`. Échec → afficher l'erreur telle quelle, STOP.
   - Lancer le sous-agent (prompt ci-dessous), puis entrer dans la « Boucle de relais » de la délégation vers un projet lié — identique.

### Retour — `FORGE_DONE` en `SCOPE: branch`

Aucune écriture dans PLAN ni LOG parent : il n'y a pas de mandat. Rendre compte en une ligne — tâches `done`, tâches `blocked` avec leur raison — puis rappeler : "`git worktree remove <WORKTREE>` once the branch is engraved." Le worktree reste en place.

### Prompt du sous-agent

Un sous-agent, type général, lancé en tâche de fond. Prompt figé — rien d'autre n'est transmis :

```
FORGE_DELEGATED
ROOT: <WORKTREE>
BRANCH: <X>
LANGUAGE: <langue de l'utilisateur>
SCOPE: branch
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
