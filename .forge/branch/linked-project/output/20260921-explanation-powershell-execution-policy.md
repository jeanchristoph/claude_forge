# Stratégie d'exécution PowerShell (ExecutionPolicy)

## 1. Contexte

Rencontrée le 2026-09-21 en lançant `20260921-mute-teams-while-dictating.ps1` :

```
Impossible de charger le fichier ... car l'exécution de scripts est désactivée sur ce système.
Pour plus d'informations, consultez about_Execution_Policies à l'adresse https://go.microsoft.com/fwlink/?LinkID=135170.
```

Cause : la stratégie d'exécution effective est `Restricted`, valeur par défaut sur les éditions client de Windows (Windows 10 / 11 Home, Pro). Dans ce mode, PowerShell accepte les commandes interactives mais refuse de charger tout fichier de script (`.ps1`, `.psm1`, `.ps1xml`).

## 2. De quoi elle protège

La stratégie d'exécution est un **garde-fou contre l'exécution accidentelle** de scripts PowerShell. Elle vise l'utilisateur qui ne voulait pas lancer un script, pas l'attaquant qui le veut.

Scénarios couverts :

- **Double-clic sur un script** reçu par mail ou téléchargé : sans stratégie, un `.ps1` associé à PowerShell s'exécuterait comme un programme. Avec `Restricted`, il est simplement refusé (ou ouvert dans le Bloc-notes selon l'association de fichier).
- **Script glissé dans un dossier cloné ou un dépôt** : un `.ps1` inattendu dans un projet ne s'exécute pas tout seul, même si une tâche de build ou un raccourci l'appelle par inadvertance.
- **Profil PowerShell (`profile.ps1`, `Microsoft.PowerShell_profile.ps1`)** : un profil injecté dans `$HOME\Documents\WindowsPowerShell\` ou `$PSHOME` s'exécuterait à chaque ouverture de console. Sous `Restricted`, il est ignoré.
- **Scripts venant d'Internet sous `RemoteSigned`** : Windows marque chaque fichier téléchargé avec un flux alternatif `Zone.Identifier` (ZoneId=3 : Internet). `RemoteSigned` exige une signature Authenticode valide pour ces fichiers et laisse passer les scripts créés localement. `Unblock-File` retire cette marque après vérification manuelle.

## 3. De quoi elle ne protège pas

Microsoft est explicite dans `about_Execution_Policies` : *« The execution policy isn't a security system that restricts user actions. […] It's not a security boundary. »* C'est une **fonctionnalité de sécurité de commodité**, pas un contrôle d'accès.

Limites concrètes :

- **Commandes tapées ou collées dans la console** : aucune restriction. Copier-coller le contenu intégral d'un script dans une fenêtre PowerShell le fait exécuter ligne par ligne, quelle que soit la stratégie.
- **Contournement par paramètre de ligne de commande** : `powershell.exe -ExecutionPolicy Bypass -File script.ps1` fonctionne pour tout processus capable de lancer PowerShell, malware inclus. La stratégie s'applique à la session, et un paramètre de lancement la redéfinit pour cette session. Seules les portées `MachinePolicy` et `UserPolicy` (GPO) résistent à ce paramètre.
- **Autres vecteurs d'exécution** : `-Command "..."`, `-EncodedCommand`, `Invoke-Expression (Get-Content script.ps1 -Raw)`, ou un flux redirigé (`Get-Content script.ps1 | powershell -`) échappent tous au contrôle.
- **Hors périmètre** : la stratégie ne concerne que PowerShell. Les `.exe`, `.bat`, `.cmd`, `.vbs`, `.js` (Windows Script Host), `.msi` et `.hta` s'exécutent indépendamment d'elle. Un script batch qui appelle `powershell -ExecutionPolicy Bypass` la neutralise en une ligne.

Conclusion : elle stoppe le geste malheureux, pas l'intention hostile. La protection réelle contre le code malveillant relève de l'antivirus, d'AppLocker / WDAC, de la signature de code et de l'hygiène de l'utilisateur.

## 4. Niveaux

| Niveau | Scripts locaux | Scripts téléchargés (Zone.Identifier) | Commandes interactives | Remarque |
|---|---|---|---|---|
| `Restricted` | Refusés | Refusés | Autorisées | Défaut Windows client. Aucun fichier de script ne se charge, profil inclus. |
| `AllSigned` | Signature Authenticode requise | Signature requise | Autorisées | Le plus strict qui autorise des scripts. Demande confirmation pour un éditeur inconnu. |
| `RemoteSigned` | Autorisés | Signature requise (sauf après `Unblock-File`) | Autorisées | Défaut Windows Server. Compromis habituel pour un poste de développement. |
| `Unrestricted` | Autorisés | Autorisés avec avertissement | Autorisées | Affiche un avertissement avant un script Internet non signé. Défaut sur Linux / macOS (non modifiable là-bas). |
| `Bypass` | Autorisés | Autorisés sans avertissement | Autorisées | Rien n'est bloqué, rien n'est signalé. Prévu pour les scripts appelés par une application qui gère elle-même sa sécurité. |
| `Undefined` | Dépend de la portée suivante | Dépend de la portée suivante | Autorisées | Aucune valeur définie à cette portée. Si toutes les portées sont `Undefined`, le comportement effectif est `Restricted` (client) ou `RemoteSigned` (serveur). |

## 5. Portées

La stratégie effective est la première portée définie (non `Undefined`) dans l'ordre de priorité ci-dessous :

| Priorité | Portée | Source | Persistance | Modifiable par `Set-ExecutionPolicy` |
|---|---|---|---|---|
| 1 | `MachinePolicy` | Stratégie de groupe (GPO) ordinateur | Registre, imposée par le domaine | Non |
| 2 | `UserPolicy` | Stratégie de groupe (GPO) utilisateur | Registre, imposée par le domaine | Non |
| 3 | `Process` | Session PowerShell courante (`-ExecutionPolicy` au lancement ou `Set-ExecutionPolicy -Scope Process`) | Variable d'environnement `$env:PSExecutionPolicyPreference`, **volatile**, rien n'est écrit sur disque | Oui |
| 4 | `CurrentUser` | Utilisateur courant | Registre `HKCU:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell` | Oui, sans élévation |
| 5 | `LocalMachine` | Tous les utilisateurs du poste | Registre `HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell` | Oui, avec élévation |

Les portées GPO (`MachinePolicy`, `UserPolicy`) sont prioritaires et ne peuvent pas être contournées par `-ExecutionPolicy Bypass`. En entreprise, c'est la seule façon de rendre la stratégie contraignante.

Inspection (lecture seule) :

```powershell
Get-ExecutionPolicy          # stratégie effective
Get-ExecutionPolicy -List    # valeur de chaque portée, dans l'ordre de priorité
```

Sortie typique sur un poste client hors domaine :

```
        Scope ExecutionPolicy
        ----- ---------------
