# Plan — plan
**Objective:** Ajouter à la validation du plan une option « Valider et enchaîner », en premier et recommandée, qui écrit le plan puis exécute toutes les tâches ouvertes sans autre question.
**Date:** 2026-10-05

## Tasks

### T1 — Retirer la limite « deux options seulement » de `SKILL.md`
**Effort:** XS
**Files:** `skills/forge/SKILL.md`
**Description:** Réécrire le ⚠️ « Validation d'un contenu présenté » (l.54) : nombre d'options libre ; jamais d'option « à retravailler » / « modifier » — un changement passe par le champ de texte libre de la question, avec son explication. Traitement du texte libre, du texte libre sans substance, de `Cancel` et de l'absence de réponse inchangé.
[x]

### T2 — Option `Validate and chain` à l'étape 7 de `p4-plan.md`
**Effort:** S
**Files:** `skills/forge/phases/p4-plan.md`
**Description:** Étape 7 : options `Validate and chain (recommended)`, `Validate`, `Cancel`, dans cet ordre, chacune décrite. `Validate and chain` → étapes 8-9 puis p5 en mode enchaîné, sans question `Mode`. `Validate` inchangé. Garde délégué : `SCOPE: linked` → option non proposée (`Validate` vaut déjà accord) ; `SCOPE: branch` → option proposée dans le `FORGE_QUESTION`, et choisie elle remplace la question `Mode` et les feux verts `Start T<n>`.
[x]

### T3 — `p5-resume.md` : pas de question `Mode` après `Validate and chain`
**Effort:** XS
**Files:** `skills/forge/phases/p5-resume.md`
**Description:** Étape 8 : nouvelle puce — plan validé dans ce tour par `Validate and chain` → aucune question, enchaîner toutes les tâches ouvertes dans l'ordre. Ajuster la puce `SCOPE: branch` et le ⚠️ « Aucun démarrage avant la réponse » (la réponse est alors la validation du plan). Reprise ultérieure → question `Mode` posée comme aujourd'hui.
[x]

### T4 — Documentation et CHANGELOG
**Effort:** S
**Files:** `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** README (« Confirmations » : retirer « n'offre que deux options », remplacer par la règle « jamais d'option à retravailler » ; État 4 : troisième option ; portée branche : phrase « le plan validé vaut accord »), en miroir dans les deux langues. CHANGELOG `## [Unreleased]` : `### Added` pour l'option, `### Changed` pour la fin de la limite à deux options.
[x]

### T5 — `grave!` : livraison sans confirmation
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Déclencheur de la Livraison : `grave!` / `engrave!` (`!` collé à la commande, seule ou suivie de branches) → livraison directe. Étapes 4-5 sautées : tableau affiché comme compte rendu, séquence exécutée aussitôt — la commande vaut autorisation pour cette séquence. Questions `Linked` / `Linked branches` maintenues (choix de périmètre). `SCOPE: branch` → pas de `FORGE_QUESTION` d'engrave. Conflit de merge ou push rejeté → arrêt, erreur telle quelle ; jamais de `--force`. `grave` sans `!` inchangé. README en miroir, CHANGELOG `### Added`.
[x]

### T6 — Remplacer `grave!` / `engrave!` par `livre` / `ship`
**Effort:** XS
**Files:** `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Livraison directe déclenchée par un message qui commence par `livre` / `ship`, seul ou suivi uniquement de branches existantes ; tout autre texte → pas une livraison. `grave!` / `engrave!` retirés. Comportement inchangé (tableau en compte rendu, questions `Linked` maintenues, arrêt sur conflit ou push rejeté). `grave` / `engrave` gardent la confirmation. README en miroir, CHANGELOG `### Added` réécrit.
[x]

