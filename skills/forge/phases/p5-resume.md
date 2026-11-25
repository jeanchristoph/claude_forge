# Reprise

## Actions — dans l'ordre

1. `.forge/project.md` — jamais lu à la reprise : section « Contexte du code » ci-dessous.
2. `.forge/coding-standards.md` — jamais lu à la reprise : même section.
3. Lire `@.forge/branch/<BRANCH>/brief.md` — contexte interne, **ne pas afficher**.
4. Reprendre `recent_log` du JSON de « Détection d'état » (`SKILL.md`).
   - Des entrées existent → afficher un résumé en tête : "**Last session :** [points clés]"
   - ⚠️ Jamais de lecture directe de `log.md` — la taille du fichier ne doit jamais peser sur le coût de la reprise.
5. Lire `@.forge/branch/<BRANCH>/plan.md`
6. Afficher le tableau d'avancement : `## Summary` du plan recopié tel quel (« Format du tableau d'avancement » ci-dessous). `.forge/branch/<BRANCH>/ticket.json` présent → afficher au-dessus une ligne `Ticket: [<code>](<url>)`.
7. **Aucune tâche ouverte** — une `[!] blocked` n'est pas ouverte → aucun mode proposé. Demander en une ligne quoi faire ensuite, puis STOP.
   > "Nothing open — what do we do next?"

   Mode délégué `SCOPE: linked` (BRIEF contient `## Origin`) → aucune question : terminer par `FORGE_DONE` (section « Mode délégué » de `SKILL.md`). STOP.
   Mode délégué `SCOPE: branch` → la même question en `FORGE_QUESTION`, `options: none`, `content: none`.

8. **Plan de branches** (au moins une tâche `### Tn — Branch <x>` ou `**Linked branch:**` ouverte — unités `child` et `linked` de `commands/swarm.md`) → aucune question `Mode` ; jamais de tâche liée enchaînée en série quand une place est libre : exécuter `bash <SKILL_DIR>/scripts/swarm-status.sh --root <ROOT> --branch <BRANCH>`, afficher l'essaim — en cours (avec `done/total`), lançables, en attente (dépendance nommée), tâches du parent —, puis la première ligne qui s'applique :
   - SWARM porte des branches `running` ou `waiting for merge` dont le délégué n'a pas été lancé dans cette conversation → « Reprise de l'essaim » (`commands/swarm.md`), qui pose la question `Resume`.
   - Branches lançables sans conflit → « Relance de l'essaim » ci-dessous.
   - Tâches ordinaires prenables (`ordinary` de `swarm-status.sh`, `waiting_for` vide) → étape 9, limitée à ces tâches ; `**Parent mode:**` de SWARM renseigné → aucune question `Mode`, mode repris (« Plan mixte — travail du parent » de `commands/swarm.md`).
   - Sinon → une ligne : "Waiting for delegates or dependencies: `<X>` (`<dépendance>`)." STOP.

   Aucun lancement sans réponse : une reprise de session n'est jamais un accord pour lancer des délégués.
