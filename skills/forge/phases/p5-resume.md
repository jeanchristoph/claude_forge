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

8. **Au moins une tâche ouverte** → poser le choix du mode d'exécution avec `AskUserQuestion` — jamais une question en texte libre.
   - `header` : `Mode` · trois options, dans cet ordre :
     - `Chain the tasks (recommended)` → "Work through every open task in order, one after another, without stopping between them."
     - `Pick a task` → "Choose which task we tackle now."
     - `Hammer the plan` → "Dispatch every open task to sub-agents in one sequence — each task tested, then reviewed by three adversarial sub-agents."
   - `Pick a task` retenu → seconde `AskUserQuestion`, `header` : `Task`, une option par tâche ouverte dans l'ordre du plan (label `T<n> — titre`, description = son effort et sa dépendance éventuelle), quatre au maximum.

   ⚠️ Aucun démarrage avant la réponse à la question — ni enchaînement, ni tâche isolée, ni frappe.

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
   - Continuer normalement

---

## Frappe — dispatch de sous-agents sur les tâches du plan

**Déclencheur :** l'utilisateur dit "frappe" / "hammer", seul ou suivi d'une tâche du plan (ex: "frappe T3").

**INVARIANT :** seul l'orchestrateur écrit dans PLAN et LOG. Les sous-agents rendent un verdict structuré, jamais une écriture directe — des écritures concurrentes corrompent les fichiers.

⚠️ Aucun sous-agent lancé avant la confirmation de l'étape 4.

**Réaction — dans l'ordre :**
1. Constituer la liste des tâches : tâche citée → elle seule ; aucune tâche citée → toutes les tâches `[ ]` du plan, dans l'ordre. Liste vide → "Nothing to hammer — every task is done." et STOP.
2. Partitionner par le champ `Files` de chaque tâche : fichiers disjoints → tâches parallèles, un worktree git par tâche ; fichiers en intersection → même groupe, traité séquentiellement.
3. Afficher le tableau de frappe (format ci-dessous).
4. Poser une confirmation unique couvrant toute la séquence, avec `AskUserQuestion` — `header` : `Hammer`, options `Run the hammering` / `Cancel`.
5. **Sur `Cancel`** → n'exécuter aucune action. STOP — ne pas continuer.
6. **Sur `Run the hammering`** → exécuter la cellule de chaque tâche (ci-dessous), sans validation intermédiaire.
7. Toutes les tâches traitées → exécuter la revue transversale (ci-dessous).
8. Rendre compte : tâches vertes, tâches `[!] blocked` avec leur raison, constats de la revue transversale.

### Cellule d'une tâche

1. **Implémentation** — un sous-agent. Contexte transmis : `brief.md`, `coding-standards.md`, la tâche et ses fichiers. Rien d'autre.
2. **Vérification mécanique** — tests, lint et types du projet.
   - Rouge → retour à l'étape 1 avec le rapport d'échec. Deux reprises au maximum.
   - Reprises épuisées → marquer `[!] blocked` avec la raison en une ligne, passer à la tâche suivante.
   - Vert → étape 3.
3. **Vérification adversariale** — trois sous-agents en contexte frais, lancés en parallèle, ne recevant que le diff de la tâche et `brief.md`. Un angle distinct par sous-agent, jamais deux fois le même : respect du brief · régression · sécurité · dette introduite.
   - Majorité défavorable → retour à l'étape 1. Deux reprises au maximum.
   - Majorité favorable → cocher `[x]`, passer à la tâche suivante.

⚠️ Consigne de réfutation à chaque vérificateur, jamais de validation — un relecteur chargé de valider valide.
⚠️ Le juge est la suite de tests, jamais un sous-agent : aucune tâche cochée `[x]` sans étape 2 verte.

### Revue transversale

Un sous-agent unique, après toutes les tâches, recevant le diff complet et `brief.md`. Objet distinct de la cellule : incohérences entre tâches, doublons, dette accumulée.
- Constats → les présenter, puis poser le choix avec `AskUserQuestion` — `header` : `Review`, options `Fix them` / `Leave them` — avant toute correction.
- Aucun constat → l'indiquer en une ligne.

### Format du tableau de frappe

Une ligne par tâche à traiter, dans l'ordre d'exécution. Quatre colonnes, en-têtes générés dans la langue de l'utilisateur : numéro de tâche, titre, mode d'exécution (`parallel` / `sequential`), nombre de sous-agents prévus.

