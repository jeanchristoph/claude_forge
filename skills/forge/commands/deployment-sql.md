# Script de déploiement SQL

**Réaction — dans l'ordre :**
1. Écrire ou réécrire sur place `.forge/branch/<BRANCH>/output/AAAAMMJJ-deployment-script.sql`, sans question — un seul fichier par branche, daté de sa création, jamais renommé.
2. Entrée LOG : `Deployment script updated: [étapes ajoutées ou modifiées]`.

**Format :** le script de déploiement se déroule dans l'ordre, de haut en bas — un sommaire exécutable, jamais une concaténation de scripts.
- En-tête en commentaire : branche, date, tableau des étapes — numéro, base visée, moment (`before` / `after deploy`), forme (`script` / `query`), script à exécuter ou objet de la requête, tâches d'origine.
- Une section par étape SQL, dans l'ordre de `## Deployment`, titrée `-- STEP [n] — [base visée] — [moment] · [T7, T9]`.
- Étape portée par un fichier (procédure, migration, réparation, tout script de plus d'une dizaine de lignes) → forme `script`, commentaire seul : chemin du script à exécuter (relatif au dossier de la branche), objet, contrôle attendu, retour arrière. Jamais son contenu recopié.
- Petite requête autonome (`EXEC`, lancement de job, `UPDATE` d'exploitation d'une dizaine de lignes au plus) → forme `query` : écrite telle quelle, exécutable, suivie de sa requête de contrôle.
- Script versionné dans le dépôt → forme `script`, son chemin dans le dépôt, prérequis, variantes production et développement.
- Valeur qui dépend de la date → calculée dans la requête, jamais laissée à saisir.
- Section `query` contenant un `USE` → placée en dernier.
- Étape prévue sans script écrit → citée dans l'en-tête, « sans script à ce jour ».

⚠️ Le script se réécrit en entier à chaque déclencheur, depuis `## Deployment` : jamais d'ajout en fin de fichier qui laisserait une étape obsolète.
