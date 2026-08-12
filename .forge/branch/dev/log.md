# Log — dev

- [2026-08-12] `coding_standards.md` renommé `coding-standards.md` avec garde de migration automatique — seul renommage du système à en exiger une, le fichier conditionnant la détection d'état.
- [2026-08-12] Conventions de nommage de fichiers et de fins de ligne consignées dans `coding-standards.md`, pas dans le brief — norme du projet, pas cadre de branche.

- [2026-08-12] Lanceurs d'installation nommés `install-windows.bat` / `install-unix.sh` — kebab-case retenu contre l'underscore (convention des commandes shell, cohérence du dépôt), `unix` retenu contre `linux` (couvre macOS et WSL).
- [2026-08-12] `.gitattributes` ajouté — `*.sh` forcé en `eol=lf` : sans lui, `core.autocrlf` casse le shebang du lanceur Unix sur un clone Windows.

- [2026-08-12] Historisation de `plan.md` restreinte à `## Tasks` — `## Summary` conservée intégralement, sans marqueur d'archive sur les lignes des tâches déplacées.
- [2026-08-12] `log.md` lu borné (`limit: 40`) et nouvelles entrées insérées en tête — la taille du log ne pèse plus sur le coût de reprise ; seuil maintenu à 90 000 car, `plan.md` abaissé à 20 000 car.

- [2026-08-12] Seuils d'historisation contrôlés une seule fois par session, à la reprise — plus aucune vérification déclenchée par une écriture en cours de tâche.

- [2026-08-05] `report.txt` rédigé dans la langue de l'utilisateur, labels compris — exception unique aux libellés figés en anglais, actée dans `coding_standards.md`.
- [2026-08-05] Réponse mail rédigée dans la langue du mail reçu, jamais celle de l'utilisateur si elle diffère — le destinataire est le correspondant.
- [2026-08-05] `rapport.txt` renommé `report.txt` — noms de fichiers produits alignés en anglais ; `rapport.txt` antérieur ni lu ni migré.
- [2026-08-05] Mode professeur : écriture sans confirmation préalable, déléguée à un agent en tâche de fond ; question de suivi → nouvel agent chaîné après la fin du précédent, jamais en parallèle.
- [2026-08-05] Fichiers `cours-*.md` existants non migrés vers `explanation-*.md` — sous-produit local, pas un fichier de contrat (cohérent avec T8).

- [2026-08-03] « Range la forge » délègue la normalisation à un agent en tâche de fond, jamais bloquante — même mécanique que l'historisation et la migration vers `log.md`.
- [2026-08-03] « Range la forge » normalise les libellés silencieusement, branche courante seulement — options « toutes les branches » et « confirmation unique » écartées.
- [2026-08-03] Libellés de structure des fichiers produits figés en anglais (`## Objective`, `## Scope & rules`, `## Tasks`…) — retenu contre la génération dans la langue de l'utilisateur, pour la stabilité de la relecture programmatique.
- [2026-08-03] Section « Contraintes » du brief renommée `## Scope & rules`, rôle élargi au périmètre et au hors périmètre ; briefs existants non migrés.
- [2026-08-03] Livraison : `<BRANCH>` mergée dans chaque branche citée (jamais en chaîne) ; `grave` seul = add/commit/push ; `<BRANCH>` citée ignorée sans warning.
- [2026-08-03] Correction appliquée au dépôt uniquement — pas de réinstallation vers `~/.claude/skills/forge/`.
