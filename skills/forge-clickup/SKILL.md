---
name: forge-clickup
description: Ouvre une tâche ClickUp, crée la branche git associée et enchaîne sur forge.
disable-model-invocation: false
---

Always respond in the user's language.

## Rôle

Guichet d'ouverture de tâche, en amont de `forge`. Tu ouvres le ticket, tu prépares
le terrain git, tu passes la main à `forge`. Tu ne codes pas, tu ne planifies pas, tu
ne rédiges aucun brief. Rien d'autre.

Les étapes s'exécutent **dans l'ordre**, sans en sauter aucune.

---

## Étape 0 — Configuration du dépôt (toujours en premier)

### Prérequis — le dépôt doit être forgé

Si le dossier `.forge/` est absent, ce dépôt n'a jamais été initialisé. Ne rien créer
à la main : invoquer `forge` via l'outil Skill pour qu'il installe `project.md` et
`coding-standards.md`, puis **reprendre l'étape 0 depuis le début**.

### Configuration de la liste

Lire `.forge/clickup.json`.

**Fichier présent et complet** → passer à l'étape 1 sans rien afficher.

**Fichier absent, illisible ou incomplet** → ne rien deviner, ne jamais réutiliser la
configuration d'un autre dépôt. Configurer maintenant :

1. Annoncer : « Première utilisation sur ce dépôt — configuration de la liste ClickUp. »
2. Appeler `clickup_get_workspace_hierarchy`, présenter les espaces / dossiers / listes.
3. Demander **quelle liste** ce dépôt vise. Sans réponse : STOP.
4. Demander la **branche de départ**, ne jamais la deviner. D'abord détecter
   lesquelles de `master` et `main` existent, en local (`refs/heads/<nom>`) comme sur
   le distant (`refs/remotes/origin/<nom>`), avec `git show-ref --verify --quiet`.
   Puis proposer un choix : chaque branche détectée, dans l'ordre `master` puis
   `main`, plus une option « autre » où l'utilisateur saisit un nom.

   Si le nom saisi ne correspond à aucune branche existante, la créer **depuis la
   branche par défaut détectée** — `master`, sinon `main` — et la publier :
   `git checkout <défaut>`, `git pull`, `git checkout -b <nom>`,
   `git push -u origin <nom>`. Si ni l'une ni l'autre n'existe, partir du `HEAD`
   courant et le signaler. Annoncer la création dans tous les cas ; elle devient la base.

   Le choix est enregistré dans `branch_from`.
5. Déduire `branch_code` sans poser de question : appeler `clickup_filter_tasks` sur
   la liste choisie et prendre une tâche existante ; si elle porte un `custom_id`,
   retenir `custom_id`, sinon `id`.
6. Écrire `.forge/clickup.json`, afficher les valeurs retenues, et demander
   confirmation avant de poursuivre.

S'il ne manque qu'un champ, compléter ce champ seul — ne pas tout redemander.

### Format du fichier

```json
{
  "workspace_id": "20462132",
  "default": { "list_id": "210826715", "path": "TOPDATA / TOPDATA / TOPWEB" },
  "aliases": {},
  "branch_from": "master",
  "branch_code": "custom_id"
}
```

| Clé | Rôle |
|---|---|
| `default` | liste visée quand aucun alias n'est passé en argument |
| `aliases` | listes secondaires : `{ "topmail": { "list_id": "…", "path": "…" } }` |
| `branch_from` | branche de départ (`master`, `dev`…) |
| `branch_code` | `custom_id` (ex. `PRJ-1133`) ou `id` (ex. `869eyzy2b`) |

L'utilisateur n'édite jamais ce fichier à la main. S'il demande de changer la liste
par défaut ou d'ajouter un alias, réécrire le fichier.

## Étape 1 — Titre

Demander le titre de la tâche, et **uniquement** le titre.

Priorité, description, échéance, assigné : ne jamais les demander. Les appliquer
seulement si l'utilisateur les a mentionnés spontanément.

Sans titre : STOP.

## Étape 2 — Liste cible

- Argument passé à la commande (`/forge-clickup topmail`) → utiliser l'alias
  correspondant, **pour ce ticket uniquement**, sans modifier `default`.
- Alias inconnu : le signaler, lister les alias disponibles, STOP.
- Aucun argument → `default`.

## Étape 3 — Créer la tâche

`clickup_create_task` avec `name` = le titre et `list_id` = la liste cible.

## Étape 4 — Récupérer le code

**Indispensable :** la réponse de création renvoie toujours `custom_id: null`, l'ID
personnalisé étant attribué juste après par ClickUp. Ne jamais s'y fier.

Rappeler `clickup_get_task` sur l'`id` retourné pour lire le vrai `custom_id`.

CODE = le champ désigné par `branch_code`, brut, sans slug ni préfixe ajouté.
Si `branch_code = custom_id` mais que le champ est vide : se rabattre sur `id` et
le signaler à l'utilisateur.

## Étape 5 — Branche

1. Vérifier que l'arbre de travail est propre : `git status --porcelain`.
   Sortie non vide → STOP, lister les fichiers en cours, attendre les instructions.
   Ne jamais basculer de branche avec des modifications en cours.
2. Exécuter, dans cet ordre (`<BASE>` = `branch_from`) :
   ```
   git checkout <BASE>
   git pull
   git checkout -b <CODE>
   git push -u origin <CODE>
   ```

**Autorisation :** cette séquence — `checkout`, `pull`, `push -u` de la branche neuve —
est autorisée de façon permanente. Elle ne s'étend à **aucun** `add`, `commit` ou `push`
ultérieur, qui restent soumis à accord explicite au cas par cas.

## Étape 6 — Passation à forge

Afficher d'abord :

> Tâche `<CODE>` créée — <URL>
> Branche `<CODE>` poussée depuis `<BASE>`.

Puis **invoquer `forge` via l'outil Skill**, sans demander de confirmation. La branche
`<CODE>` est déjà la branche courante : `forge` la reprend telle quelle et amorce
`.forge/branch/<CODE>/brief.md`.

Ne rien faire au-delà : à partir de là, c'est `forge` qui mène. Ne pas coder, ne pas
planifier, ne pas devancer ses étapes.
