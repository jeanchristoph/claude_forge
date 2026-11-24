# Essaim

**Vocabulaire :** `<PARENT_BRANCH>` = BRANCH, branche qui porte le plan de branches · *unité* = délégué de l'essaim, `type` du JSON de `swarm-status.sh` : `child` = branche fille `<X>`, même dépôt ; `linked` = branche liée, tâches ouvertes au même `**Linked branch:** <LINKED_REL> @ <LINKED_BRANCH>`, autre dépôt (« Délégation — projet lié » de `commands/delegation.md`) · `<X>` = branche fille, tâche `### Tn — Branch <X>` de PLAN · `<WORKTREE>` = `<dossier-du-dépôt>.worktrees/<X>`, chaque `/` gardé comme sous-dossier ; écrit dans SWARM relatif à ROOT (`../forge.worktrees/<X>`) — « Délégation — projet lié » de `commands/delegation.md`, invariant des chemins · N = nombre de délégués en cours, `**N:**` de SWARM, 3 par défaut · SWARM = `.forge/branch/<PARENT_BRANCH>/swarm.md` · TIME_LOG = `.forge/branch/<PARENT_BRANCH>/time-log.jsonl`.

**INVARIANT :** unité `linked` → jamais fusionnée par le parent : sa branche est livrée par la « Livraison relayée » de `commands/engrave.md`. Unité `child` → le parent seul fusionne, dans `<PARENT_BRANCH>` seulement — jamais de push, jamais de fusion vers la branche par défaut : `<PARENT_BRANCH>` est livrée par la Livraison, sur décision de l'utilisateur. Le dépôt principal reste extrait sur `<PARENT_BRANCH>`.

⚠️ N ne change que sur demande explicite de l'utilisateur (« passe à 2 ») : écrit dans SWARM, jamais demandé.

---

## Délégation — essaim de branches filles

**Déclencheur :** `Validate and launch the swarm` (plan neuf de `phases/p4-plan.md`, ajout de tâches de `phases/p5-resume.md`), demande explicite de lancer des branches filles, réponse `Launch` à « Relance de l'essaim » (`phases/p5-resume.md`), étape 5 de « Fin d'une branche fille ». Chacun est un choix de l'utilisateur et vaut confirmation : aucune autre question avant le lancement. Jamais de lancement sans l'un d'eux — une reprise de session n'en est pas un.

**Réaction — dans l'ordre :**
1. Exécuter `bash <SKILL_DIR>/scripts/swarm-status.sh --root <ROOT> --branch <PARENT_BRANCH>`.
2. Une ligne par branche de `waiting` : "`<X>` waits for `<dépendances>`." Une ligne par branche de `launchable` en `conflict` : "`<X>` not launched: conflict with `<PARENT_BRANCH>` on `<fichiers>`." — écartée, jamais lancée sans accord ; `conflict` à `null` : "`<X>` not launched: merge simulation failed." Puis, sans rien lancer à leur place :
   - `invalid` → une ligne par tâche : "T<n> can never start: `<dependency>` <unknown | blocked | dropped | in a dependency cycle | is not a valid branch name>." — correction du plan proposée (« Règles de mise à jour du plan » de `phases/p5-resume.md`) ;
   - `blocked` → "`<X>` is blocked." ;
   - `stale` → "`<X>`: worktree `<worktree>` removed by hand." et proposer `git worktree prune`, exécuté seulement sur accord.
3. Retenir, dans l'ordre du plan, les `slots` premières unités de `launchable` sans conflit, `child` et `linked` confondues. Aucune → "Nothing to launch." puis « Plan mixte — travail du parent ».
   - Unité `linked` → étapes 4 et 8 de « Délégation — projet lié » (`commands/delegation.md`) : worktree, mandat, log, marque, prompt `SCOPE: linked` ; `forged` faux → « Projet lié non forgé ». Sans la confirmation `Delegate` de son étape 6 : le choix de l'essaim vaut accord. Les étapes 4 et 5 ci-dessous ne valent que pour les unités `child`.
