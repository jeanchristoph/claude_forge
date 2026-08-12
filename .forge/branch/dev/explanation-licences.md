# Explication — licences open source

## 2026-08-12 — Choix de licence : MIT, Apache 2.0 et l'option payante

### Contexte

Le dépôt `claude_forge` est public et ne contient **aucun fichier `LICENSE`** (constat du
2026-08-12). La question posée : quelle licence choisir, et cela ferme-t-il la porte à une
version payante plus tard ?

### 1. Ne rien mettre n'est pas une position neutre

L'absence de licence n'est pas une absence de règles : c'est le **régime le plus restrictif
possible**.

- Par défaut, le droit d'auteur s'applique intégralement : **tous droits réservés**.
- Rendre le dépôt public **ne change rien**. Les conditions d'utilisation de GitHub
  accordent seulement le droit de **consulter** le code et de le **forker au sein de
  GitHub** — ni de l'utiliser, ni de le modifier, ni de le redistribuer ailleurs.

Pour un projet **destiné à être cloné et installé sur des machines tierces**, c'est un
contresens : l'usage même n'est autorisé par aucun texte. Toute entreprise passant par une
revue de conformité se retrouve bloquée.

### 2. Publier sous licence libre n'est pas céder la propriété

Confusion fréquente à lever d'emblée.

- Publier sous licence libre **n'enlève pas la titularité du droit d'auteur**. Les versions
  futures peuvent être publiées sous une **autre licence, y compris propriétaire et
  payante** — c'est exactement ce qu'ont fait HashiCorp, Redis et Elastic.
- En revanche, la licence accordée **sur une version déjà publiée est irrévocable** :
  quiconque a obtenu cette version en garde les droits pour toujours. Conséquence directe
  d'un passage au payant : un **fork de la dernière version libre** est toujours possible —
  Valkey pour Redis, OpenTofu pour Terraform.

Le vrai point de blocage n'est donc pas juridique côté auteur, il est **opérationnel** :

- **Les contributions externes.** Sans **CLA** (Contributor License Agreement), chaque
  contributeur conserve le copyright sur son apport. Relicencier devient impossible sans
  l'accord de chacun d'eux.

Deux alternatives préservent une monétisation dès le départ :

| Licence | Principe | Limite |
| --- | --- | --- |
| **PolyForm Noncommercial** | Usage gratuit **non commercial uniquement** | Pas open source au sens OSI |
| **BSL 1.1** | Usage libre **sauf concurrence directe**, bascule automatique en licence libre après un délai fixé | Pas open source au sens OSI |

Aucune des deux n'étant reconnue open source par l'OSI, **l'adoption s'en trouve freinée**.

### 3. MIT contre Apache 2.0 — les cinq différences réelles

1. **Forme** — MIT tient en un paragraphe (~170 mots). Apache 2.0 fait environ
   **10 000 mots** répartis en 9 sections.
2. **Brevets** — Apache 2.0 accorde **explicitement** une licence de brevet des
   contributeurs aux utilisateurs, assortie d'une **clause de représailles** : engager une
   action en contrefaçon de brevet sur ce logiciel fait perdre ses droits. MIT est **muette**
   sur les brevets ; une licence implicite est généralement admise, mais elle n'est écrite
   nulle part.
3. **Marques** — Apache 2.0 **exclut explicitement** tout droit sur les noms et logos.
   MIT n'en dit rien.
4. **Traçabilité des modifications** — Apache 2.0 impose de **signaler les fichiers
   modifiés** (section 4b) et de conserver le fichier `NOTICE` s'il existe. MIT n'exige que
   le maintien de la mention de copyright et du texte de licence.
5. **Contributions entrantes** — la **section 5** d'Apache 2.0 prévoit que toute
   contribution soumise l'est **sous cette même licence**, sauf mention contraire.
   ⚠️ Cela règle la **licence entrante**, **pas le droit de relicencier plus tard**, qui
   exige toujours un CLA.

### 4. Compatibilité GPL

- **MIT** : compatible **GPLv2 et GPLv3**.
- **Apache 2.0** : compatible **GPLv3**, mais **pas GPLv2** — précisément à cause de la
  clause de brevets.

### 5. Adoption observée

- **MIT** domine les projets individuels et l'écosystème JavaScript.
- **Apache 2.0** domine les projets de fondation et d'entreprise : Android, Kubernetes,
  Swift.

### 6. Application à `claude_forge`

- Le contenu est **majoritairement de la prose d'instructions en Markdown**, sans invention
  brevetable : l'apport principal d'Apache 2.0 (la clause de brevets) est donc **marginal
  ici**.
