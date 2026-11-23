# Livraison

## Livraison — commit, push, merge

**Autorisation :** la commande vaut autorisation pour cette séquence seulement — aucune confirmation avant `run`. Les questions `Linked` / `Linked branches` de l'étape 2 restent posées : elles fixent le périmètre, elles ne confirment rien.

**INVARIANT :** git opère uniquement sur le dépôt courant — jamais sur un autre dépôt ouvert en parallèle. Unique exception : `<LINKED>`, pour la création du worktree par la « Délégation — projet lié » de `commands/delegation.md`, pour la livraison relayée et pour le « Retrait du worktree lié » ci-dessous — rien d'autre.

**Publication hors dépôt :** tout texte publié sur la forge distante à la suite d'une livraison — titre et notes d'une release, description d'un tag ou d'une PR — est rédigé en **anglais**, quelle que soit la langue de l'utilisateur. Le message de commit, lui, suit la langue des commits du dépôt.

⚠️ Sortie `2` du script (conflit de merge, push rejeté) → séquence déjà arrêtée par le script ; ne rien forcer : jamais de `--force`, jamais de résolution de conflit sans demande.

Mode délégué `SCOPE: branch` → `--root` vaut ROOT (le worktree) ; compte rendu de livraison recopié entier dans le `content` du bloc qui termine le tour. `SCOPE: linked` → Livraison non applicable (section « Mode délégué » de `SKILL.md`).

**Avant la séquence :** « Vérification complète » ci-dessous. Rouge → aucune livraison. STOP — ne pas continuer.

**Réaction — dans l'ordre :**
0. Synthèse de mesure : aucune action — `engrave.sh run --model` l'écrit avant le `git add`, avec la ligne `**Actual:**` de l'en-tête du plan (« Synthèse de mesure — `metrics.json` » ci-dessous) ; toutes deux partent avec le commit.
1. Générer automatiquement le message de commit (règles COMMITS GIT : max 150 car., pas de mention Claude) — pas de confirmation sur le message lui-même.
2. Livraison relayée — pour chaque projet lié (ci-dessous) : poser les deux questions, retenir la séquence du lié.
3. Exécuter aussitôt le script en `run` pour le parent (« Script de livraison » ci-dessous), sans question ni affichage préalable.
   - Sortie `0` → étape 4.
   - Sortie `1` → afficher l'erreur telle quelle, aucun projet lié livré. STOP — ne pas continuer.
   - Sortie `2` → rendre compte du parent selon le « Gabarit — compte rendu de livraison » ci-dessous, erreur git telle quelle sous le tableau, aucun projet lié livré. STOP — ne pas continuer.
4. Pour chaque projet lié retenu, dans l'ordre du plan : exécuter le script en `run` avec ses arguments. Sortie `1` → retenir l'erreur ; sortie `2` → retenir le JSON et l'erreur. Passer au projet lié suivant ; le parent, déjà livré, n'est jamais repris.
   - Sortie `0` avec au moins une action `merge` en `done` → « Retrait du worktree lié » ci-dessous, avant le projet lié suivant.
5. Rendre compte depuis le JSON de chaque `run`, parent puis chaque projet lié, selon le « Gabarit — compte rendu de livraison » ci-dessous.

⚠️ Aucune écriture dans LOG ni PLAN après la séquence — le compte rendu est du texte seul, le working tree reste tel que la livraison l'a laissé. Ce qui doit être journalisé l'est avant le `git add`.

### Vérification complète

**Déclencheur :** Livraison, avant la séquence et toute commande git — parent seulement : la suite d'un projet lié est lancée par son délégué, avant `FORGE_DONE` (« Suite complète du projet lié » de `commands/delegated-mode.md`).

**Réaction — dans l'ordre :**
1. Commande = ligne `**Full check:** \`<commande>\`` de `## Tools & access` de `.forge/project.md`. Absente → détecter un pipeline de tests (section « Vérifications » de `phases/p0-project.md`) : trouvé → écrire `ci` dans `project.md`, sans question ; sinon la demander une fois en texte libre : "What command runs the full test suite? (`none` if there is none)", l'écrire dans `project.md`.
   - `none` → aucune vérification, aucune ligne au compte rendu.
   - `ci` → rien n'est lancé en local ; ligne `Full check: left to CI` sous le tableau. Action `push` en `done` sur `master` / `main` → ligne ajoutée : `CI not awaited: <branche> was pushed before its result` — information seule, jamais bloquante.
2. Autre valeur → l'exécuter sous ROOT. Verte → une ligne au compte rendu, sous le tableau : `Full check: passed`.
3. Rouge → afficher les échecs tels que la commande les rend, aucune livraison, aucune écriture. STOP — ne pas continuer.