4. Commande d'installation : ligne `**Install command:**` de `## Tools & access` de `project.md`. Absente et manifeste de dépendances présent (`package.json`, `composer.json`, `pyproject.toml`…) → la demander une fois en texte libre, l'écrire dans `project.md`. Aucun manifeste → aucune installation. Port de base : ligne `**Dev port:**` du même bloc, absente → aucun port attribué.
5. Pour chaque branche retenue, dans l'ordre — premier échec git → erreur affichée telle quelle, branche écartée, suivante :
   - `exists` faux → `git branch <X> <PARENT_BRANCH>` ;
   - `git worktree add "<WORKTREE>" <X>`, puis `git -C "<WORKTREE>" merge --no-edit <PARENT_BRANCH>` — dans le worktree : le dépôt principal porte souvent des fichiers d'état modifiés ;
   - `<WORKTREE>/.forge/branch/<X>/brief.md` absent → l'écrire : `## Objective` = `**Brief:**` et `**Description:**` de la tâche, `## Scope & rules` = celui du brief de `<PARENT_BRANCH>` ; `log.md` vide et dossier vide `input/` à côté ;
   - commande d'installation exécutée dans `<WORKTREE>`, fichier de verrouillage respecté, aucune mise à jour de version ;
   - port de la branche = plus petit port libre de port de base + 1 à port de base + N, libre = absent de la colonne `Port` de SWARM ; sur `127.0.0.1` seulement, gardé jusqu'au retrait du worktree.