### T7 — Délégation vers un projet lié dans un worktree
**Effort:** M
**Files:** `skills/forge/phases/p5-resume.md`, `skills/forge/SKILL.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** « Délégation — projet lié » : checkout/création de branche dans `<LINKED>` remplacé par un worktree `<LINKED>-<slug LINKED_BRANCH>` (réutilisé s'il existe), brief/log du lié écrits dedans, `ROOT: <worktree>` dans le prompt. Livraison relayée : add/commit/push dans le worktree, branche cible extraite ailleurs → `skipped`. Fin de délégation : rappel `git worktree remove` + avertissement (ni dépendances ni fichiers ignorés dans le worktree). README miroir, CHANGELOG `### Changed`.
[x]

### T8 — Option `Validate and engrave` à la validation du plan
**Effort:** S
**Files:** `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `skills/forge/SKILL.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Étape 7 de p4 : quatre options, même ordre partout, projet lié compris — `Validate and chain`, `Validate`, `Validate and engrave`, `Cancel`. `SCOPE: linked` : `Validate` relaie désormais la question `Mode` (plus d'enchaînement implicite). La nouvelle option écrit le plan, déroule aussitôt la livraison directe comme `livre` seul (add, commit, push de `<BRANCH>`, aucun merge, aucune confirmation `Engrave`), puis p5 pose la question `Mode`. Conflit ou push rejeté → arrêt, erreur telle quelle. Option proposée partout, sans `FORGE_QUESTION` d'engrave : `SCOPE: branch` → question `Mode` ensuite ; `SCOPE: linked` → gravure dans le worktree lié, puis question `Mode` relayée (push rejeté → LOG, suite maintenue) ; `SKILL.md` : exception à « Livraison non applicable ». README miroir, CHANGELOG `### Added`.
[x] Remplace la version erronée « Validate, chain and engrave » ; étape 9 de p5 retirée.

### T9 — Commande courte pour la délégation vers une nouvelle branche
**Effort:** S
**Files:** aucun en propre — la formulation retenue s'inscrit dans le déclencheur de T10, et dans README / CHANGELOG avec elle.
**Description:** Choisir un mot-commande court qui déclenche la délégation vers une nouvelle branche amorcée depuis la conversation, au même titre que `grave` / `engrave` et `livre` / `ship`. À fixer : paire français / anglais, courte, imagerie de la forge, sans collision avec les commandes existantes (`grave`, `livre`, `ship`, `ranger la forge`) ni avec git (`fork`, `branch`, `merge`) ; syntaxe `<mot> <branche>` + sujet libre facultatif (absent → sujet en cours, ambigu → demandé en une ligne) ; déclenchement strict en tête de message, formulation libre gardée en second déclencheur ; synthèse toujours soumise à la confirmation `Delegate`. À trancher plus tard.

Pistes :

| Command | Meaning | Pros | Cons |
|---|---|---|---|
| `coule <branche>` / `cast <branche>` | couler une nouvelle pièce dans un moule | imagerie forge, court | « cast » un peu technique |
| `bouture <branche>` / `cutting <branche>` | faire pousser une plante d'un fragment | métaphore exacte | sort de la forge, « cutting » ambigu |
| `scinde <branche>` / `split <branche>` | séparer en deux | sens immédiat | `split` générique |
| `essaime <branche>` / `spawn <branche>` | lancer une nouvelle colonie | dit qu'un agent part travailler | `spawn` connoté processus |
[ ]

### T10 — Délégation vers une nouvelle branche, amorcée depuis la conversation
**Effort:** M
**Files:** `skills/forge/phases/p5-resume.md`, `skills/forge/SKILL.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Nouvelle section « Délégation — nouvelle branche » dans p5. Déclencheur : commande courte fixée par T9, puis formulation libre — reprendre un sujet de la conversation sur une nouvelle branche `<X>` (agent / délégation + branche à créer + sujet). Refus : `<X>` existe → renvoi vers la délégation sur branche existante ; `.forge/project.md` absent du commit de `<défaut>` → STOP. Synthèse en 5 rubriques (problème, causes vérifiées dans le code, solutions avec pour/contre, reste à vérifier, recommandation). Inventaire : fichiers non commités de `<BRANCH>` liés au sujet (chemins absolus), commits de `<BRANCH>` absents de `<défaut>` (`git log <défaut>..<BRANCH>`, `git diff --stat <défaut>...<BRANCH>`). Affichage : synthèse entière, brief prévu, tableau de délégation (`branch`, `worktree`, `brief`, `reference`, `copy`, `agent`). Confirmation unique `Delegate` : `Open the new branch` / `Cancel`, correction par texte libre. Sur `Open the new branch` : `git worktree add --no-track -b <X> <WORKTREE> <base>` (`origin/<défaut>` après fetch si distante suivie, sinon `<défaut>`) ; brief écrit (`## Seed` : branche source + document de référence ; `## Objective` : problème + recommandation ; `## Scope & rules` : contraintes établies, sinon vide) ; `output/AAAAMMJJ-reference-<sujet-slug>.md` (synthèse entière, commits et fichiers de `<BRANCH>` absents de `<défaut>`, liste des fichiers copiés) ; copie des fichiers non commités dans `output/` ; sous-agent `SCOPE: branch` inchangé + boucle de relais. Agent sur brief `## Seed` : `Validate and engrave` → gravure (premier push `-u`) puis `FORGE_DONE` sans question `Mode` ; autres options inchangées ; plan toujours relayé. Retour : worktree propre → `git worktree remove <WORKTREE>`, sinon conservé avec raison. `<BRANCH>` jamais touchée. Exception à l'INVARIANT de `SKILL.md` : le parent écrit dans `<WORKTREE>` brief, référence et copies, jamais de code ni de plan. README miroir, CHANGELOG `### Added`.
[ ]

### T11 — Suppression des worktrees une fois leur travail commité
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Remplacer partout le rappel « `git worktree remove` once engraved » par la suppression effective. Délégation branche du même dépôt : au `FORGE_DONE`, worktree propre (`status --porcelain` vide) → `git worktree remove <WORKTREE>`, sinon conservé avec raison. Délégation projet lié : même règle avec `git -C <LINKED> worktree remove <LINKED_WORKTREE>` ; travail non commité → conservé jusqu'à la livraison relayée. Livraison relayée : après `push` réussi, `<LINKED_GIT>` worktree (pas `<LINKED>`) → `git -C <LINKED> worktree remove <LINKED_GIT>`, ligne `worktree remove` dans le tableau du lié. Échec de suppression → erreur telle quelle, worktree conservé, jamais de `--force`. README miroir, CHANGELOG `### Changed`.
[ ]

## Risks
- La copie installée (`~/.claude/skills/forge/`) n'évolue qu'après relance de l'installeur.
- Le mode enchaîné ne pose plus aucune question entre les tâches : les mises à jour substantielles du plan et les demandes hors périmètre restent soumises à confirmation.

## Deployment
None

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — Retirer la limite « deux options seulement » de `SKILL.md` | XS | [x] |
| T2 — Option `Validate and chain` à l'étape 7 de `p4-plan.md` | S | [x] |
| T3 — `p5-resume.md` : pas de question `Mode` après `Validate and chain` | XS | [x] |
| T4 — Documentation et CHANGELOG | S | [x] |
| T5 — `grave!` : livraison sans confirmation | S | [x] |
| T6 — Remplacer `grave!` / `engrave!` par `livre` / `ship` | XS | [x] |
| T7 — Délégation vers un projet lié dans un worktree | M | [x] |
| T8 — Option `Validate and engrave` à la validation du plan | S | [x] |
| T9 — Commande courte pour la délégation vers une nouvelle branche | S | [ ] |
| T10 — Délégation vers une nouvelle branche, amorcée depuis la conversation | M | [ ] |
| T11 — Suppression des worktrees une fois leur travail commité | S | [ ] |
| **Total** | **~13h** | |
