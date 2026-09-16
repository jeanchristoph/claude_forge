# Plan — linked-project
**Objective:** Déléguer des tâches du plan courant vers un projet lié forgé, exécutées dans un sous-agent étanche sur la même branche, brief hérité et plan dérivé du mandat.
**Date:** 2026-09-16

## Tasks

### T1 — Commande « Délégation — projet lié » côté parent
**Effort:** M
**Files:** `skills/forge/phases/p5-resume.md`
**Description:** Nouvelle section de commande, au même rang que Frappe / Livraison / Clôture. Déclencheur : demande visant un dossier hors du projet courant. Réaction dans l'ordre : (1) `<dossier>/.forge/` absent → "`<dossier>` is not forged — run `/forge` there first." STOP ; (2) parent sur `main`/`master` sous identifiant de ticket → "Delegation needs a real branch." STOP ; (3) tâches nommées dans la demande → elles seules, sinon `AskUserQuestion` multi-sélection sur les tâches `[ ]` du plan (quatre par question, enchaînées), aucune → STOP ; (4) branche `<BRANCH>` dans le projet lié via `git -C` — existe → checkout, absente → créée depuis `master`/`main` à jour, même règle que `/forge <nom>` ; (5) écrire le brief enfant (T2) et le log enfant avec l'entrée "Opened from `<parent>` · T<n>" ; (6) annoter chaque tâche parente `delegated to <dossier> @ <BRANCH>`, une entrée log parent ; (7) lancer le sous-agent (T4). INVARIANT : le parent n'écrit dans le projet lié que `brief.md` et `log.md` de la branche ; jamais de code, jamais de plan.
[x] delegation section written in p5-resume.md, seven ordered steps + confirmation table

