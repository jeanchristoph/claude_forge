# Livraison

## Livraison — commit, push, merge

**Autorisation :** la commande vaut autorisation pour cette séquence seulement — aucune confirmation avant `run`. Les questions `Linked` / `Linked branches` de l'étape 2 restent posées : elles fixent le périmètre, elles ne confirment rien.

**INVARIANT :** git opère uniquement sur le dépôt courant — jamais sur un autre dépôt ouvert en parallèle. Unique exception : `<LINKED>`, pour la création du worktree par la « Délégation — projet lié » de `commands/delegation.md` et pour la livraison relayée ci-dessous — rien d'autre.

**Publication hors dépôt :** tout texte publié sur la forge distante à la suite d'une livraison — titre et notes d'une release, description d'un tag ou d'une PR — est rédigé en **anglais**, quelle que soit la langue de l'utilisateur. Le message de commit, lui, suit la langue des commits du dépôt.

⚠️ Sortie `2` du script (conflit de merge, push rejeté) → séquence déjà arrêtée par le script ; ne rien forcer : jamais de `--force`, jamais de résolution de conflit sans demande.

Mode délégué `SCOPE: branch` → `--root` vaut ROOT (le worktree) ; compte rendu de livraison recopié entier dans le `content` du bloc qui termine le tour. `SCOPE: linked` → Livraison non applicable (section « Mode délégué » de `SKILL.md`).

**Réaction — dans l'ordre :**
0. Écrire la « Synthèse de mesure — `metrics.json` » ci-dessous : elle part avec le commit.
1. Générer automatiquement le message de commit (règles COMMITS GIT : max 150 car., pas de mention Claude) — pas de confirmation sur le message lui-même.
2. Livraison relayée — pour chaque projet lié (ci-dessous) : poser les deux questions, retenir la séquence du lié.
3. Exécuter aussitôt le script en `run` pour le parent (« Script de livraison » ci-dessous), sans question ni affichage préalable.
   - Sortie `0` → étape 4.
   - Sortie `1` → afficher l'erreur telle quelle, aucun projet lié livré. STOP — ne pas continuer.
   - Sortie `2` → rendre compte du parent selon le « Gabarit — compte rendu de livraison » ci-dessous, erreur git telle quelle sous le tableau, aucun projet lié livré. STOP — ne pas continuer.
4. Pour chaque projet lié retenu, dans l'ordre du plan : exécuter le script en `run` avec ses arguments. Sortie `1` → retenir l'erreur ; sortie `2` → retenir le JSON et l'erreur. Passer au projet lié suivant ; le parent, déjà livré, n'est jamais repris.
5. Rendre compte depuis le JSON de chaque `run`, parent puis chaque projet lié, selon le « Gabarit — compte rendu de livraison » ci-dessous.

⚠️ Aucune écriture dans LOG ni PLAN après la séquence — le compte rendu est du texte seul, le working tree reste tel que la livraison l'a laissé. Ce qui doit être journalisé l'est avant le `git add`.

### Synthèse de mesure — `metrics.json`

**Déclencheur :** étape 0 de la Livraison, étape 1 de la Clôture sur `Solved` (`commands/closure.md`), fusion d'une branche fille d'essaim (`commands/swarm.md`).

**Réaction — dans l'ordre :**
1. Exécuter `bash <SKILL_DIR>/scripts/time-aggregate.sh --root <ROOT> --branch <BRANCH>`. Branche fille d'un essaim → ajouter `--parent-log <dépôt principal>/.forge/branch/<PARENT>/time-log.jsonl --base <PARENT>`.
2. `planned_files` = somme des `**Estimated files:**` des tâches de PLAN ; aucun champ → `null`.
3. Écrire `.forge/branch/<BRANCH>/metrics.json` — un seul objet JSON sur une ligne, fichier réécrit à chaque passage, valeurs cumulées depuis le début de la branche, l'historique restant dans git. Champs dans cet ordre, libellés figés :
   `event` (`engrave` / `closure`), `date` (`AAAA-MM-JJ`), `branch`, `mode`, `model` (identifiant du modèle de la session), `planned_files`, `actual_files` (`files`), `lines_added`, `lines_deleted`, `agent_minutes` (`parent_minutes` + `delegated_minutes`, `null` si les deux le sont), `human_minutes`, `questions`, `check_minutes`, `tokens`, `partial` (repris tel quel : `true` quand le journal ne couvre pas le début de la branche — durées gardées, branche écartée du calibrage).
4. Exécuter `bash <SKILL_DIR>/scripts/time-calibrate.sh --root <ROOT>`. `source` à `project` et ratios différents de la ligne `**Estimation ratios:**` de `.forge/project.md` → réécrire cette ligne, sous `## Tools & access` : `**Estimation ratios:** <minutes_per_file> min/file · <tokens_per_file> tokens/file · <measured_branches> measured branches`, puis une entrée LOG avec l'ancienne valeur.
5. Compte rendu de la Livraison : une ligne sous le tableau, estimé et réel côte à côte — `Estimated ≈ <planned_files> files · ≈ <min> min (<bas>-<haut>) · actual <actual_files> files · <agent_minutes> min` ; estimé tiré de l'en-tête `**Estimate:**` de PLAN (étape 6 de `phases/p4-plan.md`), valeur absente → `—`. `partial` à `true` → ajouter ` · partial measure`.

