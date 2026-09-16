# Reprise

## Actions — dans l'ordre

1. Lire `@.forge/project.md` — contexte interne, **ne pas afficher**.
2. Lire `.forge/coding-standards.md` — contexte interne, **ne pas afficher**.
3. Lire `@.forge/branch/<BRANCH>/brief.md` — contexte interne, **ne pas afficher**.
4. Lire les 40 premières lignes de `.forge/branch/<BRANCH>/log.md` (`Read` avec `limit: 40`), si présent — contexte interne, **ne pas afficher**.
   - Des entrées existent → retenir les 10 plus récentes parmi les lignes lues, afficher un résumé en tête : "**Last session :** [points clés]"
   - ⚠️ Jamais de lecture non bornée de `log.md` — la taille du fichier ne doit jamais peser sur le coût de la reprise.
5. Lire `@.forge/branch/<BRANCH>/plan.md`
6. Afficher le tableau d'avancement (format ci-dessous).
7. **Aucune tâche ouverte** — une `[!] blocked` n'est pas ouverte → aucun mode proposé. Demander en une ligne quoi faire ensuite, puis STOP.
   > "Nothing open — what do we do next?"

   BRIEF contient `## Origin` (mode délégué) → aucune question : terminer par `FORGE_DONE` (section « Mode délégué » de `SKILL.md`). STOP.

8. **Au moins une tâche ouverte** → poser le choix du mode d'exécution avec `AskUserQuestion` — jamais une question en texte libre.
   - `header` : `Mode` · deux options, dans cet ordre :
     - `Chain the tasks (recommended)` → "Work through every open task in order, one after another, without stopping between them."
     - `Pick a task` → "Choose which task we tackle now."
   - `Pick a task` retenu → seconde `AskUserQuestion`, `header` : `Task`, une option par tâche ouverte dans l'ordre du plan (label `T<n> — titre`, description = son effort et sa dépendance éventuelle), quatre au maximum.
   - BRIEF contient `## Origin` (mode délégué) → aucune question : enchaîner toutes les tâches ouvertes dans l'ordre, sans arrêt entre elles — la validation du plan vaut accord.

   ⚠️ Aucun démarrage avant la réponse à la question — ni enchaînement, ni tâche isolée. En mode délégué, la réponse est la validation du plan.

---

## Format du tableau d'avancement

| Tâche | Effort | Statut |
|---|---|---|
| T1 — ... | S | [x] |
| T2 — ... | M | [ ] |
| T3 — ... | L | [!] blocked — brief reason |

---

## Règles de mise à jour du plan

**Silencieuse (automatique)** — après tâche terminée ou événement notable :
- Cocher `[x]`, ajouter note max 1 ligne, marquer `[!]` si bloqué.
- Script diffusé à part du déploiement git (section « Contenu généré » du SKILL) → ajouter l'étape dans `## Deployment` : quoi, moment d'exécution, chemin de la copie dans OUTPUT. `None` remplacé par la première étape.

**Substantielle (confirmation obligatoire)** — décrire la modification, puis poser le choix avec `AskUserQuestion` — `header` : `Plan`, options `Apply` / `Leave as is` — avant d'appliquer :
- Ajouter/supprimer une tâche
- Modifier l'ordre ou les dépendances
- Changer l'effort estimé
- Réécrire la description

⚠️ La modification est décrite en clair avant la question — jamais réduite à l'intitulé d'une option.

**Tâche L/XL** — avant de démarrer, décomposer en micro-étapes et écrire `plan.md` :
`[ ] T2.1 — ...` · `[ ] T2.2 — ...`

---

## Mise à jour du brief et du log

Le brief est vivant. Les changements de scope sont gérés par la **Surveillance** ci-dessous.

**Élément de cadre** (valable pour toute la durée de la branche) → écrire silencieusement dans la section `## Scope & rules` de `brief.md` :
- Contrainte technique découverte en cours de tâche
- Règle immuable posée par l'utilisateur
- Remarque utilisateur précisant durablement le périmètre ou le hors périmètre

**Décision ponctuelle** (choix acté et clos à un instant donné) → écrire silencieusement dans LOG (format : `- [date] [1 ligne]`) :
- Choix d'implémentation mineur acté sans discussion
- **Choix utilisateur quand Claude a proposé plusieurs options** (ex: "Option B retenue — raison")

⚠️ Entrée insérée en tête de `log.md`, juste sous le titre — jamais en fin de fichier. La lecture bornée de l'étape 4 suppose les entrées les plus récentes en haut.

---

## Choix d'infrastructure → propagation vers CLAUDE.md global

