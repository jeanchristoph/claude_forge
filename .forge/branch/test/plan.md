# Plan — test
**Objectif :** Empêcher toute commande git avant un récapitulatif visuel des actions prévues et une confirmation unique.
**Date :** 2026-08-03

## Tâches

### T1 — Réécrire la section « Livraison » de `p5-resume.md`
**Effort :** S
**Fichiers :** `skill/phases/p5-resume.md`
**Description :** Nouvel ordre de la réaction sur déclencheur « grave » : générer le message de commit → afficher le tableau récapitulatif des actions prévues → demander une confirmation unique → exécuter la séquence complète (`add`, `commit`, `push`, puis les merges dans l'ordre cité) sans validation intermédiaire. Ajouter un `⚠️` : aucune commande git, `git add` compris, avant le « ok ». Réplique verbatim en anglais : `Run this sequence? OK?`. Colonnes du tableau : ordre d'exécution, action git, détail (branche pour `add`/`push`, message pour `commit`, `source → cible` pour chaque `merge`). Pas de liste de fichiers, pas de décompte de lignes.
[x] Section réécrite + sous-section « Format du tableau récapitulatif » ajoutée.

### T2 — Aligner `README.md` sur le nouveau comportement
**Effort :** XS
**Fichiers :** `README.md` (section EN « Shipping », section FR « Livraison »)
**Description :** Documenter le récapitulatif obligatoire avant exécution et la confirmation unique couvrant add + commit + push + merges.
[x]

### T3 — Corriger la description du chaînage des merges dans `README.md`
**Effort :** XS
**Fichiers :** `README.md`
**Description :** Le README décrit un enchaînement `<BRANCH>` → 1ère branche → 2ème branche, alors que le skill merge toujours `<BRANCH>` (branche de départ) dans chaque branche citée. Aligner le texte EN et FR sur le comportement réel.
[x]

## Risques
- Le skill est déployé dans `~/.claude/skills/forge/` : toute modification de `skill/` n'est effective qu'après réexécution de l'installeur.
- Respecter `coding_standards.md` : infinitif impératif, `Si → `, répliques verbatim en anglais, `⚠️` en tête de ligne.

## Récapitulatif
| Tâche | Effort | Statut |
|---|---|---|
| T1 — Réécriture Livraison | S | [x] |
| T2 — README aligné | XS | [x] |
| T3 — Fix chaînage merges | XS | [x] |
| **Total estimé** | **S/M** | |
