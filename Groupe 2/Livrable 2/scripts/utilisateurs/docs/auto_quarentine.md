# Documentation - Script de quarantaine automatique multi-sites

## Description

Ce script identifie automatiquement les utilisateurs inactifs sur plusieurs sites et les place en quarantaine sans intervention manuelle. Il s'agit d'une tâche planifiée à exécuter régulièrement.

## Prérequis

- Exécuter le script en tant qu'**administrateur**
- Module Active Directory pour PowerShell installé
- Les OUs de quarantaine doivent exister pour chaque site
- Droits de modification sur les comptes utilisateurs

## Configuration

### Paramètres modifiables

```powershell
$InactiveDays = 60  # Seuil d'inactivité en jours (modifiable)
```

### Sites configurés

Le script traite automatiquement deux sites :

**SITE_ATLANTIS**
- Zone de recherche : `OU=SITE_ATLANTIS,DC=xanadu,DC=local`
- OU de quarantaine : `OU=Users,OU=QUARANTINE,OU=SITE_ATLANTIS,DC=xanadu,DC=local`
- OUs exclues :
  - `OU=Users,OU=QUARANTINE,OU=SITE_ATLANTIS,DC=xanadu,DC=local` (déjà en quarantaine)
  - `OU=ServiceAccounts,DC=xanadu,DC=local` (comptes de service)

**SITE_SPRINGFIELD**
- Zone de recherche : `OU=SITE_SPRINGFIELD,DC=xanadu,DC=local`
- OU de quarantaine : `OU=Users,OU=QUARANTINE,OU=SITE_SPRINGFIELD,DC=xanadu,DC=local`
- OUs exclues :
  - `OU=Users,OU=QUARANTINE,OU=SITE_SPRINGFIELD,DC=xanadu,DC=local`
  - `OU=ServiceAccounts,DC=xanadu,DC=local`

### Comptes exclus

Les comptes système suivants sont automatiquement exclus :
- `Administrator`
- `Guest`
- `krbtgt`

## Utilisation

### Commande de base

```powershell
.\quarantine_auto.ps1
```

Aucun paramètre n'est requis, le script s'exécute automatiquement sur tous les sites configurés.

### Planification (recommandé)

**Créer une tâche planifiée hebdomadaire :**

```powershell
$action = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument '-File "C:\Scripts\quarantine_auto.ps1"'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 3am
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "AD Quarantine Auto" -Description "Quarantaine automatique des comptes inactifs" -User "XANADU\admin" -RunLevel Highest
```

## Fonctionnement

### 1. Traitement par site

Le script traite chaque site séquentiellement :

```
┌─────────────────────────────────────┐
│ SITE: SITE_ATLANTIS                 │
└─────────────────────────────────────┘
 OU Quarantaine validee
Utilisateurs actifs analyses: 145
Utilisateurs inactifs detectes: 12
```

### 2. Identification des utilisateurs inactifs

Le script identifie les utilisateurs selon les critères suivants :
- **Compte actif** (Enabled = True)
- **Dernière connexion** :
  - Jamais connecté (`LastLogonDate` = null)
  - OU dernière connexion > 60 jours (paramètre `$InactiveDays`)
- **Non exclu** (pas dans les OUs interdites, pas un compte système)

### 3. Affichage de la liste

Le script affiche un tableau récapitulatif :

```
Name          SamAccountName  LastLogonDate        InactiveDays
----          --------------  -------------        ------------
John Doe      j.doe          2024-09-15 14:23:11  87
Jane Smith    j.smith        Jamais               Jamais connecté
Bob Martin    b.martin       2024-08-20 09:15:42  113
```

### 4. Traitement automatique

Pour chaque utilisateur inactif, le script :
1. **Désactive le compte** (si nécessaire)
2. **Déplace vers l'OU Quarantine du site**

Exemple de sortie :
```
Traitement: John Doe...
   Compte desactive: John Doe
   Compte deplace en quarantaine: John Doe
```

### 5. Résumé par site

```
--- Résumé SITE_ATLANTIS ---
Succès  : 11
Erreurs : 1
```

### 6. Résumé global

```
╔═══════════════════════════════════════╗
║          RÉSUMÉ GLOBAL                ║
╚═══════════════════════════════════════╝
Total inactifs détectés : 23
Total traités avec succès : 21
Total erreurs : 2
Quarantaine automatique terminée.
```

## Gestion des erreurs

Le script gère les erreurs pour chaque utilisateur individuellement :

| Erreur | Action | Impact |
|--------|--------|--------|
| OU cible inexistante | Skip du site entier | Le site n'est pas traité |
| Erreur de recherche | Skip du site | Passe au site suivant |
| Erreur sur un utilisateur | Enregistre l'erreur | Continue avec l'utilisateur suivant |
| Droits insuffisants | Erreur par utilisateur | Traite les autres utilisateurs |

Les erreurs sont affichées avec des warnings mais n'arrêtent pas le script.

## Ajout d'un nouveau site

Pour ajouter un site supplémentaire, modifier le tableau `$sites` :

```powershell
$sites = @(
    # ... sites existants ...
    @{
        Name = "SITE_NOUVEAU"
        SearchOU = "OU=SITE_NOUVEAU,DC=xanadu,DC=local"
        QuarantineOU = "OU=Users,OU=QUARANTINE,OU=SITE_NOUVEAU,DC=xanadu,DC=local"
        ExcludedOUs = @(
            "OU=Users,OU=QUARANTINE,OU=SITE_NOUVEAU,DC=xanadu,DC=local",
            "OU=ServiceAccounts,DC=xanadu,DC=local"
        )
    }
)
```

## Bonnes pratiques

1. **Tester** d'abord avec `$InactiveDays` élevé (90-120 jours)
2. **Planifier** l'exécution en dehors des heures ouvrées
3. **Archiver** les logs de chaque exécution
4. **Notifier** les responsables RH des comptes mis en quarantaine
5. **Réviser** régulièrement la liste des OUs et comptes exclus

## Récupération d'un compte

Si un compte a été mis en quarantaine par erreur :

```powershell
# Réactiver le compte
Enable-ADAccount -Identity "login"

# Déplacer vers l'OU d'origine
Move-ADObject -Identity "CN=Nom,OU=Users,OU=QUARANTINE,OU=SITE_X,DC=xanadu,DC=local" -TargetPath "OU=Users,OU=SITE_X,DC=xanadu,DC=local"
```

## Logs et dépannage

### Redirection des logs

Pour conserver une trace des exécutions :

```powershell
.\quarantine_auto.ps1 | Tee-Object -FilePath "C:\Logs\quarantine_$(Get-Date -Format 'yyyyMMdd').log"
```