- Les licences **Creative Commons sont à écarter** malgré la nature textuelle du projet :
  Creative Commons **déconseille elle-même** ses licences pour le logiciel, et le dépôt
  contient des **scripts exécutables**.

**Recommandation retenue : MIT**, sauf si une adoption en entreprise ou un modèle payant
précis est visé.

## 2026-08-12 — Clause de brevets et grille de conformité en entreprise

### Contexte

Question posée : que signifie exactement l'expression « une clause de brevets dans leur
grille de conformité » ? Deux notions distinctes s'y mêlent — le **mécanisme juridique des
brevets** d'une part, le **processus de validation interne des entreprises** d'autre part.

### 1. Brevet et droit d'auteur protègent deux choses différentes

| Protection | Objet protégé | Violation |
| --- | --- | --- |
| **Droit d'auteur** | L'**expression** : le code tel qu'il est écrit | Copier le code sans autorisation = contrefaçon |
| **Brevet** | L'**invention technique** : un procédé, indépendamment de son écriture | Deux programmes au code entièrement différent peuvent violer le même brevet |

Conséquence directe : une licence de code (MIT, Apache…) relève du **droit d'auteur**. Elle
ne dit **rien des brevets**, sauf si elle en parle explicitement.

**Contexte géographique** — les brevets logiciels sont courants aux **États-Unis**. En
**Europe**, les programmes d'ordinateur « en tant que tels » sont **exclus** de la
brevetabilité, mais les **inventions mises en œuvre par ordinateur** peuvent, elles, être
brevetées.

### 2. Le risque concret pour un utilisateur

Le scénario redouté est le suivant :

1. Une entreprise intègre un composant open source dans son produit.
2. Un détenteur de brevet — l'auteur du composant, un contributeur, ou un **tiers totalement
   extérieur au projet** — estime qu'une technique employée dans ce composant viole son
   brevet.
3. Il attaque en contrefaçon… **l'entreprise utilisatrice**, pas seulement l'auteur.

Sous une licence **muette sur les brevets**, l'utilisateur n'a **aucune garantie écrite**.
Une licence de brevet implicite est généralement admise par les juristes, mais elle n'est
écrite nulle part — et c'est précisément ce vide que les services juridiques refusent
d'assumer.

### 3. Ce qu'apporte la clause de brevets d'Apache 2.0 (section 3)

- **Octroi explicite** : chaque contributeur accorde à tout utilisateur une licence de brevet
  **perpétuelle, mondiale, gratuite et irrévocable**, portant sur les brevets qu'il détient
  et que sa contribution **met nécessairement en œuvre**.
- **Clause de représailles** : celui qui engage une action en contrefaçon de brevet visant ce
  logiciel **perd immédiatement** la licence de brevet qui lui avait été accordée. L'effet
  est **dissuasif et réciproque** — attaquer revient à se désarmer soi-même.

### 4. Ce qu'est une « grille de conformité »

Dans une entreprise de taille moyenne ou grande, **aucune dépendance open source n'est
intégrée sans passer par un processus de validation** : comité de revue open source, ou
outillage automatisé de type **FOSSA**, **Black Duck**, **Snyk License Compliance**.

Ce processus s'appuie sur une **politique interne** classant les licences en catégories :

| Catégorie | Contenu typique |
| --- | --- |
| **Autorisées sans condition** | MIT, BSD, Apache-2.0 |
| **Autorisées sous condition** | Déclenchent une revue juridique manuelle |
| **Interdites** | Souvent AGPL, parfois GPL selon l'usage envisagé |

Certaines politiques — notamment dans l'**industrie**, la **santé** et la **finance** —
exigent une **licence de brevet explicite** pour tout composant **redistribué dans un
produit**. Une licence muette sur les brevets y est alors classée « **sous condition** » et
déclenche une revue juridique manuelle, ce qui suffit souvent à **faire abandonner
l'adoption** — non par refus formel, mais par friction.

C'est ce **classement**, et non une clause négociée au cas par cas, que désigne l'expression
« grille de conformité ».

### 5. Application à `claude_forge`

L'exposition est **très faible** :

- Le projet **n'est pas une dépendance compilée et redistribuée** dans le produit d'un
  client. C'est un **outil de développement installé localement** dans `~/.claude/`.
- Son contenu est de la **prose d'instructions en Markdown**, sans procédé technique
  brevetable.
- Les grilles de conformité visent **en priorité les composants redistribués**.

La clause de brevets d'Apache 2.0 protégerait donc ici contre un **risque quasi inexistant**.