9. **Au moins une tâche ouverte** → poser le choix du mode d'exécution avec `AskUserQuestion` — jamais une question en texte libre.
   - Plan validé dans ce tour par `Validate and chain` — étape 7 de `p4-plan.md`, ou ajout de tâches validé ainsi (« Demande hors périmètre ») → aucune question : enchaîner toutes les tâches ouvertes dans l'ordre, sans arrêt ni feu vert entre elles. Mode délégué compris.
   - Une seule tâche ouverte → `header` : `Task`, options `Start T<n>` / `Cancel`, le titre de la tâche nommé dans la question. `Cancel` → STOP. Mode délégué `SCOPE: linked` → puce dédiée ci-dessous.
   - Plusieurs tâches ouvertes → `header` : `Mode` · deux options, dans cet ordre :
     - `Chain the tasks (recommended)` → "Work through every open task in order, one after another, without stopping between them."
     - `Pick a task` → "Choose which task we tackle now."
   - `Pick a task` retenu → seconde `AskUserQuestion`, `header` : `Task`, une option par tâche ouverte dans l'ordre du plan (label `T<n> — titre`, description = son effort et sa dépendance éventuelle), quatre au maximum.
   - Mode délégué `SCOPE: linked` (BRIEF contient `## Origin`) → aucune question : enchaîner toutes les tâches ouvertes dans l'ordre, sans arrêt entre elles — la validation du plan vaut accord.
   - Mode délégué `SCOPE: branch` → les mêmes questions `Mode` puis `Task` en `FORGE_QUESTION` ; puis, avant chaque tâche, un `FORGE_QUESTION` — `header` : `Task`, options `Start T<n>` / `Cancel`, la description entière de la tâche dans `content`. Aucun enchaînement sans ce feu vert, sauf `Validate and chain` (première puce).

   ⚠️ Aucun démarrage avant la réponse à la question — ni enchaînement, ni tâche isolée. Après `Validate and chain`, ou en mode délégué `SCOPE: linked`, la réponse est la validation du plan.

---

## Contexte du code

**Déclencheur :** démarrage d'une tâche du plan, ou « Action directe » qui modifie un fichier du projet hors `.forge/` — le premier des deux dans le tour.

**Réaction :** lire `@.forge/project.md` puis `.forge/coding-standards.md` — contexte interne, **ne pas afficher** —, avant toute autre action de la tâche. Une seule lecture par tour (« Lecture unique » de `SKILL.md`).

⚠️ Reprise, consultation de l'avancement, `grave`, clôture, contenu généré → aucune lecture : ces parcours n'ont pas besoin du contexte du code.

---

## Format du tableau d'avancement

`## Summary` de PLAN, recopié tel quel : `Task | Effort | Files | Estimated | Actual | Status`, puis `**Total**` (tâches mesurées seules ; aucune → `see **Actual:**` quand la ligne existe) et `**Remaining**` (tâches ouvertes) — tableau tenu à jour par le hook `hooks/plan-hook.sh` à chaque écriture du plan. Ligne `**Actual:**` de l'en-tête du plan présente → recopiée sous le tableau, telle quelle : temps réel de la branche ventilé par poste, valeur de la dernière livraison ou clôture (gabarit « Temps réel de la branche » de `phases/p4-plan.md`). Aucun appel de script, aucun recalcul.

⚠️ Plan antérieur au hook, sans colonnes `Estimated` / `Actual` → tableau recopié tel quel ; la première écriture du plan les ajoute.

---

## Règles de mise à jour du plan

**Silencieuse (automatique)** — après tâche terminée ou événement notable :
- Cocher `[x]`, ajouter note max 1 ligne, marquer `[!]` si bloqué. Coche → section « Mesure d'une tâche » ci-dessous. `## Summary` jamais édité à la main pour un statut, une estimation ou un réel : le hook le régénère.
  ⚠️ Coche par l'outil Edit sur la ligne de statut exacte de la tâche — jamais par `sed` ni par une expression régulière : `[ ]` y désigne un espace, et le remplacement corrompt le reste du fichier.
- Script diffusé à part du déploiement git (section « Contenu généré » du SKILL) → ajouter l'étape dans `## Deployment` : quoi, moment d'exécution, numéros des tâches d'origine, chemin de la copie dans OUTPUT. `None` remplacé par la première étape. Étape qui exécute du SQL → « Script de déploiement SQL » de « Commandes — chargées à la demande » ci-dessous.

**Substantielle (confirmation obligatoire)** — décrire la modification, puis poser le choix avec `AskUserQuestion` — `header` : `Plan`, options `Apply` / `Leave as is` — avant d'appliquer :
- Ajouter/supprimer une tâche
- Modifier l'ordre ou les dépendances
- Changer l'effort estimé
- Réécrire la description

⚠️ La modification est écrite en entier avant la question (« Règle absolue » de `SKILL.md`). Mode délégué → `FORGE_QUESTION`, la modification décrite entière dans `content`.