⚠️ `time-log.jsonl` (événements bruts) reste local, ignoré par git ; seul `metrics.json` est versionné.
⚠️ Aucune heure, aucune durée estimée à la main : sans journal, les durées restent `null`.

### Livraison relayée — projets liés

**Déclencheur :** PLAN parent porte au moins une note `delegated to <LINKED_REL> @ <LINKED_BRANCH>` (« Délégation — projet lié » de `commands/delegation.md`). Aucune → étape 2 silencieuse, jamais mentionnée.

**Vocabulaire :** `<LINKED>` = `<LINKED_REL>` de la note, résolu depuis ROOT ; une ancienne note à chemin absolu reste lue telle quelle · `<LINKED_GIT>` = dossier où la branche liée est extraite — le worktree qui porte `branch refs/heads/<LINKED_BRANCH>` dans `git -C <LINKED> worktree list --porcelain` ; aucun → `<LINKED>` lui-même (délégation ouverte avant les worktrees).

**Pour chaque `<LINKED>` distinct, dans l'ordre du plan :**
- `git -C <LINKED_GIT> status --porcelain` vide → ignorer sans question. Une ligne au rendu final : "`<LINKED>`: nothing to engrave."
- Sinon → poser le choix avec `AskUserQuestion` — `header` : `Linked`, question "Also engrave `<LINKED>` @ `<LINKED_BRANCH>`?", options `Engrave it` / `Skip`.
- **Sur `Skip`** → projet lié écarté de la séquence, sans commentaire.
- **Sur `Engrave it`** → poser le choix des branches avec `AskUserQuestion` — `header` : `Linked branches`, options dans cet ordre :
  - `Same branches as the parent` → "[branches citées du parent, dans l'ordre]" — omise si le parent n'en cite aucune.
  - `<LINKED_BRANCH> only` → "Commit and push `<LINKED_BRANCH>`, no merge."
  - `Other branches` → "I'll ask you which ones." — puis demander en texte libre, dans l'ordre voulu.
- Message de commit du lié : généré depuis les tâches du mandat cochées `[x]` avec sa note `delegated to <LINKED_REL>` — jamais depuis le code de `<LINKED>`, que le parent ne lit pas. Langue : celle des commits de `<LINKED>` (`git -C <LINKED> log -5 --format=%s`).
- Script du lié : `--root <LINKED_GIT>`, `--branch <LINKED_BRANCH>`, son message, ses branches retenues.

⚠️ Le sous-agent délégué n'est jamais sollicité pour livrer : la livraison relayée est du git pur, exécuté par le parent.

### Script de livraison

**Appel :** `bash <SKILL_DIR>/scripts/engrave.sh run --root <ROOT> --branch <BRANCH> --message "<message>" [branches citées, dans l'ordre]` — autant de branches qu'en cite l'utilisateur, aucune comprise.

**Le script porte la séquence entière** — ne jamais la recomposer en commandes git à la main :
- `run` → exécute une opération git par action, dans cet ordre : `add`, `commit`, `push` de `<BRANCH>` ; pour chaque branche citée, `checkout` de la cible, `merge` de `<BRANCH>` — jamais la branche précédente de la chaîne —, `push` de la cible ; `checkout` final de retour sur `<BRANCH>` dès qu'une branche est citée. Premier échec git → arrêt, erreur git sur la sortie d'erreur ; conflit → dépôt laissé sur la cible, merge en cours.
- JSON de `run`, écrit sur une ligne en succès comme en échec git : `{"branch":"<BRANCH>","status":"done|failed","actions":[{"step":1,"action":"add","branch":"<branche>","status":"<statut>","detail":<détail|null>,"reason":<raison|null>},…]}`.
- Statut d'une action : `done` exécutée · `skipped` écartée avant exécution, `reason` dit pourquoi · `failed` en échec, `reason` = `conflict`, `rejected` ou `git error` · `not_run` non exécutée, la séquence s'étant arrêtée avant elle.
- `detail` d'une action `done` : `commit` → hash court ; `push` → `<remote>: <ancien>..<nouveau>`, `<remote>: up to date` ou `<remote>: new branch` ; `merge` → `fast-forward`, `merge commit <hash court>` ou `already up to date` ; `add` / `checkout` → `null`. Action `failed` sur conflit → fichiers en conflit, séparés par `, `.
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
- Projet lié → une ligne `<LINKED>` seule, puis son tableau au même format. Projet lié sans rien à graver → sa ligne "`<LINKED>`: nothing to engrave." à la place du tableau. Projet lié en sortie `1` → sa ligne `<LINKED>`, puis l'erreur telle quelle.

⚠️ JSON jamais affiché brut ; compte rendu jamais complété d'une liste de fichiers — hors fichiers en conflit — ni d'un décompte de lignes, jamais remplacé par une phrase de résumé.