6. Afficher le tableau de lancement : une ligne par action, colonnes numéro, branche, action, détail, en-têtes dans la langue de l'utilisateur. Actions — aucune autre : `branch`, `worktree`, `merge <PARENT_BRANCH>`, `brief`, `install`, `agent` ; unité `linked`, branche affichée `<LINKED_REL> @ <LINKED_BRANCH>` : `worktree`, `brief` (mandat), `log`, `mark`, `forge` (projet non forgé), `agent`.
7. Lancer tous les délégués dans le même tour, en tâche de fond (« Prompt du délégué »). Pour chacun, « Mesure d'un délégué » de `commands/delegation.md` ; son identifiant va dans la colonne `Agent` de SWARM.
8. Réécrire SWARM (« Fichier d'état — `swarm.md` »), entrée LOG : `Swarm launched: <X>, <Y> ; waiting: <W> (<V>)`.
9. Entrer dans la « Boucle de relais de l'essaim », et exécuter en parallèle le « Plan mixte — travail du parent ».

⚠️ `<WORKTREE>` porte sa propre installation : jamais de lien vers les dépendances du dépôt principal.
⚠️ Chemins de worktree toujours entre guillemets dans les commandes : le dossier du dépôt peut contenir une espace.

### Prompt du délégué

Unité `linked` → « Prompt du sous-agent » de « Délégation — projet lié » (`commands/delegation.md`), tel quel. Unité `child` → un sous-agent, type général, lancé en tâche de fond. Prompt figé — rien d'autre n'est transmis, `RESUME:` seulement à la reprise :

```
FORGE_DELEGATED
ROOT: <WORKTREE>
BRANCH: <X>
LANGUAGE: <langue de l'utilisateur>
SCOPE: branch
TIME_LOG: <chemin absolu de TIME_LOG>
SWARM: <PARENT_BRANCH>
SCRATCHPAD: <scratchpad>/<X>/
PORT: <port de la branche, ou none>
RESUME: <état de la reprise, ou none>
Invoke the `forge` skill with argument `<X>`. Resolve every path and every git command under ROOT.
Delegated mode applies (section « Mode délégué » of the skill): never call AskUserQuestion.
Write every file content and every report in LANGUAGE; structure labels stay in English.
End every turn with a FORGE_QUESTION or a FORGE_DONE block.
```

---

## Boucle de relais de l'essaim

Boucle de relais de `commands/delegation.md`, avec ces règles en plus :
- **Mesure :** chaque retour d'un délégué → « Mesure d'un délégué » de `commands/delegation.md`.
- **Préfixe :** règle « Préfixe » de la boucle de relais de `commands/delegation.md`, pour chaque question ; chaque contenu affiché commence par le même préfixe.
- **Contexte de décision :** `FORGE_QUESTION` de choix — tout `header` autre que `Brief`, `Plan`, `Mode`, `Task`, `Promotion`, `Demote` — sans ce que fait l'existant, ce que chaque option change pour l'utilisateur final et ce qu'il faudrait refaire si le choix s'avère mauvais → renvoyée au délégué, `FORGE_ANSWER: add the decision context (current behaviour, effect of each option for the end user, cost of a wrong choice) and ask again.`, jamais posée.
- **Questions groupées :** plusieurs `FORGE_QUESTION` en attente → afficher le `content` entier de chacune, dans l'ordre d'arrivée, chaque bloc titré `[<X>]`, puis une seule `AskUserQuestion` qui porte jusqu'à quatre questions, une par branche. Question arrivée pendant qu'une fenêtre est ouverte → attend la suivante. Chaque réponse renvoyée à son seul délégué.
- **Note de coordination :** une autre branche en cours touche le même module ou les mêmes fichiers partagés → ajouter à la réponse « `<Y>` also changes `<module>`: separate files, minimal edits to shared files. », notée dans SWARM.
- **Choix voisins :** question proche d'un choix déjà tranché pour une autre branche (`## Choices sent to delegates` de SWARM) → le rappeler sous la question, sans répondre à la place de l'utilisateur.
- **Enchaînement :** réponse « enchaîne » à un feu vert de tâche → transmise `FORGE_ANSWER: chain the remaining tasks without asking for a green light; raise only design, architecture, security or access-rights choices, or blockers.`
- **Promotion :** `FORGE_QUESTION` `header` `Promotion` acceptée → la tâche quitte le plan fils (le délégué la retire), entre au plan parent en tâche-branche avec `**Depends on:** <X>` ; lancée à son tour par l'essaim.
- **Rétrogradation :** plan d'une branche fille validé avec moins de trois tâches → le signaler en une ligne et proposer, par `AskUserQuestion` — `header` : `Demote`, options `Keep the branch` / `Turn into a task` —, d'en faire une tâche ordinaire de `<PARENT_BRANCH>`. Sur `Turn into a task`, dans l'ordre :
  1. `FORGE_ANSWER: stop here: the branch becomes a task of the parent. Leave every file as it is and end with FORGE_DONE.` ; attendre son `FORGE_DONE`.
  2. `git -C "<WORKTREE>" status --porcelain` vide → « Retrait d'un worktree de branche fille », puis `git branch -d <X>`. Sinon → fichiers affichés, rien retiré ni supprimé sans accord.
  3. PLAN : la tâche-branche réécrite en tâche ordinaire — titre sans `Branch <X>`, `**Files:**` repris du plan fils, ses tâches dans `**Description:**` ; « Règles de mise à jour du plan » de `phases/p5-resume.md`, question `Plan`. La tâche est prise par le parent (« Plan mixte — travail du parent »). Ligne retirée de SWARM.
- Chaque choix transmis → ligne dans `## Choices sent to delegates` de SWARM.
- `FORGE_DONE` d'une unité `child` → « Fin d'une branche fille ».
- `FORGE_DONE` d'une unité `linked` → « Retour — application de `FORGE_DONE` » de `commands/delegation.md`, aucune fusion ; ligne retirée de SWARM ; place libérée → « Délégation — essaim de branches filles », étape 1, sans question : le choix de l'essaim vaut pour toutes ses unités.

⚠️ Relais avant tout : la notification d'un délégué (`FORGE_QUESTION`, `FORGE_DONE`) arrive entre deux appels d'outils, au milieu d'une tâche du parent comprise. Notification reçue → terminer l'action en cours, relayer aussitôt, puis reprendre la tâche du parent là où elle s'est arrêtée.

---

## Fin d'une branche fille

**Réaction — dans l'ordre :**
1. Compte rendu préfixé `[<X>]` : tâches faites et bloquées, vérifications, écarts au brief, fichiers déjà validés modifiés, étapes de déploiement, points ouverts.
2. Calculer sans rien écrire : type de fusion attendu (avance rapide si `<PARENT_BRANCH>` est ancêtre de `<X>`, sinon fusion inverse, avec les fichiers partagés avec les fusions déjà faites), puis les branches lançables après cette fusion (`swarm-status.sh --assume-done <X>`).
3. Une seule `AskUserQuestion`, à choix unique — `header` : `Next`, question préfixée `[<X>]` :
   - `Merge and launch <Y>` → une seule option, en tête et recommandée : `<Y>` = les places libres remplies par les lançables dans l'ordre du plan ; les autres lançables citées dans sa description ;
   - `Merge` → fusion dans `<PARENT_BRANCH>` seulement, aucune branche lancée ;
   - `Check before merging` → le parent lance l'application du worktree sur le port de la branche, donne l'adresse, puis repose cette question — seulement quand la branche a un port (`**Dev port:**` dans `project.md`) ;
   - `Do nothing` → branche laissée dans son worktree, non commitée, tâche non cochée.
   Toute option de fusion commite — le travail de `<X>` dans son worktree, et d'abord la tâche du parent en cours s'il y en a une : sa description le dit, avec les fichiers non suivis que `add -A` embarquerait. Quatre options au plus — limite d'`AskUserQuestion`. Aucune branche lançable → sans l'option `Merge and launch`, avec la ligne « no launchable branch: `<Z>` waits for `<W>` ». Tâche ordinaire du parent en cours → option de fusion libellée « after T<m> ». Fusion qui débloque une tâche ordinaire → la citer dans la description.
4. Option de fusion → « Fusion d'une branche fille ». Conflit qui n'est pas un simple ajout, ou vérification rouge → arrêt, question ; tâche non cochée, aucune branche lancée.
5. Fusion réussie et branche choisie → « Délégation — essaim de branches filles », étape 1.

---

## Fusion d'une branche fille

**Déclencheur :** option de fusion de « Fin d'une branche fille », ou demande explicite de l'utilisateur. Autorisation pour cette séquence seulement.

**Réaction — dans l'ordre :**
1. Tâche du parent avec des modifications non commitées → la terminer et la commiter d'abord : jamais de fusion par-dessus.
2. Entrée LOG de `<X>`, `--root <WORKTREE> --branch <X>` : `Done, merged into <PARENT_BRANCH>`. « Synthèse de mesure — `metrics.json` » de `commands/engrave.md` sous `--root <WORKTREE>`, avec `--parent-log` et `--base <PARENT_BRANCH>`. Puis `git -C "<WORKTREE>" status --porcelain` affiché : fichier non suivi qui n'a pas sa place dans la branche (sortie de build, `.env`, fichier local) → arrêt, question ; sinon `git -C "<WORKTREE>" add -A`, commit (message ≤ 150 caractères, sans mention de Claude).
3. `<PARENT_BRANCH>` ancêtre de `<X>` → `git merge --ff-only <X>` dans le dépôt principal.
4. Sinon → `git -C "<WORKTREE>" merge --no-ff --no-commit <PARENT_BRANCH>`, puis résoudre :
   - conflit d'ajout (deux blocs ajoutés au même endroit : listes, menus, codes d'erreur, enregistrements, exports) → garder les deux côtés ;
   - même ligne étendue des deux côtés (union de types, liste sur une ligne) → une ligne qui réunit les deux ajouts ;
   - doublon créé par l'union (import, fonction utilitaire identique) → en garder un, celui déclaré avant son premier usage ;
   - conflit logique (même traitement modifié des deux côtés : gestionnaire d'événement, aiguillage d'une commande) → combiner les deux comportements, ordre des effets justifié ; doute → `git -C "<WORKTREE>" merge --abort`, question à l'utilisateur avec les deux versions ;
   - fichier généré → prendre un côté, le régénérer par la commande du projet ;
   - plus aucun marqueur de conflit (recherche acceptant `\r?\n`), vérifications demandées par le projet vertes → commit de fusion `Merge <PARENT_BRANCH> into <X>: <fichiers combinés>`, puis étape 3.