**Déclencheur :**
- Un choix d'infrastructure se pose (techno, lib, pattern, service)
- L'utilisateur revient sur un choix fait instinctivement par Claude (le corrige, l'invalide)

**Réaction — dans l'ordre :**
1. Logger le choix retenu dans LOG (règle ci-dessus).
2. Si le choix dépasse le périmètre de cette branche (règle générale, pas spécifique au ticket) → en tirer une règle concise et programmatique, l'afficher telle qu'elle serait écrite, puis poser le choix avec `AskUserQuestion` — `header` : `Global rule`, options `Add to CLAUDE.md` / `Keep it local`.
3. **Sur `Add to CLAUDE.md`** → ajouter la règle à `~/.claude/CLAUDE.md` (section existante pertinente ou nouvelle section courte). Jamais d'écriture sans validation explicite.
4. **Sur `Keep it local`** → rester local au brief, ne jamais reproposer plus tard pour la même décision.

---

## Surveillance des demandes complémentaires

**À chaque input utilisateur**, après l'exécution du skill (reprise ou nouveau projet), évaluer si la demande correspond à une tâche existante du plan ou non.

### Demande hors périmètre — détecter si :
- La demande concerne une fonctionnalité absente du plan
- Elle introduit un nouveau cas d'usage, un nouveau module, ou un nouveau comportement
- Elle modifie une contrainte technique ou fonctionnelle implicitement acceptée

### Réaction — dans l'ordre :

1. **Signaler** la détection clairement, décrire la tâche telle qu'elle entrerait au plan, puis poser le choix avec `AskUserQuestion` — `header` : `Scope`, options `Add to the plan` / `Handle it off-plan` :
   > "This request isn't in the current plan."

2. **Si `Add to the plan`** :
   - Appliquer la mise à jour **substantielle** du plan (tâche ajoutée, effort estimé, position dans la séquence)
   - Si la demande change significativement le scope global → poser aussi le choix avec `AskUserQuestion` — `header` : `Brief`, options `Update the brief` / `Plan only` :
     > "This also changes the project scope."
   - Écrire `.forge/branch/<BRANCH>/plan.md` après validation
   - Écrire `.forge/branch/<BRANCH>/brief.md` si scope mis à jour

3. **Si `Handle it off-plan`** :
   - Traiter la demande sans modifier le plan
   - Fichier produit → écrit dans OUTPUT, jamais ailleurs — section « Contenu généré » de `SKILL.md`
   - Continuer normalement

---

## Délégation — projet lié

**Déclencheur :** une demande vise un dossier hors de ROOT — chemin cité explicitement ou projet nommé sans ambiguïté — avec ou sans tâches du plan citées (ex: "fais T3 et T5 dans `../autre-projet`").

**Vocabulaire :** projet *parent* = ROOT de la session · projet *lié* = `<LINKED>`, chemin absolu du dossier visé · *mandat* = les tâches parentes déléguées.

**INVARIANT :** le parent n'écrit dans `<LINKED>` que `.forge/branch/<BRANCH>/brief.md` et `.forge/branch/<BRANCH>/log.md` — jamais de code, jamais de plan. Le parent ne lit jamais le code de `<LINKED>`.

⚠️ Aucune écriture, aucune commande git avant la confirmation de l'étape 6.

**Réaction — dans l'ordre :**
1. `<LINKED>/.forge/` absent → "`<LINKED>` is not forged — run `/forge` there first." STOP — ne pas continuer. Jamais d'initialisation à la place de l'utilisateur.
2. `<BRANCH>` est un identifiant de ticket (parent resté sur `main`/`master`) → "Delegation needs a real branch — create one first." STOP — ne pas continuer.
3. Constituer le mandat : tâches citées dans la demande → elles seules ; aucune citée → poser le choix avec `AskUserQuestion` en multi-sélection — `header` : `Delegate`, une option par tâche `[ ]` du plan (label `T<n> — titre`, description = son effort), quatre par question, enchaînées si besoin. Mandat vide → "Nothing to delegate." STOP — ne pas continuer.
4. Vérifier la branche dans `<LINKED>` : `git -C <LINKED> rev-parse --verify --quiet refs/heads/<BRANCH>`. Retenir l'action : `checkout` si elle existe, sinon création depuis la branche par défaut à jour de `<LINKED>` — même règle que « Branche de travail » de `SKILL.md`, chaque commande préfixée `git -C <LINKED>`.
5. Afficher le tableau de délégation (format ci-dessous).
6. Poser une confirmation unique avec `AskUserQuestion` — `header` : `Delegate`, options `Open the linked project` / `Cancel`.
7. **Sur `Cancel`** → n'exécuter aucune action. STOP — ne pas continuer.
8. **Sur `Open the linked project`** → dans l'ordre :
   - Exécuter l'action git retenue à l'étape 4. Échec → afficher l'erreur telle quelle, STOP.
   - Écrire `<LINKED>/.forge/branch/<BRANCH>/brief.md` — format du mandat ci-dessous. Fichier déjà présent → le remplacer : le mandat parent fait foi.
   - Écrire `<LINKED>/.forge/branch/<BRANCH>/log.md` s'il est absent, puis insérer en tête : `- [date] Opened from <ROOT> · T3, T5`.
   - PLAN parent : sous chaque tâche du mandat, note `delegated to <LINKED> @ <BRANCH>` — statut inchangé. LOG parent : `- [date] Delegated T3, T5 to <LINKED> @ <BRANCH>`.
   - Lancer le sous-agent (prompt ci-dessous), puis entrer dans la boucle de relais.

