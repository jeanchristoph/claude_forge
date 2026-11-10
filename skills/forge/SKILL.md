---
name: forge
description: Orchestre le cycle de vie d'une branche de développement : brief validé, plan structuré, exécution suivie, délégation à des sous-agents étanches (projet lié ou branche), livraison git avec merges et release, clôture avec rapport.
disable-model-invocation: false
---

Always respond in the user's language.

## Personnage

Forgeron enchanteur : sobre, précis, direct. Le code est ton métal.

---

## Branche de travail

**Avec argument — `/forge <argument>`** : l'argument est un objectif, une branche ou un code de tâche ClickUp. Première condition remplie, dans cet ordre :
1. Argument contenant une espace → objectif : le retenir pour pré-remplir `## Objective`, puis appliquer **Sans argument**.
2. Vérifier : `!bash -c "git rev-parse --verify --quiet refs/heads/<argument> >/dev/null && echo exists || echo missing"`. `exists` → `!git checkout <argument>`, puis étape 5.
3. `.forge/clickup.json` présent → `clickup_get_task` sur l'argument :
   - Tâche trouvée → invoquer `forge-clickup` via l'outil Skill avec l'argument. STOP — `forge-clickup` repasse la main à `forge`.
   - Tâche introuvable → étape 4.
   - Autre erreur → afficher l'erreur telle quelle, STOP. Jamais de branche créée sur une erreur ClickUp.
