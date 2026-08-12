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

### T10 — Mode professeur : renommage `explanation-*` + écriture en tâche de fond
**Effort :** S
**Fichiers :** `skill/SKILL.md`, `README.md`, `.forge/project.md`
**Description :** `cours-<sujet-slug>.md` devient `explanation-<sujet-slug>.md`. L'écriture (création ou complétion par section datée) est déléguée à un agent en tâche de fond (`run_in_background: true`), sans attente de retour — le fil de la tâche en cours reprend immédiatement. La confirmation « Est-ce clair ? » est supprimée : l'écriture part dès l'explication donnée. Question de suivi sur le même sujet → nouvel agent lancé seulement après la fin du précédent, jamais deux écritures simultanées sur le même fichier. Écriture signalée à l'utilisateur en une ligne à la fin de l'agent, jamais à son lancement, sans attente de réponse. Aucune migration des fichiers `cours-*.md` existants. Détecté hors plan initial — ajouté sur confirmation.
[x]

### T11 — `rapport.txt` → `report.txt`
**Effort :** XS
**Fichiers :** `skill/phases/p5-resume.md`, `README.md`, `.forge/project.md`
**Description :** Dernier nom de fichier produit resté en français aligné sur les autres (`brief.md`, `log.md`, `plan.md`, `explanation-*.md`). Aucune migration des `rapport.txt` existants — un fichier antérieur n'est ni lu ni renommé, la clôture de tâche suivante crée `report.txt`. Détecté hors plan initial — ajouté sur confirmation.
[x]

### T12 — Clôture : rapport et réponse mail dans la langue de l'utilisateur
**Effort :** XS
**Fichiers :** `skill/phases/p5-resume.md`, `.forge/coding_standards.md`
**Description :** `report.txt` rédigé intégralement dans la langue de l'utilisateur, labels compris — exception unique et explicite à la règle des libellés de structure figés en anglais, actée dans `coding_standards.md` : fichier destiné à un lecteur humain, jamais relu programmatiquement. Réponse mail générée dans la langue du mail reçu, jamais celle de l'utilisateur si elle diffère — le destinataire est le correspondant, pas l'utilisateur. Corrigé au passage : la confirmation de clôture référençait `## Objectif`, libellé inexistant depuis T8 — remplacé par `## Objective`. Détecté hors plan initial — ajouté sur confirmation.
[x]

