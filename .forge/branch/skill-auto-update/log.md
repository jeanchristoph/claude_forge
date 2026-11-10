# Log — skill-auto-update

- [2026-11-10 16:52] Proposition de livraison explicite : commit et push de la branche, branches cibles fusionnées dans l'ordre, ex. `grave dev master` (SKILL.md, CHANGELOG) — demande utilisateur
- [2026-11-10 00:00] Contrôle de mise à jour : délai ramené de 7 jours à 24 heures (update.sh, test 23 h ajouté, README, CHANGELOG, project.md, brief) — demande utilisateur
- [2026-11-09 00:00] Proposition de livraison dans la langue de l'utilisateur : « Tape `grave` pour graver. » / "Type `engrave` to ship." — correction utilisateur
- [2026-11-09 00:00] T9 ajoutée et corrigée sur accord : BOM de settings.json (install.ps1 écrit sans BOM, install.sh le retire à la lecture)
- [2026-11-09 00:00] T6–T8 ajoutées au plan et réalisées ; défaut signalé, non corrigé : install.ps1 écrit settings.json avec BOM, que install.sh ne sait pas relire
- [2026-11-09 00:00] install.json écrit avec last_check=0 quand la version est inconnue (installation hors git) : contrôle immédiat, conforme au brief
- [2026-11-09 00:00] Risques du plan levés : processus détaché et autoremplacement de update.sh vérifiés sous Windows, aucune parade nécessaire
- [2026-11-09 00:00] SKILL.md « COMMITS GIT » : forge ne propose jamais de commit, il propose la Livraison (« Run `grave` to ship. ») — demande utilisateur
- [2026-11-09 00:00] Ancienne branche auto-update supprimée en local et sur origin, remplacée par skill-auto-update — demande utilisateur