Dernière ligne : total des tâches et total des sous-agents, reprises exclues.

⚠️ Jamais de liste de fichiers, jamais de décompte de lignes.

---

## Livraison — commit, push, merge

**Déclencheur :** l'utilisateur dit "grave" / "engrave", seul ou suivi d'une ou plusieurs branches existantes, dans l'ordre voulu (ex: "grave", "grave dev", "grave dev master").

**INVARIANT :** git opère uniquement sur le dépôt courant — jamais sur un autre dépôt ouvert en parallèle.

⚠️ Aucune commande git — `git add` compris — avant la confirmation de l'étape 3.

**Réaction — dans l'ordre :**
1. Générer automatiquement le message de commit (règles COMMITS GIT : max 150 car., pas de mention Claude) — pas de confirmation sur le message lui-même.
2. Afficher le tableau récapitulatif des actions prévues (format ci-dessous).
3. Poser une confirmation unique couvrant toute la séquence, avec `AskUserQuestion` — `header` : `Engrave`, options `Run the sequence` / `Cancel`.
4. **Sur `Cancel`** → n'exécuter aucune action. STOP — ne pas continuer.
5. **Sur `Run the sequence`** → exécuter la séquence entière sans validation intermédiaire, dans l'ordre : `git add`, `git commit`, `git push` sur `<BRANCH>`.
6. Aucune branche citée → passer directement à l'étape 8.
7. Pour chaque branche citée, dans l'ordre : branche citée égale à `<BRANCH>` → ignorer sans message ; sinon → checkout de la branche, merge de `<BRANCH>` (toujours la branche de départ, jamais la branche précédente de la chaîne), push.
8. Revenir sur `<BRANCH>`. Rendre compte : hash de commit, branches mises à jour.

### Format du tableau récapitulatif

Une ligne par action git prévue, dans l'ordre d'exécution. Trois colonnes, en-têtes générés dans la langue de l'utilisateur : numéro d'ordre, action git, détail.

Actions et détail associé — aucune autre :
- `add` → branche courante
- `commit` → message généré, entre guillemets
- `push` → remote et branche poussée
- `merge` → `<BRANCH>` → branche cible, une ligne par branche citée
- `checkout` → dernière ligne du tableau uniquement, retour sur `<BRANCH>` ; omise si aucune branche n'est citée

⚠️ Jamais de ligne `checkout` pour les changements de branche de l'étape 7 : ils restent implicites. Seul le retour final sur `<BRANCH>` est listé.
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
   - Présenter le rapport, poser le choix avec `AskUserQuestion` — `header` : `Report`, options `Write it` / `Rework it` — puis écrire `.forge/branch/<BRANCH>/report.txt`. `Rework it` → demander ce qui doit changer, régénérer, reposer la question.

3. **Publication dans ClickUp** — uniquement si `.forge/clickup.json` est présent. Fichier absent → étape entièrement silencieuse, jamais mentionnée.
   - Lire `branch_code` dans `.forge/clickup.json` : `<BRANCH>` est le code de la tâche ClickUp, `custom_id` ou `id` selon ce champ.
   - Vérifier la tâche par `clickup_get_task` avant tout envoi. Introuvable → le signaler, demander l'identifiant, ne jamais deviner. Sans réponse : passer à l'étape 4.
   - Poser le choix avec `AskUserQuestion` — `header` : `ClickUp`, options `Post the comment` / `Skip`, la tâche visée nommée dans la question.
   - **Sur `Post the comment`** → `clickup_create_task_comment` sur cette tâche, contenu de `report.txt` transmis tel quel — jamais reformulé, jamais reformaté. Rendre compte en une ligne.
   - **Sur `Skip`** → n'envoyer rien, passer à l'étape 4 sans commentaire.

   ⚠️ Action sortante : aucun envoi sans accord explicite. Le silence n'est pas un accord.

4. **Réponse client** — poser le choix avec `AskUserQuestion` — `header` : `Email`, options `Draft a reply` / `Finish`.
   - `Draft a reply` → attendre que l'utilisateur colle le mail auquel répondre, générer une réponse au ton fluide, professionnel et pédagogique, rédigée dans la langue du mail reçu — jamais celle de l'utilisateur si elle diffère.
   - `Finish` → terminer.