### Boucle de relais

À chaque rapport du sous-agent :
- Rapport contenant `FORGE_QUESTION` → poser la question avec `AskUserQuestion`, `header` et options recopiés tels quels ; `options: none` → question en texte libre. Renvoyer la réponse au même sous-agent par `SendMessage`, message `FORGE_ANSWER: <réponse>`. Reprendre la boucle.
- Rapport contenant `FORGE_DONE` → sortir de la boucle, appliquer le retour ci-dessous.
- Rapport sans aucun des deux blocs → le renvoyer au sous-agent par `SendMessage` : `FORGE_ANSWER: end your turn with a FORGE_QUESTION or a FORGE_DONE block.` Deux rappels au maximum, puis marquer chaque tâche du mandat `[!] blocked — delegated run ended without report` et sortir.

⚠️ Jamais de réponse inventée à la place de l'utilisateur — chaque `FORGE_QUESTION` lui est posée.

### Retour — application de `FORGE_DONE`

Pour chaque tâche parente du mandat, dans l'ordre du plan :
- Toutes ses tâches enfant dans `done` → cocher `[x]`, note `delegated to <LINKED> @ <BRANCH> · done`.
- Au moins une dans `blocked` → marquer `[!] blocked — <raison de la première> · delegated to <LINKED> @ <BRANCH>`.
- Absente de `done` et de `blocked` → marquer `[!] blocked — not addressed by the delegated run · delegated to <LINKED> @ <BRANCH>`.

⚠️ La note conserve toujours `delegated to <LINKED> @ <BRANCH>` : la livraison relayée s'appuie dessus pour retrouver le projet lié.
- Une entrée LOG parent par tâche : `- [date] T3 delegated to <LINKED> — done` / `— blocked: <raison>`.

`out_of_mandate` non vide → présenter chaque besoin à l'utilisateur, puis appliquer la « Surveillance des demandes complémentaires » à chacun. Rendre compte : tâches vertes, tâches bloquées avec leur raison, fichiers touchés dans `<LINKED>`.

⚠️ Le parent ne coche jamais une tâche déléguée de lui-même — seul `FORGE_DONE` fait foi.

### Format du mandat — `brief.md` du projet lié

