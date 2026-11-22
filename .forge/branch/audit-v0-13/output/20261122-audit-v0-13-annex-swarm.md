# Audit essaim (swarm) — forge v0.13.0 — lecture seule

Périmètre lu en entier : `skills/forge/commands/swarm.md`, `scripts/swarm-status.sh`, `scripts/time-calibrate.sh`, `references/estimation.json`, `phases/p4-plan.md`, `phases/p5-resume.md`, `commands/delegated-mode.md`, `commands/delegation.md`, `SKILL.md`, `tests/swarm-status.test.sh`, `README.fr.md` §« Essaim de branches filles » (l. 495-534). Lu en appui : `scripts/status.sh` (l. 85-93), `scripts/time-aggregate.sh` (en-tête, l. 80-110), `scripts/time-mark.sh` (en-tête), `commands/engrave.md` (§ Synthèse), `phases/p0-project.md` (gabarit `## Tools & access`).

Vérifications exécutées (bac à sable du scratchpad, dépôt non touché) :
- `bash tests/swarm-status.test.sh` → 24 passed, 0 failed (bash 5.2.26, git 2.45.1).
- `time-calibrate.sh --groups …` sans historique (valeurs de référence) → tableau §1.
- `git checkout x` depuis le dépôt principal quand `x` est extraite dans un worktree → `fatal: 'x' is already used by worktree…`, exit 128 ; `git -C <worktree> checkout x` → `Already on 'x'`.
- `git worktree remove` d'un worktree propre portant un `node_modules/` ignoré → retiré sans `--force` (seul le dossier `<dépôt>.worktrees/` vide reste).

Gravité : **bloquant** (le flux promis ne se fait pas sans intervention non documentée) · **gênant** (question/action en trop, risque réel) · **mineur**.

---

## 1. Déclenchement

### Conditions exactes
- Proposition : `p4-plan.md:35` et `:107` — « au moins deux groupes de tâches remplissent la Règle de branche » ; Règle (`p4-plan.md:99-101`) = **Durée** fichiers du groupe × `minutes_per_file` ≥ `branch_minutes` **et** **Indépendance** (aucun fichier partagé hors socle). Jamais en mode délégué (`p4-plan.md:35`).
- Effet : 4e option `Validate and launch the swarm` en tête de la question `Plan` (`p4-plan.md:43`), « toujours proposée, perte de temps comprise ».
- Lancement : `swarm.md:13` — cette option, demande explicite, `Launch` à « Relance de l'essaim » (`p5-resume.md:258-265`, seulement depuis l'étape 8 de la reprise), étape 5 de « Fin d'une branche fille ».

### Calcul du seuil (valeurs de référence, `estimation.json:2,7`)
`branch_minutes / minutes_per_file` = 15 / 0,5 = **30 fichiers par groupe**, donc un plan d'au moins **60 fichiers** répartis en deux modules sans fichier commun. Gain mesuré par le script lui-même (`time-calibrate.sh --groups`, référence, `--slots 3`) :

| Groupes (fichiers) | Série | Essaim | Écart |
|---|---|---|---|
| 30,30 (seuil exact) | 30 min | 33 min | **3 min perdues** |
| 36,36 | 36 | 36 | 0 |
| 37,37 | 37 | 36 | 1 min gagnée |
| 24,24,24 (sous le seuil, non proposé) | 36 | 35 | 1 min gagnée |
| 30,30,30 | 45 | 38 | 7 min gagnées |
| 30,30,30,30 | 60 | 66 | **6 min perdues** (4 branches > 3 places + 4 fusions en série) |

Constats :

**D1 — gênant — seuil incohérent avec le coût fixe qu'il prétend couvrir.** `p4-plan.md:100` justifie 15 min « au-delà du coût fixe d'une branche, environ 8 min de délégué et 5 min de fusion » ; or au seuil exact l'essaim de deux branches *perd* du temps (tableau). Le seuil compare la durée d'*un* groupe au coût fixe d'*une* branche, alors que le gain dépend de la durée des *autres* groupes (seule la plus courte est économisée) et que les fusions sont en série (`time-calibrate.sh:136`). De plus `branch_minutes` reste figé (`time-calibrate.sh:235-236`, « recopié tel quel ») alors que `delegate_minutes`/`merge_minutes` se recalibrent sur le projet (`:153-154`) : un projet qui mesure 20 min de mise en route garde un seuil à 15.
*Correction :* remplacer la condition « Durée » par le verdict du script : proposer l'essaim quand `swarm.swarm_minutes < swarm.serial_minutes` pour les groupes indépendants (le calcul existe déjà) ; ou dériver le seuil : `branch_minutes = delegate_minutes + merge_minutes + marge`, calculé dans `time-calibrate.sh` et non lu dans `estimation.json`.

