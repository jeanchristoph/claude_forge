# Plan — topdon_api/simplify-architecture
**Objective:** Doter forge d'une table de routage de l'information durable (CLAUDE.md global / coding-standards.md par nature / project.md / brief / log / output) et donner à `coding-standards.md` une structure générique fixe `## Architecture` / `## Constraints` / `## Conventions`, la carte des dossiers restant dans `project.md` `## Key structure`.
**Date:** 2026-09-29
**Origin:** D:/www/topdon/topdon_api · simplify-architecture · T10

## Tasks

### T1 — Table de routage de l'information dans SKILL.md ← parent T10
**Effort:** S
**Files:** `skills/forge/SKILL.md`
**Description:** Nouvelle section `## Routage de l'information` après « Contenu généré ». `**Déclencheur :**` une information durable apparaît (décision, règle, constat). `**Réaction :**` consulter la table dans l'ordre, première ligne applicable, sans question. Critère énoncé une fois : normatif ou descriptif d'abord, portée ensuite. Lignes, dans l'ordre : vaut pour tous les projets → `~/.claude/CLAUDE.md`, proposé puis validé (renvoi vers « Choix d'infrastructure » de p5) ; fait technique qui fonde une contrainte → le fait dans `.forge/project.md`, la règle dans `.forge/coding-standards.md` `## Constraints` ; règle du projet à appliquer en codant → `.forge/coding-standards.md`, dans la section de sa nature (`## Architecture` / `## Constraints` / `## Conventions`) ; description du projet tel qu'il est (stack, carte des dossiers et de leur rôle, points d'entrée) → `.forge/project.md` ; règle ou contrainte de la seule branche → `brief.md` `## Scope & rules` ; décision ponctuelle → `log.md` ; livrable à la demande → OUTPUT (renvoi vers « Contenu généré »). La ligne « fait technique » précède la ligne « règle du projet » : première ligne applicable, elle capte le cas double.
[x] Section « Routage de l'information » ajoutée après « Contenu généré », renvois vers p5.

### T2 — p1 : structure générique fixe de coding-standards.md ← parent T10
**Effort:** S
**Files:** `skills/forge/phases/p1-coding-standards.md`
**Description:** Gabarit de génération réécrit, libellés anglais figés : `## Architecture` (`### Directory layout`, `### Naming`, `### Dependencies`), `## Constraints` (une sous-section par sujet), `## Conventions`. Contenu rédigé depuis ce que l'État 0 a observé, adapté à la forme du projet, jamais « module » présupposé. Section sans matière observée ou projet vide → `<!-- pending -->`, section conservée. Garde inchangée.
[x] Objectif, gabarit et étapes de contenu réécrits ; `<!-- pending -->` pour une section vide.

### T3 — p0 : `## Key structure` = carte des dossiers ; mise à jour sans réécriture de coding-standards.md ← parent T10
**Effort:** XS
**Files:** `skills/forge/phases/p0-project.md`
**Description:** Gabarit `## Key structure` précisé : carte des dossiers et de leur rôle (descriptif, aucune règle). Mode mise à jour : `.forge/coding-standards.md` lu, jamais réécrit — un écart normatif constaté est proposé à l'humain selon la table de routage de `SKILL.md`, jamais écrit d'office.
[x] Key structure = carte descriptive ; ⚠️ coding-standards.md jamais réécrit en mise à jour.

### T4 — README.md + README.fr.md ← parent T10
**Effort:** S
**Files:** `README.md`, `README.fr.md`
**Description:** Nouvelle section « Information routing » / « Routage de l'information » ; section `coding-standards.md` réécrite (structure fixe, rôle de chaque section, `<!-- pending -->`) ; States 0/1 et « Updating project.md » alignés ; annotation de `coding-standards.md` dans l'arborescence `.forge/`. Même plan section à section dans les deux langues.
[x] Sections coding-standards.md + Routage ajoutées, États 0/1, mise à jour project.md et arborescence alignés, EN/FR.

### T5 — Corrections après test sur topwebj5 ← parent T10
**Effort:** XS
**Files:** `skills/forge/phases/p1-coding-standards.md`, `skills/forge/SKILL.md`, `README.md`, `README.fr.md`
**Description:** `### Naming` couvre tous les identifiants (fichiers, dossiers, classes, méthodes, variables, constantes, tables et colonnes de base, booléens) ; `## Conventions` découpée en sous-sections par sujet (`Language`, `Code`, `Errors & logs`, `Tests`, `Comments`, `Git`…) comme `## Constraints` ; `coding-standards.md` ne recopie jamais le `CLAUDE.md` global — uniquement ajout ou dérogation, règle énoncée dans p1 (étape 4, lecture de `~/.claude/CLAUDE.md`) et dans la table de routage.
[x] p1 (gabarit + étape 4), SKILL.md (ligne « règle du projet » + ⚠️), README EN/FR alignés.

