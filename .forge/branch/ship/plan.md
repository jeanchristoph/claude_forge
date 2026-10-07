# Plan — ship
**Objective:** Sortir la séquence git de la livraison (`ship` / `engrave`) de `p5-resume.md` vers un script bash unique, appelé en aperçu puis en exécution, quel que soit le nombre de branches citées.
**Date:** 2026-10-07

## Tasks

### T1 — Script `engrave.sh` et sa suite de tests
**Effort:** M
**Files:** `skills/forge/scripts/engrave.sh`, `tests/engrave.test.sh`
**Description:** Script rangé dans le dossier du skill, donc déployé par la boucle `skills/*/` des installeurs sans les modifier. Signature : `engrave.sh <preview|run> --branch <BRANCH> --message "<msg>" [--root <dir>] [target...]`, avec autant de branches cibles positionnelles qu'on en cite, dans l'ordre.
- Gardes : la branche courante de `--root` doit être `<BRANCH>` ; message non vide et de 150 caractères au plus ; mode inconnu → usage et code de sortie 1.
- Résolution des cibles : cible égale à `<BRANCH>` → aucune ligne ; cible absente (`show-ref`) → `skipped — branch missing` ; cible extraite dans un autre worktree (`worktree list --porcelain`) → `skipped — checked out in another worktree`. Working tree propre → lignes `add` et `commit` marquées `skipped — nothing to commit`, le push reste.
- `preview` : tableau Markdown sur un template fixe, en-têtes anglais `| # | Action | Detail |` : `add`, `commit`, `push`, un `merge` par cible, `checkout` final (omis sans cible). Aucune commande git en écriture.
- `run` : `add` → `commit` → `push -u <remote> <BRANCH>` (remote = upstream, sinon `origin`), puis pour chaque cible retenue `checkout` → `merge --no-edit <BRANCH>` → `push`, toujours depuis la branche de départ ; retour sur `<BRANCH>`. Premier échec git (conflit, push rejeté) → erreur affichée telle quelle, arrêt, code de sortie 2, jamais de `--force`. Succès → hash du commit et branches mises à jour.
- Tests écrits avec le script, sur un dépôt temporaire et un remote bare (AAA, intitulés en français) : aperçu avec 0, 1 et 3 cibles ; cible égale à `<BRANCH>` ignorée ; cible absente ; cible extraite dans un autre worktree ; exécution complète poussée sur le remote ; conflit qui arrête la séquence avant la cible suivante ; message trop long ; mauvaise branche courante ; working tree propre.
[x] 23 tests verts (`bash tests/engrave.test.sh`), mutation du script détectée.

### T2 — Brancher la Livraison de `p5-resume.md` sur le script
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`, `skills/forge/SKILL.md`
**Description:** Étape 3 → appeler `engrave.sh preview` et afficher sa sortie telle quelle. Étapes 6 à 9 → un seul appel `engrave.sh run` avec les mêmes arguments. Étape 10 (projets liés) → même appel avec `--root <LINKED_GIT>` et `<LINKED_BRANCH>`. Retirer de la prose les règles désormais portées par le script (cible égale à `<BRANCH>`, `skipped — branch missing`, `skipped — checked out in another worktree`, ordre des actions, arrêt sur échec), et remplacer « Format du tableau récapitulatif » par un renvoi au script : le tableau n'a plus d'en-têtes dans la langue de l'utilisateur. Garder les questions (`Engrave`, `Ship`, `Linked`, `Linked branches`), la génération du message et l'INVARIANT dépôt courant. Ajuster la ligne `SCOPE: branch` de `SKILL.md` (`--root` = ROOT).
[x] Réaction réduite à 8 étapes, section « Script de livraison » à la place du format du tableau.

### T3 — Documentation et métadonnées du dépôt
**Effort:** S
**Files:** `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`, `.gitattributes`
**Description:** Section « Shipping » des deux README, avec le même contenu dans chaque langue : la séquence est exécutée par `engrave.sh`, et le tableau récapitulatif a un format fixe. Ajouter une entrée `### Changed` dans `[Unreleased]` du CHANGELOG. Ajouter `skills/forge/scripts/` et `tests/` à la structure de `project.md`. Ajouter `tests/ export-ignore` dans `.gitattributes` ; le `eol=lf` des `*.sh` couvre déjà le script.
[x] README ×2 (arborescence + Shipping), CHANGELOG, project.md, `tests/ export-ignore`.

### T4 — `grave` prend le mode `ship`, suppression de `ship` / `livre`
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`, `skills/forge/SKILL.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Après validation par l'utilisateur des tests de T1 à T3 en l'état : `grave` / `engrave` adoptent le déroulé actuel de la livraison directe — tableau `preview` affiché comme compte rendu, `run` aussitôt, sans question `Engrave` (mode délégué `SCOPE: branch` compris) ; le déclencheur reste strict (le message commence par `grave` / `engrave`, branches existantes uniquement). Commandes `ship` / `livre` et paragraphe « Livraison directe » supprimés ; questions `Linked` / `Linked branches` gardées. `engrave.sh` inchangé : `preview` reste disponible pour une future commande de dry run, à nommer plus tard. Docs : puce « Shipping shortcuts », section Livraison et intro des deux README ; entrée « Direct shipping » de `[Unreleased]` dans le CHANGELOG réécrite. Au merge de `fix` : écarter sa question `Ship` (60 s).
[!] blocked — en attente des tests de l'utilisateur sur T1 à T3 en l'état.

