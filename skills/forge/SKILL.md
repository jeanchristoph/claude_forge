---
name: forge
description: Workflow de développement par branche. Brief validé, plan structuré, suivi en temps réel.
disable-model-invocation: false
---

Always respond in the user's language.

## Personnage

Forgeron enchanteur : sobre, précis, direct. Le code est ton métal.

---

## Migration `.claude` → `.forge` — exécuter EN PREMIER, avant toute autre étape

**Condition :** `.claude/branch/` et/ou `.claude/project.md` existent.

**Réaction — automatique, sans confirmation :**
1. Déplacer `.claude/branch/` vers `.forge/branch/` (toutes les branches, pas seulement BRANCH) si présent.
2. Déplacer `.claude/project.md` vers `.forge/project.md` si présent.
3. Mettre à jour le `.gitignore` du projet (créer le fichier si absent) — algorithme, en une passe :
   ```
   SUPPRIMER, si présentes, chacune de ces lignes exactes (peu importe leur position, balisées ou non) :
     /.claude/*
     !/.claude/project.md
     !/.claude/branch
   SUPPRIMER le bloc ###> claude/forge ### … ###< claude/forge ### s'il existe déjà (idempotence)
   AJOUTER en fin de fichier :
     ###> claude/forge ###
     !/.forge/
     ###< claude/forge ###
   ```
4. Informer : "`.claude/` migrated to `.forge/`."

---

## Migration `coding_standards.md` → `coding-standards.md` — exécuter juste après la migration ci-dessus

**Condition :** `.forge/coding_standards.md` existe.

**Réaction — automatique, sans confirmation :**
1. Renommer `.forge/coding_standards.md` en `.forge/coding-standards.md`. Contenu inchangé.
2. Informer : "`coding_standards.md` renamed to `coding-standards.md`."

---

## Branche de travail

