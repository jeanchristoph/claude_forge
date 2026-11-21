# Génération du plan

## Garde — mode délégué

En mode délégué (section « Mode délégué » de `SKILL.md`), quelle que soit la portée : étapes 5 et 7 → `FORGE_QUESTION`, mêmes header et options ; l'étape 7 recopie le plan entier dans `content`, l'étape 5 les approches présentées.
- `SCOPE: linked` → étape 7 sans `Validate and chain` : `Validate` y vaut déjà accord d'enchaîner.
- `SCOPE: branch` → étape 7 avec ses trois options ; `Validate and chain` retenu remplace la question `Mode` et chaque feu vert `Start T<n>`.

Si BRIEF contient `## Origin` (`SCOPE: linked` — mandat) → les étapes ci-dessous s'appliquent avec ces règles :
- Source unique du plan : `### Delegated tasks` du brief. `## Objective` et `## Scope & rules` cadrent, ils ne génèrent aucune tâche.
- En-tête supplémentaire, sous `**Date:**` : `**Origin:** <parent> · <BRANCH> · T3, T5` — valeurs reprises de `## Origin`.
- Titre de tâche : `### T1 — [Titre] ← parent T3`. Une tâche parente peut donner plusieurs tâches enfant ; chaque tâche enfant pointe une seule tâche parente.
- Aucune tâche hors mandat. Besoin hors périmètre découvert à la rédaction → entrée LOG `Out of mandate: [besoin]`, jamais une tâche ; remonté dans `FORGE_DONE`.

`SCOPE: branch` → aucune règle de mandat : plan rédigé depuis le brief comme pour toute branche.

## Étapes — dans l'ordre

1. Lire `@.forge/project.md`
2. Lire `.forge/coding-standards.md`
3. Lire `@.forge/branch/<BRANCH>/brief.md`
4. Reformuler l'objectif en 1 phrase pour confirmer la lecture.
5. Si plusieurs approches architecturales viables, les présenter :
   ```
   I have [N] possible approaches:
   **Option A — [Name]** : [1-2 sentences] | + ... | - ...
   **Option B — [Name]** : [1-2 sentences] | + ... | - ...
   ```
   Puis poser le choix avec `AskUserQuestion` — `header` : `Approach`, une option par approche (label `Option X — Name`, description = son compromis), quatre au maximum. Attendre le choix avant de continuer.
