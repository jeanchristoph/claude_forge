# Le frontmatter YAML dans un fichier Markdown

## 2026-11-17

### 1. Définition

Un fichier `.md` peut commencer par un bloc délimité par deux lignes `---` :

```markdown
---
name: forge
description: "Orchestre le cycle de vie d'une branche de développement : brief validé, ..."
---

# Titre du document

Contenu Markdown…
```

- Ce qui se trouve entre les deux `---` est du **YAML** : c'est le *frontmatter*.
- Tout ce qui suit est du **Markdown** ordinaire.

C'est une convention née avec les générateurs de sites statiques **Jekyll** et **Hugo**, reprise ensuite par les skills Claude Code (`SKILL.md`) et par les IDE.

### 2. Qui lit ce bloc, et comment

- **Le parseur Markdown** ignore ce bloc ou le masque à l'affichage : il ne fait pas partie du contenu rendu.
- **Un outil** (Claude Code, un générateur de site, un IDE) le lit comme des **métadonnées** : `name`, `description`, `title`, `date`, etc. Pour un skill Claude Code, `name` et `description` servent à identifier le skill et à décider quand le déclencher.

### 3. Exemple réel dans le dépôt forge

Valeur fautive :

```yaml
description: Orchestre le cycle de vie d'une branche de développement : brief validé, ...
```

La séquence `: ` (deux-points suivi d'une espace) est **interdite dans une valeur YAML sans guillemets** : le parseur y voit le début d'une nouvelle paire clé/valeur et lève l'erreur *mapping values are not allowed here*.

Correction : entourer la valeur de guillemets doubles.

```yaml
description: "Orchestre le cycle de vie d'une branche de développement : brief validé, ..."
```

### 4. Règles pratiques

Mettre la valeur entre **guillemets doubles** dès qu'elle :

- contient `: ` (deux-points suivi d'une espace) ;
- contient ` #` (espace suivie d'un dièse, interprété comme un commentaire) ;
- commence par l'un de ces caractères : `[`, `{`, `*`, `&`, `!`, `|`, `>`, `'`, `"`, `%` ou `@`.

Échappement :

| Style de guillemets | Caractères à traiter | Exemple |
|---|---|---|
| Doubles `"…"` | échapper `"` et `\` avec `\` | `"Il dit \"oui\" dans C:\\temp"` |
| Simples `'…'` | doubler l'apostrophe : `''` | `'Orchestre l''état d''une branche'` |

### 5. Pourquoi l'IDE signale l'erreur alors que Claude Code charge le skill

Tous les outils ne lisent pas le frontmatter avec la même rigueur :

- **Certains chargeurs sont tolérants** : ils récupèrent la valeur ligne par ligne, ou se rabattent sur une lecture approximative quand le YAML est invalide. Claude Code charge alors le skill malgré tout.
- **D'autres outils sont stricts** : l'IDE valide le YAML selon la spécification et signale l'erreur.

Se fier à la tolérance d'un chargeur est fragile : une autre version ou un autre outil peut refuser le fichier. Un frontmatter valide pour le parseur le plus strict fonctionne partout.
