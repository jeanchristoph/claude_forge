# Explication — produire une démo animée pour le README

## 2026-08-12 — Produire le GIF de démonstration

### Contexte

Le README de `claude_forge` ne contient **aucun visuel**. Or il s'agit d'un outil en ligne
de commande dont tout l'intérêt réside dans l'interaction : tableau d'avancement, questions
de confirmation, récapitulatif git. Pour ce type d'outil, une démo animée est le **premier
facteur de conversion** d'un visiteur GitHub — elle montre en quelques secondes ce qu'un
paragraphe de prose ne parvient pas à transmettre.

### Les trois voies possibles

#### 1. ScreenToGif — l'outil de référence sur Windows

Application Windows gratuite et open source, installable par :

```
winget install NickeManarin.ScreenToGif
```

Elle combine quatre fonctions dans une seule interface :

| Fonction        | Ce qu'elle apporte                                                              |
| --------------- | ------------------------------------------------------------------------------- |
| **Enregistreur** | Capture d'une zone d'écran (rectangle ou fenêtre), nombre d'images par seconde réglable |
| **Éditeur**      | Travail image par image : suppression d'images, ajustement de la durée de chacune, recadrage, redimensionnement, annotations |
| **Optimiseur**   | Réduction de la palette de couleurs, encodage limité aux zones changeantes entre deux images |
| **Export**       | GIF, APNG, MP4, WebM ou séquence d'images                                        |

**C'est l'éditeur qui fait la valeur de l'outil.** La démo d'un agent est truffée de
latences, et leur suppression représente l'essentiel du travail de production.

**Limite :** interface graphique pilotée à la souris — **non automatisable**.

#### 2. VHS (Charm) — la démo déterministe

Outil en ligne de commande piloté par un fichier `.tape` qui décrit les frappes, les pauses
et les réglages d'affichage. Il génère un GIF **déterministe**, rejouable à chaque version
sans nouvelle prise de vue.

Prérequis — trois binaires, tous disponibles via winget :

```
winget install charmbracelet.vhs
winget install tsl0922.ttyd
winget install Gyan.FFmpeg
```

S'y ajoute un navigateur headless téléchargé au premier lancement.

**Limite majeure :** VHS pilote **les frappes, jamais les réponses**. Une session Claude
n'est pas déterministe — latences de trois à trente secondes, texte variable. Un scénario à
pauses fixes produit donc soit des coupures en pleine phrase, soit de longs blancs.

**La sortie viable est la reconstitution :** un script qui rejoue les sorties réelles du
skill avec des temporisations choisies. Condition impérative : reproduire ces sorties
**mot pour mot**, jamais une version embellie.

#### 3. Enregistrement vidéo puis upload direct

`Win+G` ou l'outil Capture de Windows 11 produit un MP4, et GitHub affiche nativement les
vidéos dans un README : le fichier déposé dans une issue renvoie une URL à coller.

**Avantages :** dix fois plus léger qu'un GIF, meilleure qualité, contrôles de lecture.

**Revers :**
- la vidéo n'est **pas versionnée** dans le dépôt ;
- elle dépend d'une **URL GitHub** externe ;
- elle **ne s'anime pas** dans les aperçus sur les réseaux sociaux ni dans les listes
  communautaires.

Pour un outil en ligne de commande, le **GIF reste le standard**.

### Réglages valables quelle que soit la voie retenue

- **Terminal en 100×30, police de 14 à 16 points.** Au-delà, le texte devient illisible une
  fois le GIF redimensionné par GitHub.
- **Thème sombre, aucun chemin personnel à l'écran** : travailler dans un dépôt de
  démonstration.
- **Cible de poids : moins de 5 Mo, largeur d'environ 900 pixels.** Au-delà, l'affichage
  GitHub devient lent.
- **Couper toutes les latences**, y compris celles des frappes de l'opérateur.

### Scénario retenu pour ce projet — moins de vingt secondes

1. `/forge` lancé sur une branche
2. le récapitulatif « Last session »
3. le tableau d'avancement
4. un « Ready to start with T1? » suivi d'un « go »
5. le tableau récapitulatif des actions git avant livraison

Emplacement prévu dans le README, sous forme de commentaire HTML, avec le chemin
`docs/demo.gif`.
