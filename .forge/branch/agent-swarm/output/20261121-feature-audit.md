# Audit de la branche `agent-swarm`

**Date :** 2026-11-21 · **Périmètre :** `git diff master...HEAD`, soit 47 fichiers et +3 850 lignes. Il couvre la mesure du temps (hook, agrégation, calibrage, marques de tâche), l'estimation par fichiers, le temps estimé et réel par tâche, l'essaim de branches filles et `log-entry.sh`.
**Méthode :** trois audits indépendants en lecture seule : scripts de mesure, protocole d'essaim, fluidité et instructions. Les constats graves ont été revérifiés à la main. Aucun fichier du skill n'a été modifié.
**Légende :** [V] vérifié (exécution ou lecture croisée) · [P] plausible, non rejoué.

## Synthèse

| Axe | Verdict |
|---|---|
| Fonctionnel | Les tests sont tous verts : 7 suites de mesure (164 tests) et `swarm-status` (15). Il reste un plantage du calibrage et plusieurs trous dans le protocole d'essaim, qui n'a jamais été essayé avec de vrais délégués. |
| Performance | Le hook est asynchrone (≈ 130 ms par appel, sans latence perçue). L'agrégation est lente sur un gros journal (20 s pour 50 000 lignes). Le vrai coût est ailleurs : les tours de modèle ajoutés à chaque tâche. |
| Fluidité | Chaque tâche demande 2 appels Bash de plus, un plan de 15 tâches demande 16 appels, et une simple reprise peut lancer l'essaim sans rien demander. |
| Pertinence | La mesure sous-estime le temps d'agent d'environ ×2 (I1). Le temps par tâche apporte peu (« ≈ 2 min » presque partout). Le seuil de 300 000 tokens n'est pas fondé. |

**Ce qui est solide :**
- **`log-entry.sh` :** plus d'heure inventée, et un Read et un Edit de moins par entrée LOG.
- **Hook :** il sort toujours en 0, n'écrit rien sur la sortie standard et ne lit aucun transcript. Les écritures concurrentes tiennent (3 × 40 hooks parallèles, aucune ligne perdue ni entrelacée).
- **Parsing tolérant :** il accepte CRLF, BOM, lignes tronquées, chemins avec espaces et branches avec `/`.
- **Mesure partielle :** une mesure `partial` est écartée du calibrage, et le résultat reste marqué `indicative` sous 5 branches mesurées.
- **`swarm-status.sh` :** lecture seule, et sa simulation `merge-tree` ne touche pas le dépôt.
- **Garde-fous git :** pas de push, pas de fusion vers la branche par défaut, retrait du worktree sans `--force`, aucun chemin absolu écrit.

---

## Bloquants

### B1. `time-calibrate.sh` plante sur `actual_files: null` [V]
- **Où :** `time-calibrate.sh:40,42`. `$3 > 0` est vrai pour la chaîne `"null"` (comparaison de chaînes en awk).
- **Effet reproduit :** `awk: fatal: division by zero`. Le JSON rendu est tronqué (`,"range_low":…`) avec le code de sortie **0**.
- **Quand :** dès qu'un dépôt n'a ni `master` ni `main` (par exemple `develop`), `actual_files` vaut null. Le `metrics.json` est versionné, donc **toutes les estimations futures du projet sont cassées**.
- **Correction :** ajouter `$3 != "null"` aux lignes 40 et 42, avec un test.

### B2. Question `Next` à 5 options, plus que les 4 qu'accepte `AskUserQuestion` [V]
- **Où :** `swarm.md:81-84`. On y trouve jusqu'à deux `Merge and launch <Y>`, plus `Merge`, `Check before merging` et `Do nothing`.
- **Correction :** une seule option `Merge and launch <Y>` ; les autres branches lançables sont citées dans sa description.