### T6 — p2 et p5 renvoient vers la table de routage ← parent T10
**Effort:** XS
**Files:** `skills/forge/phases/p2-brief.md`, `skills/forge/phases/p5-resume.md`
**Description:** p2 : la phrase « décisions ponctuelles → LOG » remplacée par un renvoi vers « Routage de l'information ». p5 : « Mise à jour du brief et du log » renvoie vers la table et ne garde que la procédure d'écriture (silencieuse, format, insertion en tête) ; « Choix d'infrastructure » : étape 2 déclenchée quand la table désigne le `CLAUDE.md` global, validation `Add to CLAUDE.md` / `Keep it local` conservée.
[x] p2 + p5 alignés ; `Keep it local` → ligne suivante applicable de la table (au lieu du brief en dur).

### T7 — Entrée CHANGELOG `[Unreleased]` ← parent T10
**Effort:** XS
**Files:** `CHANGELOG.md`
**Description:** `### Added` : table de routage de l'information. `### Changed` : structure fixe de `coding-standards.md` ; `## Key structure` descriptive et `coding-standards.md` jamais réécrit en mise à jour.
[x] Trois entrées ajoutées en tête de leurs rubriques.

### T8 — Restructuration du coding-standards.md du dépôt forge ← parent T10
**Effort:** S
**Files:** `.forge/coding-standards.md`
**Description:** Règles existantes redistribuées dans `## Architecture` / `## Constraints` / `## Conventions`, sans perte ni recopie du `CLAUDE.md` global.
[x] Constraints : libellés anglais figés, fins de ligne ; Conventions : Wording, Instruction structure ; Naming : phases, lanceurs, fichiers produits, placeholders ; Directory layout tiré de `project.md` ; Dependencies `<!-- pending -->` ; règle kebab-case retirée (déjà dans le `CLAUDE.md` global).

### T9 — Routage par nature et portée, section `## Business rules` ← parent T10
**Effort:** S
**Files:** `skills/forge/SKILL.md`, `skills/forge/phases/p0-project.md`, `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Table de routage par nature (technique / métier) et portée : règle technique tout le projet → `coding-standards.md` ; règle métier tout le projet → `project.md` `## Business rules` ; règle technique ou métier de la seule branche → brief `## Scope & rules`. p0 : `## Business rules` ajoutée au gabarit, normative, jamais réécrite ni supprimée en mise à jour, `<!-- pending -->` si vide. p5 : `Keep it local` suit la table selon nature et portée. README ×2 et CHANGELOG alignés.
[x] SKILL.md (critère + 2 lignes), p0 (gabarit + ⚠️ mise à jour), p5 (`Keep it local`), README EN/FR, CHANGELOG (entrée routage complétée + entrée Business rules).

### T10 — `## Business rules` dans le project.md du dépôt forge ← parent T10
**Effort:** XS
**Files:** `.forge/project.md`
**Description:** Ajouter `## Business rules` après `## Entry points`, selon le gabarit p0 : règles métier existantes du dépôt, sinon `<!-- pending -->`.
[x] Les trois règles non négociables du skill (confirmation explicite, aucune mention Claude, commit ≤150 caractères) déplacées depuis `## Detected conventions` ; date de mise à jour 2026-09-29.

## Risks
- Règle énoncée une seule fois : p2 et p5 recoupent la table ; hors mandat, consigné au LOG — la table renvoie vers eux sans les réécrire.
- Les `coding-standards.md` existants ne sont pas migrés : mise à jour à la main. Celui du dépôt forge est consigné au LOG hors mandat.
- CHANGELOG `[Unreleased]` attendu par la convention du dépôt mais absent du mandat — consigné au LOG.

## Deployment
None

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — Table de routage dans SKILL.md | S | [x] |
| T2 — p1 structure Architecture / Constraints / Conventions | S | [x] |
| T3 — p0 Key structure + mise à jour | XS | [x] |
| T4 — README.md + README.fr.md | S | [x] |
| T5 — Corrections après test sur topwebj5 | XS | [x] |
| T6 — p2 et p5 renvoient vers la table de routage | XS | [x] |
| T7 — Entrée CHANGELOG | XS | [x] |
| T8 — coding-standards.md du dépôt forge | S | [x] |
| T9 — Routage nature/portée + Business rules | S | [x] |
| T10 — Business rules du project.md forge | XS | [x] |
| **Total** | **5×S + 5×XS (≈ 7h15)** | |
