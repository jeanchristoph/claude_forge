## Origin
**Tasks:** T9, T10

### Delegated tasks

#### T9 — Branche liée nommée d'après la tâche, inscrite dans le plan parent ; l'enfant ne nomme jamais le parent (dépôt forge)
**Effort:** M
**Files:** `skills/forge/commands/delegation.md`, `skills/forge/commands/delegated-mode.md`, `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `skills/forge/commands/engrave.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Constats sur une délégation réelle : le nom de branche liée `<PARENT_FOLDER>/<BRANCH>` était imposé, sans rapport avec la tâche, et la branche a dû être renommée après coup ; le mandat recopiait le brief parent en entier (client, base, adresses e-mail de particuliers) dans un projet lié public, alors que le parent est privé.
- Nommage, même règle que forge classique : étape 3 de la « Garde de sécurité » de `SKILL.md`, l'objectif étant le titre de la tâche déléguée (ou l'objet commun des tâches d'un mandat), collision vérifiée dans le projet lié ; `delegation.md` renvoie à cette règle sans la recopier. Le préfixe `<PARENT_FOLDER>/` disparaît.
- Lien tenu par le parent seul : nouveau champ de tâche `**Linked branch:** <LINKED_REL> @ <branche>`, sous `**Files:**`, écrit dès l'entrée de la tâche au plan (« Demande hors périmètre », plan neuf) et affiché dans le « Gabarit — question `Plan` » (`Branche liée : <branche>`) ; tâche ancienne sans ce champ → nom écrit à l'action `mark`. La délégation lit ce champ, sans le recalculer ; des tâches au même champ partagent branche et worktree (`reuse`). La note de statut `delegated to <LINKED_REL> @ <branche>` est gardée (livraison relayée).
- L'enfant ne nomme jamais le parent : aucun nom de dossier, de branche, de ticket, de client ni de donnée du parent dans la branche liée (nom, brief, plan, log, code, CHANGELOG, commits). Exception : quand le but de la tâche ou une référence est nécessaire pour l'exécuter, cette référence est gardée, limitée au strict nécessaire et écrite dans la tâche elle-même — jamais le brief parent recopié en bloc.
- Mandat : `## Origin` garde son rôle de marqueur du mode délégué, avec seulement `**Tasks:**` et les tâches déléguées ; plus de `**Parent:**`, plus de `**Branch:**`, plus de brief parent recopié ; l'objectif du mandat est rédigé à partir des seules tâches.
- Règle de rédaction dans `p5-resume.md` et `p4-plan.md` : une tâche qui porte `**Linked branch:**` est écrite sans référence au parent, car elle est recopiée telle quelle dans le mandat (sauf l'exception ci-dessus).
- Log de l'enfant : `Opened by delegation · T…` au lieu de `Opened from <PARENT_FOLDER>`. `delegated-mode.md` : le délégué ne réintroduit jamais le parent dans ce qu'il écrit, hors références fournies par la tâche.
- Vérifier ce qui suppose l'ancien préfixe, `**Parent:**`, `**Branch:**` ou le brief recopié (`engrave.md`, `delegated-mode.md`, `swarm.md`, scripts, tests) ; adapter ce qui doit l'être, signaler le reste.
- Nettoyage de la branche liée elle-même : ligne `**Origin:**` de son `plan.md` et entrée « Opened from … » de son `log.md` réécrites sans mention du parent — exception à « LOG jamais édité », justifiée par la confidentialité et notée dans le log. Le `brief.md` est déjà réécrit par le nouveau mandat.
- `p4-plan.md` : champ optionnel dans le format de tâche. README français et anglais : description de la délégation vers un projet lié mise à jour. `CHANGELOG.md`, `[Unreleased]` — `### Changed` : « Linked-project delegation names the linked branch with the same rule as a regular forge branch (short kebab-case slug of the delegated task, `-2`/`-3` on collision) and records the link in the parent plan only (`**Linked branch:** <path> @ <branch>`); the linked project never names the parent — the mandate carries the delegated tasks only, no parent brief, folder, branch or client data — unless the task's goal or a reference is required to carry it out, kept to the strict minimum inside the task. »

#### T10 — Documenter le nouveau hook dans la structure du projet (dépôt forge)
**Effort:** XS
**Files:** `.forge/project.md`, `README.md`, `README.fr.md`
**Description:** Arborescence de `.forge/project.md` et des deux README : ajout de `skills/forge/hooks/linked-write-guard.sh` (écriture de la session parente dans un projet lié refusée) et de `tests/linked-write-guard.test.sh`, au même format que les hooks et tests existants.


## Objective
Faire nommer la branche d'un projet lié d'après la tâche déléguée, selon la règle de nommage de forge classique, avec un lien tenu par le seul plan parent, et garantir que le projet lié ne porte jamais le nom ni les données du projet parent ; documenter le hook `linked-write-guard.sh` dans la structure du projet.

## Scope & rules
- Le projet lié peut être public et le parent privé : aucune donnée du parent dans ce dépôt, sauf une référence strictement nécessaire à une tâche, écrite dans la tâche.
