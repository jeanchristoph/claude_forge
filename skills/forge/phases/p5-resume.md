# Reprise

## Actions — dans l'ordre

1. Lire `@.forge/project.md` — contexte interne, **ne pas afficher**.
2. Lire `.forge/coding-standards.md` — contexte interne, **ne pas afficher**.
3. Lire `@.forge/branch/<BRANCH>/brief.md` — contexte interne, **ne pas afficher**.
4. Reprendre `recent_log` du JSON de « Détection d'état » (`SKILL.md`).
   - Des entrées existent → afficher un résumé en tête : "**Last session :** [points clés]"
   - ⚠️ Jamais de lecture directe de `log.md` — la taille du fichier ne doit jamais peser sur le coût de la reprise.
5. Lire `@.forge/branch/<BRANCH>/plan.md`
6. Afficher le tableau d'avancement (format ci-dessous).
7. **Aucune tâche ouverte** — une `[!] blocked` n'est pas ouverte → aucun mode proposé. Demander en une ligne quoi faire ensuite, puis STOP.
   > "Nothing open — what do we do next?"

   Mode délégué `SCOPE: linked` (BRIEF contient `## Origin`) → aucune question : terminer par `FORGE_DONE` (section « Mode délégué » de `SKILL.md`). STOP.
   Mode délégué `SCOPE: branch` → la même question en `FORGE_QUESTION`, `options: none`, `content: none`.

8. **Au moins une tâche ouverte** → poser le choix du mode d'exécution avec `AskUserQuestion` — jamais une question en texte libre.
   - Plan validé dans ce tour par `Validate and chain` (étape 7 de `p4-plan.md`) → aucune question : enchaîner toutes les tâches ouvertes dans l'ordre, sans arrêt ni feu vert entre elles. Mode délégué compris.
   - Une seule tâche ouverte → `header` : `Task`, options `Start T<n>` / `Cancel`, le titre de la tâche nommé dans la question. `Cancel` → STOP. Mode délégué `SCOPE: linked` → puce dédiée ci-dessous.
   - Plusieurs tâches ouvertes → `header` : `Mode` · deux options, dans cet ordre :
     - `Chain the tasks (recommended)` → "Work through every open task in order, one after another, without stopping between them."
     - `Pick a task` → "Choose which task we tackle now."
   - `Pick a task` retenu → seconde `AskUserQuestion`, `header` : `Task`, une option par tâche ouverte dans l'ordre du plan (label `T<n> — titre`, description = son effort et sa dépendance éventuelle), quatre au maximum.
   - Mode délégué `SCOPE: linked` (BRIEF contient `## Origin`) → aucune question : enchaîner toutes les tâches ouvertes dans l'ordre, sans arrêt entre elles — la validation du plan vaut accord.
   - Mode délégué `SCOPE: branch` → les mêmes questions `Mode` puis `Task` en `FORGE_QUESTION` ; puis, avant chaque tâche, un `FORGE_QUESTION` — `header` : `Task`, options `Start T<n>` / `Cancel`, la description entière de la tâche dans `content`. Aucun enchaînement sans ce feu vert, sauf `Validate and chain` (première puce).

   ⚠️ Aucun démarrage avant la réponse à la question — ni enchaînement, ni tâche isolée. Après `Validate and chain`, ou en mode délégué `SCOPE: linked`, la réponse est la validation du plan.

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
- Script diffusé à part du déploiement git (section « Contenu généré » du SKILL) → ajouter l'étape dans `## Deployment` : quoi, moment d'exécution, numéros des tâches d'origine, chemin de la copie dans OUTPUT. `None` remplacé par la première étape. Étape qui exécute du SQL → section « Script de déploiement SQL » ci-dessous.

**Substantielle (confirmation obligatoire)** — décrire la modification, puis poser le choix avec `AskUserQuestion` — `header` : `Plan`, options `Apply` / `Leave as is` — avant d'appliquer :
- Ajouter/supprimer une tâche
- Modifier l'ordre ou les dépendances
- Changer l'effort estimé
- Réécrire la description