5. Fusion réussie → PLAN : tâche `<X>` cochée `[x]`, note d'une ligne — hashes ; `**Actual time:**` écrit par le hook à la coche, somme des tâches du plan de `<X>`. Vérification impossible dans le worktree → ajoutée à la tâche finale de vérification d'ensemble. LOG parent.
6. Compte rendu : tableau des opérations au format du « Gabarit — compte rendu de livraison » de `commands/engrave.md`, conflits résolus, vérification, tâches débloquées.
7. « Retrait d'un worktree de branche fille ». Réécrire SWARM.

---

## Retrait d'un worktree de branche fille

**Réaction — dans l'ordre :**
1. `git -C "<WORKTREE>" status --porcelain` vide, sinon STOP : afficher les fichiers, jamais de `--force` sans accord.
2. Application ou services lancés depuis le worktree → les arrêter et le signaler.
3. `git worktree remove "<WORKTREE>"` — l'installation propre au worktree part avec lui.

---

## Fichier d'état — `swarm.md`

Réécrit par le parent à chaque événement — lancement, question, réponse, fin, fusion —, versionné avec `<PARENT_BRANCH>`. Libellés figés en anglais, contenu dans la langue de l'utilisateur :

```markdown
# Swarm — <PARENT_BRANCH>
**N:** 3
**Parent task:** T<m> — [titre], ou none
**Parent mode:** chain, pick, ou none

| Branch | Type | State | Worktree | Agent | Port | Since | Last event |
|---|---|---|---|---|---|---|---|
| <X> | child | running · T7/19 | ../<dossier-du-dépôt>.worktrees/<X> | <identifiant du délégué> | 3001 | [now] | plan validated (chain) |
| <Y> | child | waiting for merge | ../<dossier-du-dépôt>.worktrees/<Y> | <identifiant du délégué> | 3002 | [now] | FORGE_DONE |
| <Z> | child | waits for <X> | — | — | — | — | — |
| <LINKED_REL> @ <LINKED_BRANCH> | linked | running | <LINKED_REL>.worktrees/<LINKED_BRANCH> | <identifiant du délégué> | none | [now] | mandate written |

## Choices sent to delegates
- <X> : [choix] ([date de now])

## Coordination notes
- <X> and <Y> change module M: separate files.
```

