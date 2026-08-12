# Explication — signaler une montée de version sur GitHub

## 2026-08-12 — Signaler une montée de version sur GitHub

### Question posée

Comment déclencher des événements sur GitHub pour annoncer une montée de version ?

### Les quatre niveaux, du plus simple au plus automatisé

#### 1. Le tag git — la brique de base

```bash
git tag -a v1.2 -m "Message"
git push origin v1.2
```

Un **tag annoté** est un objet git immuable pointant sur un commit, porteur d'un auteur,
d'une date et d'un message. Sans tag, il n'existe **aucun point de repère de version**
dans l'historique.

Un **tag léger** (`git tag v1.2`, sans `-a`) ne porte ni auteur ni message : préférer
l'annoté pour une version publiée.

#### 2. La GitHub Release — le tag habillé

Une release se construit **au-dessus d'un tag** et y ajoute un titre, des notes de version,
et éventuellement des binaires attachés. Elle se crée depuis l'interface GitHub ou en ligne
de commande :

```bash
gh release create v1.2 --title "..." --notes "..."
gh release create v1.2 --generate-notes   # notes composées par GitHub
```

L'option `--generate-notes` laisse GitHub composer les notes à partir des commits et des
pull requests intervenus depuis la release précédente.

Point important : c'est **la release, pas le tag seul**, qui apparaît dans l'onglet
« Releases » et qui notifie les personnes ayant activé « Watch → Releases only ».

#### 3. Les événements GitHub Actions — le sens strict de « lancer des événements »

Deux déclencheurs distincts, à ne pas confondre :

| Déclencheur                      | Se produit quand              | Usage typique                          |
| -------------------------------- | ----------------------------- | -------------------------------------- |
| `on: push: tags: ['v*']`         | un tag correspondant au motif est poussé | construire un artefact, publier un paquet, déployer |
| `on: release: types: [published]`| une release est publiée       | workflow ayant besoin des notes de version |

Un tag poussé **ne publie pas** de release automatiquement, et une release **peut être créée
sans** passer par un push de tag : les deux événements ne sont pas interchangeables.

#### 4. Le versionnage automatisé

Outils : **release-please**, **semantic-release**, **changesets**.

Ils lisent les messages de commit au format **Conventional Commits** (`feat:`, `fix:`,
`BREAKING CHANGE:`), en déduisent le numéro **SemVer** suivant, génèrent le CHANGELOG,
posent le tag et publient la release.

Coût d'entrée : une discipline stricte sur les messages de commit.

### Application au dépôt claude_forge — état constaté le 2026-08-12

- Aucun dossier `.github/`, donc **aucun workflow**.
- **Aucun tag posé** (`git tag -l` renvoie une liste vide).
- Le numéro de version vit **uniquement dans `README.md`** (`**Version:** 1.1`, présent à la
  fois dans la section anglaise et dans la section française).

Conséquence : il n'existe à ce jour **aucun mécanisme reliant ce numéro à l'historique git**.
Une montée de version n'est visible nulle part ailleurs que dans le texte du README.

### Chemin minimal recommandé pour ce dépôt

1. Incrémenter le numéro dans **les deux sections** du README.
2. Commiter.
3. Poser un tag annoté `v1.2`.
4. Le pousser.
5. Créer la release : `gh release create v1.2 --generate-notes`.

Aucun workflow GitHub Actions n'est nécessaire tant qu'il n'y a rien à construire ni à
publier automatiquement : **un skill se distribue par clone, pas par artefact**.

### Piège à connaître

`git push` **ne pousse pas les tags**. Il faut explicitement :

```bash
git push origin <tag>
# ou
git push --follow-tags   # ne pousse que les tags annotés atteignables depuis les commits poussés
```

## 2026-08-12 — CHANGELOG et événement de release dans le feed GitHub

### Questions posées

Comment le CHANGELOG s'insère-t-il dans la chaîne ? Et pourquoi une release apparaît-elle
dans le feed GitHub d'un abonné ?

### Le CHANGELOG, source de vérité de la chaîne

La chaîne de publication se lit dans un seul sens :

```
entrée de CHANGELOG  →  notes de release  →  événement dans le feed
```

Ce qui s'affiche chez les abonnés n'est jamais meilleur que ce qui a été écrit dans le
CHANGELOG : **c'est le maillon amont qui fixe la qualité de tout le reste**.

Le fichier vit à la racine du dépôt sous le nom `CHANGELOG.md`, au format standard
**Keep a Changelog** :

- une section par version, en **ordre antichronologique** (la plus récente en haut) ;
- des rubriques fixes à l'intérieur de chaque version : `Added`, `Changed`, `Fixed`,
  `Removed`, `Deprecated`, `Security` ;
- une section `[Unreleased]` en tête, alimentée **au fil de l'eau** — on n'écrit pas le
  changelog le jour de la release, on y déverse au fur et à mesure ;
- en bas de fichier, des **liens de comparaison** entre versions (`v1.1...v1.2`) renvoyant
  vers le diff GitHub correspondant.

### Tenu à la main ou généré — le critère de choix

Deux familles d'outillage, et un critère qui tranche entre elles :

| Approche | Ce qu'elle lit | Ce qu'elle exige |
| -------- | -------------- | ---------------- |
| release-please, semantic-release, changesets | les **messages de commit** au format Conventional Commits | une discipline stricte sur chaque message |
| `gh release create --generate-notes` | les **pull requests** mergées entre deux tags | un flux de travail passant par des PR |

Le point souvent mal compris : `--generate-notes` ne compose pas ses notes à partir des
commits directs, mais à partir des **pull requests**. Sur un dépôt où l'on commite
directement sur une branche sans passer par une PR — ce qui est le cas de `claude_forge` —
les notes générées ressortent **vides ou inutiles**.

**Conclusion pour ce dépôt** : un `CHANGELOG.md` tenu à la main. D'autant que les messages
de commit y sont déjà rédigés comme des entrées de changelog — la matière existe, il suffit
de la ranger.

### Pourquoi une release apparaît dans le feed d'un abonné

GitHub émet un `ReleaseEvent` **à la publication d'une release, et à ce moment seulement**.
Ni un commit, ni un push de tag ne produisent cette ligne dans le feed.

Trois conditions **cumulatives** pour que la ligne s'affiche :

1. **Dépôt public** — un dépôt privé n'émet aucun événement.
2. **Release publiée, pas brouillon** — un *draft* n'émet rien tant qu'il n'est pas publié ;
   une *pre-release* émet bien, mais s'affiche marquée comme telle.
3. **Un compte qui suit l'auteur** ou qui *watch* le dépôt.

Deux canaux distincts en découlent : les **followers** voient la ligne dans leur feed ; ceux
qui ont activé « Watch → Releases only » reçoivent **en plus** une notification par mail.

#### Structure de la ligne affichée

Telle qu'observée sur un projet tiers le 2026-08-12, la ligne du feed reprend :

- le **titre de la release**, sur le motif `version — résumé court`
  (ex. `v0.6.6 — Fidélité du refus et de la vérification`) ;
- puis le **début du corps des notes**, tronqué par GitHub avec un lien *Read more*.

Conséquence pratique : le titre et les toutes premières lignes des notes portent seuls la
lisibilité de l'annonce — le reste est replié.

### État constaté du dépôt claude_forge au 2026-08-12

- Aucun tag, aucune release.
- Pas de dossier `.github/`.
- `gh` CLI **non installé** sur la machine de travail — une release passerait donc par
  l'interface web, sauf à installer le CLI :

```bash
winget install GitHub.cli
```