⚠️ La modification est écrite en entier avant la question (« Règle absolue » de `SKILL.md`). Mode délégué → `FORGE_QUESTION`, la modification décrite entière dans `content`.

**Tâche L/XL** — avant de démarrer, décomposer en micro-étapes et écrire `plan.md` :
`[ ] T2.1 — ...` · `[ ] T2.2 — ...`

---

## Script de déploiement SQL

**Déclencheur :** `## Deployment` gagne ou modifie une étape qui exécute du SQL — migration, script de reconstruction, requête d'exploitation.

**Réaction — dans l'ordre :**
1. Écrire ou réécrire sur place `.forge/branch/<BRANCH>/output/AAAAMMJJ-deployment-script.sql`, sans question — un seul fichier par branche, daté de sa création, jamais renommé.
2. Écrire une entrée dans LOG : `- [AAAA-MM-JJ HH:MM] Deployment script updated: [étapes ajoutées ou modifiées]`.

**Format :**
- En-tête en commentaire : branche, date, tableau des étapes — numéro, base visée, moment (`before` / `after deploy`), forme (`comment` / `query`), tâches d'origine.
- Une section par étape SQL, dans l'ordre de `## Deployment`, titrée `-- STEP [n] — [base visée] — [moment] · [T7, T9]`.
- Script versionné dans le dépôt → commentaire seul : chemin, prérequis, précautions, variantes production et développement. Jamais recopié.
- Requête autonome (`EXEC`, job, `UPDATE` d'exploitation) → telle quelle, exécutable, suivie de sa requête de contrôle.
- Valeur qui dépend de la date → calculée dans la requête, jamais laissée à saisir.
- Section contenant un `USE` → placée en dernier.
- Étape sans SQL → absente du script.

⚠️ Le script se réécrit en entier à chaque déclencheur, depuis `## Deployment` : jamais d'ajout en fin de fichier qui laisserait une étape obsolète.

---

## Mise à jour du brief et du log

Le brief est vivant. Les changements de scope sont gérés par la **Surveillance** ci-dessous.

**Élément de cadre** (valable pour toute la durée de la branche) → écrire silencieusement dans la section `## Scope & rules` de `brief.md` :
- Contrainte technique découverte en cours de tâche
- Règle immuable posée par l'utilisateur
- Remarque utilisateur précisant durablement le périmètre ou le hors périmètre

**Décision ponctuelle** (choix acté et clos à un instant donné) → écrire silencieusement dans LOG (format : `- [AAAA-MM-JJ HH:MM] [1 ligne]`, heure locale) :
- Choix d'implémentation mineur acté sans discussion
- **Choix utilisateur quand Claude a proposé plusieurs options** (ex: "Option B retenue — raison")

⚠️ Entrée insérée en tête de `log.md`, juste sous le titre — jamais en fin de fichier : `status.sh` suppose les entrées les plus récentes en haut. `log.md` absent → le créer.

---

## Correction ou choix d'infrastructure → propagation vers CLAUDE.md

### Garde

Mode délégué → aucune proposition : `AskUserQuestion` est inaccessible et aucune écriture n'a lieu hors de ROOT. STOP — ne pas continuer cette section.

**Déclencheur :**
- Un choix d'infrastructure se pose (techno, lib, pattern, service)
- L'utilisateur revient sur un choix fait instinctivement par Claude (le corrige, l'invalide)
- L'utilisateur demande une correction de syntaxe, de structure ou de convention de code (nommage, format, organisation) sur un contenu produit par Claude

⚠️ Bug fonctionnel, changement de besoin → aucun déclenchement.

