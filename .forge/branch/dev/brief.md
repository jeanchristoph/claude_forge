# Brief — dev

## Objective

Séparer le journal des décisions du brief : actuellement, `## Décisions & Contraintes` dans `brief.md` mélange contraintes immuables et décisions ponctuelles historisées. Créer un fichier log dédié par branche portant l'historique des décisions. Au démarrage (reprise), ne lire que les 10 dernières entrées du log. `brief.md` ne conserve plus que l'objectif et les contraintes/règles immuables (pas l'historique des décisions ponctuelles), ces dernières étant entièrement déplacées vers le log.

## Scope & rules

- `CHANGELOG.md` maintenu à chaque évolution du skill : l'entrée est écrite sous `[Unreleased]`, rubrique `Added` / `Changed` / `Fixed` / `Removed`, avant toute livraison. Une évolution livrée sans entrée de changelog est une évolution invisible.
- Rédaction du changelog en anglais, format *Keep a Changelog*, par regroupement thématique — jamais un commit par ligne.
- Numérotation en `0.x` tant que le format des fichiers produits peut encore changer. Le passage en `1.0.0` vaut engagement à ne plus casser ce format sans version majeure.