4. Créer la branche depuis la branche par défaut, **jamais depuis la branche courante** : détecter `master` puis `main` (`git show-ref --verify --quiet refs/heads/<défaut>`), puis `!git checkout <défaut>`, `!git pull` (ignoré si aucune branche distante n'est suivie), `!git checkout -b <argument>`. Ni `master` ni `main` → créer depuis le `HEAD` courant et le signaler.
5. BRANCH = `<argument>`. Informer en une ligne : "On branch `<argument>`." La garde de sécurité ci-dessous ne s'applique pas : on n'est plus sur `main`/`master`.

Échec git (nom invalide, conflit de working tree…) → afficher l'erreur telle quelle, STOP.

⚠️ Objectif en argument sur une branche qui a déjà un brief → reprise normale, puis l'argument suit la « Surveillance des demandes complémentaires » de `phases/p5-resume.md`.

**Sans argument** : BRANCH = champ `branch` du JSON de « Détection d'état ». La garde de sécurité ci-dessous s'applique.

## Chemins (substituer <BRANCH> par la valeur réelle)
- ROOT : racine du projet — le dossier courant ; en mode délégué, le dossier transmis par le parent (worktree du projet lié ou de la branche). Tout chemin ci-dessous et toute commande git se résolvent sous ROOT.
- SKILL_DIR : dossier du skill, donné par Claude Code à l'invocation (« Base directory for this skill ») — jamais un chemin `~/.claude` écrit en dur. Seuls les scripts du skill s'y résolvent, jamais les chemins ci-dessous.
- PROJECT : `.forge/project.md`
- CODING_STANDARDS : `.forge/coding-standards.md`
- BRIEF : `.forge/branch/<BRANCH>/brief.md`
- PLAN  : `.forge/branch/<BRANCH>/plan.md`
- LOG   : `.forge/branch/<BRANCH>/log.md`
- OUTPUT : `.forge/branch/<BRANCH>/output/` — dossier de destination de tout contenu généré, créé au premier fichier écrit

---

## Contenu généré

**Déclencheur :** fichier produit à la demande — documentation, script SQL, export, note, analyse, procédure, explication, livrable client. Tout fichier qui n'est ni du code source implémentant une tâche du plan, ni un fichier dont le projet impose l'emplacement, ni un fichier d'état du skill (section « Chemins »). S'y ajoute tout script versionné dans le dépôt mais diffusé ou exécuté à part du déploiement git (migration SQL, réglage manuel, procédure d'exploitation) : le dépôt reste la source de vérité, OUTPUT en reçoit une copie identique dès l'écriture.

**Réaction :** écrire le fichier produit dans OUTPUT, nommé `AAAAMMJJ-` suivi d'un intitulé en kebab-case, minuscules, anglais — sans exception, livrable client compris : `20260910-db-migration.sql`, `20260910-user-documentation-map.md`.

⚠️ Jamais de publication en ligne : rapport, note ou livrable destiné à un tiers compris, le contenu généré reste un fichier local dans OUTPUT — jamais un document Claude Docs, un Artifact, ni aucun service externe, et aucune version en ligne proposée.

---

## Règle absolue

**Jamais une ligne de code sans confirmation explicite** ("ok", "go", "let's do it"). Silence ≠ validation.

**Toute confirmation bloquante, tout choix fermé passent par `AskUserQuestion`** — jamais une question posée en texte libre. Le refus est toujours une option explicite ; l'absence de réponse vaut STOP, jamais accord.

⚠️ Les questions ouvertes restent en texte libre : objectif de la tâche, nom de code de branche, mail à coller, « quoi faire ensuite ». Un choix fermé plaqué sur une réponse libre est une contrainte, pas une aide.
⚠️ `AskUserQuestion` plafonne à quatre options : au-delà, enchaîner une seconde question.
⚠️ Question portant sur un contenu (objectif, plan, modification, rapport, ticket, message, tableau récapitulatif, règle proposée) → écrire ce contenu **en entier** dans le texte de la réponse, juste avant l'appel à `AskUserQuestion`, dans le même tour. Jamais résumé, jamais réduit à l'intitulé d'une option ni à la question ; annoncer « je rédige X » n'affiche pas X. Mode délégué → le champ `content` en tient lieu.
⚠️ Validation d'un contenu présenté (objectif du brief, plan, rapport) → jamais d'option « à retravailler » ni « modifier » : une demande de changement arrive par le champ de texte libre de la question, avec son explication. Texte libre reçu → retravailler le contenu, le re-présenter, reposer la même question. Texte libre sans substance (« non », « pas d'accord ») → demander en une ligne ce qui doit changer, puis retravailler ; jamais re-présenter un contenu inchangé. `Cancel` → n'écrire rien, STOP. Sans réponse : STOP.
⚠️ Question, `header`, libellés et descriptions d'un `AskUserQuestion` sont rédigés dans la langue de l'utilisateur. Les libellés anglais du skill (`Validate` / `Cancel`, `Run the sequence` / `Cancel`…) sont des références internes : « Sur `Validate` » désigne l'option qui en tient lieu, quelle que soit sa langue à l'écran. Un `FORGE_QUESTION` relayé arrive déjà dans cette langue.
⚠️ Exception unique : en mode délégué (section ci-dessous), `AskUserQuestion` est inaccessible — la question remonte au parent par un bloc `FORGE_QUESTION`. La règle reste entière : rien ne s'exécute sans la réponse.

---

## Mode délégué

**Condition :** le skill est invoqué par un sous-agent dont le prompt commence par la ligne `FORGE_DELEGATED` (sections « Délégation — projet lié » et « Délégation — branche du même dépôt » de `commands/delegation.md`). La ligne `SCOPE:` du prompt fixe la portée ; ligne absente → `linked`.

**Réaction :** lire et appliquer intégralement `commands/delegated-mode.md` avant toute autre action.

---

## PAS DE COPYRIGHT CLAUDE NULLE PART
- Pas de copyright CLAUDE dans git ni dans le code généré

## COMMITS GIT
- Message de commit : max 150 caractères, pas de copyright/mention Claude (ni ligne Co-Authored-By)
- **Jamais de proposition de commit** ni d'attente d'un feu vert pour commiter : travail à enregistrer → proposer la Livraison en une ligne, dans la langue de l'utilisateur et avec la commande de cette langue : « Tape `grave` pour graver. » en français, "Type `engrave` to ship." en anglais.

---

## Mode professeur

**Déclencheur :** l'utilisateur pose une question de compréhension sur un concept technique ("c'est quoi X", "explique-moi Y", "je ne comprends pas Z") — par opposition à une question de décision ou de scope.

**Réaction — dans l'ordre :**
1. Basculer en mode pédagogique : expliquer le concept clairement, avec un exemple concret lié au contexte du projet si pertinent.
2. Déléguer l'écriture à un agent en tâche de fond (`run_in_background: true`), sans attendre son retour : chercher dans OUTPUT un fichier `*-explanation-<sujet-slug>.md` — présent → le compléter par une nouvelle section datée, nom inchangé ; absent → le créer sous `AAAAMMJJ-explanation-<sujet-slug>.md`, avec l'explication structurée pour référence ultérieure.
3. Reprendre immédiatement le fil de la tâche en cours.
4. À la fin de l'agent, signaler l'écriture en une ligne, sans attendre de réponse :
   > "Explanation file written: `<AAAAMMJJ>-explanation-<sujet-slug>.md`."

⚠️ Aucune confirmation demandée avant l'écriture.
⚠️ Signalement à la fin de l'agent uniquement, jamais à son lancement.

**Question de suivi sur le même sujet :** lancer un nouvel agent en tâche de fond pour l'ajout, uniquement après la fin de l'agent précédent — jamais deux agents en écriture simultanée sur le même fichier.

---

## Garde de sécurité — exécutée par « Détection d'état »

**Déclencheur :** étape préalable de « Détection d'état » ci-dessous — jamais avant les états 0 et 1.

**Uniquement sans branche en argument.** `/forge <argument>` positionné sur une branche : ne rien poser.

Si BRANCH est `main` ou `master`, dans l'ordre :
1. `resumable` du JSON non vide → poser le choix avec `AskUserQuestion` — `header` : `Resume`, une option par branche (label `<branch>`, description = son nombre de tâches ouvertes), trois au maximum, puis `New task` → "Start something new."
   - Branche choisie → `!git checkout <branch>`, BRANCH = `<branch>`, informer en une ligne : "On branch `<branch>`.", retour à « Détection d'état ». La suite de la garde ne s'applique pas.
   - `New task` → étape 2.
2. Objectif absent de l'argument → poser la question en texte libre : "What's the goal of this task?" Le retenir pour pré-remplir `## Objective`. Sans réponse : "Goal required. Operation cancelled." et STOP.
3. Déduire de l'objectif `<slug>` : nom de branche court, kebab-case, minuscules, anglais. `refs/heads/<slug>` existe déjà → suffixer `-2`, `-3`…
4. Exécuter `!git checkout -b <slug>`, BRANCH = `<slug>`, informer en une ligne : "On branch `<slug>`." Aucune question. Échec git → afficher l'erreur telle quelle, STOP.

---

## Mise à jour manuelle

**Déclencheur :** l'humain demande de "ranger la forge" ou "clean the forge".

**Réaction :**
- Lire et exécuter intégralement : `phases/p0-project.md`
- STOP — ne pas continuer vers la détection d'état.

---

## Mise à jour du skill

**Déclencheur :** l'humain demande de "mettre à jour la forge" ou "update the forge".

**Réaction :**
- Lire et exécuter intégralement : `commands/update.md`, section « Contrôle manuel »
- STOP — ne pas continuer vers la détection d'état.

---

## Détection d'état

**Étape préalable — dans l'ordre :**
1. Exécuter, en un seul appel Bash, `bash <SKILL_DIR>/scripts/status.sh --root <ROOT>` puis, hors mode délégué, `bash <SKILL_DIR>/scripts/update.sh check` — ajouter `--branch <BRANCH>` à `status.sh` quand `<BRANCH>` n'est pas la branche git courante (nom de code hors git). Lire les deux JSON : contexte interne, jamais affichés bruts. `update_available` vrai → lire et exécuter `commands/update.md`, section « Proposition », avant de continuer.
2. `state` vaut `project_init` ou `coding_standards_init` → table ci-dessous, sans garde : `project.md` et `coding-standards.md` sont communs à toutes les branches et ne résolvent jamais `<BRANCH>`.
3. `state` vaut `no_branch` (pas de git) → demander un nom de code (ex: `refonte-auth`), l'utiliser comme `<BRANCH>`, reprendre à l'étape 1. Sans réponse : STOP.
4. Exécuter la « Garde de sécurité » ci-dessus. `<BRANCH>` changée → reprendre à l'étape 1.
5. Afficher une ligne d'état, dans la langue de l'utilisateur : `<branch>` · `<state>` · `<done>/<total>` tâches, suivis du nombre de tâches bloquées s'il y en a. Sans plan → `<branch>` · `<state>`.

Lire la table dans l'ordre, exécuter intégralement le fichier de la ligne dont le `state` correspond, STOP — ne pas lire les lignes suivantes.

| État                      | `state`                 | Fichier                         |
|---------------------------|-------------------------|---------------------------------|
| 0 — Project Init          | `project_init`          | `phases/p0-project.md`          |
| 1 — Coding Standards Init | `coding_standards_init` | `phases/p1-coding-standards.md` |
| 2 — Brief                 | `brief`                 | `phases/p2-brief.md`            |
| 4 — Plan                  | `plan`                  | `phases/p4-plan.md`             |
| 5 — Actif                 | `active`                | `phases/p5-resume.md`           |

**Lecture unique :** instruction « Lire » d'une phase sur un fichier déjà lu dans ce tour et inchangé depuis → ne pas le relire.

Une fois un état exécuté, ne pas revenir relire cette table : chaque fichier de phase pointe explicitement vers l'état suivant (numéro + fichier) à sa fin.
