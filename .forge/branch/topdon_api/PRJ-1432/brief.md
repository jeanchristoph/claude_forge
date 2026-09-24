## Origin
**Parent:** D:\www\topdon\topdon_api
**Branch:** PRJ-1432
**Tasks:** T13

### Delegated tasks

#### T13 — Skill forge : script de déploiement SQL généré automatiquement
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`, `skills/forge/phases/p4-plan.md`, `README.md`, `README.fr.md`, `CHANGELOG.md` (dans `D:\www\perso\claude skills\forge`)
**Description:**
- Déclencheur : la section `## Deployment` du plan gagne ou modifie une étape qui exécute du SQL (migration, script de reconstruction, requête d'exploitation).
- Réaction, sans question : écrire ou réécrire sur place `output/AAAAMMJJ-deployment-script.sql`. C'est un seul fichier par branche, daté de sa création. Une ligne est ajoutée au log.
- Format :
  - en-tête : branche, date, tableau des étapes (numéro, base visée, moment, forme `comment` / `query`, tâches d'origine) ;
  - une section `-- STEP [n] — [base visée] — [moment] · T7, T9` par étape SQL, dans l'ordre de `## Deployment` ;
  - un script versionné dans le dépôt apparaît en commentaire seul (chemin, prérequis, précautions, variantes production et développement), jamais recopié ;
  - une requête autonome (`EXEC`, job, `UPDATE` d'exploitation) apparaît telle quelle, exécutable, suivie de sa requête de contrôle ;
  - une valeur qui dépend de la date est calculée dans la requête, jamais laissée à saisir ;
  - une section contenant un `USE` est placée en dernier ;
  - une étape sans SQL n'apparaît pas dans le script.
- Numéros de tâches : le format d'une étape de `## Deployment` (p4-plan) gagne `· T1, T3` ; la règle de mise à jour silencieuse de p5 exige ces numéros et renvoie vers la nouvelle section « Script de déploiement SQL ».
- Documentation : une ligne dans chaque README ; dans le CHANGELOG, sous `[Unreleased]`, une entrée `### Added` et une entrée `### Changed`.

## Objective

Traiter, côté API, les retours de la tâche ClickUp PRJ-1432 « TOPDON_V2 - Reprise du visuel et des données graphiques » (https://app.clickup.com/t/869f3z3xy). Les commentaires de la tâche priment sur sa description initiale.

Périmètre API (catalogue de graphiques + API) :
- Unités : renseigner l'unité (%, €…) de chaque série qui en a besoin pour être comprise (`render_options.unit`).
- Unités biaisées : vérifier que les séries en % ne dépassent pas 100 % à tort.
- Plafond : nouvelle colonne `y_max` pour bloquer à 100 certains graphiques en %.
- Séries vides : désactiver une série toujours à 0, `''` ou NULL.
- Taille et ordre d'affichage :
  - Acquisition : Nouveaux donateurs, Collecte et Nombre de dons par campagne en XL.
  - Fidélisation : Attrition en position 1 (XL) avec une description sous le graphique, Cycle de vie des donateurs en position 2 (XL).
  - Prélèvements : Synthèse des prélèvements automatiques en XL.
- Coûts de collecte : montants empilés (`stack_id`).

Hors périmètre (front ou plus tard) : palette de couleurs, description en bleu pastel, visuel du résumé IA, bouton d'export ; couleur de chaque axe des ordonnées assortie à sa courbe (à voir en plan : l'API devra peut-être indiquer l'axe de chaque série) ; coût de collecte web à reprendre en interne via la facturation (à voir avec FRED) ; comparaison de campagnes.

## Scope & rules

- Consolidation des temps de réponse : entrée au plan de PRJ-1432 le 2026-09-23 (T7 à T10, script 015). Restent hors périmètre : le front (dépôt React) et tout cache côté API.
- Pistes retenues pour la passe de consolidation des temps de réponse (utilisateur, 2026-09-23) : (1) index couvrants sur dons et requêtes réécrites pour pouvoir utiliser l'index ; (2) table v2_ de résumé par donateur (premier/dernier don) ; (3) instantanés mensuels v2_ pour les fenêtres glissantes (66, 67, 68, 86), remplis par un traitement planifié séparé ; (4) côté front, chargement des cartes au défilement et squelettes. PAS de cache côté API.
- Livraison de la consolidation : les index, les tables v2_ précalculées et les réécritures de requêtes seront livrés dans un nouveau script SQL de diffusion (nouvelle migration numérotée), pas en retouchant 004, 006 ou 007 (utilisateur, 2026-09-23).
- Verrou partagé des commandes planifiées (T11) : entre dans le périmètre (utilisateur, 2026-09-23), y compris pour `app:insight:generate-syntheses`, par exception à l'exclusion générale du cron Insight.
- Règle de performance (utilisateur, 2026-09-23) : tout graphique publié doit répondre en moins de 1 s.