**Réaction — dans l'ordre :**
1. Correction demandée → l'appliquer d'abord.
2. Logger le choix retenu ou la correction dans LOG (règle ci-dessus).
3. Si le cas est propre à cette branche ou à une seule occurrence (coquille isolée) → STOP — ne pas continuer cette section.
4. Si `~/.claude/CLAUDE.md` ou le `CLAUDE.md` à la racine du projet couvre déjà le cas → STOP — ne pas continuer cette section.
5. En tirer une règle concise et programmatique au format `Quand [cas] → [conduite]`, généralisée, sans nom de fichier ni de ticket, et l'afficher telle qu'elle serait écrite.
6. Poser le choix avec `AskUserQuestion` — `header` : `Rule`, trois options, dans cet ordre :
   - `Add to global CLAUDE.md` → "Add this rule to `~/.claude/CLAUDE.md`, for all your projects."
   - `Add to project CLAUDE.md` → "Add this rule to the `CLAUDE.md` at the project root, created if absent."
   - `Keep it local` → "Write nothing to any `CLAUDE.md`."
7. **Sur `Add to global CLAUDE.md`** → ajouter la règle à `~/.claude/CLAUDE.md` (section existante pertinente ou nouvelle section courte).
8. **Sur `Add to project CLAUDE.md`** → ajouter la règle au `CLAUDE.md` à la racine du projet (section existante pertinente ou nouvelle section courte), créé s'il est absent.
9. **Sur `Keep it local`** → n'écrire dans aucun `CLAUDE.md`, ne jamais reproposer plus tard pour le même cas.

⚠️ Aucune écriture dans un `CLAUDE.md` sans réponse à cette question. Sans réponse → n'écrire rien.

---

## Surveillance des demandes complémentaires

**À chaque input utilisateur**, après l'exécution du skill (reprise ou nouveau projet), évaluer si la demande correspond à une tâche existante du plan ou non.

### Action directe — exécuter sans tâche ni question

**Condition — l'une ou l'autre :**
- La demande est un ordre précis (quoi, où), tient en une commande ou une modification locale, et n'appelle aucune décision de conception — supprimer ou renommer un fichier, corriger un texte, ajouter un mot, exécuter une commande.
- Le résultat demandé est un contenu généré au sens de la section « Contenu généré » de `SKILL.md` — documentation, export, script SQL, classeur de contrôle, analyse, livrable client — quelle que soit sa taille. Le plan ne trace que les tâches qui implémentent l'objectif du brief : un livrable demandé en cours de route se produit, il ne se planifie pas.

**Réaction :** exécuter immédiatement — l'ordre explicite est la confirmation exigée par la règle absolue. Contenu généré → écrit dans OUTPUT, une ligne dans LOG. Le dépôt change → une ligne dans LOG. Aucune tâche, aucune question.

⚠️ Doute entre action directe et demande complémentaire, entre livrable et fonctionnalité → action directe : une action de trop ne coûte rien, une question de trop coûte un aller-retour.

### Demande hors périmètre — détecter si :
- La demande concerne une fonctionnalité absente du plan
- Elle introduit un nouveau cas d'usage, un nouveau module, ou un nouveau comportement
- Elle modifie une contrainte technique ou fonctionnelle implicitement acceptée

### Réaction — dans l'ordre :

Une demande complémentaire est toujours une tâche du plan — jamais de choix « au plan / hors plan ».

1. **Formuler** la tâche telle qu'elle entre au plan — titre, effort, fichiers, description — précédée de :
   > "This request isn't in the current plan."
   Si la demande change durablement le périmètre → ajouter à la même présentation l'entrée proposée pour `## Scope & rules` du brief.

2. **Poser une seule question** avec `AskUserQuestion` — `header` : `Plan`, options `Validate` / `Cancel` — motif « Validation d'un contenu » de `SKILL.md` : le changement demandé arrive en texte libre, reformuler, reposer la question. Champ `question` = la tâche formulée, recopiée en dur selon le « Gabarit — question `Plan` » ci-dessous, puis une ligne vide et la phrase de question. Aucun champ `preview`. Mode délégué → `FORGE_QUESTION`, la tâche formulée entière dans `content`.

   ⚠️ Le texte écrit avant `AskUserQuestion` peut être masqué à l'écran de l'utilisateur : la tâche recopiée dans `question` est la seule copie garantie visible avec la question.