### T2 — Format du mandat : bloc `## Origin` du brief enfant
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`
**Description:** Gabarit figé, libellés en anglais : brief parent recopié à l'identique, précédé de `## Origin` — `**Parent:** <chemin absolu>`, `**Branch:** <BRANCH>`, `**Tasks:** T3, T5` — puis `### Delegated tasks` : chaque tâche parente recopiée intégralement (numéro, titre, effort, fichiers, description). `## Objective` et `## Scope & rules` suivent, inchangés. Aucune reformulation.
[x] mandate template fixed in p5-resume.md (## Origin / ### Delegated tasks)

### T3 — Mode délégué : marqueur, cloison, relais
**Effort:** M
**Files:** `skills/forge/SKILL.md`
**Description:** Nouvelle section « Mode délégué ». Condition : BRIEF contient `## Origin`. Règles : (a) ROOT = dossier transmis par le parent — tout chemin `.forge/` et toute commande git résolus sous ROOT ; (b) jamais `AskUserQuestion` — tout point bloquant termine le tour avec un bloc `FORGE_QUESTION` (`header`, `question`, `options` label — description, ou `options: none` pour une question ouverte) ; (c) frappe interdite ; (d) fin de séquence = bloc `FORGE_DONE` (`done`, `blocked` avec raison, `out_of_mandate`, `files`). INVARIANT : rien du parent n'entre, rien d'autre que `FORGE_DONE` ne sort. Renvoi depuis la section « Règle absolue » pour l'exception au `AskUserQuestion`.
[x] SKILL.md: ROOT path, « Mode délégué » section, FORGE_QUESTION / FORGE_DONE formats, exception noted under Règle absolue

### T4 — Lancement du sous-agent et boucle de relais côté parent
**Effort:** M
**Files:** `skills/forge/phases/p5-resume.md`
**Description:** Suite de T1. Prompt du sous-agent figé : ROOT, `<BRANCH>`, ordre d'invoquer le skill `forge` avec `<BRANCH>` en argument, rappel du mode délégué. Rien d'autre. Boucle : rapport contenant `FORGE_QUESTION` → relayer tel quel via `AskUserQuestion` (même header, mêmes options ; `options: none` → question en texte libre), renvoyer la réponse par `SendMessage` au même agent ; rapport contenant `FORGE_DONE` → sortie de boucle. Retour : pour chaque tâche parente déléguée, toutes ses tâches enfant `done` → `[x]` note `delegated · done`, une `blocked` → `[!] blocked — <raison>`, `out_of_mandate` → présenté à l'utilisateur, entrée log par tâche. Le parent ne coche jamais de lui-même.
[x] relay loop, FORGE_DONE return rules and fixed sub-agent prompt in p5-resume.md

### T5 — Plan enfant dérivé du mandat
**Effort:** M
**Files:** `skills/forge/phases/p4-plan.md`
**Description:** Garde en tête : BRIEF contient `## Origin` → plan rédigé exclusivement depuis `### Delegated tasks`. En-tête supplémentaire `**Origin:** <parent> · <BRANCH> · T3, T5`. Titre de tâche enfant `### T1 — [Titre] ← parent T3` ; une tâche parente peut donner plusieurs tâches enfant. Aucune tâche hors mandat ; un besoin hors périmètre → entrée log enfant, remonté dans `FORGE_DONE`. Étape 5 (approches) et étape 7 (validation) passent par `FORGE_QUESTION` — renvoi vers la section « Mode délégué ».
[x] p4-plan.md guard: mandate-only plan, Origin header, ← parent T<n> titles

### T6 — Frappe interdite en mode délégué
**Effort:** XS
**Files:** `skills/forge/phases/p5-resume.md`
**Description:** Reprise : option `Hammer the plan` retirée du choix de mode quand BRIEF contient `## Origin`. Frappe : garde en tête — mode délégué → "Hammering is disabled in a delegated context." STOP.
[x] Hammer option removed in delegated mode, guard on Frappe, FORGE_DONE on nothing open

### T7 — Test bout en bout sur deux dépôts forgés
**Effort:** S
**Files:** aucun fichier du dépôt — deux dépôts jetables dans le scratchpad
**Description:** Parent avec un plan de trois tâches, enfant forgé vide. Délégation de deux tâches : vérifier refus si `.forge/` absent, création de branche, brief enfant conforme au gabarit, relais d'une question de plan, `FORGE_DONE` avec une tâche verte, une bloquée, un besoin hors mandat ; marquage parent correct. Résultat consigné dans `output/20260916-linked-project-test-report.md`.
[x] end-to-end run green, report in output/20260916-linked-project-test-report.md; LANGUAGE line added to the prompt

### T8 — Documentation et publication 0.9.5
**Effort:** S
**Files:** `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Section « Delegating to a linked project » dans les deux README (même plan, même commit), mise à jour des sections State 5 et Hammering. CHANGELOG : entrée `Added` sous Unreleased, puis section `[0.9.5] — 2026-09-16` et liens de comparaison.
[x] README en/fr section « Delegating to a linked project », CHANGELOG 0.9.5 with compare links

### T9 — Livraison relayée vers le projet lié
**Effort:** M
**Files:** `skills/forge/phases/p5-resume.md`, `skills/forge/SKILL.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Au « grave » du parent, avant le tableau récapitulatif : détecter les projets liés depuis les notes `delegated to <LINKED> @ <BRANCH>` du plan parent ; pour chacun ayant des modifications non commitées, `AskUserQuestion` `Linked` (`Engrave it` / `Skip`) puis `Linked branches` (`Same branches as the parent` / `<BRANCH> only` / `Other branches` → texte libre). Message de commit du lié généré depuis les tâches `done` du mandat. Second bloc de tableau par projet lié ; une seule confirmation couvre parent et liés. Exécution en `git -C <LINKED>` par le parent, jamais par le sous-agent. Invariant git élargi : positionnement de branche et livraison déléguée. Branche citée absente du lié → `skipped`.
[x] relayed shipping in Livraison, tested on fixtures (parent dev+master, linked feat-greeting only); return note now keeps the linked path

### T10 — Suppression de la frappe
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`, `skills/forge/SKILL.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Retirer la commande « frappe » / « hammer » : section Frappe de p5-resume, option `Hammer the plan` du choix de mode (deux options restent), gardes et mentions en mode délégué devenues sans objet, prompt du sous-agent, sections Hammering des deux README, CHANGELOG `Removed` en 0.9.5. Motif : peu utilisée ; le mode d'exécution relève des préférences de codage de l'utilisateur dans CLAUDE.md, pas de forge.
[x] Frappe section, Hammer option, delegated guards and prompt line removed; README en/fr, CHANGELOG Removed

### T11 — Questions à choix dans la langue de l'utilisateur
**Effort:** S
**Files:** `skills/forge/SKILL.md`, `.forge/coding-standards.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Règle unique sous « Règle absolue » : question, header, libellés et descriptions d'un `AskUserQuestion` rédigés dans la langue de l'utilisateur ; les libellés anglais du skill sont des références internes (« Sur `Validate` » désigne l'option qui en tient lieu). Norme `coding-standards.md` alignée (exception aux répliques verbatim en anglais), README en/fr section Confirmations, CHANGELOG `Changed`.
[x] single rule in SKILL.md, coding-standards exception, README Confirmations en/fr, CHANGELOG Changed

### T12 — Validation d'un contenu : `Validate` / `Cancel` + texte libre expliqué
**Effort:** S
**Files:** `skills/forge/SKILL.md`, `skills/forge/phases/p2-brief.md`, `skills/forge/phases/p4-plan.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Motif unique sous « Règle absolue » : validation d'un contenu présenté → `Validate` / `Cancel` seulement, jamais d'option « à retravailler » ; demande de changement en texte libre avec explication → contenu retravaillé, même question ; texte sans substance → demander ce qui doit changer ; jamais re-présenter un contenu inchangé. p2 (`Objective`), p4 (`Plan`), clôture (`Report`) renvoient au motif. README en/fr Confirmations, CHANGELOG `Changed`.
[x] single pattern in SKILL.md, p2/p4/closure aligned, README en/fr, CHANGELOG

### T13 — Mode délégué : la validation du plan vaut accord
**Effort:** XS
**Files:** `skills/forge/phases/p5-resume.md`, `skills/forge/SKILL.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** En mode délégué, aucune question `Mode` : après validation du plan, le sous-agent enchaîne toutes les tâches ouvertes dans l'ordre. Un relais de moins par délégation.
[x] reprise and « Mode délégué » rule aligned, README en/fr, CHANGELOG

### T14 — Retrait des migrations et de la normalisation
**Effort:** S
**Files:** `skills/forge/SKILL.md`, `skills/forge/phases/p0-project.md`, `skills/forge/phases/p3-log.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Retirer tout mécanisme de migration ou de compatibilité : sections `.claude` → `.forge` et `coding_standards.md` de SKILL.md, migration des décisions du brief en p3 (réduite à la création d'un log vide), normalisation des libellés en p0. README en/fr et CHANGELOG alignés ; `docs/demo.sh` et l'historique du CHANGELOG intacts.
[x] SKILL.md, p0, p3 stripped; README en/fr, CHANGELOG header + Removed entry

### T15 — forge-clickup : objectif demandé, titre et description déduits
**Effort:** S
**Files:** `skills/forge-clickup/SKILL.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Étape 1 demande l'objectif en texte libre ; titre (une ligne) et description (quelques phrases) en sont déduits dans la langue de l'utilisateur, validés par le motif « Validation d'un contenu » avant création. Étape 3 crée la tâche avec `name` + `description`. Forge pré-remplit ensuite `## Objective` depuis la conversation.
[x] step 1 rewritten, create_task carries description, README en/fr usage line, CHANGELOG Unreleased

### T16 — Demande complémentaire = tâche au plan, validée sur sa formulation
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** La Surveillance ne propose plus `Add to the plan` / `Handle it off-plan` ni la question `Brief` : la tâche est formulée (titre, effort, fichiers, description, entrée `## Scope & rules` si le périmètre change) et validée en une question — motif « Validation d'un contenu ». `Validate` → plan (et brief) écrits, exécution selon le mode en cours ; `Cancel` → rien n'entre au plan, demande non traitée.
[x] Surveillance rewritten in p5-resume, README en/fr (intro + section), CHANGELOG Unreleased

### T17 — Exclure `.forge/`, `docs/` et les fichiers `.git*` des archives de release
**Effort:** XS
**Files:** `.gitattributes`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** `export-ignore` sur `.forge/`, `docs/`, `.gitattributes`, `.gitignore` — le dépôt les suit toujours, seules les archives « Source code » des releases GitHub les omettent. Ligne dans la section Installation des README, entrée CHANGELOG. Effet à partir du prochain tag.
[x] export-ignore rules in .gitattributes, README en/fr Installation, CHANGELOG Unreleased

### T19 — Action directe ≠ demande complémentaire
**Effort:** XS
**Files:** `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Seuil ajouté en tête de la Surveillance : un ordre précis, local, sans décision de conception est une action directe — exécutée immédiatement, journalisée si le dépôt change, jamais une tâche ni une question ; l'ordre explicite vaut confirmation. Doute → action directe. Le reste reste une demande complémentaire.
[x] Surveillance threshold in p5-resume, README en/fr, CHANGELOG Unreleased

## Risks
- Chaque question bloquante du sous-agent coûte un tour complet de relais — acceptable car le brief est hérité et la frappe interdite : validation du plan et choix du mode sont les seuls points attendus.
- Le sous-agent doit résoudre tous les chemins sous ROOT : un `.forge/` relatif écrit dans le projet parent violerait la cloison. Le test T7 le vérifie explicitement.
- Permissions Claude Code : les écritures hors du projet courant déclenchent des demandes d'autorisation — c'est l'utilisateur qui les voit, pas le sous-agent.

## Deployment
None

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — Commande « Délégation — projet lié » côté parent | M | [x] |
| T2 — Format du mandat : bloc `## Origin` | S | [x] |
| T3 — Mode délégué : marqueur, cloison, relais | M | [x] |
| T4 — Lancement du sous-agent et boucle de relais | M | [x] |
| T5 — Plan enfant dérivé du mandat | M | [x] |
| T6 — Frappe interdite en mode délégué | XS | [x] |
| T7 — Test bout en bout sur deux dépôts forgés | S | [x] |
| T8 — Documentation et publication 0.9.5 | S | [x] |
| T9 — Livraison relayée vers le projet lié | M | [x] |
| T10 — Suppression de la frappe | S | [x] |
| T11 — Questions à choix dans la langue de l'utilisateur | S | [x] |
| T12 — Validation d'un contenu : `Validate` / `Cancel` + texte libre | S | [x] |
| T13 — Mode délégué : la validation du plan vaut accord | XS | [x] |
| T14 — Retrait des migrations et de la normalisation | S | [x] |
| T15 — forge-clickup : objectif demandé, titre et description déduits | S | [x] |
| T16 — Demande complémentaire = tâche au plan, validée sur sa formulation | S | [x] |
| T17 — Exclure `.forge/`, `docs/` et `.git*` des archives de release | XS | [x] |
| T19 — Action directe ≠ demande complémentaire | XS | [x] |
| **Total** | **5M + 9S + 4XS** | |
