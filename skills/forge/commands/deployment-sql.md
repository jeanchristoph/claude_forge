# Script de déploiement SQL

**Réaction — dans l'ordre :**
1. Écrire ou réécrire sur place `.forge/branch/<BRANCH>/output/AAAAMMJJ-deployment-script.sql`, sans question — un seul fichier par branche, daté de sa création, jamais renommé.
2. Entrée LOG : `Deployment script updated: [étapes ajoutées ou modifiées]`.

**Format :**
- En-tête en commentaire : branche, date, tableau des étapes — numéro, base visée, moment (`before` / `after deploy`), forme (`comment` / `query`), tâches d'origine.
- Une section par étape SQL, dans l'ordre de `## Deployment`, titrée `-- STEP [n] — [base visée] — [moment] · [T7, T9]`.
- Script versionné dans le dépôt → commentaire seul : chemin, prérequis, précautions, variantes production et développement. Jamais recopié.
- Requête autonome (`EXEC`, job, `UPDATE` d'exploitation) → telle quelle, exécutable, suivie de sa requête de contrôle.
- Valeur qui dépend de la date → calculée dans la requête, jamais laissée à saisir.
- Section contenant un `USE` → placée en dernier.
- Étape sans SQL → absente du script.

⚠️ Le script se réécrit en entier à chaque déclencheur, depuis `## Deployment` : jamais d'ajout en fin de fichier qui laisserait une étape obsolète.