Colonne `Since` et date d'un choix → valeur `now` du JSON de `swarm-status.sh`, exécuté dans le tour avant la réécriture de SWARM (« Entrée LOG » de `SKILL.md`). `Since` change quand l'état de la branche change, gardé sinon.

Colonne `Agent` : identifiant du délégué en cours, remplacé à chaque relance ; `Port` : `none` sans port de base, toujours `none` pour une unité `linked`.

---

## Reprise de l'essaim

**Déclencheur :** SWARM porte des branches `running` ou `waiting for merge` dont l'identifiant `Agent` n'a été lancé par aucun appel de cette conversation — session neuve, contexte compacté, délégués arrêtés.

⚠️ Rien ne dit au parent si un délégué lancé ailleurs tourne encore : relancer une branche dont le délégué écrit toujours met deux agents dans le même worktree. Jamais de relance sans réponse à la question `Resume`.

**Réaction — dans l'ordre :**
1. Chaque branche `waiting for merge` → étape 3 de « Fin d'une branche fille » : la question `Next` est reposée. Aucune branche `running` → STOP.
2. Pour chaque branche `running` de SWARM : plan écrit ou non, validé ou non, tâches cochées, tête de son LOG (dernière ligne « task <n> started »), `git -C "<WORKTREE>" status --porcelain`. Afficher une ligne par branche : état, identifiant `Agent`, `Since`, dernier événement.
3. Poser le choix avec `AskUserQuestion` — `header` : `Resume` :
   - `Relaunch <X>, <Y>` → "Their delegates are stopped: start a new delegate on each branch."
   - `Still running` → "The delegates still work in another session: relaunch nothing." — STOP.
   - `Later` → "Relaunch nothing now." — STOP.
