# Mise à jour du skill

## Garde

Mode délégué → aucune proposition, aucun contrôle : `AskUserQuestion` est inaccessible et aucune écriture n'a lieu hors de ROOT. STOP — ne pas continuer ce fichier.

## Contrôle manuel

**Déclencheur :** section « Mise à jour du skill » de `SKILL.md`.

**Réaction — dans l'ordre :**
1. Exécuter `bash <SKILL_DIR>/scripts/update.sh check --force`. Lire le JSON : contexte interne, jamais affiché brut.
2. `check` vaut `failed` → "Update check failed — the forge repository is unreachable." STOP — ne pas continuer.
3. `update_available` faux → "Forge is up to date (`<installed>`)." STOP — ne pas continuer.
4. `update_available` vrai → « Proposition » ci-dessous, puis STOP — ne pas continuer, quelle que soit la réponse.

## Proposition

**Déclencheur :**
- `update_available` vrai dans le JSON de `update.sh check` à l'étape préalable de « Détection d'état » (`SKILL.md`)
- Étape 4 du « Contrôle manuel » ci-dessus

**Réaction — dans l'ordre :**
1. Poser le choix avec `AskUserQuestion` — `header` : `Update`, question nommant `installed` (`null` → version inconnue) et `latest`, deux options :
   - `Update now` → "Install `<latest>` now, then relaunch `/forge`."
   - `Later` → "Skip this version; only a newer one is offered at startup."
2. Sur `Later` → exécuter `bash <SKILL_DIR>/scripts/update.sh dismiss` : cette version n'est plus proposée au démarrage, seule une version plus récente ou le « Contrôle manuel » la repropose. Revenir au déclencheur et continuer là où il s'est arrêté.
3. Sur `Update now` → exécuter `bash <SKILL_DIR>/scripts/update.sh run`. Lire le JSON : contexte interne, jamais affiché brut.
   - Sortie `0` → "Forge updated: `<from>` → `<to>`. Relaunch `/forge` to use it." STOP — ne pas continuer : les instructions chargées dans ce tour sont celles de l'ancienne version.
   - Sortie `2` → "Update failed: `<reason>`.", suivi de `detail` en bloc de code quand il n'est pas `null`. Revenir au déclencheur et continuer là où il s'est arrêté.
   - Sortie `1` → afficher l'erreur telle quelle. Revenir au déclencheur et continuer là où il s'est arrêté.

⚠️ Une seule proposition par tour : `Later` retenu ou échec → aucune nouvelle proposition dans ce tour, même si « Détection d'état » reprend à son étape 1.
