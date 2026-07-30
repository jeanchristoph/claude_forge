# Plan — dev
**Objectif :** Extraire les décisions historisées de `brief.md` vers un fichier `log.md` dédié par branche, lu uniquement sur ses 10 dernières entrées à la reprise ; `brief.md` ne garde que l'objectif et les contraintes immuables, sans plus jamais être historisé.
**Date :** 2026-07-30

## Tâches

### T1 — Ajouter le chemin LOG
**Effort :** XS
**Fichiers :** `skill/SKILL.md`
**Description :** Ajouter `LOG : .forge/branch/<BRANCH>/log.md` à la liste des chemins (section « Chemins »), aux côtés de PROJECT, CODING_STANDARDS, BRIEF, PLAN.
[x]

### T2 — Retirer les Décisions du format brief, appliquer la règle anti-gabarit-figé
**Effort :** S
**Fichiers :** `skill/phases/p2-brief.md`
**Description :** `brief.md` ne garde que `## Objectif` et `## Contraintes` (immuables) — plus de section Décisions. Remplacer le bloc de format littéral figé par des instructions de structure (nom de section + rôle), conformément à la nouvelle règle de `.forge/coding_standards.md` (pas de gabarit en dur figeant la langue).
[ ]

### T3 — Écriture des décisions dans log.md
**Effort :** S
**Fichiers :** `skill/phases/p4-resume.md` (section « Mise à jour du brief »)
**Description :** Les décisions ponctuelles s'écrivent désormais dans `log.md` (append, format `- [date] [1 ligne]`), plus dans `brief.md`. Les contraintes immuables continuent d'aller dans `brief.md` sous `## Contraintes`, jamais archivées.
[x]

### T4 — Lecture bornée à la reprise, suppression de l'historisation du brief
**Effort :** S
**Fichiers :** `skill/phases/p4-resume.md` (sections « Actions — dans l'ordre » et « Historisation »)
**Description :** À la reprise, lire seulement les 10 dernières entrées de `log.md` pour construire le résumé « Last session » (plus toute la section Décisions de brief.md). `brief.md` ne fait plus l'objet d'aucune historisation — le seuil de taille (actuellement 30 000 car.) ne s'applique plus qu'à `log.md`, avec son propre nommage `log_AAAAMMJJ.md`.
[x]

### T5 — Procédure de migration vers log.md
**Effort :** M
**Fichiers :** `skill/SKILL.md` (nouvelle garde de migration)
**Description :** Nouvelle garde exécutée juste après la migration `.claude` → `.forge`. Condition : BRIEF existe ET LOG absent. Réaction automatique, sans confirmation :
1. Si `brief.md` contient `## Décisions & Contraintes` avec des entrées → renommer cette section en `## Contraintes`, n'y garder que le premier bloc contigu (contraintes). Tout ce qui suit ce premier bloc est déplacé vers `log.md` (créé si absent) tel quel — aucune reformulation, aucun retraitement, simple commande de déplacement.
2. Si aucune section trouvée → créer `log.md` vide quand même (lecture des « 10 dernières entrées » ne doit jamais échouer).
[x]

### T6 — Mettre à jour README.md (EN + FR)
**Effort :** S
**Fichiers :** `README.md`
**Description :** Refléter le nouveau format brief/log dans les deux sections (EN puis FR) : structure des fichiers générés (`log.md`), comportement des États 1-3 (Bootstrap/Plan/Actif), « Living brief »/« Brief vivant », « Last session summary », règles de mise à jour du brief. Détecté hors plan initial — ajouté sur confirmation.
[x]

## Risques
- L'identification du premier bloc (contraintes) repose sur la mise en forme existante (groupe contigu en tête de `## Décisions & Contraintes`), pas sur une analyse sémantique — la migration est un simple déplacement, sans reformulation.

## Récapitulatif
| Tâche | Effort | Statut |
|---|---|---|
| T1 — Chemin LOG | XS | [x] |
| T2 — Format brief sans Décisions | S | [x] |
| T3 — Écriture décisions → log.md | S | [x] |
| T4 — Lecture bornée + fin historisation brief | S | [x] |
| T5 — Migration vers log.md | M | [x] |
| T6 — Mise à jour README.md | S | [x] |
| **Total estimé** | **~5h30** | |
