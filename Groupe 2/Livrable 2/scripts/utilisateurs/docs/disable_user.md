# Documentation - Script de désactivation d'utilisateurs AD

## Description

Ce script PowerShell automatise la désactivation et le déplacement d'utilisateurs dans l'Active Directory du domaine Xanadu vers une unité organisationnelle (OU) dédiée aux comptes en quarantaine.

## Prérequis

- Exécuter le script en tant qu'**administrateur**
- L'OU cible `OU=Users,OU=Quarentine,DC=xanadu,DC=local` doit exister

## Utilisation

### Commande de base

```powershell
.\disable_user.ps1 -UserLogin "login"
```

ou

```powershell
.\disable_user.ps1 "login"
```

### Paramètres

| Paramètre | Type | Position | Obligatoire | Description |
|-----------|------|----------|-------------|-------------|
| `-UserLogin` | String | 0 | Oui | Login (SamAccountName) de l'utilisateur à désactiver |

### Exemples

**Désactiver un utilisateur :**
```powershell
.\disable_user.ps1 -UserLogin "f.luu"
```

**Utilisation avec position :**
```powershell
.\disable_user.ps1 "t.rabatel"
```

## Fonctionnement

### 1. Recherche de l'utilisateur

Le script recherche l'utilisateur dans l'Active Directory et affiche ses informations :
- Nom complet (Name)
- Display Name
- Login (SamAccountName)
- Statut actuel (Actif/Désactivé)

### 2. Vérifications automatiques

Le script effectue plusieurs vérifications de sécurité :
- Détecte si l'utilisateur est déjà en Quarentine
- Vérifie si un doublon existe dans l'OU cible
- Propose un renommage automatique en cas de conflit de nom

### 3. Confirmation des actions

Le script liste les actions à effectuer et demande confirmation :
```
Actions a effectuer :
  1. Desactivation du compte
  2. Deplacement vers : OU=Users,OU=Quarentine,DC=xanadu,DC=local

Confirmez-vous ces actions ? (O/N)
```

### 4. Exécution

Le script effectue les opérations suivantes dans l'ordre :
1. **Renommage** (si conflit détecté) → Ajout d'un timestamp au nom
2. **Désactivation du compte** (si nécessaire) → Le compte ne peut plus se connecter
3. **Déplacement vers l'OU Quarentine** → Organisation des comptes inactifs

### 5. Résumé

À la fin, le script affiche un résumé de l'opération :
```
=== Operation terminee avec succes ===
  Nom            : Felipe Luu
  Nouveau DN     : CN=Felipe Luu,OU=Users,OU=Quarentine,DC=xanadu,DC=local
  Statut         : Desactive
```

## Gestion des erreurs

Le script gère automatiquement les erreurs courantes :
- Utilisateur introuvable
- OU cible inexistante
- Conflit de nom (propose un renommage)
- Droits insuffisants