3. **Sur `Validate`** → appliquer la mise à jour du plan (tâche ajoutée, effort, position dans la séquence), écrire `.forge/branch/<BRANCH>/plan.md`, écrire `.forge/branch/<BRANCH>/brief.md` si `## Scope & rules` change, puis exécuter la tâche selon le mode en cours.

4. **Sur `Cancel`** → rien n'entre au plan, la demande n'est pas traitée. STOP — ne pas continuer.

### Gabarit — question `Plan`

Gabarit figé du champ `question` de l'étape 2 — crochets à remplir, rien d'autre ne change. Texte brut : jamais de titre Markdown, jamais de tableau Markdown (non rendus dans la boîte de dialogue). Fichiers et entrée `## Scope & rules` jamais recopiés dans `question` : ils restent dans la présentation de la réponse. Description entière, jamais résumée, découpée en puces `-` — puces numérotées `1.` `2.` quand l'ordre compte —, une idée par puce.

```
header:   Plan
question: T[n] — [Titre]
          Effort : [S|M|L|XL]
          Description :
          - [idée 1]
          - [idée 2]

          [Ajouter cette tâche au plan et l'exécuter ?]
option 1: [Valider] — [Ajoute T[n] au plan et l'exécute.]
option 2: [Annuler] — [Rien n'entre au plan.]
```

---

## Renommage de branche

**Déclencheur :** l'utilisateur demande de renommer la branche courante.

**Réaction — dans l'ordre :**
1. Exécuter `git branch -m <nouveau>`. Échec git → afficher l'erreur telle quelle, STOP.
2. Déplacer `.forge/branch/<ancien>/` vers `.forge/branch/<nouveau>/`, retirer les dossiers parents devenus vides.
3. Écrire une entrée dans LOG.
4. `git ls-remote --heads origin <ancien>` non vide → signaler : "`<ancien>` still exists on origin — not deleted."
5. Informer en une ligne : "On branch `<nouveau>`."

⚠️ Jamais de suppression de l'ancien nom sur le distant sans demande.

---

## Commandes — chargées à la demande

Lire et exécuter intégralement le fichier de la première commande dont le déclencheur s'applique. Déclencheur absent → aucune lecture.

### Délégation — projet lié → `commands/delegation.md`, section du même nom

**Déclencheur :** une demande vise un dossier hors de ROOT — chemin cité explicitement ou projet nommé sans ambiguïté — avec ou sans tâches du plan citées (ex: "fais T3 et T5 dans `../autre-projet`").

### Délégation — branche du même dépôt → `commands/delegation.md`, section du même nom

**Déclencheur :** une demande de lancer un agent ou un forge délégué sur une branche `<X>` du dépôt courant — « lance un agent forge sur la branche X », « lance un agent sur la branche X », « lance un forge délégué sur X », « ouvre la branche X dans un agent » et toute formulation équivalente : agent ou forge délégué + nom de branche, sans chemin de dossier. Un chemin de dossier cité → « Délégation — projet lié » ci-dessus.

### Livraison → `commands/engrave.md`

**Déclencheur :** message qui commence par "grave" / "engrave" et ne contient rien d'autre que des branches existantes, dans l'ordre voulu (ex: "grave", "grave dev", "grave dev master"). Autre texte dans le message → pas une livraison.

### Clôture de tâche → `commands/closure.md`

**Déclencheur :**
- Toutes les tâches du plan sont `[x]` ET l'utilisateur a validé les tests, OU
- L'utilisateur emploie un terme de clôture ("terminé", "end", "pb résolu", ou équivalent)
