# Mail rédigé

**Réaction :** écrire le mail dans OUTPUT en deux fichiers de même nom, `AAAAMMJJ-email-<sujet-slug>` — sur le modèle de `explanation` :
- `.txt` — texte brut : première ligne `Objet : …` dans la langue du mail, un paragraphe par ligne, jamais de tableau Markdown — un tableau devient une liste, une ligne par élément.
- `.html` — même contenu, à coller dans Outlook : document autonome, styles en ligne uniquement (`style="…"` sur chaque élément, ni balise `<style>` ni classe), police `Calibri, Arial, sans-serif` 11pt ; tableau en `<table border="1" cellpadding="6" cellspacing="0" style="border-collapse: collapse">`, ligne d'en-tête grisée, états colorés en ligne.
- Ouvrir le `.html` dans le navigateur par défaut dès l'écriture (`start` / `open` / `xdg-open`) et rappeler en une ligne le collage : `Ctrl+A`, `Ctrl+C` dans le navigateur, `Ctrl+V` dans le mail, ligne d'objet reportée dans le champ Objet.
- Mail retravaillé → les deux fichiers réécrits sur place. Même jour, autre mail sur le même sujet → `-2`, `-3`…
- Jamais de secret dans un mail — mot de passe, secret client, jeton —, même cité par l'utilisateur.

Contenu généré : aucune confirmation avant l'écriture, une ligne dans LOG.