### B3. Plan non écrit sur `Validate and launch the swarm` [V]
- **Où :** `p4-plan.md:45`. Le plan n'est écrit que sur `Validate and chain` ou `Validate`. Ensuite, `swarm-status.sh` s'arrête avec `no plan for <PARENT>`.
- **Correction :** ajouter l'option à l'étape 8.

### B4. Délégué en double sur un même worktree, et reprise contradictoire [V lecture]
- **Contradiction :** `swarm.md:145` dit que le skill « ne le propose ni ne le déclenche jamais ». Or `p5-resume.md:19` et `:246` déclenchent la reprise quand une branche est `running` « sans délégué actif ».
- **Détection impossible :** aucun outil ne dit quels délégués sont actifs. Après `/compact` ou un nouveau `/forge`, le parent peut relancer une branche sur un worktree où un délégué écrit encore.
- **Correction :** stocker l'`agent_id` de chaque branche dans `swarm.md`, et ne jamais reprendre sans une question `Resume`.

### B5. Une reprise lance l'essaim sans accord [V]
- **Où :** l'étape 8 de `p5-resume.md:19` applique « Relance de l'essaim » sans question, et `swarm.md:13` dit « La demande vaut confirmation ».
- **Effet :** un simple `/forge` pour voir l'état crée des worktrees, installe les dépendances et lance jusqu'à 3 délégués en arrière-plan, soit des centaines de milliers de tokens. `Validate`, `Validate and chain` et `Validate and launch the swarm` aboutissent au même résultat.
- **Correction :** lancer automatiquement seulement sur `Validate and launch the swarm`. À la reprise, poser une question `Swarm` : `Launch <X>, <Y>` / `Work on parent tasks` / `Later`.

---

## Importants

### Mesure et estimation

**I1. Temps d'agent sous-mesuré d'environ ×2 [V]**
- **Où :** `time-aggregate.sh:69-71` et `:126-128`. Un `UserPromptSubmit` arrivé sans `Stop` écrase le tour ouvert sans le compter.
- **Quand :** message tapé pendant le travail, Échap, ou `task-notification` d'un délégué.
- **Journal réel :** 34 prompts pour 24 `Stop`. On mesure `parent_minutes` à 7,5 au lieu d'au moins 14,6.
- **Effet :** le calibrage hérite d'un ratio minutes/fichier deux fois trop bas, et le cas est fréquent en essaim. Le test `test_ignores_turn_without_stop` entérine ce défaut.
- **Correction :** fermer le tour ouvert au dernier événement observé avant le nouveau prompt.

**I2. Le hook sort en code 1 sous bash < 5 [V par émulation]**
- **Où :** `time-hook.sh:38-41` et `time-mark.sh:208-211`. Sans `EPOCHREALTIME` (par exemple le bash 3.2 de macOS), on obtient `substring expression < 0`.
- **Effet :** cela viole la règle « sortie 0 », et la mesure est perdue sans aucun signe. `log-entry.sh` demande aussi bash ≥ 4.2.
- **Correction :** ajouter `[ -n "$EPOCHREALTIME" ] || exit 0` et documenter l'exigence de version.

**I3. Agrégation à ≈ 0,4 ms par ligne [V]**
- **Mesures :** 50 200 lignes → 20 s, et 90 s avec `--task` sur 4 tâches. La cause est `field()`, dont la regex est recompilée à chaque appel (`time-aggregate.sh:37-43`).
- **Volume :** le journal n'est jamais purgé, et l'essaim le fait grossir vite.
- **Correction :** un `field()` à base de `index()`/`substr()`, testé 25 à 50 fois plus rapide.

**I4. Une tâche ajoutée en cours de branche n'a jamais d'`Estimated time` [V]**
- **Contradiction :** `p4-plan.md:36` le prévoit, mais le parcours d'ajout (`p5-resume.md:191-213`) n'appelle pas `time-calibrate.sh`.
- **Preuve :** T16 à T22 de ce plan n'en ont pas, donc leurs colonnes Estimé et Réel restent vides.
- **Correction :** appeler `time-calibrate.sh --files <n>` à l'étape 3 de la Surveillance.