4. Sur `Relaunch` : unité `linked` → nouveau délégué au prompt de « Délégation — projet lié », sans `RESUME:` : il reprend par la phase de reprise de son propre plan. Unité `child` → un nouveau délégué par branche, ligne `RESUME:` = « a previous delegated run was stopped; plan <validated with chaining | validated | not written>. Run `git status` first, check every uncommitted or partial file (complete, project checks green), finish or redo it, then continue. » suivie des choix et notes de coordination de SWARM. « Mesure d'un délégué » de `commands/delegation.md`.
   Même port (colonne `Port`, ligne `PORT:` du prompt), nouvel identifiant dans la colonne `Agent`.
5. Entrée LOG parent : `Delegates relaunched after interruption: <X>, <Y>`.

---

## Plan mixte — travail du parent

**Condition :** PLAN porte des tâches ordinaires ouvertes à côté des tâches-branches — une seule tâche-branche comprise : sa branche fille et le parent avancent en parallèle, vérification d'ensemble finale inchangée.

**Réaction — dans l'ordre :**
1. Tâches ordinaires qui débloquent des branches (socle des points d'extension, données partagées) → exécutées par le parent avant le lancement de ces branches.
2. Pendant que les délégués travaillent, prendre une à une les tâches de `ordinary` (`swarm-status.sh`) dont `waiting_for` est vide et `is_last` faux, qui ne modifient aucun fichier d'une branche en cours — étape 9 de `phases/p5-resume.md`, limitée à ces tâches. Tâche prise → `**Parent task:**` de SWARM.
   - Question `Mode` posée une seule fois pour toute la durée de l'essaim, réponse écrite dans `**Parent mode:**` de SWARM (`chain` / `pick`) ; jamais reposée tant que la ligne existe.
   - Tâche terminée ou relais traité → tâche prenable suivante aussitôt, dans le mode retenu, sans rendre la main.
3. Chaque tâche du parent commitée fait avancer `<PARENT_BRANCH>` : la fusion des branches en cours passera par une fusion inverse.
4. Plus de tâche prenable → une ligne : "Waiting for delegates: `<X>`, `<Y>`." Seul moment où le parent rend la main pendant l'essaim.
5. Toutes les branches fusionnées et toutes les tâches ordinaires faites → tâche finale de vérification d'ensemble, depuis le dépôt principal.

---

## Sous-tâches ClickUp des branches filles

**Condition :** `.forge/branch/<PARENT_BRANCH>/ticket.json` présent, `tracker` à `clickup`.

**Réaction :**
- Premier lancement de l'essaim → `AskUserQuestion` à cocher — `header` : `ClickUp`, une option par branche fille, quatre par question : créer une sous-tâche ClickUp par branche cochée (`clickup_create_task`, `parent` = `code` de `ticket.json`).
- Sous-tâche créée → `<WORKTREE>/.forge/branch/<X>/ticket.json` (`tracker`, `code`, `url`), nom de branche inchangé.
- Lancement de la branche → statut « en cours » ; fusion → statut « terminée » (`clickup_update_task`).

⚠️ Action sortante : aucune sous-tâche créée sans case cochée.