**D2 — gênant — déclenchement rare en pratique.** 60 fichiers en deux modules étanches est un plan inhabituel ; combiné à la taille cible « 3 à 20 tâches » par branche (`p4-plan.md:116`) et à l'exigence d'indépendance stricte, l'option n'apparaîtra que sur des chantiers de type « nouveau module × 2 ». Ce n'est pas un défaut en soi (l'essaim coûte), mais le README (`README.fr.md:500-502`) le présente comme un mode courant.
*Correction :* documenter l'ordre de grandeur (« ≈ 30 fichiers par groupe au calibrage par défaut ») dans le README et dans la description de l'option.

**D3 — mineur — la règle ignore la correction d'erreur de fichiers.** `p4-plan.md:100` multiplie par `minutes_per_file` brut ; `--groups` applique `file_error` quand `apply_file_error` est vrai (`time-calibrate.sh:164`). Le tableau des groupes et le verdict peuvent diverger.
*Correction :* « Durée » = minutes du groupe telles que `--groups`/`--files` les rend.

**D4 — mineur — contradiction sur la taille minimale d'une branche.** `p4-plan.md:99` « une tâche seule peut former un groupe » vs `p4-plan.md:116` « 3 à 20 tâches ; en dessous → tâche ordinaire » vs rétrogradation `swarm.md:71` (< 3 tâches). *Correction :* retirer « une tâche seule peut former un groupe » ou préciser « une tâche XL découpée en ≥ 3 sous-tâches ».

### Le modèle a-t-il les infos pour décider ?
- Oui pour la durée : l'appel unique `--files` de l'étape 6 (`p4-plan.md:31`) rend `minutes_per_file` et `branch_minutes` (`time-calibrate.sh:157,236`).
- Partiellement pour l'indépendance : seule source = les `**Files:**` des tâches ; une ligne en motif ou `(≈ n)` (`p4-plan.md:91`) rend le recouvrement invérifiable, et le format d'une tâche-branche n'a plus que `[dossier ou module]` (`p4-plan.md:125`). Le modèle n'a aucun outil pour détecter un fichier partagé (routes, DI, menu) autrement qu'à la lecture.

**D5 — gênant — ordre des opérations de l'étape 6 contradictoire.** `p4-plan.md:30` impose d'estimer « en un seul appel » `--files` sur les tâches, puis `:35` regroupe en tâches-branches (`**Estimated time:**` exigé `:124`) et `:110` appelle `--groups` : deux appels, et l'`**Estimated time:**` d'une tâche-branche n'a pas de source définie (somme des tâches ? `--files <somme>` ?).
*Correction :* écrire « Estimated time d'une tâche-branche = `--files <somme du groupe>` dans le même appel (valeur ajoutée en fin de liste) ».

**D6 — mineur — `**Install command:**` et `**Dev port:**` n'existent dans aucun gabarit.** Lus en `swarm.md:22` et `:90`, absents du gabarit `## Tools & access` (`p0-project.md:67-70`). La commande d'installation est demandée une fois ; le port ne l'est jamais : sans édition manuelle de `project.md`, aucun port, et l'option `Check before merging` (`swarm.md:90`) n'apparaît jamais.
*Correction :* ajouter les deux lignes au gabarit p0 (valeur `none` permise) et demander le port avec la commande d'installation.