**I5. Lignes `delegate` / `delegate_usage` écrites à la main dans le journal [V]**
- **Où :** `delegation.md:10-12`.
- **Effets :**
  - un `ts` postérieur au `SubagentStart` fait tomber `delegated_minutes` à 0 (essai : 0,0 au lieu de 2,0) ;
  - [P] une ligne écrite en UTF-16 depuis PowerShell 5.1 serait illisible.
- **Correction :** une action `time-mark.sh --event delegate|delegate_usage`, sur le modèle de `log-entry.sh`.

### Essaim

**I6. Dépendances impossibles : blocage silencieux [V essai]**
- **Cas reproduits :** cycle, tâche inexistante, dépendance `[!]` ou `[-]`, et `Depends on: T1 (because…)` mal lu. Dans tous ces cas, la branche reste `waiting` indéfiniment.
- **Aggravant :** une tâche-branche `[!]` n'apparaît dans aucune liste.
- **Correction :** des champs `invalid` et `blocked` dans `swarm-status.sh`.

**I7. Un worktree supprimé à la main reste `running` [V essai]**
- **Où :** `swarm-status.sh:112-121` ignore `prunable`.
- **Effet :** la branche occupe une place indéfiniment, et `git worktree add` échoue ensuite.
- **Correction :** un état `stale`, et proposer `git worktree prune`.

**I8. Impasses à la reprise [V/P]**
- **Plan mixte dont toutes les branches attendent une tâche ordinaire :** ni Relance ni Reprise ne s'applique, et la tâche ordinaire n'est jamais proposée (`p5-resume.md:19`).
- **Branche `waiting for merge` :** elle n'est reprise par rien après un redémarrage.
- **Contradiction :** `swarm.md:166` renvoie au mode d'exécution normal, alors que `p5-resume.md:19` interdit la question `Mode`.

**I9. Ports en collision et jamais conservés [V lecture]**
- **Règle actuelle :** « base + rang ». Si A est fusionnée et que D est lancée, D prend le rang de C.
- **Lacunes :** aucune colonne `Port` dans `swarm.md`, et le port n'est pas repris à la reprise.
- **Fonction dormante :** aucune étape n'écrit `**Dev port:**`, donc `Check before merging` ne peut pas fonctionner.

**I10. Commits implicites à la fusion [V lecture]**
- **Où :** `swarm.md:96-97`. La fusion commite la tâche en cours du parent et fait `git add -A` dans le worktree (sorties de build, `.env` copié…).
- **Écart :** l'option `Merge` n'en dit rien, ce qui heurte la règle « pas de commit sans autorisation ».
- **Rien n'est commité dans une fille avant sa fusion :** un délégué interrompu ne laisse aucun point de retour par tâche.

**I11. Environnement du worktree incomplet [P]**
- Les fichiers ignorés (`.env`, configuration locale) ne sont pas copiés.
- La base de développement est partagée par tous les délégués : migrations et tests se percutent.

**I12. Permissions hors du dossier de travail [P, risque majeur]**
- Les worktrees (`../forge.worktrees`) sont hors du dossier de la session. Les délégués en arrière-plan peuvent buter sur des invites de permission.
- **À documenter :** `/add-dir` ou `additionalDirectories`.

**I13. Le relais ne peut pas interrompre le parent [P]**
- Le retour d'un délégué n'arrive qu'au tour suivant. Si le parent enchaîne ses tâches dans un long tour, les délégués en attente restent bloqués.
- **Correction :** une tâche ordinaire par tour côté parent, ou la limite écrite noir sur blanc.