6. Générer le plan (format ci-dessous), puis l'estimer en un seul appel :
   - exécuter `bash <SKILL_DIR>/scripts/time-calibrate.sh --root <ROOT> --files <n1>,<n2>,…` — une valeur par tâche, dans l'ordre du plan : ses fichiers (« Fichiers d'une tâche » ci-dessous) ;
   - chaque tâche porte `**Estimated time:** ≈ <minutes> min (<low>-<high>)`, tiré de son rang dans `estimates` — `estimate` pour un plan d'une seule tâche ;
   - écrire l'en-tête `**Estimate:**` depuis `estimate` : `≈ <files> files · ≈ <minutes> min (<low>-<high>)`, suivi de ` · indicative` quand `indicative` est vrai.
   ⚠️ `**Estimated time:**` est figé à l'écriture du plan, jamais recalculé : c'est la prévision comparée au réel (`**Actual time:**`, section « Mesure d'une tâche » de `phases/p5-resume.md`). Tâche ajoutée en cours de branche → son estimation au ratio du moment, figée à son tour.
   Au moins deux tâches remplissent la « Règle de branche » ci-dessous → appliquer « Plan de branches » avant de présenter. Mode délégué → jamais de plan de branches : un sous-agent ne lance pas d'autres sous-agents ; la tâche qui le mériterait passe par la question `Promotion` (`commands/delegated-mode.md`).
   Présenter le plan.
7. Poser le choix avec `AskUserQuestion` — `header` : `Plan`, motif « Validation d'un contenu » de `SKILL.md` : le changement demandé arrive en texte libre, itérer, reposer la question. Trois options, dans cet ordre :
   - `Validate and chain` → "Validate the plan and work through every open task in order, without any further question."
   - `Validate` → "Validate the plan, then choose how to run the tasks."
   - `Cancel` → "Write nothing and stop."

   Plan d'une seule tâche d'effort XS → sans l'option `Validate` : le feu vert unique vaut pour le plan et la tâche.
   Plan de branches → quatrième option, en tête : `Validate and launch the swarm` → "Validate the plan, create the child branches and launch the first ones in parallel."
8. Écrire `.forge/branch/<BRANCH>/plan.md` après validation — `Validate and launch the swarm`, `Validate and chain` ou `Validate`.
9. Si `project.md` contient uniquement `<!-- pending -->` → le compléter (stack, périmètre, conventions du plan).
10. Continuer directement à l'État 5 : lire et exécuter `phases/p5-resume.md`.
    - Sur `Validate and launch the swarm` → lire et exécuter `commands/swarm.md`, section « Délégation — essaim de branches filles » : branche fille, worktree et brief sont créés au lancement de chacune.
    - Sur `Validate and chain` → p5 en mode enchaîné : aucune question `Mode`, aucun feu vert entre les tâches (étape 9 de `p5-resume.md`).
    - Sur `Validate` → p5 pose la question `Mode`.

---

## Format du plan

⚠️ Titres de sections et libellés de champs écrits tels quels ci-dessous, en anglais, quelle que soit la langue de l'utilisateur — seul le contenu entre crochets suit sa langue.

```markdown
# Plan — <BRANCH>
**Objective:** [1 phrase tirée du brief]
**Date:** [date du jour]
**Estimate:** ≈ [fichiers] files · ≈ [minutes] min ([bas]-[haut])

## Tasks

### T1 — [Titre court et précis]
**Effort:** XS/S/M/L/XL
**Estimated time:** ≈ [minutes] min ([bas]-[haut])
**Files:** `chemin/vers/fichier`, `chemin/vers/test`
**Description:** [Ce qui doit être fait, comment, avec quels patterns]
[ ]

<!-- Tâche L ou XL : décomposer en micro-étapes avant de démarrer
[ ] T1.1 — ...
[ ] T1.2 — ...
-->

## Risks
- [Point d'attention si applicable, sinon omettre]

## Deployment
[Étapes manuelles hors déploiement git, dans l'ordre d'exécution — script SQL, réglage de configuration, procédure d'exploitation. Aucune → `None`]
- [ ] [Quoi — quand : before / after deploy] · [T1, T3] — `output/AAAAMMJJ-intitule.sql`

## Summary
| Task | Effort | Files | Status |
|---|---|---|---|
| T1 — ... | S | 3 | [ ] |
| **Total** | **[répartition des lettres]** | **[somme]** | |
```

**Fichiers d'une tâche :** nombre de chemins listés dans `**Files:**`, tests compris. Ligne avec un motif (`src/**/*.ts`) ou des fichiers encore inconnus → nombre écrit en fin de ligne, `(≈ n)`, qui prime. Ancien plan qui porte `**Estimated files:**` → ce champ prime.
**Effort :** XS · S · M · L · XL — taille relative des tâches, sans durée attachée ; XL → découper en sous-tâches, ou en branche si la tâche remplit la « Règle de branche ».
**Estimate :** ordre de grandeur de durée d'agent, jamais un délai engageant ; le temps de réponse de l'utilisateur n'y est jamais compté.

---

## Règle de branche

**Condition :** une tâche est une branche dès qu'au moins `branch_criteria_required` critères ci-dessous sont vrais, vérifiés à l'écriture du plan — seuils de `time-calibrate.sh` :
- elle crée un module (bounded context) ou étend l'API publique d'un module existant ;
- elle exige des décisions à faire trancher : choix à soumettre, écarts à une référence, règles métier à confirmer — une branche a un brief, une tâche n'en a pas ;
- elle se livre et se teste seule : persistance, interface d'accès et écrans d'une même fonctionnalité ;
- sa durée estimée (fichiers de la tâche × `minutes_per_file`) atteint `branch_minutes` ;
- elle traverse au moins `branch_layers` couches (domaine, application, infrastructure, adaptateur, migrations).

**Critère prioritaire :** tokens estimés (fichiers de la tâche × `tokens_per_file`) au-delà de `branch_tokens` → branche, quel que soit le nombre de critères remplis.

⚠️ La lettre d'effort ne sert jamais de frontière : elle dépend de l'échelle de celui qui écrit le plan.

## Plan de branches

**Déclencheur :** au moins deux tâches du plan rédigé remplissent la « Règle de branche ».

**Réaction — dans l'ordre :**
1. Présenter avant le plan le tableau des critères : une ligne par tâche, une colonne par critère (`✓` / vide), une colonne tokens estimés, une colonne verdict (`branch` / `task`). En-têtes dans la langue de l'utilisateur.
2. Réécrire chaque tâche retenue en tâche-branche (format ci-dessous). Les autres restent des tâches ordinaires ; chaque tâche, ordinaire ou branche, porte `**Depends on:**`.
3. Découper selon ces règles :
   - par module ou par tranche verticale, jamais par couche : une branche « domaine seul » ne se teste pas seule ;
   - le producteur avant le consommateur : la branche qui crée une donnée partagée passe avant celles qui la lisent ;
   - listes partagées (menu, codes d'erreur, migrations, abonnements aux événements, routes, assemblage des dépendances) touchées par plusieurs branches → tâche ordinaire « socle des points d'extension » en tête du plan : chaque module déclare ses entrées dans ses propres fichiers, l'assemblage les découvre ;
   - taille cible d'une branche : 3 à 20 tâches ; en dessous → tâche ordinaire ; au-dessus → deux branches.
4. Ajouter en dernière tâche une tâche ordinaire « Vérification d'ensemble » qui dépend de toutes les branches : installation, build, tests de bout en bout et vérification visuelle de l'assemblage fusionné.

### Format d'une tâche-branche

```markdown
### T2 — Branch `<BRANCH>-<slug>` — [Titre]
**Effort:** L
**Estimated time:** ≈ [minutes] min ([bas]-[haut])
**Files:** `[dossier ou module touché]` (≈ [nombre])
**Depends on:** T1, `<BRANCH>-<autre-slug>`
**Brief:** [objectif de la branche en une phrase]
**Description:** [périmètre, règles reprises du brief, décisions attendues]
[ ]
```

- Nom de branche `<BRANCH>-<slug>`, kebab-case, anglais — jamais `<BRANCH>/<slug>` : git refuse une branche et une sous-branche de même préfixe.
- `**Depends on:**` liste des numéros de tâche ou des noms de branche, séparés par des virgules, ou `none` — jamais une phrase : la sélection de l'essaim la lit sans interprétation.
