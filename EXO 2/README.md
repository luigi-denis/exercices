# Scripts Active Directory - LaPlateforme

Ensemble de scripts PowerShell pour déployer et peupler un annuaire Active Directory sur Windows Server 2025.

---

## Prérequis

- Windows Server 2025 en version standalone (pas encore promu en contrôleur de domaine)
- Droits administrateur local
- PowerShell 5.1 (inclus dans Windows Server 2025)

---

## Script 1 : Promotion AD.ps1

**Rôle** : Promouvoir le serveur Windows Server 2025 en contrôleur de domaine du domaine `laplateforme.io`.

### Ce que fait le script

1. **Avertissement IP** — Le script affiche un message d'alerte clair pour rappeler à l'administrateur de configurer une IP fixe **AVANT** de lancer le script (exemple donné : 192.168.1.10 / 255.255.255.0 / 192.168.1.254). L'administrateur doit le faire manuellement dans les paramètres réseau de Windows.

2. **Configuration DNS** — Configure le DNS de l'interface réseau active en **127.0.0.1** (loopback), afin que le serveur puisse se résoudre lui-même lors de la promotion.

3. **Installation du rôle AD DS** — Installe le rôle Active Directory Domain Services + outils d'administration.

4. **Promotion en contrôleur de domaine** — Crée la forêt et le domaine `laplateforme.io` avec le mot de passe DSRM `P@ssword`. Le serveur redémarre automatiquement à la fin.

### Utilisation

```
.\Promotion AD.ps1
```

> **Important** : configurer l'IP fixe **avant** de lancer le script. Le DNS est mis en 127.0.0.1 automatiquement.

---

## Script 2 : Peuplement AD.ps1

**Rôle** : Peupler l'Active Directory à partir d'un fichier CSV contenant les utilisateurs et leurs groupes d'appartenance.

### Ce que fait le script

1. **Chargement du module Active Directory** — Importe le module AD pour PowerShell.

2. **Récupération du domaine** — Détecte automatiquement le DN du domaine connecté.

3. **Création de la structure des OU** — Crée les unités d'organisation suivantes (si elles n'existent pas déjà) :
   - `OU=LaPlateforme` (racine)
   - `OU=Utilisateurs,OU=LaPlateforme`
   - `OU=Groupes,OU=LaPlateforme`

4. **Sélection du fichier CSV** — Ouvre une fenêtre de dialogue pour choisir le fichier CSV des utilisateurs.

5. **Mot de passe par défaut** — Définit le mot de passe `Azerty_2025!` pour tous les utilisateurs créés.

6. **Import des utilisateurs** — Pour chaque ligne du CSV :
   - Construit le SamAccountName `prenom.nom` en minuscules, **sans accents** (ex: `marc.thillot`)
   - Vérifie si l'utilisateur existe déjà dans l'AD (comparaison insensible à la casse)
   - Si l'utilisateur n'existe pas → le crée dans `OU=Utilisateurs,OU=LaPlateforme`
   - **Force le changement de mot de passe à la première connexion**

7. **Gestion des groupes** — Pour chaque groupe mentionné dans les colonnes `groupe1` à `groupe6` du CSV :
   - Vérifie si le groupe existe déjà (comparaison insensible à la casse)
   - Crée le groupe de sécurité (scope Global) dans `OU=Groupes,OU=LaPlateforme` si nécessaire
   - Ajoute l'utilisateur au groupe
   - Affiche un avertissement en cas de doublon ou d'erreur d'ajout

8. **Résumé** — Affiche un décompte final : utilisateurs créés, ignorés, groupes créés, groupes déjà existants.

### Format du fichier CSV

Le fichier CSV utilise le séparateur point-virgule (`;`) et doit contenir les colonnes suivantes :

```
nom;prenom;groupe1;groupe2;groupe3;groupe4;groupe5;groupe6
THILLOT;MARC;Administratif;Technique;;
ARAGON;ISABELLE;Animation;;;;
AVARO;MARINA;As;Médical;;;;
```

> Les colonnes `groupe3` à `groupe6` sont optionnelles. Les noms de groupes sont自动iquement nettoyés des accents.

### Utilisation

```
.\Peuplement AD.ps1
```

Une boîte de dialogue vous invite à sélectionner le fichier CSV. Le script affiche un résumé à la fin.

---

## Notes

- Les deux scripts fonctionnent avec un annuaire Active Directory **existant** (après promotion du premier contrôleur de domaine).
- Le script de peuplement est **idempotent** : il peut être exécuté plusieurs fois sans erreur. Les utilisateurs et groupes déjà existants sont détectés et ne sont pas recréés.
- Les comparaisons dans le script de peuplement sont **insensibles à la casse** (MARgueRite = marguerite).