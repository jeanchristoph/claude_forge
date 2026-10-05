# Plan — plan
**Objective:** Ajouter à la validation du plan une option « Valider et enchaîner », en premier et recommandée, qui écrit le plan puis exécute toutes les tâches ouvertes sans autre question.
**Date:** 2026-10-05

## Tasks

### T1 — Retirer la limite « deux options seulement » de `SKILL.md`
**Effort:** XS
**Files:** `skills/forge/SKILL.md`
**Description:** Réécrire le ⚠️ « Validation d'un contenu présenté » (l.54) : nombre d'options libre ; jamais d'option « à retravailler » / « modifier » — un changement passe par le champ de texte libre de la question, avec son explication. Traitement du texte libre, du texte libre sans substance, de `Cancel` et de l'absence de réponse inchangé.
[x]

### T2 — Option `Validate and chain` à l'étape 7 de `p4-plan.md`
**Effort:** S
**Files:** `skills/forge/phases/p4-plan.md`
**Description:** Étape 7 : options `Validate and chain (recommended)`, `Validate`, `Cancel`, dans cet ordre, chacune décrite. `Validate and chain` → étapes 8-9 puis p5 en mode enchaîné, sans question `Mode`. `Validate` inchangé. Garde délégué : `SCOPE: linked` → option non proposée (`Validate` vaut déjà accord) ; `SCOPE: branch` → option proposée dans le `FORGE_QUESTION`, et choisie elle remplace la question `Mode` et les feux verts `Start T<n>`.
[x]

### T3 — `p5-resume.md` : pas de question `Mode` après `Validate and chain`
**Effort:** XS
**Files:** `skills/forge/phases/p5-resume.md`
**Description:** Étape 8 : nouvelle puce — plan validé dans ce tour par `Validate and chain` → aucune question, enchaîner toutes les tâches ouvertes dans l'ordre. Ajuster la puce `SCOPE: branch` et le ⚠️ « Aucun démarrage avant la réponse » (la réponse est alors la validation du plan). Reprise ultérieure → question `Mode` posée comme aujourd'hui.
[x]

### T4 — Documentation et CHANGELOG
**Effort:** S
**Files:** `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** README (« Confirmations » : retirer « n'offre que deux options », remplacer par la règle « jamais d'option à retravailler » ; État 4 : troisième option ; portée branche : phrase « le plan validé vaut accord »), en miroir dans les deux langues. CHANGELOG `## [Unreleased]` : `### Added` pour l'option, `### Changed` pour la fin de la limite à deux options.
[x]

### T5 — `grave!` : livraison sans confirmation
**Effort:** S
**Files:** `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Déclencheur de la Livraison : `grave!` / `engrave!` (`!` collé à la commande, seule ou suivie de branches) → livraison directe. Étapes 4-5 sautées : tableau affiché comme compte rendu, séquence exécutée aussitôt — la commande vaut autorisation pour cette séquence. Questions `Linked` / `Linked branches` maintenues (choix de périmètre). `SCOPE: branch` → pas de `FORGE_QUESTION` d'engrave. Conflit de merge ou push rejeté → arrêt, erreur telle quelle ; jamais de `--force`. `grave` sans `!` inchangé. README en miroir, CHANGELOG `### Added`.
[x]

### T6 — Remplacer `grave!` / `engrave!` par `livre` / `ship`
**Effort:** XS
**Files:** `skills/forge/phases/p5-resume.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** Livraison directe déclenchée par un message qui commence par `livre` / `ship`, seul ou suivi uniquement de branches existantes ; tout autre texte → pas une livraison. `grave!` / `engrave!` retirés. Comportement inchangé (tableau en compte rendu, questions `Linked` maintenues, arrêt sur conflit ou push rejeté). `grave` / `engrave` gardent la confirmation. README en miroir, CHANGELOG `### Added` réécrit.
[x]

### T7 — Délégation vers un projet lié dans un worktree
**Effort:** M
**Files:** `skills/forge/phases/p5-resume.md`, `skills/forge/SKILL.md`, `README.md`, `README.fr.md`, `CHANGELOG.md`
**Description:** « Délégation — projet lié » : checkout/création de branche dans `<LINKED>` remplacé par un worktree `<LINKED>-<slug LINKED_BRANCH>` (réutilisé s'il existe), brief/log du lié écrits dedans, `ROOT: <worktree>` dans le prompt. Livraison relayée : add/commit/push dans le worktree, branche cible extraite ailleurs → `skipped`. Fin de délégation : rappel `git worktree remove` + avertissement (ni dépendances ni fichiers ignorés dans le worktree). README miroir, CHANGELOG `### Changed`.
[x]

## Risks
- La copie installée (`~/.claude/skills/forge/`) n'évolue qu'après relance de l'installeur.
- Le mode enchaîné ne pose plus aucune question entre les tâches : les mises à jour substantielles du plan et les demandes hors périmètre restent soumises à confirmation.

## Deployment
None

## Summary
| Task | Effort | Status |
|---|---|---|
| T1 — Retirer la limite « deux options seulement » de `SKILL.md` | XS | [x] |
| T2 — Option `Validate and chain` à l'étape 7 de `p4-plan.md` | S | [x] |
| T3 — `p5-resume.md` : pas de question `Mode` après `Validate and chain` | XS | [x] |
| T4 — Documentation et CHANGELOG | S | [x] |
| T5 — `grave!` : livraison sans confirmation | S | [x] |
| T6 — Remplacer `grave!` / `engrave!` par `livre` / `ship` | XS | [x] |
| T7 — Délégation vers un projet lié dans un worktree | M | [x] |
| **Total** | **~7h** | |
