# Documentation - create_user_info.ps1

## Description

Ce script PowerShell automatise la creation simultanee de **deux comptes** pour un utilisateur du departement INFO :
1. **Compte utilisateur standard** - Login normal (ex: `f.luu`)
2. **Compte administrateur** - Login avec prefixe `adm_` (ex: `adm_f.luu`)

Les deux comptes sont crees dans l'OU `OU=Users,OU=INFO,DC=xanadu,DC=local` et le compte admin est ajoute au groupe `Admins`.

## Prerequis

- Executer le script en tant qu'**administrateur**
- **Le fichier user_functions.ps1 doit etre dans le meme repertoire** (contient les fonctions communes)
 

## Utilisation

### Commande de base

```powershell
.\create_user_info.ps1 -FirstName "Prenom" -LastName "Nom" -Description "Description"
```

### Parametres

| Parametre | Type | Obligatoire | Description | Exemple |
|-----------|------|-------------|-------------|---------|
| `-FirstName` | String | Oui | Prenom de l'utilisateur | `"Felipe"` |
| `-LastName` | String | Oui | Nom de l'utilisateur | `"Luu"` |
| `-Description` | String | Oui | Description/poste | `"Developpeur"` |

### Exemples

**Creer les comptes pour un developpeur :**
```powershell
.\create_user_info.ps1 -FirstName "Felipe" -LastName "Luu" -Description "Developpeur Full-Stack"
```

**Creer les comptes pour un administrateur systeme :**
```powershell
.\create_user_info.ps1 -FirstName "Alex" -LastName "Martin" -Description "Administrateur Systeme"
```

## Fonctionnement

### 1. Validation des donnees

Le script verifie que :
- Les noms ne contiennent que des lettres (pas d'accents ni caracteres speciaux)
- Le script est execute avec des privileges administrateur

### 2. Creation du compte utilisateur

#### Generation automatique du login
- Format : `[premiere lettre du prenom].[nom]`
- Exemple : Felipe Luu → `f.luu`
- Si le login existe deja, un numero est ajoute (`f.luu2`, `f.luu3`, etc.)

#### Informations creees
- **Login** : `f.luu`
- **Email** : `f.luu@xanadu.com`
- **Nom complet** : `Felipe Luu` (ou `Felipe Luu 2` si doublon dans l'OU)
- **Mot de passe** : Genere automatiquement (ex: `Fluu2025!`)
- **OU** : `OU=Users,OU=INFO,DC=xanadu,DC=local`

#### Groupes assignes
- INFO (groupe du departement)

### 3. Creation du compte administrateur

#### Generation automatique du login admin
- Format : `adm_[login utilisateur]`
- Exemple : Si user = `f.luu` → admin = `adm_f.luu`
- Gestion automatique des doublons

#### Informations creees
- **Login** : `adm_f.luu`
- **Email** : `adm_f.luu@xanadu.com`
- **Nom complet** : `Felipe Luu` (ou numero si doublon)
- **Description** : `Developpeur Full-Stack (Admin)`
- **Mot de passe** : Genere automatiquement (ex: `Adm_fluu2025!`)
- **OU** : `OU=Users,OU=INFO,DC=xanadu,DC=local`

#### Groupes assignes
- INFO (groupe du departement)
- Admins (groupe des administrateurs du domaine)

> **Note** : Le departement INFO n'utilise pas les groupes Shadow_* et Admin_INFO

### 4. Generation des mots de passe

#### Format automatique
```
[Premiere lettre en majuscule][reste du login sans points][annee actuelle]!
```

**Exemples :**
- Login `f.luu` → Mot de passe : `Fluu2025!`
- Login `adm_f.luu` → Mot de passe : `Adm_fluu2025!`

#### Securite
- Minimum 8 caracteres
- Majuscule
- Minuscule
- Chiffre
- Caractere special
- **Changement obligatoire a la premiere connexion**