⚠️ Seul moment où la suite complète du dépôt courant tourne : pendant une tâche, seuls les tests des fichiers modifiés (« Tests d'une tâche » de `phases/p5-resume.md`).

### Synthèse de mesure — `metrics.json`

**Déclencheur :** Livraison (écrite par `engrave.sh run --model`, étape 3), étape 1 de la Clôture sur `Solved` (`commands/closure.md`), fusion d'une branche fille d'essaim (`commands/swarm.md`).

**Réaction :** jamais écrite par le modèle — `scripts/metrics.sh` l'écrit et rend compte en JSON :
- Livraison → aucun appel : `engrave.sh run` reçoit `--model <identifiant du modèle de la session>` et écrit la synthèse avant le `git add` ; compte rendu sous `metrics` du JSON de `run`.
- Clôture → `bash <SKILL_DIR>/scripts/metrics.sh --root <ROOT> --branch <BRANCH> --event closure --model <identifiant du modèle de la session>`.
- Branche fille d'un essaim → même appel, `--event engrave`, sous `--root <WORKTREE>`, avec `--parent-log <dépôt principal>/.forge/branch/<PARENT_BRANCH>/time-log.jsonl --base <PARENT_BRANCH>` (`<PARENT_BRANCH>` : vocabulaire de `commands/swarm.md`).

Compte rendu de la Livraison : une ligne sous le tableau, depuis `metrics` — `Estimated ≈ <planned_files> files · ≈ <estimated_minutes> min (<estimated_low>-<estimated_high>) · actual <actual_files> files · <agent_minutes> min` ; valeur `null` → `—` ; `partial` à `true` → ajouter ` · partial measure`. `metrics` absent (dossier de branche absent) → aucune ligne.

**Temps réel de la branche :** à chaque passage, avec un journal de mesure, `scripts/metrics.sh` réécrit sans doublon la ligne `**Actual:**` de l'en-tête du plan, sous `**Estimate:**`, à défaut sous `**Date:**` — gabarit « Temps réel de la branche » de `phases/p4-plan.md`. Seul écrivain de la ligne : entre deux passages, elle garde la valeur du dernier. Sans journal → plan intact.

⚠️ `metrics.json` : un objet sur une ligne, réécrit à chaque passage, valeurs cumulées depuis le début de la branche — champs, ordre et règles de comptage fixés par `scripts/metrics.sh`. `time-log.jsonl` (événements bruts) reste local, ignoré par git ; seul `metrics.json` est versionné.
⚠️ Aucune heure, aucune durée estimée à la main : sans journal, les durées restent `null`.

### Livraison relayée — projets liés

**Déclencheur :** PLAN parent porte au moins une note `delegated to <LINKED_REL> @ <LINKED_BRANCH>` (« Délégation — projet lié » de `commands/delegation.md`). Aucune → étape 2 silencieuse, jamais mentionnée.

**Vocabulaire :** `<LINKED>` = `<LINKED_REL>` de la note, résolu depuis ROOT ; une ancienne note à chemin absolu reste lue telle quelle · `<LINKED_GIT>` = dossier où la branche liée est extraite — le worktree qui porte `branch refs/heads/<LINKED_BRANCH>` dans `git -C <LINKED> worktree list --porcelain` ; aucun → `<LINKED>` lui-même (délégation ouverte avant les worktrees).

**Pour chaque `<LINKED>` distinct, dans l'ordre du plan :**
- `git -C <LINKED_GIT> status --porcelain` vide → ignorer sans question. Une ligne au rendu final : "`<LINKED>`: nothing to engrave."
- Sinon → poser le choix avec `AskUserQuestion` — `header` : `Linked`, question "Also engrave `<LINKED>` @ `<LINKED_BRANCH>`?", options `Engrave it` / `Skip`. Note du projet lié portant `full check: failed` → l'échec recopié en tête de la question : "Full check failed: <échec>." — information, jamais bloquante ; note sans `full check` (retour sans suite, ou délégation antérieure à cette règle) → rien d'ajouté.
- **Sur `Skip`** → projet lié écarté de la séquence, sans commentaire.
- **Sur `Engrave it`** → poser le choix des branches avec `AskUserQuestion` — `header` : `Linked branches`, options dans cet ordre :
  - `Same branches as the parent` → "[branches citées du parent, dans l'ordre]" — omise si le parent n'en cite aucune.
  - `<LINKED_BRANCH> only` → "Commit and push `<LINKED_BRANCH>`, no merge."
  - `Other branches` → "I'll ask you which ones." — puis demander en texte libre, dans l'ordre voulu.
- Message de commit du lié : généré depuis les tâches du mandat cochées `[x]` avec sa note `delegated to <LINKED_REL>` — jamais depuis le code de `<LINKED>`, que le parent ne lit pas. Aucun nom de dossier, de branche, de ticket ni de client du parent (invariant de « Délégation — projet lié » de `commands/delegation.md`). Langue : celle des commits de `<LINKED>` (`git -C <LINKED> log -5 --format=%s`).
- Script du lié : `--root <LINKED_GIT>`, `--branch <LINKED_BRANCH>`, son message, ses branches retenues.

⚠️ Le sous-agent délégué n'est jamais sollicité pour livrer : la livraison relayée est du git pur, exécuté par le parent.

### Retrait du worktree lié

**Déclencheur :** étape 4 de la Livraison — `run` du projet lié en sortie `0`, fusion faite ou non : sans fusion, le worktree est gardé et sa commande de retrait affichée ; étape 4 de la Clôture (`commands/closure.md`), pour une fusion faite hors forge (pull request).

**Réaction :** `bash <SKILL_DIR>/scripts/linked-worktree-cleanup.sh --linked <LINKED> --branch <LINKED_BRANCH> --merged-into <branches cibles retenues pour le projet lié, séparées par des virgules>` — `--merged-into` omis sans branche cible et à la Clôture ; le script décide seul, jamais de `git worktree remove` à la main :
- Retiré seulement si le worktree n'est pas `<LINKED>` lui-même, si son working tree est propre et si `<LINKED_BRANCH>` est fusionnée dans la branche par défaut de `<LINKED>` ou dans l'une des branches de `--merged-into` (une livraison limitée à `dev` compte), locale ou sur `origin` après `fetch` ; `git worktree remove` sans `--force`, la branche gardée.
- JSON sur une ligne : `{"worktree":<chemin|null>,"status":"removed|kept|absent","reason":<raison|null>}` — raison de `kept` : `not merged`, `uncommitted changes`, `main working tree`, `git error` ; `absent` → aucun worktree n'extrait la branche, rien à retirer.
- Compte rendu de la Livraison, une ligne sous le tableau du projet lié, jamais omise pour un worktree gardé :
  - `removed` → `worktree: removed` ;
  - `kept` → `worktree: kept — <reason> · remove: git -C "<LINKED>" worktree remove "<worktree>"` ; raison `uncommitted changes` → ` — commit or discard the changes first` ajouté ; raison `main working tree` → sans commande, ce dossier n'est jamais retiré ;
  - `absent` → aucune ligne.

⚠️ Fusion par squash ou rebase : la branche n'est pas ancêtre de la branche par défaut → `kept — not merged`, jamais forcé.

### Script de livraison

**Appel :** `bash <SKILL_DIR>/scripts/engrave.sh run --root <ROOT> --branch <BRANCH> --message "<message>" --model <identifiant du modèle de la session> [branches citées, dans l'ordre]` — autant de branches qu'en cite l'utilisateur, aucune comprise.

**Le script porte la séquence entière** — ne jamais la recomposer en commandes git à la main :
- `run` → exécute une opération git par action, dans cet ordre : `ignore` et `untrack` seulement quand ils ont à faire, puis `add`, `commit`, `push` de `<BRANCH>` ; pour chaque branche citée, `checkout` de la cible, `merge` de `<BRANCH>` — jamais la branche précédente de la chaîne —, `push` de la cible ; `checkout` final de retour sur `<BRANCH>` dès qu'une branche est citée. Premier échec git → arrêt, erreur git sur la sortie d'erreur ; conflit → dépôt laissé sur la cible, merge en cours.
- JSON de `run`, écrit sur une ligne en succès comme en échec git : `{"branch":"<BRANCH>","status":"done|failed","actions":[{"step":1,"action":"add","branch":"<branche>","status":"<statut>","detail":<détail|null>,"reason":<raison|null>},…],"metrics":{…}}` — `metrics` présent avec `--model` et un dossier `.forge/branch/<BRANCH>/`.
- Statut d'une action : `done` exécutée · `skipped` écartée avant exécution, `reason` dit pourquoi · `failed` en échec, `reason` = `conflict`, `rejected` ou `git error` · `not_run` non exécutée, la séquence s'étant arrêtée avant elle.
- Fichiers locaux de forge — journal de mesure `time-log.jsonl`, fichiers apportés `.forge/branch/*/input/` — jamais commités, quelle que soit la branche de démarrage de `/forge` : `ignore` → règles forge manquantes ajoutées au `.gitignore` par `scripts/checks.sh`, `.gitignore` commité avec la livraison ; `untrack` → ces fichiers encore suivis retirés de l'index (`git rm --cached`), gardés sur disque. Projet sain → aucune des deux, séquence inchangée. L'historique déjà poussé n'est jamais réécrit.
- `detail` d'une action `done` : `ignore` → `.gitignore` ; `untrack` → fichiers retirés, séparés par `, ` ; `commit` → hash court ; `push` → `<remote>: <ancien>..<nouveau>`, `<remote>: up to date` ou `<remote>: new branch` ; `merge` → `fast-forward`, `merge commit <hash court>` ou `already up to date` ; `add` / `checkout` → `null`. Action `failed` sur conflit → fichiers en conflit, séparés par `, `.
- Branche citée égale à `<BRANCH>` → absente des actions. Branche absente → une seule action `merge` en `skipped`, `branch missing`, jamais créée. Branche extraite dans un autre worktree → idem, `checked out in another worktree`. Working tree propre → `add` et `commit` en `skipped`, `nothing to commit`, le `push` reste. Après un échec, une action `skipped` garde son statut et sa raison.
- Sorties : `0` succès · `1` usage ou garde (branche courante différente de `--branch`, message vide ou au-delà de 150 caractères), sans JSON · `2` échec git, JSON écrit.
- `preview` → même liste d'actions en JSON, statut `planned` ou `skipped`, sans rien exécuter — jamais appelé par la Livraison.

### Gabarit — compte rendu de livraison

Gabarit figé de l'étape 5, rempli depuis le JSON de `run` — crochets à remplir, rien d'autre ne change. Un tableau par projet, cinq colonnes dans cet ordre, en-têtes générés dans la langue de l'utilisateur : numéro d'ordre, branche, opération, résultat, détail. Exemple : `grave dev staging master`, `staging` absente, conflit sur `master` ; un projet lié livré sur sa seule branche.

```markdown
| # | [Branche] | [Opération] | [Résultat] | [Détail] |
|---|---|---|---|---|
| 1 | `ship` | `add` | DONE | |
| 2 | `ship` | `commit` | DONE | `a3f9c12` "[message]" |
| 3 | `ship` | `push` | DONE | origin: `9e1b2c4..a3f9c12` |
| 4 | `dev` | `checkout` | DONE | |
| 5 | `dev` | `merge ship` | DONE | fast-forward |
| 6 | `dev` | `push` | DONE | origin: `7d0e3a1..a3f9c12` |
| 7 | `staging` | `merge ship` | SKIPPED | branch missing |
| 8 | `master` | `checkout` | DONE | |
| 9 | `master` | `merge ship` | FAILED | conflict — `README.md`, `CHANGELOG.md` |
| 10 | `master` | `push` | HALTED | |
| 11 | `ship` | `checkout` | HALTED | |

[erreur git telle quelle]

`../my-api`

| # | [Branche] | [Opération] | [Résultat] | [Détail] |
|---|---|---|---|---|
| 1 | `forge/ship` | `add` | DONE | |
| 2 | `forge/ship` | `commit` | DONE | `7be04d1` "[message]" |
| 3 | `forge/ship` | `push` | DONE | origin: new branch |
```

- Une ligne par action du JSON, dans son ordre : `step`, `branch`, `action` — `merge` suivi de la branche fusionnée, `merge <BRANCH>` —, libellé du `status`, puis le détail.
- Libellé du `status`, figé dans toutes les langues — jamais le code brut, jamais traduit : `done` → `DONE` · `skipped` → `SKIPPED` · `failed` → `FAILED` · `not_run` → `HALTED`. Raisons et détails gardés tels que le JSON les donne.
- Détail `done` : `commit` → hash en inline code suivi du message de l'appel entre guillemets ; `push` → `detail` tel quel, plage en inline code ; `merge` → `detail` tel quel ; `detail` à `null` → cellule vide.
- Détail `skipped` → `reason`. Détail `failed` → `reason`, suivie de ` — ` et des fichiers en inline code si `detail` est non nul. Détail `not_run` → cellule vide.
- `status` du JSON à `failed` → erreur git telle quelle sous le tableau.
- Projet lié → une ligne `<LINKED>` seule, puis son tableau au même format, puis sa ligne `worktree` (« Retrait du worktree lié »). Projet lié sans rien à graver → sa ligne "`<LINKED>`: nothing to engrave." à la place du tableau. Projet lié en sortie `1` → sa ligne `<LINKED>`, puis l'erreur telle quelle.

⚠️ JSON jamais affiché brut ; compte rendu jamais complété d'une liste de fichiers — hors fichiers en conflit — ni d'un décompte de lignes, jamais remplacé par une phrase de résumé.