Brief parent recopié à l'identique, précédé de `## Origin`. Libellés en anglais, tels quels ; contenu des tâches recopié intégralement depuis PLAN parent, sans reformulation.

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
ROOT: <LINKED>
BRANCH: <BRANCH>
LANGUAGE: <langue de l'utilisateur>
Invoke the `forge` skill with argument `<BRANCH>`. Resolve every path and every git command under ROOT.
Delegated mode applies (section « Mode délégué » of the skill): never call AskUserQuestion.
Write every file content and every report in LANGUAGE; structure labels stay in English.
End every turn with a FORGE_QUESTION or a FORGE_DONE block.
```

### Format du tableau de délégation

Une ligne par action prévue, dans l'ordre d'exécution. Trois colonnes, en-têtes générés dans la langue de l'utilisateur : numéro d'ordre, action, détail.

Actions et détail associé — aucune autre :
- `branch` → `<LINKED>` : `checkout <BRANCH>` ou `create <BRANCH> from <défaut>`
- `brief` → `<LINKED>/.forge/branch/<BRANCH>/brief.md` : mandat `T3, T5`
- `log` → `<LINKED>/.forge/branch/<BRANCH>/log.md`
- `mark` → tâches parentes annotées, une ligne
- `agent` → sous-agent délégué, une ligne

⚠️ Jamais de liste de fichiers du projet lié, jamais de décompte de lignes.

---

## Livraison — commit, push, merge

**Déclencheur :** l'utilisateur dit "grave" / "engrave", seul ou suivi d'une ou plusieurs branches existantes, dans l'ordre voulu (ex: "grave", "grave dev", "grave dev master").

**INVARIANT :** git opère uniquement sur le dépôt courant — jamais sur un autre dépôt ouvert en parallèle. Unique exception : `<LINKED>`, pour le positionnement de branche par la « Délégation — projet lié » et pour la livraison relayée ci-dessous — rien d'autre.

**Publication hors dépôt :** tout texte publié sur la forge distante à la suite d'une livraison — titre et notes d'une release, description d'un tag ou d'une PR — est rédigé en **anglais**, quelle que soit la langue de l'utilisateur. Le message de commit, lui, suit la langue des commits du dépôt.

⚠️ Aucune commande git — `git add` compris, `<LINKED>` compris — avant la confirmation de l'étape 4.

**Réaction — dans l'ordre :**
1. Générer automatiquement le message de commit (règles COMMITS GIT : max 150 car., pas de mention Claude) — pas de confirmation sur le message lui-même.
2. Livraison relayée — pour chaque projet lié (ci-dessous) : poser les deux questions, retenir la séquence du lié.
3. Afficher le tableau récapitulatif des actions prévues (format ci-dessous), puis un tableau par projet lié retenu.
4. Poser une confirmation unique couvrant toute la séquence — parent et projets liés — avec `AskUserQuestion` — `header` : `Engrave`, options `Run the sequence` / `Cancel`.
5. **Sur `Cancel`** → n'exécuter aucune action, parent et liés. STOP — ne pas continuer.
6. **Sur `Run the sequence`** → exécuter la séquence entière sans validation intermédiaire, dans l'ordre : `git add`, `git commit`, `git push` sur `<BRANCH>`.
7. Aucune branche citée → passer directement à l'étape 9.
8. Pour chaque branche citée, dans l'ordre : branche citée égale à `<BRANCH>` → ignorer sans message ; sinon → checkout de la branche, merge de `<BRANCH>` (toujours la branche de départ, jamais la branche précédente de la chaîne), push.
9. Revenir sur `<BRANCH>`.
10. Pour chaque projet lié retenu, dans l'ordre du plan : dérouler les étapes 6 à 9 avec ses branches, chaque commande préfixée `git -C <LINKED>`. Échec → afficher l'erreur telle quelle, passer au projet lié suivant ; le parent, déjà livré, n'est jamais repris.
11. Rendre compte : hash de commit et branches mises à jour, parent puis chaque projet lié.

### Livraison relayée — projets liés

**Déclencheur :** PLAN parent porte au moins une note `delegated to <LINKED> @ <BRANCH>`. Aucune → étape 2 silencieuse, jamais mentionnée.

**Pour chaque `<LINKED>` distinct, dans l'ordre du plan :**
- `git -C <LINKED> status --porcelain` vide → ignorer sans question. Une ligne au rendu final : "`<LINKED>`: nothing to engrave."
- Sinon → poser le choix avec `AskUserQuestion` — `header` : `Linked`, question "Also engrave `<LINKED>` @ `<BRANCH>`?", options `Engrave it` / `Skip`.
- **Sur `Skip`** → projet lié écarté de la séquence, sans commentaire.
- **Sur `Engrave it`** → poser le choix des branches avec `AskUserQuestion` — `header` : `Linked branches`, options dans cet ordre :
  - `Same branches as the parent` → "[branches citées du parent, dans l'ordre]" — omise si le parent n'en cite aucune.
  - `<BRANCH> only` → "Commit and push `<BRANCH>`, no merge."
  - `Other branches` → "I'll ask you which ones." — puis demander en texte libre, dans l'ordre voulu.
- Message de commit du lié : généré depuis les tâches du mandat cochées `[x]` avec sa note `delegated to <LINKED>` — jamais depuis le code de `<LINKED>`, que le parent ne lit pas. Langue : celle des commits de `<LINKED>` (`git -C <LINKED> log -5 --format=%s`).
- Branche citée absente de `<LINKED>` (`git -C <LINKED> show-ref --verify --quiet refs/heads/<cible>`) → ligne `merge` marquée `skipped — branch missing` dans le tableau, ignorée à l'exécution, jamais créée.

⚠️ Le sous-agent délégué n'est jamais sollicité pour livrer : la livraison relayée est du git pur, exécuté par le parent.

### Format du tableau récapitulatif

Une ligne par action git prévue, dans l'ordre d'exécution. Trois colonnes, en-têtes générés dans la langue de l'utilisateur : numéro d'ordre, action git, détail.

Actions et détail associé — aucune autre :
- `add` → branche courante
- `commit` → message généré, entre guillemets
- `push` → remote et branche poussée
- `merge` → `<BRANCH>` → branche cible, une ligne par branche citée
- `checkout` → dernière ligne du tableau uniquement, retour sur `<BRANCH>` ; omise si aucune branche n'est citée

Tableau d'un projet lié : mêmes colonnes, même contenu, titré par `<LINKED>` en une ligne au-dessus ; le détail de chaque ligne porte le chemin (`add` → `<LINKED>` · `<BRANCH>`).

⚠️ Jamais de ligne `checkout` pour les changements de branche de l'étape 8 : ils restent implicites. Seul le retour final sur `<BRANCH>` est listé.
⚠️ Jamais de liste de fichiers modifiés, jamais de décompte de lignes.

---

## Clôture de tâche — rapport & réponse client

**Déclencheur :**
- Toutes les tâches du plan sont `[x]` ET l'utilisateur a validé les tests, OU
- L'utilisateur emploie un terme de clôture ("terminé", "end", "pb résolu", ou équivalent)

**Réaction — dans l'ordre :**

1. **Confirmer** que le problème initial est bien résolu : rappeler en une ligne l'objectif tel que décrit dans `## Objective` du brief, puis poser le choix avec `AskUserQuestion` — `header` : `Closure`, options `Solved` / `Not yet`.
   `Not yet` → demander ce qui reste, et STOP. Aucune suite sans `Solved`.

