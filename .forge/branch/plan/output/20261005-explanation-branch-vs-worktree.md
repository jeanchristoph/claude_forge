# Branche ou worktree : quelle différence ?

## 1. La branche : une ligne d'historique

Une branche est simplement un **nom posé sur un commit** : `dev`, `master`, `forge/CU-123`.
Chaque nouveau commit fait avancer ce nom d'un cran. La branche vit **dans le dépôt** (le
dossier `.git`) : elle n'a aucun emplacement propre sur le disque, aucun dossier à elle.

> Analogie : un **classeur de versions** rangé dans une armoire. Le classeur existe, mais tant
> qu'on ne l'ouvre pas, on ne peut pas en modifier les pages.

## 2. Le worktree : là où les fichiers sont « dépliés »

Un worktree (copie de travail) est un **dossier sur le disque** dans lequel les fichiers d'une
branche sont dépliés pour qu'on puisse les éditer, les lancer, les tester.

Vous en utilisez déjà un sans le savoir : le dossier habituel du projet **est** un worktree, le
worktree principal. Quand vous tapez `git checkout X`, vous changez la branche dépliée **dans
ce dossier-là** : les fichiers sont remplacés sur place.

> Analogie : le **bureau** sur lequel on étale un classeur pour travailler dessus.

## 3. Le problème : un bureau, un seul classeur ouvert

Un seul dossier ne peut contenir qu'une seule branche à la fois. Si un agent automatique fait
`git checkout forge/CU-123` dans **votre** dossier, votre branche disparaît sous vos pieds :
vos fichiers ouverts dans l'éditeur changent, votre serveur local sert un autre code, et vos
modifications en cours se retrouvent mélangées avec son travail.

## 4. La solution : un deuxième bureau

```bash
git worktree add <chemin> <branche>
```

Cette commande crée **un autre dossier**, avec une **branche différente** dépliée dedans, mais
reliée au **même dépôt `.git`** :

- ce n'est pas un clone : rien n'est dupliqué côté historique ;
- un commit fait d'un côté est immédiatement visible de l'autre (`git log`, `git branch`) ;
- les branches, les remotes, la configuration sont partagés.

Règle à retenir : **une branche ne peut être dépliée que dans un seul worktree à la fois**.
Git refuse de faire un `checkout dev` dans le deuxième dossier si `dev` est déjà ouvert dans le
premier. C'est précisément ce qui protège votre travail.

## 5. Exemple concret

| Dossier                                       | Qui travaille | Branche        |
|-----------------------------------------------|---------------|----------------|
| `D:/www/topdon_api`                           | vous          | `dev`          |
| `D:/www/topdon_api.worktrees/forge/CU-123`    | l'agent       | `forge/CU-123` |

Vous continuez sur `dev` sans être dérangé ; l'agent travaille en parallèle dans son propre
dossier. Le nom du dossier n'a **aucun effet** pour git : `topdon_api.worktrees` est un simple
choix de rangement. Les `/` du nom de branche (`forge/CU-123`) deviennent naturellement des
sous-dossiers.

## 6. Ce qu'un worktree n'a pas

Un worktree neuf ne contient que les **fichiers versionnés**. Tout ce qui est ignoré par git
manque : `node_modules`, `vendor`, `.env`, caches de build. Il faut les réinstaller ou les
recopier si l'on veut lancer le projet depuis ce dossier.

Nettoyage :

```bash
git worktree list              # voir tous les worktrees et leur branche
git worktree remove <chemin>   # supprimer un worktree (la branche, elle, reste)
```

Supprimer un worktree ne supprime **pas** la branche : on range le bureau, le classeur retourne
dans l'armoire avec tous ses commits.
