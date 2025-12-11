# Documentation - Script de création d'utilisateurs AD

## Description

Ce script PowerShell automatise la création d'utilisateurs dans l'Active Directory du domaine Xanadu avec attribution automatique des groupes et des droits.

## Prérequis

- Exécuter le script en tant qu'**administrateur**

## Utilisation

### Commande de base

```powershell
.\create_user.ps1 -FirstName "Prénom" -LastName "Nom" -Description "Description" -isAdmin $false
```

### Paramètres

| Paramètre | Type | Description | Exemple |
|-----------|------|-------------|---------|
| `-FirstName` | String | Prénom de l'utilisateur | `"Felipe"` |
| `-LastName` | String | Nom de l'utilisateur | `"Luu"` |
| `-Description` | String | Description/poste | `"Développeur"` |
| `-isAdmin` | Boolean | Admin ou utilisateur standard | `$true` ou `$false` |

### Exemples

**Créer un utilisateur standard :**
```powershell
.\create_user.ps1 -FirstName "Tony" -LastName "Rabatel" -Description "DRH" -isAdmin $false
```

**Créer un administrateur :**
```powershell
.\create_user.ps1 -FirstName "Alex" -LastName "Rivet" -Description "Admin Système" -isAdmin $true
```

## Fonctionnement

### 1. Sélection du département
Le script affiche un menu avec les départements disponibles :
- BDE
- CGF
- COMMERCIAL
- DIRECTION
- JURIDIQUE
- LABO
- INFORMATIQUE
- RH

### 2. Création automatique
Le script génère automatiquement :
- **Login** : première lettre du prénom + nom (ex: `f.luu`)
- **Email** : login@xanadu.com (ex: `f.luu@xanadu.com`)
- **Nom complet** : Si doublon dans le même département, ajoute un numéro

### 3. Mot de passe

#### Génération automatique
Le script génère automatiquement un **mot de passe temporaire** basé sur le login de l'utilisateur.

**Format du mot de passe :**
```
[Première lettre en majuscule][reste du login][année actuelle]!
```

**Exemples :**
- Login `f.luu` → Mot de passe : `Fluu2025!`
- Login `t.rabatel` → Mot de passe : `Trabatel2025!`
- Login `a.rivet2` → Mot de passe : `Arivet22025!`

#### Règles de complexité respectées
Le mot de passe généré respecte automatiquement les règles de sécurité :
- Minimum 8 caractères
- Au moins une majuscule
- Au moins une minuscule
- Au moins un chiffre
- Au moins un caractère spécial (!)

#### Changement obligatoire à la première connexion
**IMPORTANT** : L'utilisateur est automatiquement contraint de changer son mot de passe lors de sa première connexion au domaine.

Le mot de passe temporaire est affiché à la fin de la création pour que l'administrateur puisse le communiquer à l'utilisateur.

### 4. Attribution des droits

#### Utilisateur standard (`-isAdmin $false`)
Le script demande pour chaque type de droit :
- **Read** : Lecture des fichiers du département
- **Write** : Écriture des fichiers du département
- **Modify** : Modification des fichiers du département

Répondre par `o` (oui), `n` (non) ou Entrée (non par défaut).

#### Administrateur (`-isAdmin $true`)
Attribution automatique de tous les groupes admin :
- `Admin_[DÉPARTEMENT]`
- `Shadow_r_[DÉPARTEMENT]`
- `Shadow_w_[DÉPARTEMENT]`
- `Shadow_m_[DÉPARTEMENT]`

## Gestion des doublons

Le script gère automatiquement les utilisateurs avec le même nom :

### Même nom, départements différents
```
RH : Felipe Luu (login: f.luu)
INFORMATIQUE : Felipe Luu (login: f.luu2)
```

### Même nom, même département
```
RH : Felipe Luu (login: f.luu)
RH : Felipe Luu 2 (login: f.luu2)
RH : Felipe Luu 3 (login: f.luu3)
```

## Emplacement dans l'AD

Les utilisateurs sont créés dans :
```
OU=Users,OU=[DÉPARTEMENT],DC=xanadu,DC=local
```

## Sécurité

### Points forts
- Mot de passe généré automatiquement conforme aux règles de complexité
- Changement de mot de passe obligatoire à la première connexion
- Aucun stockage du mot de passe en clair (sauf affichage temporaire)
- Validation des caractères dans les noms (lettres uniquement)

### Recommandations
- Communiquer le mot de passe temporaire de manière sécurisée à l'utilisateur
- Le mot de passe temporaire devient obsolète après la première connexion
- Privilégier l'envoi du mot de passe par un canal sécurisé (pas par email)

## Notes

- Les caractères accentués et spéciaux ne sont pas autorisés dans les noms
- Le login est toujours en minuscules
- Le script nécessite le module Active Directory PowerShell
- En cas d'erreur, le script affiche un message d'erreur détaillé et quitte avec le code 1