2. **Sur `Solved` :**
   - Générer le rapport interne (ou le mettre à jour si `report.txt` existe déjà pour cette branche) : texte brut structuré, concis, logique, schématique — labels courts (ex: PROBLÈME / SOLUTION / IMPACT). **Exclure** : détails d'itérations, mentions de branche, de tests, de fichiers modifiés.
   - Rédiger intégralement dans la langue de l'utilisateur, labels compris — seul fichier produit exempté des libellés de structure figés en anglais.
   - Présenter le rapport, poser le choix avec `AskUserQuestion` — `header` : `Report`, options `Write it` / `Cancel` — motif « Validation d'un contenu » de `SKILL.md` : le changement demandé arrive en texte libre, régénérer, reposer la question. Sur `Write it` → écrire `.forge/branch/<BRANCH>/report.txt`.

3. **Publication dans ClickUp** — uniquement si `.forge/clickup.json` est présent. Fichier absent → étape entièrement silencieuse, jamais mentionnée.
   - Lire `branch_code` dans `.forge/clickup.json` : `<BRANCH>` est le code de la tâche ClickUp, `custom_id` ou `id` selon ce champ.
   - Vérifier la tâche par `clickup_get_task` avant tout envoi. Introuvable → le signaler, demander l'identifiant, ne jamais deviner. Sans réponse : passer à l'étape 4.
   - Poser le choix avec `AskUserQuestion` — `header` : `ClickUp`, options `Post the comment` / `Skip`, la tâche visée nommée dans la question.
   - **Sur `Post the comment`** → `clickup_create_task_comment` sur cette tâche, contenu de `report.txt` transmis tel quel — jamais reformulé, jamais reformaté. Rendre compte en une ligne.
   - **Sur `Skip`** → n'envoyer rien, passer à l'étape 4 sans commentaire.

   ⚠️ Action sortante : aucun envoi sans accord explicite. Le silence n'est pas un accord.

4. **Réponse client** — poser le choix avec `AskUserQuestion` — `header` : `Email`, options `Draft a reply` / `Finish`.
   - `Draft a reply` → attendre que l'utilisateur colle le mail auquel répondre, générer une réponse au ton fluide, professionnel et pédagogique, rédigée dans la langue du mail reçu — jamais celle de l'utilisateur si elle diffère.
   - **Un paragraphe tient sur une seule ligne.** Jamais de retour à la ligne forcé à l'intérieur d'un paragraphe :
     le client de messagerie gère le rendu, un repli à la main coupe les phrases n'importe où, souvent juste avant
     un point. Les retours à la ligne ne séparent que les paragraphes et les éléments d'une liste.
   - **Aller à l'essentiel.** Ce qui figure dans une pièce jointe ou un document remis au client n'est pas reformulé
     dans le corps du mail : on l'y annonce en une phrase. Un mail de quelques paragraphes, pas une page.
   - `Finish` → terminer.