**Tâche L/XL** — avant de démarrer, décomposer en micro-étapes et écrire `plan.md` :
`[ ] T2.1 — ...` · `[ ] T2.2 — ...`

---

## Mesure d'une tâche

**Déclencheur :** coche `[x]` d'une tâche du plan — dans tous les modes, enchaîné, tâche choisie ou délégué.

**Réaction — dans l'ordre :**
1. Aucune marque, aucun appel de script : le hook `hooks/plan-hook.sh` (`PostToolUse` sur `Edit|Write|MultiEdit`) voit la coche dans `plan.md`.
2. Le hook écrit dans le journal de mesure le début de la tâche (dernier point d'étape : coche précédente ou première écriture du plan) et sa fin, puis calcule le réel par `time-aggregate.sh --task`.
3. Le hook écrit sous `**Estimated time:**` de la tâche, à défaut sous `**Effort:**` : `**Actual time:** ≈ <agent_minutes> min agent (incl. <check_minutes> min checks) · human <human_minutes> min (<questions> questions) · <actual_files> files · total ≈ <agent + human> min`, sans la partie fichiers quand `actual_files` est `null` ; sans mesure → `**Actual time:** —`. Premier nombre = temps d'agent, vérifications comprises, comparé à l'estimation ; total = agent + humain, vérifications jamais ajoutées. La part de vérifications nourrit le coût fixe de vérification de l'estimation.

⚠️ Jamais de `**Actual time:**` écrit à la main, jamais de durée estimée à la place d'une mesure absente. Hook signalé dans le contexte (`forge plan-hook: …`) → relire `plan.md` avant de l'éditer de nouveau.
⚠️ Tâche-branche d'un essaim (titre `— Branch <X>`) et tâche déléguée à un projet lié (`**Linked branch:**` ou note `delegated to`) → aucune marque, jamais le temps de la session parente ; leur réel est écrit par le hook à la coche : somme des réels des tâches de leur plan, vérifications comprises, même format qu'une tâche ordinaire. Plan absent ou tâche faite non mesurée → `—`.
⚠️ Plusieurs tâches cochées d'un même coup → tâches simultanées, `—` pour chacune : cocher chaque tâche à sa fin, une par édition.
⚠️ Rafale — tâche à fichiers prévus cochée moins d'une minute après la précédente, sans fichier changé entre les deux → tâches simultanées elles aussi : `—` pour tout le groupe, réel déjà écrit de la première compris ; leur temps reste dans `**Unplanned**`.

---

## Sous-agents ordinaires

**Condition :** sous-agent lancé pendant une tâche par l'outil `Agent`, hors délégué forge (prompt `FORGE_DELEGATED`).

**Réaction :**
- Usage limité à la lecture : exploration, recherche, revue, vérification indépendante.
- Écriture d'un fichier de ROOT → session elle-même, en série ; travail d'écriture parallélisable → tâche-branche et essaim (« Règle de branche » de `phases/p4-plan.md`, « Promotion d'une tâche » ci-dessous).

⚠️ Jamais d'écriture par un sous-agent ordinaire, encore moins par plusieurs en parallèle dans le même working tree : aucun isolement, conflits sur les mêmes fichiers, tâches simultanées non mesurables (`overlapping_tasks`).

---

## Promotion d'une tâche

**Déclencheur :** tâche ordinaire en cours dont la taille réelle, apparue à l'exploration, remplit la « Règle de branche » de `phases/p4-plan.md` — session principale ou délégué d'un essaim (`commands/delegated-mode.md`).

**Réaction — dans l'ordre :**
1. Poser le choix avec `AskUserQuestion` — `header` : `Promotion`, question "T<n> deserves its own branch: turn it into a branch task?", la description de la tâche réécrite en tâche-branche (« Format d'une tâche-branche » de `phases/p4-plan.md`) écrite en entier avant la question, options `Promote` / `Keep it here`.
2. Sur `Promote` → PLAN : la tâche réécrite en tâche-branche, entrée LOG `T<n> promoted to branch <X>`, puis étape 8 des « Actions », qui propose son lancement.
3. Sur `Keep it here` → la tâche continue dans la session.

⚠️ Question posée avant le premier fichier écrit pour la tâche : une branche fille part de la branche parente commitée, un travail entamé ne la suivrait pas. Fichier déjà écrit → aucune question, la tâche se termine en série.

---

## Mise à jour du brief et du log

Le brief est vivant. Les changements de scope sont gérés par la **Surveillance** ci-dessous.

**Élément de cadre** (valable pour toute la durée de la branche) → écrire silencieusement dans la section `## Scope & rules` de `brief.md` :
- Contrainte technique découverte en cours de tâche
- Règle immuable posée par l'utilisateur
- Remarque utilisateur précisant durablement le périmètre ou le hors périmètre

**Décision ponctuelle** (choix acté et clos à un instant donné) → écrire silencieusement une entrée LOG d'une ligne (« Entrée LOG » de `SKILL.md`) :
- Choix d'implémentation mineur acté sans discussion
- **Choix utilisateur quand Claude a proposé plusieurs options** (ex: "Option B retenue — raison")

⚠️ `status.sh` suppose les entrées les plus récentes en haut : jamais d'entrée écrite hors de `log-entry.sh`.

---

## Surveillance des demandes complémentaires

**À chaque input utilisateur**, après l'exécution du skill (reprise ou nouveau projet), évaluer si la demande correspond à une tâche existante du plan ou non.

⚠️ Question sur le projet qui n'appelle aucune action → réponse en lecture seule, ni tâche, ni question `Plan`, ni ligne dans LOG.

### Demande de vérification — prioritaire sur l'action directe

**Déclencheur :** l'utilisateur demande de vérifier ou de tester quelque chose — lancer des tests, contrôler un comportement, reproduire un cas.

**Réaction :**
- Test rapide — une commande ou une lecture, sans test à écrire ni scénario en plusieurs étapes → « Action directe » ci-dessous, sans question.
- Sinon, dans l'ordre :
  1. Formuler la tâche de vérification selon le « Gabarit — question `Plan` » ci-dessous.
  2. Poser une seule question avec `AskUserQuestion` — `header` : `Test`, champ `question` = la tâche formulée, puis une ligne vide et la phrase de question, trois options :
     - `Add to plan` → "Add T[n] to the plan, then run it." — même suite que `Validate and chain` dans « Demande hors périmètre ».
     - `Check without a task` → "Run the check now, nothing enters the plan." — « Action directe », une ligne dans LOG.
     - `Cancel` → "Nothing is checked." — STOP.

⚠️ Doute entre test rapide et vérification plus lourde → poser la question `Test`.
⚠️ Mode délégué → `FORGE_QUESTION`, la tâche formulée entière dans `content`.

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

1. **Formuler** la tâche telle qu'elle entre au plan — titre, effort, temps estimé, fichiers, description — précédée de :
   > "This request isn't in the current plan."
   Temps estimé présenté : `bash <SKILL_DIR>/scripts/time-calibrate.sh --root <ROOT> --files <fichiers de la tâche>` (`review` pour une tâche de relecture, « Tâche de relecture » de `phases/p4-plan.md`), `estimate` au ratio du moment, `null` → `—`. Jamais écrit par le modèle : le hook `hooks/plan-hook.sh` écrit `**Estimated time:**` à l'écriture du plan et le fige.
   Si la demande change durablement le périmètre → ajouter à la même présentation l'entrée proposée pour `## Scope & rules` du brief.
   Tâche qui vise un projet lié → champ `**Linked branch:**` et rédaction sans référence au parent, selon « Branche liée » de `phases/p4-plan.md`.
   Tâches formulées qui remplissent la « Règle de branche » de `phases/p4-plan.md` et plan qui remplit alors le déclencheur de son « Plan de branches », tâches-branches déjà au plan comprises → les présenter en tâche-branche (« Format d'une tâche-branche »), tableau des groupes en tête. Mode délégué → jamais : « Promotion d'une tâche » ci-dessous.

2. **Poser une seule question** avec `AskUserQuestion` — `header` : `Plan`, options de la question `Plan` d'un plan neuf (étape 7 de `p4-plan.md`), dans cet ordre : `Validate and chain` / `Validate` / `Cancel`, précédées de `Validate and launch the swarm` quand une tâche-branche est formulée — motif « Validation d'un contenu » de `SKILL.md` : le changement demandé arrive en texte libre, reformuler, reposer la question. Champ `question` = la tâche formulée, recopiée en dur selon le « Gabarit — question `Plan` » ci-dessous, puis une ligne vide et la phrase de question. Aucun champ `preview`. Mode délégué → `FORGE_QUESTION`, la tâche formulée entière dans `content`.

   ⚠️ Le texte écrit avant `AskUserQuestion` peut être masqué à l'écran de l'utilisateur : la tâche recopiée dans `question` est la seule copie garantie visible avec la question.

3. **Sur `Validate and launch the swarm`, `Validate and chain` ou `Validate`** → appliquer la mise à jour du plan (tâches ajoutées, effort, position dans la séquence), écrire `.forge/branch/<BRANCH>/plan.md`, écrire `.forge/branch/<BRANCH>/brief.md` si `## Scope & rules` change, puis :
   - `Validate and launch the swarm` → « Délégation — essaim de branches filles » de `commands/swarm.md`.
   - `Validate and chain` → enchaîner toutes les tâches ouvertes dans l'ordre, sans autre question — même règle qu'à l'étape 9 des « Actions ».
   - `Validate` → rien n'est exécuté : étape 9 des « Actions », question `Mode` ou `Task` comme pour un plan neuf.

4. **Sur `Cancel`** → rien n'entre au plan, la demande n'est pas traitée. STOP — ne pas continuer.

### Gabarit — question `Plan`

Gabarit figé du champ `question` de l'étape 2 — crochets à remplir, rien d'autre ne change. Texte brut : jamais de titre Markdown, jamais de tableau Markdown (non rendus dans la boîte de dialogue). Fichiers et entrée `## Scope & rules` jamais recopiés dans `question` : ils restent dans la présentation de la réponse. Description entière, jamais résumée, découpée en puces `-` — puces numérotées `1.` `2.` quand l'ordre compte —, une idée par puce.

```
header:   Plan
question: T[n] — [Titre]
          Effort : [S|M|L|XL] · [n] fichiers · ≈ [minutes] min ([bas]-[haut])
          Branche liée : [branche]   ← tâche qui porte `**Linked branch:**` seulement
          Description :
          - [idée 1]
          - [idée 2]

          [Ajouter cette tâche au plan ?]
option 1: [Valider et enchaîner] — [Ajoute T[n] au plan et l'exécute, sans autre question.]
option 2: [Valider] — [Ajoute T[n] au plan, puis demande comment exécuter les tâches.]
option 3: [Annuler] — [Rien n'entre au plan.]
          Tâche-branche formulée → option en tête : [Valider et lancer l'essaim] — [Ajoute T[n] au plan et lance sa branche fille.]
          Tâche liée formulée et place libre dans l'essaim (`slots` de `swarm-status.sh`) → même option en tête : [Valider et lancer l'essaim] — [Ajoute T[n] au plan et lance son délégué en parallèle des autres.]
```

---

## Commandes — chargées à la demande

Lire et exécuter intégralement le fichier de la première commande dont le déclencheur s'applique. Déclencheur absent → aucune lecture.

### Essaim → `commands/swarm.md`, section du même nom que le déclencheur

**Déclencheur :**
- demande de lancer, relancer ou reprendre des branches filles du plan (« lance l'essaim », « lance les branches », « relance T3 »), ou de déléguer plusieurs tâches vers des projets liés ou des branches liées différents (« délègue T3, T5 et T7 ») → « Délégation — essaim de branches filles » ;
- `FORGE_QUESTION` ou `FORGE_DONE` d'un délégué lancé par l'essaim → « Boucle de relais de l'essaim » ;
- étape 8 de « Actions », branches `running` ou `waiting for merge` dont le délégué n'a pas été lancé dans cette conversation → « Reprise de l'essaim » ;
- réponse `Launch` à la question « Relance de l'essaim » ci-dessous → « Délégation — essaim de branches filles ».

### Relance de l'essaim

**Déclencheur :** étape 8 de « Actions », branches lançables sans conflit dans le JSON de `swarm-status.sh` (`slots` = places libres, N délégués au plus, `**N:**` de `swarm.md`).

**Réaction :** poser le choix avec `AskUserQuestion` — `header` : `Swarm` :
- `Launch <X>, <Y>` → "Launch these delegates in parallel." — unités `child` et `linked`, les `slots` premières lançables, dans l'ordre du plan ; « Délégation — essaim de branches filles » de `commands/swarm.md`.
- `Work on parent tasks` → "Leave the swarm as is and take the parent's own tasks." — seulement si des tâches ordinaires sont prenables ; étape 9, limitée à ces tâches.
- `Later` → "Launch nothing now." — STOP.

### Script de déploiement SQL → `commands/deployment-sql.md`

**Déclencheur :** `## Deployment` gagne ou modifie une étape qui exécute du SQL — migration, script de reconstruction, requête d'exploitation —, ou le fichier SQL d'une étape déjà listée est écrit. Message `forge plan-hook: deployment script missing` ou `… incomplete` → même réaction, sans attendre.

### Propagation vers CLAUDE.md → `commands/rule-propagation.md`

**Déclencheur :**
- Un choix d'infrastructure se pose (techno, lib, pattern, service)
- L'utilisateur revient sur un choix fait instinctivement par Claude (le corrige, l'invalide)
- L'utilisateur demande une correction de syntaxe, de structure ou de convention de code (nommage, format, organisation) sur un contenu produit par Claude

⚠️ Bug fonctionnel, changement de besoin → aucun déclenchement.

### Renommage de branche → `commands/branch-rename.md`

**Déclencheur :** l'utilisateur demande de renommer la branche courante.

### Délégation — projet lié → `commands/delegation.md`, section du même nom

**Déclencheur :** une demande vise un dossier hors de ROOT — chemin cité explicitement ou projet nommé sans ambiguïté — avec ou sans tâches du plan citées (ex: "fais T3 et T5 dans `../autre-projet`"), une seule branche liée. Plusieurs branches liées → « Essaim » ci-dessus.

⚠️ Demande hors plan qui vise le projet lié → « Demande hors périmètre » d'abord (tâche ajoutée au plan), puis cette délégation — jamais de worktree créé ni de code écrit par le parent, même pour une petite modification.

### Délégation — branche du même dépôt → `commands/delegation.md`, section du même nom

**Déclencheur :** une demande de lancer un agent ou un forge délégué sur une branche `<X>` du dépôt courant — « lance un agent forge sur la branche X », « lance un agent sur la branche X », « lance un forge délégué sur X », « ouvre la branche X dans un agent » et toute formulation équivalente : agent ou forge délégué + nom de branche, sans chemin de dossier. Un chemin de dossier cité → « Délégation — projet lié » ci-dessus.

### Livraison → `commands/engrave.md`

**Déclencheur :** message qui commence par "grave" / "engrave" et ne contient rien d'autre que des branches existantes, dans l'ordre voulu (ex: "grave", "grave dev", "grave dev master"). Autre texte dans le message → pas une livraison.

### Clôture de tâche → `commands/closure.md`

**Déclencheur :**
- Toutes les tâches du plan sont `[x]` ET l'utilisateur a validé les tests, OU
- L'utilisateur emploie un terme de clôture ("terminé", "end", "pb résolu", ou équivalent)
