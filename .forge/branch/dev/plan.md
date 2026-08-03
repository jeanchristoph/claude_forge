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
[x]

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

### T7 — Livraison : merge de la branche de départ dans chaque branche citée
**Effort :** XS
**Fichiers :** `skill/phases/p5-resume.md` (section « Livraison — commit, push, merge »)
**Description :** `<BRANCH>` (branche de départ) est mergée dans chacune des branches citées, jamais la précédente de la chaîne dans la suivante. `grave` seul → `add` + `commit` + `push` uniquement. Branche citée égale à `<BRANCH>` → ignorée sans message. Détecté hors plan initial — ajouté sur confirmation.
[x]

### T8 — Libellés de structure figés en anglais (brief + plan)
**Effort :** S
**Fichiers :** `skill/phases/p2-brief.md`, `skill/phases/p3-log.md`, `skill/phases/p4-plan.md`, `skill/phases/p5-resume.md`, `.forge/coding_standards.md`, `README.md`
**Description :** La section « Contraintes » du brief devient `## Scope & rules`, au rôle élargi : règles immuables, contraintes techniques, périmètre et hors périmètre valables toute la durée de la branche. Titres et libellés de champs de `brief.md` et `plan.md` figés en anglais (`## Objective`, `## Scope & rules`, `## Tasks`, `**Effort:**`, `## Risks`, `## Summary`) — seul le contenu suit la langue de l'utilisateur. Règle inverse de l'ancienne consigne anti-gabarit-figé : `coding_standards.md` mis à jour en conséquence (stabilité de la relecture programmatique). Aucune migration des briefs existants. Détecté hors plan initial — ajouté sur confirmation.
[x]

### T9 — « Range la forge » : normaliser les libellés des fichiers forge
**Effort :** M
**Fichiers :** `skill/phases/p0-project.md`, `README.md`
**Description :** En mode mise à jour (« range la forge »), vérifier la conformité des fichiers de la branche courante (`project.md`, `brief.md`, `plan.md`) aux libellés de structure fixés en anglais, et renommer silencieusement les titres non conformes. Traitement délégué à un agent en tâche de fond (`run_in_background: true`), jamais bloquant — même mécanique que l'historisation. Périmètre : `project.md` + `.forge/branch/<BRANCH>/` uniquement, jamais les autres branches. Détection par rôle et position de section, jamais par correspondance de texte — un fichier généré par une version antérieure peut porter n'importe quelle langue. Contenu jamais modifié, seuls les libellés changent. Référence des libellés : `phases/p2-brief.md` et `phases/p4-plan.md`, jamais redéfinie ici. Détecté hors plan initial — ajouté sur confirmation.
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
| T7 — Livraison : merge depuis la branche de départ | XS | [x] |
| T8 — Libellés de structure figés en anglais | S | [x] |
| T9 — Range la forge : normalisation des libellés | M | [x] |
| **Total estimé** | **~6h** | |
