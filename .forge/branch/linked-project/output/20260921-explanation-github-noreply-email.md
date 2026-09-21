# Adresse e-mail `noreply` de GitHub

## 2026-09-21

### 1. Contexte

La question s'est posée au moment de passer un dépôt personnel en public. Chaque commit git embarque l'identité de son auteur (`user.name` et `user.email`) : dès que le dépôt devient public, l'adresse configurée dans `user.email` devient lisible par n'importe qui, sur tout l'historique.

### 2. Le problème

- `git log` (en clone local ou via l'API) affiche l'e-mail en clair pour chaque commit.
- Les vues `.patch` et `.diff` de GitHub (`https://github.com/<login>/<repo>/commit/<sha>.patch`) exposent la ligne `From: Nom <email>` sans authentification.
- Ces sources sont massivement scrapées : listes de spam, mais surtout phishing ciblé développeurs (faux e-mails « votre dépôt a été signalé », fausses alertes de sécurité, faux recruteurs), avec un taux de succès supérieur parce que le message peut citer le nom exact du dépôt et du projet.
- Une adresse professionnelle exposée ainsi lie de plus le dépôt personnel à l'employeur.

### 3. La solution

GitHub attribue à chaque compte une adresse de la forme :

```
<id>+<login>@users.noreply.github.com
```

où `<id>` est l'identifiant numérique du compte et `<login>` le nom d'utilisateur.

- Elle **ne reçoit aucun message** : un spammeur qui la collecte n'obtient rien.
- Elle est **reconnue par GitHub** comme appartenant au compte : les commits signés avec cette adresse sont attribués au profil (avatar, lien vers le profil, graphe de contributions), exactement comme avec l'adresse réelle.
- Elle reste stable dans le temps, même en cas de changement de login (grâce à l'`<id>`).

### 4. Mise en place

#### 4.1. Configuration git

Portée **locale au dépôt**, jamais globale si une adresse professionnelle sert pour d'autres dépôts sur la même machine :

```bash
cd <repo>
git config user.email "<id>+<login>@users.noreply.github.com"
git config user.email   # vérification
```

Pour appliquer cette adresse à tous les dépôts personnels d'un même dossier sans toucher aux dépôts professionnels, utiliser une inclusion conditionnelle dans `~/.gitconfig` :

```ini
[includeIf "gitdir:D:/www/perso/"]
    path = ~/.gitconfig-perso
```

et dans `~/.gitconfig-perso` :

```ini
[user]
    email = <id>+<login>@users.noreply.github.com
```

#### 4.2. Réglages GitHub

Dans **Settings → Emails** :

- cocher **« Keep my email addresses private »** : GitHub utilise alors l'adresse `noreply` pour les opérations effectuées depuis l'interface web (merge de PR, édition en ligne, squash) ;
- cocher **« Block command line pushes that expose my email »** : tout `git push` contenant un commit dont l'auteur est une adresse réelle liée au compte est refusé, ce qui évite les fuites par oubli sur une nouvelle machine.

#### 4.3. Où trouver l'adresse exacte

Sur cette même page **Settings → Emails**, sous la case « Keep my email addresses private », GitHub affiche l'adresse `noreply` complète à copier. Ne pas la deviner : l'`<id>` numérique n'apparaît nulle part ailleurs de manière évidente.

### 5. Historique existant

Changer `user.email` ne modifie que les commits futurs. Les commits déjà créés gardent l'ancienne adresse et restent visibles dans le dépôt public tant que l'historique n'est pas réécrit.

#### 5.1. Réécriture avec `git filter-repo` (recommandé)

```bash
git filter-repo --email-callback '
    return email.replace(b"ancienne@adresse.tld", b"<id>+<login>@users.noreply.github.com")
'
git push --force-with-lease --all
git push --force-with-lease --tags
```

`git filter-repo` réécrit à la fois `author` et `committer`, sur toutes les branches et tous les tags, et supprime les références d'origine. Il doit être installé séparément (`pip install git-filter-repo`) et s'exécute sur un clone frais.

#### 5.2. Alternative avec `git rebase`

Pour un dépôt à une seule branche linéaire :

```bash
git rebase --root --exec 'git commit --amend --reset-author --no-edit'
git push --force-with-lease
```

`--reset-author` reprend l'identité configurée localement (il faut donc avoir fait l'étape 4.1 avant) et remet la date d'auteur à maintenant ; pour conserver les dates d'origine, préférer `filter-repo`.

#### 5.3. Conditions et risques

Cette réécriture n'est raisonnable que si :

- le dépôt est **jeune** et l'historique court ;
- **personne d'autre ne l'a cloné** ni forké : tous les SHA changent, tout clone existant diverge et devra être re-cloné ;
- aucune PR, aucun tag signé, aucune release ne référence les anciens SHA.

Sinon : les forks conservent l'ancien historique (donc l'ancienne adresse), les contributeurs subissent des conflits sur chaque branche, et GitHub peut conserver en cache les anciens commits accessibles par SHA direct pendant un temps. Dans ce cas, accepter la fuite passée et se contenter de protéger l'avenir.

### 6. Ce que ça ne fait pas

- **Pas d'anonymat** : l'adresse contient le login, et chaque commit reste lié au profil GitHub. Elle masque une boîte mail, pas une identité.
- **Ne protège pas les e-mails déjà publiés** : une adresse présente dans un fork, un miroir, un cache ou une archive tierce y reste.
- **Ne couvre pas les autres canaux** : e-mail dans un `package.json`, un `composer.json`, un `AUTHORS`, un en-tête de fichier ou un commit d'un autre contributeur reste à traiter séparément.
- **Ne remplace pas la signature** : l'attribution au profil ne prouve pas l'authenticité du commit ; pour cela, signer les commits (GPG, SSH ou S/MIME) et activer « Vigilant mode ».