### T13 — Historisation vérifiée au démarrage uniquement
**Effort :** S
**Fichiers :** `skill/phases/p5-resume.md` (sections « Actions — dans l'ordre » et « Historisation »)
**Description :** Le contrôle des seuils (`log.md`, `plan.md`) cesse d'être déclenché après chaque écriture réelle. Il devient un contrôle unique à la reprise, exécuté dans les `Actions — dans l'ordre` après lecture de `log.md` et `plan.md`, avant l'affichage du tableau d'avancement. En cours de session, aucune écriture ne déclenche plus de proposition d'historisation — le développement n'est jamais interrompu. Proposition et confirmation obligatoire inchangées, exécution toujours déléguée à un agent en tâche de fond. Détecté hors plan initial — ajouté sur confirmation.
[x]

### T14 — Lecture bornée du log, seuils recalibrés, historisation du plan limitée à `## Tasks`
**Effort :** S
**Fichiers :** `skill/phases/p5-resume.md` (sections « Actions — dans l'ordre » et « Historisation »)
**Description :** Trois volets.
1. Étape 4 : la lecture de `log.md` impose son mécanisme — `Read` avec `limit: 40`, les 10 entrées les plus récentes retenues parmi les lignes lues. Sans borne explicite, `Read` charge le fichier entier et la totalité du log entre en contexte à chaque reprise ; « lire les 10 dernières entrées » n'était qu'une intention. La convention d'écriture est figée dans « Mise à jour du brief et du log » : nouvelle entrée insérée **en tête** de `log.md`, juste sous le titre — la borne de lecture n'a de sens que si les entrées récentes sont en haut du fichier.
2. Seuils : `log.md` maintenu à 90 000 car — une fois la lecture bornée, sa taille ne pèse plus sur la reprise. `plan.md` abaissé de 30 000 à 20 000 car — injecté intégralement via `@`, il gouverne seul le coût de reprise. Note `⚠️` ajoutée dans « Historisation » explicitant cette asymétrie de mécanisme (`@` intégral vs `limit`).
3. Historisation de `plan.md` restreinte à la section `## Tasks` : `## Summary` et `## Risks` restent intactes — le tableau récapitulatif conserve toutes ses lignes, y compris celles des tâches archivées, et reste la vue complète de la branche. Garder les 10 tâches `[x]` les plus récentes, déplacer les plus anciennes. Règles conservées : tâche portant un sous-élément non coché jamais archivée, déplacement verbatim. Aucun marqueur d'archive sur les lignes du récapitulatif — déplacement strictement verbatim.
Détecté hors plan initial — ajouté sur confirmation.
[x]

### T15 — Lanceurs d'installation exécutables à la racine
**Effort :** XS
**Fichiers :** `install-windows.bat` (nouveau), `install-unix.sh` (nouveau), `README.md`, `.forge/project.md`
**Description :** Deux lanceurs à la racine du dépôt, appelables directement depuis un terminal, pour éviter la commande longue vers `install/`. Noms portant explicitement la plateforme cible.
- `install-windows.bat` → invoque `install/install.ps1` via `powershell -NoProfile -ExecutionPolicy Bypass -File`, chemin résolu relativement au script (`%~dp0`), code de sortie propagé. Appelable en cmd comme en PowerShell.
- `install-unix.sh` → shebang `#!/usr/bin/env bash`, délègue à `install/install.sh`, chemin résolu relativement au script. Bit exécutable versionné (`git update-index --chmod=+x`) pour que `./install-unix.sh` fonctionne après clone.
- Aucune logique d'installation dupliquée : les lanceurs délèguent, les installeurs existants restent la seule source de vérité.
- `README.md` : section Installation (EN + FR) et arborescence mises à jour. `.forge/project.md` : structure mise à jour.
- `.gitattributes` créé au passage : `*.sh` en `eol=lf`, `*.bat`/`*.ps1` en `eol=crlf`. Sans lui, `core.autocrlf` transforme le shebang du lanceur Unix en CRLF sur un clone Windows et le rend inexécutable sous WSL.
Détecté hors plan initial — ajouté sur confirmation.
[x]

### T16 — `coding_standards.md` → `coding-standards.md`
**Effort :** S
**Fichiers :** `skill/SKILL.md`, `skill/phases/p0-project.md`, `skill/phases/p1-coding-standards.md`, `skill/phases/p2-brief.md`, `skill/phases/p4-plan.md`, `skill/phases/p5-resume.md`, `README.md`, `.forge/project.md`, `.forge/coding_standards.md`
**Description :** Dernier nom du système en snake_case aligné sur le kebab-case employé partout ailleurs (`forge-precompact.sh`, `p0-project.md`, `explanation-<slug>.md`).
- Garde de migration dans `skill/SKILL.md`, placée juste après la migration `.claude` → `.forge` : `.forge/coding_standards.md` présent → renommer en `.forge/coding-standards.md`. Automatique, sans confirmation.
- ⚠️ Migration obligatoire, contrairement aux renommages précédents (`rapport.txt`, `cours-*`) : `CODING_STANDARDS` conditionne la détection d'état. Sans garde, le fichier est vu absent, l'État 1 se déclenche et régénère un fichier vierge par-dessus les standards rédigés du projet.
- Chemin `CODING_STANDARDS` et toutes les références mises à jour dans le skill, le README (EN + FR) et `project.md`. Fichier du dépôt renommé au passage.
- Conventions retenues consignées dans `coding-standards.md` : sections « Nommage des fichiers » (kebab-case, suffixe de plateforme `-windows`/`-unix`, nom de fichier produit en anglais) et « Fins de ligne » (`.gitattributes`, `*.sh` en LF).
Détecté hors plan initial — ajouté sur confirmation.
[x]

### T17 — `CHANGELOG.md`, premier tag, première release
**Effort :** M
**Fichiers :** `CHANGELOG.md` (nouveau), `README.md`, `.forge/project.md`
**Description :** Le dépôt n'a aujourd'hui ni tag, ni release, ni changelog : le numéro de version ne vit que dans le texte du `README.md` et une montée de version n'est visible nulle part — ni dans l'historique git, ni dans le feed GitHub des abonnés.
- `CHANGELOG.md` à la racine, format *Keep a Changelog* : rubriques `Added` / `Changed` / `Fixed` / `Removed`, ordre antichronologique, section `[Unreleased]` en tête, liens de comparaison `vX.Y...vX.Z` en bas.
- Reconstitution rétroactive à partir des 48 commits existants (2026-05-04 → 2026-08-12), par vagues thématiques et jamais un commit par ligne : `v0.1.0` (premier jet), `v0.2.0`, `v0.3.0`, `v0.4.0`, `v0.5.0`, `v0.6.0`, `v0.7.0` (état courant).
- Numérotation repartie en `0.x` : le développement initial autorise les changements de format sans version majeure, ce qui décrit exactement l'historique du projet. Le `1.1` affiché dans le README n'est pas repris — incohérence assumée, visible nulle part ailleurs que dans l'historique git.
- `README.md` : `**Version:**` porté à 0.7.0 dans les deux sections (EN + FR), lien vers `CHANGELOG.md`. `.forge/project.md` : structure mise à jour.
- Tags annotés et release publiée : exécutés dans la procédure de **Livraison**, jamais dans la tâche elle-même. Sept tags rétroactifs, mais une seule release publiée — sept releases déverseraient sept lignes d'un coup dans le feed des abonnés.
- ⚠️ `gh` CLI absent de la machine : la release passe par l'interface web GitHub, ou nécessite `winget install GitHub.cli` — décision à prendre au moment de publier.
- Hors périmètre : workflow GitHub Actions et versionnage automatisé (release-please, semantic-release). Rien à construire ni à publier automatiquement — un skill se distribue par clone.
- `gh` CLI 2.97.0 installé et authentifié en cours de tâche ; dépôt confirmé public, condition nécessaire au `ReleaseEvent`.
- Tags `v1.0` (`c120ce2`) et `v1.1` (`205110f`) à poser rétroactivement en même temps que `v1.2`, sans quoi les liens de comparaison du changelog sont morts.
Détecté hors plan initial — ajouté sur confirmation.
[x]

### T18 — Licence MIT
**Effort :** XS
**Fichiers :** `LICENSE` (nouveau), `README.md`, `CHANGELOG.md`, `.forge/project.md`
**Description :** Le dépôt était public sans licence, donc sous droit d'auteur intégral : consultable et forkable sur GitHub, mais ni utilisable, ni modifiable, ni redistribuable — incohérent avec un outil fait pour être cloné et installé.
- `LICENSE` MIT à la racine, copyright 2026 Jean-Christophe Malaval.
- Section `## License` / `## Licence` en fin de chaque version du README, `LICENSE` ajouté aux deux arborescences, entrée `Added` dans le changelog.
- MIT retenue contre Apache 2.0 : le projet est de la prose d'instructions sans procédé brevetable, la clause de brevets d'Apache couvrirait un risque quasi nul pour un fichier dix fois plus long. La bascule vers Apache 2.0 reste possible à tout moment, MIT accordant explicitement le droit de sous-licencier.
- Hors périmètre : CLA pour les contributions externes — nécessaire seulement en cas de passage à une licence propriétaire, jamais pour un passage vers Apache 2.0.
Détecté hors plan initial — ajouté sur confirmation.
[x]

### T19 — Visibilité du dépôt
**Effort :** S
**Fichiers :** `README.md`, métadonnées GitHub (hors dépôt)
**Description :** Le dépôt n'a aucun topic, une description en français alors que toute sa documentation publique est en anglais, aucun badge et aucun visuel. Quatre étoiles à ce jour.
- Topics posés via `gh repo edit` : `claude-code`, `claude`, `anthropic`, `ai-agent`, `developer-tools`, `workflow`, `cli`. Sans eux, le dépôt n'apparaît dans aucune recherche thématique.
- Description basculée en anglais — c'est la seule phrase visible dans une liste de résultats GitHub.
- Badges en tête de README (licence, dernière release) via shields.io, dans les deux versions.
- Emplacement de la démo visuelle préparé dans le README, avec les indications d'enregistrement. ⚠️ Le GIF lui-même est enregistré par l'utilisateur pendant une session réelle — non productible ici.
- Hors périmètre : renommage du dépôt (`claude_forge` → kebab-case), diffusion externe (listes communautaires, réseaux, article). Décisions à part.
- Ligne `**Version:**` du README supprimée au profit du badge de release, qui se met à jour seul — un numéro en dur dans le texte est une source d'oubli à chaque livraison.
- Topics et description : exécutés dans la procédure de **Livraison**, comme les tags de T17 — modification de métadonnées publiques, jamais silencieuse.
Détecté hors plan initial — ajouté sur confirmation.
[x]

### T20 — Démo animée générée par VHS
**Effort :** M
**Fichiers :** `docs/demo.tape` (nouveau), `docs/demo.sh` (nouveau), `docs/demo.gif` (généré), `README.md`, `.forge/project.md`
**Description :** T19 tenait le GIF pour non productible ici ; la chaîne VHS fonctionne sous WSL, ce constat tombe.
- `docs/demo.sh` rejoue les sorties du skill avec des temporisations choisies : récap « Last session », tableau d'avancement, « Ready to start with T1? » suivi d'un « go », tableau récapitulatif des actions git.
- ⚠️ Sorties reproduites mot pour mot depuis les phases du skill, jamais une version embellie — une démo reconstituée est acceptable, une démo qui montre un comportement inexistant ne l'est pas.
- `docs/demo.tape` pilote l'enregistrement : commandes de lancement masquées (`Hide` / `Show`), 100×30, police 16, thème sombre, cible sous 5 Mo.
- Démo régénérable à chaque évolution du skill sans nouvelle prise, les deux fichiers sources étant versionnés.
- Chaîne de génération : WSL Debian 13, `vhs` + `ttyd` en binaires officiels (`ttyd` retiré des dépôts Debian 13), `ffmpeg` et `chromium` par apt. ⚠️ Exécution en utilisateur non-root obligatoire — Chromium refuse de démarrer en root. Prérequis documentés pour un contributeur.
- `README.md` : commentaire d'emplacement remplacé par l'image, dans les deux versions, avec mention explicite que la session est reconstituée.
- Résultat : 26 s, 985 Ko, 1100×720. Tableau d'avancement à 5 s, tâche exécutée à 12 s, récapitulatif git à 20 s.
- `docs/README.md` documente la chaîne et ses deux pièges : WSL obligatoire (VHS ne tient pas sous Windows natif), exécution en utilisateur non-root (Chromium refuse de démarrer, VHS se bloque sans message).
Détecté hors plan initial — ajouté sur confirmation.
[x]

### T21 — README scindé par langue, sélecteur en badges
**Effort :** S
**Fichiers :** `README.md`, `README.fr.md` (nouveau), `docs/demo.sh`, `docs/demo.gif`, `.forge/project.md`, `CHANGELOG.md`
**Description :** Le README bilingue dépassait 640 lignes, dont la moitié de traduction : la démo et la section Installation étaient noyées dans le défilement.
- `README.md` ne garde que l'anglais, le français part dans `README.fr.md`. Même plan de section à section, environ 325 lignes chacun.
- Sélecteur de langue en badges cliquables juste sous le titre, langue courante en bleu, l'autre en gris — GitHub n'offre aucun bouton de langue natif, deux fichiers liés sont la convention.
- Démo : `grave master` remplacé par `engrave master`, la démo étant en anglais. GIF régénéré.
- Convention de documentation de `project.md` mise à jour : un fichier par langue, toute évolution de l'un répercutée sur l'autre dans le même commit.
Détecté hors plan initial — ajouté sur confirmation.
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
| T10 — Mode professeur : `explanation-*` en tâche de fond | S | [x] |
| T11 — `rapport.txt` → `report.txt` | XS | [x] |
| T12 — Rapport et réponse mail dans la langue de l'utilisateur | XS | [x] |
| T13 — Historisation vérifiée au démarrage uniquement | S | [x] |
| T14 — Lecture bornée du log + seuils recalibrés | S | [x] |
| T15 — Lanceurs d'installation à la racine | XS | [x] |
| T16 — `coding_standards.md` → `coding-standards.md` | S | [x] |
| T17 — `CHANGELOG.md`, premier tag, première release | M | [x] |
| T18 — Licence MIT | XS | [x] |
| T19 — Visibilité du dépôt | S | [x] |
| T20 — Démo animée générée par VHS | M | [x] |
| T21 — README scindé par langue | S | [x] |
| **Total estimé** | **~16h** | |
