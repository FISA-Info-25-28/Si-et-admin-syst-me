# XanaduScripts

Module PowerShell pour la gestion des utilisateurs Active Directory.

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-blue.svg)](https://docs.microsoft.com/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%20Server-0078D6.svg)](https://www.microsoft.com/windows-server)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Description

**XanaduScripts** est un module PowerShell interactif conçu pour simplifier la gestion des utilisateurs Active Directory. Il offre une interface en ligne de commande intuitive avec navigation au clavier pour effectuer les opérations courantes d'administration.

## Fonctionnalités

| Fonctionnalité | Description |
|----------------|-------------|
| **Création d'utilisateurs** | Création guidée avec sélection de l'OU |
| **Modification d'utilisateurs** | Mise à jour du nom, prénom, email, groupe |
| **Suppression d'utilisateurs** | Suppression sécurisée avec confirmation |
| **Liste des utilisateurs** | Affichage en arborescence (tree view) |
| **Réinitialisation de mot de passe** | Reset avec changement obligatoire à la connexion |

## Installation

### Prérequis

- Windows Server 2016+ ou Windows 10/11 avec RSAT
- PowerShell 5.1 ou supérieur
- Module Active Directory (`RSAT-AD-PowerShell`)
- Droits d'administration sur l'Active Directory

### Installation du module

```powershell
# Cloner le repository
git clone https://github.com/VincentPmf/XanaduScripts.git

# Initialisation de la commande PowerShell
C:\$PORFILE

# Ajouter dans le fichier
Import-Module C:\[Chemin du script]
```

### Lancement des scripts :
#### Management des users
```powershell
# Commande PowerShell
Start-UserManagement

# Créer un utilisateur
Start-UserManagement -Action Create -Nom "Dupont" -Prenom "Jean" -Group "Compta"

# Modifier un utilisateur
Start-UserManagement -Action Update

# Supprimer un utilisateur
Start-UserManagement -Action Delete

# Lister les utilisateurs
Start-UserManagement -Action List
```

#### Vérification du DC
```powershell
# Vérifier l'intégrité du Domain Controller (tous les tests)
Verify-DCIntegrity

# Mode DC uniquement (infrastructure)
Verify-DCIntegrity -Mode DC

# Mode AD uniquement (Active Directory)
Verify-DCIntegrity -Mode AD

# Tous les tests
Verify-DCIntegrity -Mode All
```

## 📝 License

Distribué sous licence MIT. Voir `LICENSE` pour plus d'informations.

## Auteur

**Vincent Pmf** - [@VincentPmf](https://github.com/VincentPmf)


