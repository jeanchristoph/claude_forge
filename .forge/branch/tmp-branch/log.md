# Log — tmp-branch

- [2026-10-27 00:00] T1–T3 terminées : `temp-branch.sh` (16 tests verts, `engrave.test.sh` toujours 33/33), garde `SKILL.md` à 3 options, README FR/EN, CHANGELOG, `project.md`
- [2026-10-27 00:00] Marques de translittération iconv (`'`, `^`, `~`, `"`, `` ` ``, `?`) supprimées avant le slug : sous Git Bash `é` → `'e`, sinon `jérôme` donnait `j-er-ome`
- [2026-10-27 00:00] Un préfixe `<chiffres>-` n'est retiré que sur le domaine `users.noreply.gitlab.com` : `2024-equipe@…` reste `2024-equipe`

- [2026-10-27 00:00] Plan validé en mode enchaîné (Validate and chain)
- [2026-10-27 00:00] Option B retenue — script dédié `temp-branch.sh` testé, sur le modèle d'`engrave.sh`
- [2026-10-27 00:00] Identité de la branche temporaire : partie locale de `user.email` sans préfixe noreply, préférée à `user.name` (unique, stable, sans réseau)
