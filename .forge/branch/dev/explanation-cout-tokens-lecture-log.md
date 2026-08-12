# Explication — coût en tokens de la lecture de log.md

## 2026-08-12 — Lecture bornée du log et coût en contexte

### Question posée

Ne pas historiser `log.md` coûte-t-il des tokens ? Autrement dit : Claude ne lit-il vraiment
que les 10 dernières entrées du journal, quelle que soit la taille réelle du fichier ?

### Principe — ce qui entre dans le contexte

- **Tout octet lu par un outil** (`Read`, `Grep`, `Bash`) entre dans la fenêtre de contexte
  et est refacturé en tokens à **chaque tour suivant** de la conversation. Ordre de grandeur
  en français : ~3,5 à 4 caractères par token.
- Un chemin **préfixé `@`** dans une instruction de skill (ex. `@.forge/branch/<BRANCH>/plan.md`)
  provoque l'injection **intégrale** du fichier : aucune borne n'est possible.
- Un chemin **sans `@`** est lu via l'outil `Read`, qui accepte les paramètres `offset` et
  `limit` : la lecture peut alors être bornée à N lignes. C'est le cas de `log.md` dans
  `skill/phases/p5-resume.md` — ce choix est délibéré.

### Le point critique

« Lire les 10 dernières entrées » est une **intention**, pas un **mécanisme**.

Sans paramètre `limit` explicite dans l'instruction, `Read` lit le fichier entier
(2000 lignes par défaut) et la totalité du log entre en contexte.

Observation faite dans la session du 2026-08-12 : le log de la branche `dev`
(2 115 caractères, 12 entrées) a bien été lu **intégralement**.

La lecture bornée n'est donc garantie que si l'instruction **impose le mécanisme**.

### Ordre de lecture

Dans `log.md`, les entrées les plus récentes sont **en tête de fichier** (append en haut).
« Les 10 dernières entrées » correspondent donc aux ~10 premières lignes de contenu.
La borne est ainsi implémentable directement par `limit`, sans avoir à lire la fin du fichier.

### Conséquence sur les seuils d'historisation

- **Tant que la lecture n'est pas bornée** par un `limit` explicite, la taille de `log.md`
  coûte directement du contexte à chaque reprise. Un seuil élevé
  (90 000 caractères ≈ 24 000 tokens ≈ 510 entrées) est alors coûteux.
- **Si la lecture est bornée**, le coût de reprise devient **constant** quelle que soit la
  taille du fichier. Le seuil ne sert plus qu'à contenir la lisibilité du fichier et le coût
  de l'agent d'archivage.

### Chiffres mesurés le 2026-08-12 sur ce dépôt

| Fichier        | Taille             | Volume        | Moyenne            |
| -------------- | ------------------ | ------------- | ------------------ |
| `dev/plan.md`  | 10 071 caractères  | 13 tâches     | ~775 car. / tâche  |
| `dev/log.md`   | 2 115 caractères   | 12 entrées    | ~176 car. / entrée |