### Déclencheurs manquants
**D7 — bloquant — essaim validé mais rien ne se lance quand un socle précède les branches.** `p4-plan.md:115` crée systématiquement une tâche ordinaire « socle des points d'extension » en tête dès qu'une liste partagée existe, et les branches en dépendent (`Depends on: T1`, cf. plan type `tests/swarm-status.test.sh:16-22`). Au clic `Validate and launch the swarm` : toutes les branches sont `waiting` → « Nothing to launch. » → « Plan mixte » (`swarm.md:21`) → le parent fait le socle (`swarm.md:181`). Ensuite **aucun déclencheur** ne relance l'essaim : la liste `swarm.md:13` ne contient ni « coche d'une tâche ordinaire qui débloque une branche », ni retour depuis le Plan mixte ; `p5-resume.md:8` ne s'évalue qu'à la reprise. L'utilisateur doit deviner qu'il faut taper « lance l'essaim » ou relancer `/forge`.
*Correction :* dans « Plan mixte », étape 1 : « tâche qui débloque des branches cochée → `swarm-status.sh` ; `launchable` non vide → « Délégation — essaim », étape 1, sans question (le choix `Validate and launch the swarm` vaut accord pour toutes les branches du plan) ». Même règle à la coche de toute tâche ordinaire (`ordinary` levant un `waiting_for`).

**D8 — gênant — « parallélise » sur un plan déjà écrit : aucun chemin.** Les déclencheurs Essaim (`p5-resume.md:252-256`) supposent des tâches-branches existantes. Un plan validé sans tâche-branche (ou qui n'atteignait pas le seuil) ne peut pas être converti : la demande tombe dans « Surveillance » (`p5-resume.md:158+`) qui ne sait qu'ajouter des tâches.
*Correction :* déclencheur « demande de paralléliser / passer en essaim » → appliquer « Règle de branche » + « Plan de branches » de `p4-plan.md` aux tâches ouvertes, présenter le tableau des groupes, question `Plan` (modification substantielle, `p5-resume.md:62`) avec l'option `Apply and launch the swarm`. Indiquer aussi si l'utilisateur peut forcer l'essaim sous le seuil (aujourd'hui : non).

**D9 — mineur — un seul groupe éligible n'ouvre rien.** Un gros groupe isolable + tâches ordinaires du parent pourrait tourner en parallèle (1 délégué + parent) ; la condition « ≥ 2 groupes » l'exclut. Choix défendable, à documenter.

---

## 2. Actions utilisateur — plan prêt → toutes branches fusionnées + vérification d'ensemble

Séquence telle que les fichiers la prescrivent (N = 3, deux ou trois branches, un socle) :