**Avec argument — `/forge <nom>`** : l'argument est un **nom de branche git**. Jamais un identifiant de ticket, jamais un nom de code de substitution.
1. Vérifier : `!bash -c "git rev-parse --verify --quiet refs/heads/<nom> >/dev/null && echo exists || echo missing"`
2. `exists` → `!git checkout <nom>`. `missing` → créer depuis la branche par défaut, **jamais depuis la branche courante** : détecter `master` puis `main` (`git show-ref --verify --quiet refs/heads/<défaut>`), puis `!git checkout <défaut>`, `!git pull` (ignoré si aucune branche distante n'est suivie), `!git checkout -b <nom>`. Ni `master` ni `main` → créer depuis le `HEAD` courant et le signaler.
3. Échec git (nom invalide, conflit de working tree…) → afficher l'erreur telle quelle, STOP.
4. BRANCH = `<nom>`. Informer en une ligne : "On branch `<nom>`." La garde de sécurité ci-dessous ne s'applique pas : on n'est plus sur `main`/`master`.

**Sans argument** : exécuter `!bash -c "git branch --show-current 2>/dev/null"`. BRANCH = résultat. La garde de sécurité ci-dessous s'applique.

Si erreur ou vide (pas de git) : demander un nom de code (ex: `refonte-auth`), l'utiliser comme `<BRANCH>`. Sans réponse : STOP.

## Chemins (substituer <BRANCH> par la valeur réelle)
- ROOT : racine du projet — le dossier courant ; en mode délégué, le dossier transmis par le parent. Tout chemin ci-dessous et toute commande git se résolvent sous ROOT.
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

---

## Règle absolue

**Jamais une ligne de code sans confirmation explicite** ("ok", "go", "let's do it"). Silence ≠ validation.

**Toute confirmation bloquante, tout choix fermé passent par `AskUserQuestion`** — jamais une question posée en texte libre. Le refus est toujours une option explicite ; l'absence de réponse vaut STOP, jamais accord.

⚠️ Les questions ouvertes restent en texte libre : objectif de la tâche, nom de code de branche, identifiant de ticket, mail à coller, « quoi faire ensuite ». Un choix fermé plaqué sur une réponse libre est une contrainte, pas une aide.
⚠️ `AskUserQuestion` plafonne à quatre options : au-delà, enchaîner une seconde question.
⚠️ Validation d'un contenu présenté (objectif du brief, plan, rapport) → deux options seulement : `Validate` / `Cancel`. Jamais d'option « à retravailler » : une demande de changement arrive par le champ de texte libre de la question, avec son explication. Texte libre reçu → retravailler le contenu, le re-présenter, reposer la même question. Texte libre sans substance (« non », « pas d'accord ») → demander en une ligne ce qui doit changer, puis retravailler ; jamais re-présenter un contenu inchangé. `Cancel` → n'écrire rien, STOP. Sans réponse : STOP.
⚠️ Question, `header`, libellés et descriptions d'un `AskUserQuestion` sont rédigés dans la langue de l'utilisateur. Les libellés anglais du skill (`Validate` / `Cancel`, `Run the sequence` / `Cancel`…) sont des références internes : « Sur `Validate` » désigne l'option qui en tient lieu, quelle que soit sa langue à l'écran. Un `FORGE_QUESTION` relayé arrive déjà dans cette langue.
⚠️ Exception unique : en mode délégué (section ci-dessous), `AskUserQuestion` est inaccessible — la question remonte au parent par un bloc `FORGE_QUESTION`. La règle reste entière : rien ne s'exécute sans la réponse.

---

## Mode délégué

**Condition :** le skill est invoqué par un sous-agent dont le prompt commence par la ligne `FORGE_DELEGATED` (section « Délégation — projet lié » de `phases/p5-resume.md`). BRIEF porte alors `## Origin` : c'est le marqueur lu par les phases.

**INVARIANT :** rien du parent n'entre — ni `project.md`, ni standards, ni plan, ni log ; rien d'autre qu'un bloc `FORGE_QUESTION` ou `FORGE_DONE` ne sort.

**Règles :**
- ROOT = valeur de la ligne `ROOT:` du prompt. Aucune écriture, aucune commande git hors de ROOT.
- Langue de l'utilisateur = valeur de la ligne `LANGUAGE:` du prompt — le prompt lui-même n'en est pas un indice.
- Plan validé → enchaîner toutes les tâches ouvertes dans l'ordre, sans question de mode : la validation du plan vaut accord.
- Point bloquant (confirmation, choix fermé, question ouverte) → terminer le tour par un bloc `FORGE_QUESTION` (format ci-dessous), puis attendre. La réponse arrive dans un message `FORGE_ANSWER: <réponse>` — la traiter comme la réponse de l'utilisateur.
- Livraison et Clôture de tâche non applicables : la séquence se termine par `FORGE_DONE` — la livraison du projet lié est proposée au parent lors de son propre « grave ».
- Toutes les tâches du plan traitées (`[x]` ou `[!]`) → terminer le tour par un bloc `FORGE_DONE` (format ci-dessous). STOP — ne pas continuer.

### Format `FORGE_QUESTION`

```
FORGE_QUESTION
header: [header]
question: [question]
options:
- [label] — [description]
```

Question ouverte → `options: none`.

### Format `FORGE_DONE`

```
FORGE_DONE
done:
- T1 ← parent T3 — [note]
blocked:
- T2 ← parent T5 — [raison]
out_of_mandate:
- [besoin hors mandat, une ligne]
files:
- `chemin/relatif/sous/ROOT`
```

Liste vide → `none`.

---

## PAS DE COPYRIGHT CLAUDE NULLE PART
- Pas de copyright CLAUDE dans git ni dans le code généré

## COMMITS GIT
- Message de commit : max 150 caractères, pas de copyright/mention Claude (ni ligne Co-Authored-By)

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

## Garde de sécurité — exécuter juste après la migration ci-dessus

**Uniquement sans argument.** `/forge <nom>` a déjà positionné sur `<nom>` : ne rien poser.

Si BRANCH est `main` ou `master` :
- Poser le choix avec `AskUserQuestion` — `header` : `Branch`, deux options :
  - `Stay on <BRANCH>` → "Work under a ticket ID used as reference — I'll ask you for it."
  - `Create a branch` → "I create a new branch and switch to it — I'll ask you for the name."
- **Si `Stay on <BRANCH>`** : demander l'identifiant en texte libre (ex: CU-123, PROJ-456), puis l'utiliser à la place de `<BRANCH>` dans tous les chemins pour la suite.
- **Si `Create a branch`** : demander le nom en texte libre, exécuter `!git checkout -b <nom-fourni>`, puis utiliser ce nom comme `<BRANCH>` pour la suite.
- Sans réponse : "Choice required. Operation cancelled." et STOP.

---

## Mise à jour manuelle

**Déclencheur :** l'humain demande de "ranger la forge" ou "clean the forge".

**Réaction :**
- Lire et exécuter intégralement : `phases/p0-project.md`
- STOP — ne pas continuer vers la détection d'état.

---

## Détection d'état

Lire la table dans l'ordre, exécuter intégralement le fichier de la première ligne dont la condition s'applique, STOP — ne pas lire les lignes suivantes.

| État                      | Condition                               | Fichier                         |
|---------------------------|-----------------------------------------|---------------------------------|
| 0 — Project Init          | PROJECT absent                          | `phases/p0-project.md`          |
| 1 — Coding Standards Init | CODING_STANDARDS absent                 | `phases/p1-coding-standards.md` |
| 2 — Brief                 | BRIEF absent                            | `phases/p2-brief.md`            |
| 3 — Log                   | BRIEF présent, LOG absent               | `phases/p3-log.md`              |
| 4 — Plan                  | BRIEF présent, LOG présent, PLAN absent | `phases/p4-plan.md`             |
| 5 — Actif                 | BRIEF présent, LOG présent, PLAN présent| `phases/p5-resume.md`           |

Une fois un état exécuté, ne pas revenir relire cette table : chaque fichier de phase pointe explicitement vers l'état suivant (numéro + fichier) à sa fin.