**I14. Règles mal ciblées [V lecture]**
- **Contexte de décision :** la règle (`swarm.md:61`) s'applique aussi aux questions de procédure (`Plan`, `Mode`, `Task`), ce qui les renvoie en boucle au délégué.
- **Essaim imbriqué :** possible, puisque le Plan de branches n'est pas exclu en mode délégué.
- **Rétrogradation :** `Turn into a task` n'a aucune procédure.

### Fluidité et coût

**I15. Surcoût en tours de modèle [V décompte]**
- **Constat :** les scripts sont rapides ; chaque appel est pourtant un tour de modèle de plus.
- **Décompte :**
  - **chaque tâche :** +2 Bash et +1 Edit ;
  - **écriture d'un plan :** n+1 appels à `time-calibrate`, donc 16 appels pour 15 tâches ;
  - **chaque `grave` :** +3 à 5 appels ;
  - **chaque événement d'essaim :** `swarm-status` relancé, puis `swarm.md` réécrit en entier.
- **Effet :** environ 20 à 30 tours de plus pour un plan de 10 tâches, eux-mêmes comptés dans `agent_minutes`.
- **Pistes :**
  - accepter `time-calibrate.sh --files 3,5,8` en un seul appel ;
  - fusionner la coche de Tn et le démarrage de Tn+1 ;
  - calculer la ligne Remaining dans `status.sh`.

---

## Mineurs

**Scripts :**
- **`Estimated time` arrondi :** `≈ 0 min (0-1)` pour 1 fichier ; une estimation égale à sa borne haute (`%.0f`).
- **Fiabilité gonflée :** `in_range` est calculé sur l'échantillon qui fixe le ratio.
- **Hook :**
  - le `ts` d'un PostToolUse est pris après le parsing et après `git`, donc décalé de plusieurs secondes sur une grosse sortie (4 Mo → 3,6 s) ;
  - −37 % possible avec `source` et `read -d ''`.
- **`time-mark.sh` :** il refuse `T2.1` alors que p5 décompose les tâches L et XL ainsi.
- **Journal :** `SubagentStart` sans `Stop` : temps perdu sans signalement. Événements perdus en tête détachée ou après `git branch -m`.
- **`swarm-status.sh` :**
  - une note `[x] …` sous une case `[ ]` marque la tâche comme faite ;
  - un titre `Branch feat/x:` donne un nom de branche invalide ;
  - une parente absente apparaît comme `conflict:true` ;
  - les conflits entre filles ne sont pas simulés.

**Instructions :**
- **Renvoi trompeur :** « Relance de l'essaim » est attribuée à `swarm.md` alors qu'elle est dans `p5-resume.md`.
- **Placeholders :** `<PARENT>` désigne le dossier dans `delegation.md` et la branche dans `swarm.md` ; `N` n'est pas défini dans p5.
- **`**Estimation ratios:**` :** écrit dans `project.md` à chaque grave, mais jamais lu.
- **`metrics.json` de clôture :** presque toujours écrasé par celui du `grave` suivant.
- **Surcharge des seuils :** une surcharge par `coding-standards.md` est annoncée, sans aucun format défini.
- **Projets existants :** jamais branchés sur la mesure (le `**Check pattern:**` est généré seulement à la création de `project.md`).
- **Tableau d'avancement :** l'emplacement de `Actual time` n'est pas défini pour un ancien plan, ni les cellules d'un plan partiellement estimé.
- **Règles répétées,** contre la règle « énoncée une seule fois » : pas de chemin absolu, pas d'heure écrite par Claude, le parent seul fusionne.
- **Branches filles créées deux fois :** dans `p4-plan.md:47` et dans `swarm.md:21`.
- **« Aucune question » contredit :** la commande d'installation et ClickUp posent une question.
- **Écritures du délégué :** `TIME_LOG` et `SCRATCHPAD` sont hors de ROOT, sans exception écrite. `git -C <WORKTREE>` n'est pas guillemeté (ce dépôt a un espace).

