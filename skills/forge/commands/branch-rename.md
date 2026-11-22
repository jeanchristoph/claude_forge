# Renommage de branche

**Réaction — dans l'ordre :**
1. Exécuter `git branch -m <nouveau>`. Échec git → afficher l'erreur telle quelle, STOP.
2. Déplacer `.forge/branch/<ancien>/` vers `.forge/branch/<nouveau>/`, retirer les dossiers parents devenus vides.
3. Écrire une entrée dans LOG.
4. `git ls-remote --heads origin <ancien>` non vide → signaler : "`<ancien>` still exists on origin — not deleted."
5. Informer en une ligne : "On branch `<nouveau>`."

⚠️ Jamais de suppression de l'ancien nom sur le distant sans demande.
