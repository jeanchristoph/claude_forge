# Mise à jour du skill

## Garde

Mode délégué → rien n'est fait : aucune écriture n'a lieu hors de ROOT. STOP — ne pas continuer ce fichier.

## Mise à jour

**Déclencheur :** "mettre à jour la forge" / "update the forge" (section « Mise à jour du skill » de `SKILL.md`). La demande vaut accord : aucune question.

**Réaction :** exécuter `bash <SKILL_DIR>/scripts/update.sh run` — cherche le dernier tag publié, l'installe s'il est plus récent, version ignorée comprise. Lire le JSON : contexte interne, jamais affiché brut.
- `status` vaut `done` → "Forge updated: `<from>` → `<to>`. Relaunch `/forge` to use it." STOP — ne pas continuer : les instructions chargées dans ce tour sont celles de l'ancienne version.
- `status` vaut `up_to_date` → "Forge is up to date (`<from>`)." STOP — ne pas continuer.
- Sortie `2` → "Update failed: `<reason>`.", suivi de `detail` en bloc de code quand il n'est pas `null`. STOP — ne pas continuer.
- Sortie `1` → afficher l'erreur telle quelle. STOP — ne pas continuer.

## Version ignorée

**Déclencheur :** "ignore cette version" / "ignore this version", après une annonce du hook `update-notice.sh`.

**Réaction :** exécuter `bash <SKILL_DIR>/scripts/update.sh dismiss`. Lire le JSON : contexte interne, jamais affiché brut.
- `dismissed` non nul → "`<dismissed>` won't be announced again; a newer version will. `update the forge` still installs it." STOP — ne pas continuer.
- `dismissed` nul → "No version to ignore." STOP — ne pas continuer.

⚠️ Commande citée dans la langue de l'utilisateur (« mets à jour la forge » en français).