**Plan de cette branche :**
- Les lignes 1-2 de `.forge/branch/agent-swarm/plan.md` sont corrompues depuis `517c749` (`#[x]Plan[x]—[x]agent-swarm`) : un remplacement par regex de `[ ]`.
- Une règle « coche par Edit sur la ligne exacte » éviterait la récidive.

**Documentation :**
- **Exemples de plan :** ceux des README omettent `**Estimated time:**`, et `README.fr.md` traduit les libellés figés.
- **CHANGELOG :** il annonce `**Dev port:**`, qu'aucune étape n'écrit.

---

## Pertinence

1. **Temps par tâche, estimé et réel.**
   - **Coût :** 2 appels par tâche et 2 colonnes de plus.
   - **Apport :** affichage seul. Ces valeurs ne nourrissent aucun calibrage, et à 0,5 min par fichier presque tout affiche « ≈ 2 min ».
   - **Piste :** garder les marques `time-mark`, et calculer les durées en une passe au `grave`.
2. **Tableau d'avancement à 6 colonnes.**
   - Effort, Fichiers et Estimé disent trois fois la taille de la tâche.
   - **Piste :** retirer l'Effort, ou masquer Estimé et Réel tant que `indicative` est vrai.
3. **Nombre de fichiers comme prédicteur.**
   - C'est une unité grossière. Le seul point réel donne 45 fichiers prévus pour 31 réels (×0,69).
   - **Piste :** n'appliquer aucun facteur sous 3 points, et comparer plus tard au ratio par 100 lignes (`lines_added` est déjà stocké).
4. **Seuil de branche à 300 000 tokens.**
   - La règle s'applique à une tâche isolée, alors que p4 fait découper les XL : elle ne se déclenche qu'avec un plan à gros grain, ce qui est circulaire.
   - Le sens de `subagent_tokens` (contexte occupé ou cumul des entrées) n'est pas vérifié.
   - **Piste :** appliquer la règle à des groupes de tâches, et recalibrer après un vrai essaim.
5. **Essaim : gain réel.**
   - Le parallélisme est borné par le rythme de réponse de l'utilisateur : un `Start Tn` par tâche et par fille donne environ 9 questions avant de coder, puis jusqu'à 24 feux verts pour 3 branches de 8 tâches.
   - Le parent consomme environ 20 à 30 k tokens par branche relayée.
   - **Piste :** pour une fille, un plan validé vaut enchaînement ; N = 2 au premier essai réel.
6. **Coût de contexte.**
   - `p4-plan.md` est multiplié par 2,3, et `p5-resume.md` gagne 22 %.
   - « Règle de branche » et « Plan de branches » sont chargés pour tout plan.
   - **Piste :** les déplacer dans `commands/swarm.md`, lus seulement au-delà d'un seuil, et sortir le bloc `SWARM:` de `delegated-mode.md`.

---

## Priorités proposées

1. **Correctifs immédiats, petits et ciblés :**
   - B1 calibrage null ;
   - B2 limite de 4 options ;
   - B3 écriture du plan ;
   - I2 bash < 5 ;
   - I4 `Estimated time` des tâches ajoutées ;
   - réparation des lignes 1-2 de ce plan.
2. **Mesure crédible :**
   - I1 tour sans `Stop` ;
   - I3 performance de `field()` ;
   - I5 lignes `delegate` par script.
3. **Essaim sûr :**
   - B4 `agent_id` et reprise sur question ;
   - B5 pas de lancement à la reprise ;
   - I6 et I7 dépendances invalides et worktrees périmés ;
   - I8 impasses ;
   - I9 ports ;
   - I10 commits annoncés.
4. **Allègement :**
   - I15 regroupement des appels ;
   - temps par tâche calculé au `grave` ;
   - tableau à 5 colonnes ;
   - sections d'essaim chargées à la demande.
5. **Essai réel** d'un essaim avec N = 2 avant de toucher aux seuils.
