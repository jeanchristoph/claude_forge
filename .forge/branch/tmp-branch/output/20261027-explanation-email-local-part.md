# Partie locale d'une adresse e-mail et identifiant de personne

## 2026-10-27

### 1. Anatomie d'une adresse e-mail

Une adresse e-mail se découpe en deux parties autour du `@` :

| Partie | Position | Exemple (`claude.malaval@topdata.fr`) | Rôle |
|---|---|---|---|
| Partie locale | avant le `@` | `claude.malaval` | désigne la boîte (la personne) chez le fournisseur |
| Domaine | après le `@` | `topdata.fr` | désigne le serveur / l'organisation qui reçoit le courrier |

Le domaine est partagé par tous les utilisateurs d'une même organisation : il ne distingue personne. C'est la partie locale qui porte l'identité de la personne.

### 2. Adresses noreply des forges

Les forges proposent des adresses masquées pour ne pas exposer l'e-mail réel dans les commits.

**GitHub** : `<id numérique>+<login>@users.noreply.github.com`

- Exemple : `64985971+jeanchristoph@users.noreply.github.com`
- `64985971` : identifiant numérique du compte GitHub (stable, même si le login change)
- `+` : séparateur
- `jeanchristoph` : login GitHub
- Les anciens comptes peuvent avoir la forme sans id : `<login>@users.noreply.github.com`.

**GitLab** : `<id>-<login>@users.noreply.gitlab.com`

- Même principe, mais le séparateur est un tiret `-` au lieu de `+`.
- Exemple : `1234567-jeanchristoph@users.noreply.gitlab.com`

Dans les deux cas, la partie locale brute contient un préfixe numérique technique qui n'a pas de sens pour un humain : il faut le retirer (`^\d+[+-]`) pour retrouver le login.

### 3. Pourquoi la partie locale sert d'identifiant dans une branche temporaire

Une branche temporaire suit le format `tmp/<identifiant>-<ddmmyyyy>`, par exemple `tmp/jeanchristoph-27102026`.

L'identifiant doit être :

- **propre à la personne** : deux développeurs ne doivent pas produire la même branche le même jour ;
- **stable** : identique d'une session à l'autre sur la même machine ;
- **lisible** : on reconnaît l'auteur en lisant le nom de branche ;
- **sans espace ni caractère spécial** : compatible avec les règles de nommage des refs git.

La partie locale de `user.email` remplit ces critères, une fois le préfixe noreply retiré :

| `user.email` | Partie locale brute | Après retrait du préfixe | Identifiant |
|---|---|---|---|
| `64985971+jeanchristoph@users.noreply.github.com` | `64985971+jeanchristoph` | `jeanchristoph` | `jeanchristoph` |
| `1234567-jeanchristoph@users.noreply.gitlab.com` | `1234567-jeanchristoph` | `jeanchristoph` | `jeanchristoph` |
| `claude.malaval@topdata.fr` | `claude.malaval` | `claude.malaval` | `claude-malaval` |

Sans retrait du préfixe, la branche deviendrait `tmp/64985971-jeanchristoph-27102026` : unique mais illisible, et différente selon que la personne utilise son adresse noreply ou son adresse réelle.

Le domaine, lui, est écarté : il identifie l'organisation, pas la personne.

### 4. Conversion en slug

La partie locale est ensuite normalisée en slug :

1. passage en minuscules ;
2. retrait des accents (`é` → `e`, `ç` → `c`…) ;
3. remplacement de tout caractère hors `[a-z0-9]` par `-` ;
4. (en pratique) fusion des tirets consécutifs et suppression des tirets en début et fin.

Exemples :

- `claude.malaval` → `claude-malaval`
- `Jean.Christophe` → `jean-christophe`
- `hélène_dupont` → `helene-dupont`

### 5. Git n'a pas d'identifiant utilisateur propre

Git ne connaît aucun identifiant de compte : il ne stocke que deux valeurs déclaratives, `user.name` et `user.email` (`git config user.name`, `git config user.email`), recopiées dans chaque commit.

- `user.name` est un texte libre (espaces, accents, majuscules : `Jean-Christophe`, `Claude Malaval`), souvent ambigu et peu adapté à un nom de branche.
- `user.email` est structuré et, par convention, unique par personne : c'est donc la source la plus fiable pour dériver un identifiant, via sa partie locale nettoyée et slugifiée.

Les identifiants numériques des forges (id GitHub, id GitLab) n'existent que côté forge ; git ne les voit qu'indirectement, à travers l'adresse noreply éventuellement configurée dans `user.email`.