### T5 — Tableau récapitulatif dans la question `Engrave`
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Étape 4 de la Livraison : la sortie de `preview` — parent puis chaque projet lié titré par `<LINKED>` — est recopiée telle quelle dans le champ `preview` de l'option `Run the sequence` : la boîte de dialogue masque le texte qui la précède. L'affichage texte de l'étape 3 reste. Mode délégué `SCOPE: branch` : le tableau part déjà dans `content`, le parent le recopie dans `preview` au relais. Entrée `### Fixed` dans `[Unreleased]` du CHANGELOG. Après T4 (plus de question `Engrave` pour `grave`), le tableau s'affiche en compte rendu, sans dialogue pour le masquer.
[x] `preview` de `Run the sequence` + relais `SCOPE: branch`, README ×2, `### Fixed` au CHANGELOG. Remplacé par T6.

### T6 — Tableau récapitulatif dans le texte de la question `Engrave`
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Étape 4 de la Livraison : la sortie de `preview` (parent puis chaque projet lié titré par `<LINKED>`) est recopiée telle quelle en tête du champ `question` de `AskUserQuestion`, suivie d'une ligne vide et de la phrase de question. Le champ `preview` de `Run the sequence` est retiré, parce qu'il casse le rendu du tableau. Le `⚠️` sur la boîte de dialogue qui masque le texte précédent reste, avec le nouveau remède. L'affichage texte de l'étape 3 ne change pas. En mode délégué `SCOPE: branch`, le parent recopie le `content` en tête de la question. Dans les deux README, la mention du `preview` est remplacée ; l'entrée `### Fixed` de T5 dans le CHANGELOG est réécrite.
[x] Tableau en tête de `question`, `preview` retiré, README ×2, CHANGELOG `### Fixed` réécrit. Remplacé par T7 : tableau dans la réponse seule, comme sur master.

### T7 — `engrave.sh preview` renvoie du JSON, Claude met en forme
**Effort:** M
**Files:** `skills/forge/scripts/engrave.sh`, `tests/engrave.test.sh`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`, `.forge/project.md`
**Description:** `preview` écrit un objet JSON sur une ligne (`branch`, puis `step`, `action`, `detail`, `skip` par action), sans `jq` ; `json_string` échappe `"`, `\` et les contrôles ; `render_table` et `escape_cell` supprimées ; `run`, gardes et codes de sortie inchangés. Tests de `preview` réécrits sur le JSON, échappement couvert. `p5-resume.md` fixe un seul rendu : le tableau récapitulatif de master (en-têtes dans la langue de l'utilisateur) dans la réponse ; la question `Engrave` ne porte que sa phrase, comme sur master (T5/T6 annulées). JSON jamais affiché brut. README ×2, CHANGELOG (`### Fixed` de T5/T6 retiré), `project.md`.
[x] 26 tests verts, rendu de master restauré, docs à jour.

### T8 — Tableau récapitulatif toujours affiché à la confirmation `grave`
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Étapes 3 et 4 de la Livraison : le tableau récapitulatif, au format actuel (`#` / action git / détail, une ligne par action du JSON de `preview`), est le dernier texte du tour, juste avant l'`AskUserQuestion` `Engrave` — aucun appel d'outil entre les deux, `preview` et `status` exécutés avant. Rien d'autre d'imposé autour du tableau ; la question garde sa phrase seule. Mode délégué `SCOPE: branch` : le tableau dans `content`, inchangé. `engrave.sh` inchangé. Section Shipping des deux README, `### Changed` dans `[Unreleased]` du CHANGELOG.
[x] Corrigé : gabarit figé — tableau dans la réponse, liste numérotée en dur dans `question` (texte avant la question masqué à l'écran), jamais de `preview` ; README ×2, CHANGELOG réécrit.

## Risks
- Appeler le script déclenche une demande de permission Bash, sauf en mode auto. En livraison directe, cette demande peut bloquer la séquence au-delà des 60 s de la question `Ship`. Aucune règle `permissions.allow` n'est ajoutée : autoriser d'office un script qui commit et pousse irait contre la règle des commits.
- Sous Windows, le script dépend de Git Bash, comme le reste du skill.

## Deployment
None

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — Script `engrave.sh` et tests | M | [x] |
| T2 — Brancher `p5-resume.md` sur le script | S | [x] |
| T3 — Documentation et métadonnées | S | [x] |
| T4 — `grave` en mode `ship`, suppression de `ship` / `livre` | S | [!] blocked — tests utilisateur |
| T5 — Tableau dans la question `Engrave` | S | [x] |
| T6 — Tableau dans le texte de la question `Engrave` | S | [x] |
| T7 — `preview` en JSON, mise en page par Claude | M | [x] |
| T8 — Tableau toujours affiché à la confirmation `grave` | S | [x] |
| **Total** | **2M + 6S** | |
