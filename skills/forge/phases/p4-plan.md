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
6. Générer le plan (format ci-dessous), puis l'estimer pour la présentation en un seul appel : `bash <SKILL_DIR>/scripts/time-calibrate.sh --root <ROOT> --files <n1>,<n2>,…` — une valeur par tâche, dans l'ordre du plan : ses fichiers (« Fichiers d'une tâche » ci-dessous). Présenter chaque tâche avec son rang dans `estimates`, et le plan avec `estimate`.
   ⚠️ Jamais de `**Estimate:**`, de `**Estimated time:**` ni de colonne `Estimated` / `Actual` / ligne `**Remaining**` écrits par le modèle : le hook `scripts/plan-hook.sh` les écrit à chaque écriture de `plan.md` — temps estimé de chaque tâche sous `**Effort:**`, en-tête sous `**Date:**`, `## Summary` régénéré depuis les tâches. `**Estimated time:**` est figé à son écriture, jamais recalculé : c'est la prévision comparée au réel (`**Actual time:**`, section « Mesure d'une tâche » de `phases/p5-resume.md`). Tâche ajoutée en cours de branche → estimée par le hook au ratio du moment, figée à son tour.
   Au moins deux groupes de tâches remplissent la « Règle de branche » ci-dessous → appliquer « Plan de branches » avant de présenter. Mode délégué → jamais de plan de branches : un sous-agent ne lance pas d'autres sous-agents ; la tâche qui le mériterait passe par la question `Promotion` (`commands/delegated-mode.md`).
   Présenter le plan.
7. Poser le choix avec `AskUserQuestion` — `header` : `Plan`, motif « Validation d'un contenu » de `SKILL.md` : le changement demandé arrive en texte libre, itérer, reposer la question. Trois options, dans cet ordre :
   - `Validate and chain` → "Validate the plan and work through every open task in order, without any further question."
   - `Validate` → "Validate the plan, then choose how to run the tasks."
   - `Cancel` → "Write nothing and stop."

   Plan d'une seule tâche d'effort XS → sans l'option `Validate` : le feu vert unique vaut pour le plan et la tâche.
   Plan de branches → quatrième option, en tête : `Validate and launch the swarm` → "Validate the plan, create the child branches and launch the first ones in parallel." — description complétée de l'estimation (`≈ <swarm_minutes> min instead of ≈ <serial_minutes> min, <écart>`, étape 1 de « Plan de branches »). Option toujours proposée, perte de temps comprise : le choix revient à l'utilisateur, l'estimation sous les yeux.
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

## Tasks

### T1 — [Titre court et précis]
**Effort:** XS/S/M/L/XL
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
| Task | Effort | Files | Estimated | Actual | Status |
|---|---|---|---|---|---|
| T1 — [titre court] | S | 3 | — | — | [ ] |
```

**Écrit par le hook :** `**Estimate:**` sous `**Date:**`, `**Estimated time:**` sous `**Effort:**`, `**Actual time:**` à la coche, et `## Summary` entier — colonnes `Estimated` et `Actual` recopiées des tâches, `Status` recopié de la ligne de statut (raison d'un `[!]` comprise), lignes `**Total**` et `**Remaining**` (tâches ouvertes). Le modèle n'écrit que la ligne de chaque tâche avec son titre court ; le hook garde ce titre, ajoute la ligne d'une tâche absente et réécrit tout le reste.

**Fichiers d'une tâche :** nombre de chemins listés dans `**Files:**`, tests compris. Ligne avec un motif (`src/**/*.ts`) ou des fichiers encore inconnus → nombre écrit en fin de ligne, `(≈ n)`, qui prime. Ancien plan qui porte `**Estimated files:**` → ce champ prime.
**Effort :** XS · S · M · L · XL — taille relative des tâches, sans durée attachée ; XL → découper en sous-tâches, ou en branche si la tâche remplit la « Règle de branche ».
**Estimate :** ordre de grandeur de durée d'agent, jamais un délai engageant ; le temps de réponse de l'utilisateur n'y est jamais compté.

---

## Règle de branche

**Condition :** un groupe de tâches est une branche quand les deux points ci-dessous sont vrais, vérifiés à l'écriture du plan. Groupe = tâches d'un même module ou d'une même tranche fonctionnelle (persistance, interface d'accès et écrans d'une même fonctionnalité) ; une tâche seule peut former un groupe.
- **Durée :** fichiers du groupe (« Fichiers d'une tâche », additionnés) × `minutes_per_file` de `time-calibrate.sh` ≥ `branch_minutes` — seuil placé au-delà du coût fixe d'une branche, environ 8 min de délégué et 5 min de fusion.
- **Indépendance :** le groupe se livre et se teste seul, sans fichier partagé avec un autre groupe hors du socle des points d'extension — sinon chaque fusion finirait en conflit.

⚠️ La lettre d'effort ne sert jamais de frontière : elle dépend de l'échelle de celui qui écrit le plan.

## Plan de branches

**Déclencheur :** au moins deux groupes de tâches du plan rédigé remplissent la « Règle de branche ».

**Réaction — dans l'ordre :**
1. Présenter avant le plan le tableau des groupes : une ligne par groupe — tâches, fichiers, durée estimée, indépendance (`✓` / fichier partagé), verdict (`branch` / `task`). En-têtes dans la langue de l'utilisateur. Sous le tableau, le gain de l'essaim : `bash <SKILL_DIR>/scripts/time-calibrate.sh --root <ROOT> --groups <fichiers de chaque groupe retenu>` (`--slots <N>` quand `swarm.md` fixe N), puis `Swarm ≈ <swarm_minutes> min instead of ≈ <serial_minutes> min in series (<écart>) · <branches> branches, fixed cost <fixed_minutes> min · dependencies ignored`. Écart = `serial_minutes` − `swarm_minutes` : `<n> min saved` quand il est positif, `<n> min lost` sinon.
2. Réécrire chaque groupe retenu en une tâche-branche (format ci-dessous), ses tâches reprises dans `**Description:**` : elles deviennent le plan de la branche fille. Les autres restent des tâches ordinaires ; chaque tâche, ordinaire ou branche, porte `**Depends on:**`.
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
**Files:** `[dossier ou module touché]` (≈ [nombre])
**Depends on:** T1, `<BRANCH>-<autre-slug>`
**Brief:** [objectif de la branche en une phrase]
**Description:** [périmètre, règles reprises du brief, décisions attendues]
[ ]
```

- Nom de branche `<BRANCH>-<slug>`, kebab-case, anglais — jamais `<BRANCH>/<slug>` : git refuse une branche et une sous-branche de même préfixe.
- `**Depends on:**` liste des numéros de tâche ou des noms de branche, séparés par des virgules, ou `none` — jamais une phrase : la sélection de l'essaim la lit sans interprétation.