| # | Action | Source | Évitable / regroupable |
|---|---|---|---|
| 1 | Question `Plan` → `Validate and launch the swarm` | `p4-plan.md:37-43` | Nécessaire |
| 2 | Question `Swarm` (Relance) si p5 est exécuté avant swarm.md | `p4-plan.md:46-47` + `p5-resume.md:19-21` | **Évitable** (A1) |
| 3 | Question `ClickUp` (sous-tâches) au premier lancement, si ticket ClickUp | `swarm.md:194` | Regroupable avec #1 (case dans la même fenêtre) |
| 4 | Commande d'installation en texte libre, si absente | `swarm.md:22` | Regroupable/évitable : déductible du manifeste + fichier de verrou (`package-lock.json` → `npm ci`) ; contredit `swarm.md:13` « aucune autre question avant le lancement » |
| 5 | Question `Mode` (puis `Task`) pour les tâches ordinaires du parent | `swarm.md:182` → étape 9 `p5-resume.md:26-32` | **Évitable** (A2) |
| 6 | Relancer l'essaim à la main après le socle (« lance l'essaim ») | D7 | **Évitable** (D7) |
| 7 | Par branche : `Approach` si plusieurs approches (FORGE_QUESTION) | `p4-plan.md:5,29` | Regroupable (fenêtre groupée, `swarm.md:66`) |
| 8 | Par branche : validation du plan fils (`Plan`, plan entier recopié) | `p4-plan.md:7`, `delegated-mode.md:23` | **Évitable** (A3) |
| 9 | Par branche, si `Validate` au lieu de `Validate and chain` : `Mode`, puis `Start T<n>` **avant chaque tâche** | `p5-resume.md:34` | Évitable par A3 ; sinon `enchaîne` (`swarm.md:69`) — non proposé comme option |
| 10 | Par branche : `Demote` si plan fils < 3 tâches | `swarm.md:71` | Rare (taille cible ≥ 3) |
| 11 | Par branche : questions de conception (`Promotion`, choix d'archi, `Test`, hors périmètre) | `delegated-mode.md:33-34`, `p5-resume.md:172,204` | Nécessaires |
| 12 | Par branche : question `Next` (fusion) à chaque `FORGE_DONE` | `swarm.md:87-92` | Regroupable : plusieurs `FORGE_DONE` simultanés ne sont pas groupés (A4) |
| 13 | Par fusion : fichier non suivi douteux, conflit logique douteux, vérification rouge | `swarm.md:105,111,93` | Nécessaires (exceptionnels) |
| 14 | `git worktree prune` sur accord si worktree supprimé à la main | `swarm.md:20` | Exceptionnel |
| 15 | Vérification d'ensemble : démarrage non défini | `swarm.md:185` | À préciser (A5) |
| 16 | `grave` pour livrer la branche parente | `swarm.md:5` | Hors périmètre |

Minimum incompressible pour 3 branches sans incident : #1 + 3 × #8 (si conservé) + 3 × #12 ≈ 7 interactions ; prescrit aujourd'hui, cas typique avec socle et `Validate` dans les fils : 1 + 1 (#2) + 1 (#5) + 1 (#6) + 3 + 3×(1 + n tâches) + 3 ≈ 10 + 3n.

**A1 — gênant — double question à la validation.** `p4-plan.md:46` dit « Continuer à l'État 5 : lire et exécuter p5-resume.md », puis en sous-puce « Sur `Validate and launch the swarm` → lire et exécuter swarm.md ». Si p5 est exécuté (étapes 1-8), son étape 8 voit des branches lançables et pose la question `Swarm` (`p5-resume.md:21,262`) alors que l'utilisateur vient de choisir le lancement. *Correction :* « Sur `Validate and launch the swarm` → **au lieu de** p5, swarm.md ».

**A2 — gênant — question `Mode` pour le travail du parent + contradiction.** « Plan mixte » renvoie à l'étape 9 de p5 (`swarm.md:182`), qui pose `Mode` (`p5-resume.md:29`) — la puce « Validate and chain → aucune question » (`:27`) ne couvre pas « Validate and launch the swarm ». Et le mode `Chain` (« sans arrêt entre elles ») contredit `swarm.md:78` (« une seule tâche ordinaire par tour »). *Correction :* `Validate and launch the swarm` vaut accord d'enchaîner les tâches ordinaires prenables, une par tour ; aucune question `Mode`.

**A3 — gênant — validation du plan de chaque branche fille.** Les tâches d'une branche fille sont déjà validées dans la `**Description:**` de la tâche-branche du plan parent (`p4-plan.md:111`), mais le délégué re-planifie et pose `Plan` (contenu entier) puis, sans `Validate and chain`, un feu vert par tâche (`delegated-mode.md:23`, `p5-resume.md:34`). Trois plans arrivent ensemble dans une fenêtre groupée dont chaque `question` porte un plan entier (`delegation.md:49` impose le Gabarit `Plan` — conçu pour **une** tâche, `p5-resume.md:214-227`). *Correction :* ligne de prompt `PLAN: pre-approved` (ou mention dans le brief fils) : plan fils fidèle à la description → écrit et enchaîné sans question ; `FORGE_QUESTION Plan` seulement si le délégué ajoute/retire une tâche ou change le périmètre.

**A4 — mineur — `Next` non groupé.** La règle de groupement ne vise que les `FORGE_QUESTION` (`swarm.md:66`) ; deux `FORGE_DONE` proches donnent deux fenêtres `Next` successives. *Correction :* étendre « Questions groupées » à la question `Next`.

**A5 — gênant — démarrage de la vérification d'ensemble non défini.** `swarm.md:185` « toutes fusionnées → tâche finale » sans dire si c'est automatique, ni quel déclencheur l'amène (la dernière fusion passe par `swarm.md:94`, qui ne relance que si une branche est choisie). Elle sort aussi du « Plan mixte » (`is_last` exclu, `swarm.md:182`). *Correction :* étape 6 de « Fusion d'une branche fille » : plus aucune tâche-branche ouverte → enchaîner la vérification d'ensemble (la validation initiale vaut accord), sinon question `Task` explicite.

**A6 — mineur — le parent ne progresse qu'au réveil.** « Une seule tâche ordinaire par tour, rendre la main » (`swarm.md:78`) : si aucun délégué ne notifie, le parent ne reprend la tâche suivante qu'à un message de l'utilisateur. Non documenté. *Correction :* dire que le tour suivant est déclenché par la prochaine notification ou par un « continue » de l'utilisateur, et l'afficher en fin de tour (« Waiting for delegates… type `continue` to take T<n> »).

---

## 3. Robustesse

**R1 — gênant — groupement des `FORGE_QUESTION` incompatible avec les questions ouvertes et au-delà de 4.** `swarm.md:66` : « une seule `AskUserQuestion` qui porte jusqu'à quatre questions ». Une `FORGE_QUESTION` `options: none` (question ouverte, `delegated-mode.md:48`, `p5-resume.md:17`) se relaie en texte libre (`delegation.md:49`) et ne peut pas entrer dans la fenêtre groupée ; avec N > 4, cinq questions simultanées ne sont pas traitées (« arrivée pendant une fenêtre ouverte » ne couvre pas « 5 en attente »). Chaque `question` doit aussi porter le préfixe `[<X>]` + contenu entier → fenêtre illisible pour des plans. *Correction :* questions ouvertes posées une par une après la fenêtre groupée, au-delà de 4 → fenêtre suivante, et N borné à 4 tant que le groupement vaut une fenêtre.

**R2 — gênant — échec d'un délégué non géré dans l'essaim.** La boucle de `delegation.md:51` (deux rappels puis « marquer chaque tâche du mandat `[!]` ») suppose un mandat : il n'y en a pas dans l'essaim. Aucun état `failed` dans SWARM (`swarm.md:138-142`), aucune règle pour un délégué terminé sur erreur (limite de contexte, erreur API, arrêt sans bloc). La branche garde son worktree → `swarm-status.sh` la compte `running` (`swarm-status.sh:292-293`) et occupe une place indéfiniment. *Correction :* « Rapport sans bloc après deux rappels » ou erreur de l'outil → ligne SWARM `stopped`, tâche-branche laissée ouverte, question `Resume` (Relaunch / Keep / Turn into a task) — réutilise « Reprise de l'essaim ».

**R3 — gênant — reprise après compactage : question `Resume` à tort, risque de double délégué.** Déclencheur `swarm.md:159` : « identifiant `Agent` lancé par aucun appel de cette conversation — session neuve, **contexte compacté** ». Après compactage dans la même session, les délégués tournent toujours ; si l'utilisateur répond `Relaunch`, deux agents écrivent dans le même worktree — exactement le risque que `swarm.md:161` veut éviter. *Correction :* noter dans SWARM l'identifiant de la session parente (déjà présent dans le journal du hook, champ `session` lu par `time-aggregate.sh:86`) ; même session → délégués réputés vivants, pas de question.

**R4 — mineur — reprise : ordre des questions.** `swarm.md:164` pose d'abord `Next` pour chaque branche `waiting for merge` (fusions possibles, donc nouveaux lancements via `Merge and launch`), puis `Resume` pour les `running` : un lancement peut précéder la décision sur les délégués arrêtés et prendre leur place. *Correction :* `Resume` d'abord, `Next` ensuite.

**R5 — bloquant — worktree d'une branche fille sans `.forge/` versionné.** Le worktree ne porte que les fichiers commités. `status.sh:86-87` rend `project_init` si `.forge/project.md` est absent, `coding_standards_init` si `coding-standards.md` l'est : le délégué partirait en initialisation de projet dans le worktree au lieu de planifier. Cas courant au premier usage de forge sur un dépôt (rien n'est commité avant le premier `grave`). La délégation vers un projet lié contrôle ce cas (`delegation.md:35`) ; l'essaim non (`swarm.md:23-28`). *Correction :* étape 5 de « Délégation — essaim » : `git cat-file -e <PARENT_BRANCH>:.forge/project.md` et `…coding-standards.md` échouent → « `.forge/` is not committed on `<PARENT_BRANCH>` — commit it first. » STOP (ou copier les deux fichiers dans le worktree, à choisir).

**R6 — mineur — fusion.** Procédure solide (`swarm.md:98-116`) : avance rapide sinon fusion inverse dans le worktree, règles de conflit, vérification, marques `merge_start`/`merge_done`. Points :
- `git merge --ff-only <X>` dans le dépôt principal qui porte des fichiers d'état non commités (plan, swarm, log, `project.md` modifié par `swarm.md:22`) : sûr tant que `<X>` ne touche pas ces chemins ; une Promotion ou un `project.md` complété par le délégué (`p4-plan.md:45`, étape 9 « pending ») ferait échouer l'avance rapide sans consigne. *Correction :* échec `--ff-only` → afficher les fichiers en cause, question.
- `metrics.json` de la branche fille est écrit à l'étape 2, avant `merge_done` (étape 5) : son `merge_minutes` reste `null` ; la mesure de fusion n'arrive que par le `metrics.json` du parent au `grave` (`engrave.md` § Synthèse). Correct mais à documenter. Le champ `event` n'a que `engrave` / `closure` (`engrave.md:37`) alors que la fusion d'une branche fille est un troisième déclencheur (`engrave.md:30`). *Correction :* `event: merge`.
- `git merge-tree --write-tree` (`swarm-status.sh:250`) exige git ≥ 2.38 ; plus ancien → code 129 → `conflict: null` pour toute branche existante, message « merge simulation failed » sans cause. Aucune exigence de version documentée. `swarm-status.sh` utilise `declare -A` et `printf %(…)T` (bash ≥ 4.2) sans la garde présente dans `log-entry.sh:63-66`.

**R7 — mineur — nettoyage.** Retrait après fusion : `status --porcelain` vide puis `git worktree remove` (`swarm.md:120-125`) — vérifié : les dépendances ignorées partent avec le worktree. Restent : la branche `<X>` n'est jamais supprimée après fusion (seulement dans la rétrogradation, `swarm.md:73`) → branches locales qui s'accumulent ; dossier `<dépôt>.worktrees/` vide laissé ; `Do nothing` (`swarm.md:91`) garde worktree, port et place sans échéance. *Correction :* `git branch -d <X>` à l'étape 7 de la fusion ; `Do nothing` affiché dans la ligne d'essaim de chaque reprise.

**R8 — mineur — limite N.** N = 3 par défaut, modifié sur demande seulement (`swarm.md:7`) ; places = N − branches à worktree (`swarm-status.sh:331`), branches `waiting for merge` et `Do nothing` comprises — cohérent (le port et l'installation restent occupés). Mais N n'est borné ni par la fenêtre groupée (4 questions, R1) ni par la machine (N installations complètes de dépendances). *Correction :* N ≤ 4 documenté.

**R9 — gênant — permissions des worktrees hors du dossier de session.** Le README le dit (`README.fr.md:525-527` : `/add-dir ../<dépôt>.worktrees`), `swarm.md` ne le vérifie ni ne le rappelle avant de lancer. Selon la doc officielle (§5), chaque demande de permission d'un délégué d'arrière-plan arrive dans la session principale : sans `/add-dir`, l'utilisateur reçoit une rafale de demandes de permission en plus des questions relayées. *Correction :* étape 4 de « Délégation — essaim » : rappeler la commande `/add-dir "<dépôt>.worktrees"` dans le tableau de lancement au premier lancement.

---

## 4. Incohérences instructions ↔ scripts, contradictions, termes

Champs JSON de `swarm-status.sh` ↔ `swarm.md` / `p5-resume.md` : `launchable` (`exists`, `conflict` true/false/null, `conflict_files`), `waiting.waiting_for`, `invalid` (`dependency`, `reason`), `blocked`, `stale.worktree`, `running` (`done`, `total`), `ordinary` (`waiting_for`, `is_last`), `slots`, `now` — **tous cohérents**. Options CLI : `--root`, `--branch`, `--assume-done` (`swarm.md:16,86`), `--groups`, `--slots` (`p4-plan.md:110`), `--files` (`p4-plan.md:31`), `time-mark.sh --event merge_start|merge_done|delegate|delegate_usage` (`swarm.md:103,114`, `delegation.md:10-11`), `time-aggregate.sh --parent-log --base` (`engrave.md:33`) — **tous conformes** aux usages des scripts. `open_branches` et `n` sont produits mais lus nulle part (sans gravité).

**I1 — gênant — contradiction « aucune autre question avant le lancement ».** `swarm.md:13` vs `swarm.md:22` (commande d'installation demandée) et `swarm.md:194` (question `ClickUp` au premier lancement). *Correction :* les poser avant / dans la question `Plan`, ou écrire l'exception.

**I2 — mineur — libellés `reason` du script ↔ phrases.** Script : `unknown|blocked|dropped|cycle|branch_name` (`swarm-status.sh:187-193,291`) ; `swarm.md:18` : `unknown | blocked | dropped | in a dependency cycle | is not a valid branch name` — correspondance implicite. *Correction :* table `reason → phrase` explicite.

**I3 — mineur — commentaire faux dans `time-calibrate.sh`.** `:148-149` « sous 10 tâches mesurées » alors que `MIN_RANGE_TASKS=20` (`:34`) et l'en-tête dit 20 (`:9-10`).

**I4 — mineur — chemin `<WORKTREE>` relatif ou absolu.** `swarm.md:3` le définit relatif dans SWARM ; le prompt `ROOT: <WORKTREE>` (`swarm.md:43`) ne dit pas « absolu », alors que la délégation de branche l'exige (`delegation.md:129`) et que le cwd du sous-agent est celui du parent. *Correction :* `ROOT: <chemin absolu de WORKTREE>`.

**I5 — mineur — listes d'en-têtes exemptés du contexte de décision divergentes.** `swarm.md:65` : Brief, Plan, Mode, Task, Promotion, Demote ; `delegated-mode.md:34` : sans Demote. `Approach` (p4 étape 5) n'est exempté nulle part → la question d'approche d'un délégué sera renvoyée s'il manque « coût d'un mauvais choix ». Intentionnel ? *Correction :* une seule liste, définie à un endroit.

**I6 — mineur — Promotion sans moyen de calcul.** `delegated-mode.md:33` demande au délégué d'appliquer la « Règle de branche » sans lui dire d'appeler `time-calibrate.sh` (c'est sous ROOT, donc permis).

**I7 — mineur — délégué sans mandat, boucle de relais héritée.** `swarm.md:62` reprend la boucle de `delegation.md:46-53`, dont la sortie d'échec marque « chaque tâche du mandat » (R2).

**I8 — mineur — description du skill.** `SKILL.md:3` ne cite pas l'essaim (« projet lié ou branche »).

**I9 — mineur — Gabarit `Plan` détourné.** `delegation.md:49` recopie le `content` d'un `Plan` délégué « selon le Gabarit — question `Plan` », gabarit à une seule tâche (`p5-resume.md:216-227`) ; pour un plan entier, la forme n'est pas définie.

Termes non définis : « socle des points d'extension » (défini par l'exemple `p4-plan.md:115`, suffisant) ; « fichier partagé » / « même module » pour la note de coordination (`swarm.md:67`) — le parent ne lit pas le code des branches, il ne peut le savoir que par les `**Files:**` du plan ; « vérification complète » (`swarm.md:113`) = `**Check pattern:**` ? non dit.

---

## 5. Contraintes Claude Code réelles

Constaté dans cette session même (ce rapport est produit par un sous-agent lancé par l'outil Agent) :
- **Skill dans un sous-agent : oui.** L'outil `Skill` figure dans les outils de ce sous-agent et `forge` dans la liste des skills disponibles → un délégué peut exécuter `/forge` via l'outil Skill.
- **AskUserQuestion : absent** de la liste d'outils de ce sous-agent → le contournement `FORGE_QUESTION` est nécessaire et bien posé (`SKILL.md:106`, `delegated-mode.md:8`, prompts `swarm.md:53`, `delegation.md:107`).
- **Worktree :** le sous-agent ne change pas de dossier — le cwd est celui du parent et revient au dossier de départ entre deux appels Bash (consigne de ce harnais). Tout repose donc sur `ROOT` + `git -C` / `--root`. Vérifié : un `git checkout <X>` exécuté par erreur dans le dépôt principal échoue proprement (« already used by worktree ») — pas de dégât, mais `SKILL.md:19,27` fait alors « afficher l'erreur, STOP » → délégué arrêté sans bloc → R2. *Correction :* `SKILL.md:19` en mode délégué : `git -C <ROOT> checkout`.
- **SendMessage** est un outil *différé* dans ce harnais (schéma à charger par ToolSearch avant usage) ; la boucle de relais (`delegation.md:49`) l'utilise sans le dire. Sans gravité pour un modèle qui suit les consignes du harnais.
- **Retour d'un sous-agent :** dans ce harnais, seul le rapport transmis par `SubagentHandback` atteint le parent ; le texte final brut n'est pas livré. Le prompt délégué dit « End every turn with a FORGE_QUESTION or a FORGE_DONE block » (`swarm.md:55`) ; le harnais indique lui-même au sous-agent d'utiliser `SubagentHandback`, donc le bloc devrait passer dans ce rapport — mais si la remise ne contient pas le bloc mot pour mot, la boucle tombe dans le cas « rapport sans bloc ». *Correction :* « End every turn by handing back a report that contains the FORGE_QUESTION or FORGE_DONE block verbatim ».
- **Mesure des délégués :** `delegation.md:11` lit `subagent_tokens` « de la notification » — constaté : la notification de fin d'un sous-agent de cette session porte `<usage><subagent_tokens>…</subagent_tokens>…</usage>` → cohérent.
- **Documentation officielle** (code.claude.com/docs/en/sub-agents.md, consultée via un sous-agent de vérification) :
  - Skill tool disponible par défaut aux sous-agents ; `AskUserQuestion` retiré de *tout* sous-agent, avant-plan comme arrière-plan → confirme les deux points ci-dessus.
  - Un sous-agent d'arrière-plan **remonte chaque demande de permission dans la session principale** (Échap refuse l'appel sans arrêter le sous-agent). Le README (`README.fr.md:526-527`) dit qu'il « s'arrête » : inexact, il attend une réponse, ce qui fait N fenêtres de permission concurrentes avec les questions relayées. R9 reste valable (mêmes conséquences pour l'utilisateur), formulation du README à corriger.
  - `SendMessage` reprend un sous-agent terminé avec tout son historique → la boucle de relais est faisable telle que décrite.
  - Survie d'un sous-agent d'arrière-plan à la fermeture de la session parente : **non documentée** → la prudence de « Reprise de l'essaim » (question `Resume`, option `Still running`) est justifiée.
  - Limites d'`AskUserQuestion` (nombre de questions par appel, options, longueur du `header`, question sans option) : **non documentées** dans tools-reference. Les « quatre options » (`SKILL.md:102`) et « jusqu'à quatre questions » (`swarm.md:66`) reposent sur le schéma de l'outil vu par la session parente, non vérifiable depuis un sous-agent qui n'a pas l'outil — à confirmer par l'auteur ; la réponse en texte libre (`Other`) est documentée, ce qui valide « changement demandé en texte libre » (`SKILL.md:104`).

---

## Verdict

**Bien intégré : oui pour le socle, non pour les jonctions.** Le script d'état est propre, en lecture seule, testé (24/24), et ses champs comme les options CLI des scripts de mesure correspondent exactement aux instructions. Les invariants (le parent seul fusionne, jamais de push, jamais de lancement sans choix utilisateur, questions relayées) sont tenus de bout en bout et le mode délégué est le bon contournement de l'absence d'`AskUserQuestion`. En revanche les passages entre phases fuient : p4 → p5 → swarm.md peut poser deux fois la même décision (A1), le Plan mixte réinjecte la question `Mode` (A2), un worktree sans `.forge/` commité envoie le délégué en initialisation (R5), et l'échec d'un délégué n'a pas d'état (R2).

**Minimum d'actions : non.** L'utilisateur valide le plan parent, puis à nouveau chaque plan fils dont les tâches figuraient déjà dans le plan parent, puis éventuellement chaque tâche ; s'y ajoutent `Mode` pour le parent et une relance manuelle après le socle. Les gisements : plan fils pré-approuvé (A3), `Validate and launch the swarm` valant accord pour le travail du parent et la vérification finale (A2, A5), relance automatique après le socle (D7), `Next` groupé (A4). On passerait d'environ 10 + 3n interactions à environ 1 + 2 par branche.

**Se déclenche bien : non.** Au calibrage de référence, une branche demande ≈ 30 fichiers et l'essaim deux branches ≥ 60 fichiers indépendants ; au seuil exact le script lui-même annonce une perte (30 vs 33 min) — le seuil ne garantit pas le gain qu'il justifie (D1). Quand il se déclenche avec un socle en tête — cas que p4 prescrit dès qu'une liste est partagée — rien ne se lance et rien ne relance (D7, bloquant). Et aucun chemin ne mène à l'essaim depuis un plan déjà écrit (D8).

Priorités : D7, R5 (bloquants) ; puis A1, A2, A3, R2, R3, D1.