MachinePolicy       Undefined
   UserPolicy       Undefined
      Process       Undefined
  CurrentUser       Undefined
 LocalMachine       Undefined
```

Toutes `Undefined` → effectif `Restricted`.

## 6. Contournements légitimes sans rien modifier

Deux approches lancent un script sans toucher au registre ni laisser de trace persistante. Elles n'agissent que sur la portée `Process`.

### a. Paramètre de lancement (recommandé pour une exécution ponctuelle)

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\chemin\vers\20260921-mute-teams-while-dictating.ps1"
```

- `-ExecutionPolicy Bypass` ne vaut que pour ce processus.
- `-NoProfile` évite de charger un profil, ce qui accélère le démarrage et limite les effets de bord.
- `-File` (et non `-Command`) transmet correctement les paramètres du script et renvoie son code de sortie.
- Fonctionne depuis un `.bat`, un raccourci, une tâche planifiée ou un autre script.
- Sous PowerShell 7 : `pwsh.exe` avec les mêmes paramètres.

### b. Modification de la portée `Process` dans une console déjà ouverte

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\20260921-mute-teams-while-dictating.ps1
```

- Valable jusqu'à la fermeture de la fenêtre PowerShell.
- Stockée dans `$env:PSExecutionPolicyPreference`, jamais dans le registre.
- `-ExecutionPolicy RemoteSigned` suffit pour un script créé localement ; `Bypass` évite tout dialogue.
- Un `-Force` évite la demande de confirmation dans une session non interactive.

### c. Pourquoi ne pas utiliser `Set-ExecutionPolicy -Scope CurrentUser` ici

`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` est la réponse habituelle des tutoriels. Elle n'est pas retenue dans ce projet :

- Elle **écrit dans le registre** (`HKCU:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell`, valeur `ExecutionPolicy`). La règle du projet interdit toute écriture de configuration Windows persistante : registre, variables d'environnement persistantes, services, tâches planifiées, pare-feu, stratégies.
- Elle change le comportement de **toutes** les futures sessions PowerShell de l'utilisateur, pas seulement de celle qui exécute ce script. Le garde-fou décrit en section 2 disparaît pour tout le poste.
- Elle laisse un état modifié derrière elle que rien ne remet en place : le script terminé, la configuration reste altérée.
- Elle n'est pas nécessaire : la portée `Process` couvre exactement le besoin (exécuter ce script, maintenant) sans effet durable.

Un script ou une documentation qui aurait besoin d'un réglage persistant le **documente** et laisse l'utilisateur décider, au lieu de l'appliquer.

## 7. Analogie

La stratégie d'exécution est le **film plastique transparent sur un bouton** : un capot qui se soulève d'un geste avant d'appuyer.

- Il empêche d'appuyer **par accident** : un coude qui traîne, un objet posé dessus, un enfant qui joue. C'est exactement le double-clic sur un `.ps1` reçu par mail.
- Il n'empêche personne d'appuyer **volontairement** : soulever le capot prend une seconde et ne demande aucune clé. C'est `-ExecutionPolicy Bypass`.
- Il ne protège que **ce bouton** : le reste du tableau de commande (`.exe`, `.bat`, `.vbs`) reste accessible.
- On peut soulever le capot **le temps d'appuyer** (portée `Process`) ou le **retirer définitivement** (`CurrentUser`, `LocalMachine`). Retirer le capot pour une seule pression est une mauvaise habitude : le lendemain, l'accident redevient possible.
- Seul un **cadenas** posé par le responsable du site (GPO `MachinePolicy` / `UserPolicy`) transforme le capot en véritable verrou.
