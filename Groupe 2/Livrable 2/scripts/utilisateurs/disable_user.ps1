<#
.SYNOPSIS
    Script de désactivation et mise en quarantaine d'un compte utilisateur Active Directory.

.DESCRIPTION
    Ce script permet de désactiver un compte utilisateur et de le déplacer vers l'OU de quarantaine
    correspondant à son site d'origine (ATLANTIS ou SPRINGFIELD).
    
    Le script effectue les opérations suivantes :
    - Recherche l'utilisateur dans Active Directory
    - Détermine automatiquement le site de l'utilisateur (ATLANTIS ou SPRINGFIELD)
    - Vérifie si l'utilisateur est déjà en quarantaine
    - Détecte les conflits de noms dans l'OU de destination
    - Propose de renommer l'utilisateur en cas de conflit
    - Désactive le compte (si actif)
    - Déplace le compte vers l'OU QUARANTINE du site correspondant
    
    Le script inclut plusieurs protections :
    - Détection des utilisateurs déjà en quarantaine
    - Gestion des doublons (homonymes)
    - Confirmations avant chaque action critique
    - Vérification de l'existence de l'OU cible
    
    Structure des OUs de quarantaine :
    - SITE_ATLANTIS : OU=Users,OU=QUARANTINE,OU=SITE_ATLANTIS,DC=xanadu,DC=local
    - SITE_SPRINGFIELD : OU=Users,OU=QUARANTINE,OU=SITE_SPRINGFIELD,DC=xanadu,DC=local

.PARAMETER UserLogin
    Login (SamAccountName) de l'utilisateur à désactiver et mettre en quarantaine (obligatoire)

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$UserLogin
)

# ========================================
# FONCTIONS
# ========================================

<#
.SYNOPSIS
    Détermine le site d'un utilisateur à partir de son Distinguished Name.

.DESCRIPTION
    Cette fonction analyse le DN (Distinguished Name) d'un utilisateur pour identifier
    s'il appartient au site ATLANTIS ou SPRINGFIELD.
    
    La détection se base sur la présence de "OU=SITE_ATLANTIS" ou "OU=SITE_SPRINGFIELD"
    dans le chemin DN de l'utilisateur.

.PARAMETER UserDN
    Distinguished Name complet de l'utilisateur

.OUTPUTS
    String : "ATLANTIS", "SPRINGFIELD" ou $null si le site ne peut être déterminé

.EXAMPLE
    Get-UserSite -UserDN "CN=Jean Dupont,OU=Users,OU=RH,OU=SITE_ATLANTIS,DC=xanadu,DC=local"
    # Retourne : "ATLANTIS"

.EXAMPLE
    Get-UserSite -UserDN "CN=Marie Martin,OU=Users,OU=LABO,OU=SITE_SPRINGFIELD,DC=xanadu,DC=local"
    # Retourne : "SPRINGFIELD"
#>
function Get-UserSite {
    param([string]$UserDN)
    
    # Rechercher la présence de SITE_ATLANTIS dans le DN
    if ($UserDN -like "*OU=SITE_ATLANTIS*") {
        return "ATLANTIS"
    } 
    # Rechercher la présence de SITE_SPRINGFIELD dans le DN
    elseif ($UserDN -like "*OU=SITE_SPRINGFIELD*") {
        return "SPRINGFIELD"
    } 
    # Aucun site reconnu
    else {
        return $null
    }
}

# ========================================
# SCRIPT PRINCIPAL
# ========================================

# Affichage du titre et du login traité
Write-Host "`n=== Desactivation et deplacement d'utilisateur AD ===" -ForegroundColor Cyan
Write-Host "Login utilisateur : $UserLogin`n" -ForegroundColor Yellow

try {
    # ========================================
    # ÉTAPE 1 : RECHERCHE DE L'UTILISATEUR
    # ========================================
    
    Write-Host "Recherche de l'utilisateur..." -ForegroundColor Gray
    
    # Récupérer l'objet utilisateur avec ses propriétés essentielles
    $user = Get-ADUser -Identity $UserLogin -Properties Name, DistinguishedName, Enabled -ErrorAction Stop
    
    # ========================================
    # ÉTAPE 2 : DÉTERMINATION DU SITE
    # ========================================
    
    # Identifier le site de l'utilisateur à partir de son DN
    $userSite = Get-UserSite -UserDN $user.DistinguishedName
    
    # Vérifier que le site a pu être déterminé
    if ($null -eq $userSite) {
        Write-Error "Impossible de determiner le site de l'utilisateur."
        Write-Error "DN: $($user.DistinguishedName)"
        Write-Error "L'utilisateur n'est ni sur SITE_ATLANTIS ni sur SITE_SPRINGFIELD."
        exit 1
    }
    
    # Construire le chemin de l'OU QUARANTINE du site correspondant
    $targetOU = "OU=Users,OU=QUARANTINE,OU=SITE_$userSite,DC=xanadu,DC=local"
    
    # ========================================
    # AFFICHAGE DES INFORMATIONS DE L'UTILISATEUR
    # ========================================
    
    Write-Host "Utilisateur trouve :" -ForegroundColor Green
    Write-Host "  Nom complet    : $($user.Name)" -ForegroundColor White
    Write-Host "  Login          : $($user.SamAccountName)" -ForegroundColor White
    Write-Host "  Site actuel    : SITE_$userSite" -ForegroundColor Cyan
    Write-Host "  DN actuel      : $($user.DistinguishedName)" -ForegroundColor White
    Write-Host "  Statut         : $(if($user.Enabled){'Active'}else{'Deja desactive'})" -ForegroundColor White
    Write-Host "  OU cible       : $targetOU" -ForegroundColor Cyan
    Write-Host ""

    # ========================================
    # ÉTAPE 3 : VÉRIFICATION SI DÉJÀ EN QUARANTAINE
    # ========================================
    
    # Vérifier si l'utilisateur est déjà dans l'OU de quarantaine
    if ($user.DistinguishedName -like "*$targetOU*") {
        Write-Warning "L'utilisateur est deja dans l'OU QUARANTINE de SITE_$userSite !"
        
        # Si le compte est encore actif, proposer de le désactiver
        if ($user.Enabled) {
            Write-Host "Le compte est encore actif. Desactivation..." -ForegroundColor Yellow
            $confirmation = Read-Host "Confirmer la desactivation ? (O/N)"
            if ($confirmation -eq 'O' -or $confirmation -eq 'o') {
                Disable-ADAccount -Identity $UserLogin -ErrorAction Stop
                Write-Host "Compte desactive avec succes" -ForegroundColor Green
            }
        } else {
            Write-Host "Le compte est deja desactive et en quarantaine. Aucune action necessaire." -ForegroundColor Green
        }
        exit 0
    }

    # ========================================
    # ÉTAPE 4 : DÉTECTION DES CONFLITS DE NOMS
    # ========================================
    
    Write-Host "Verification des doublons dans l'OU QUARANTINE..." -ForegroundColor Gray
    
    # Rechercher un utilisateur avec le même nom dans l'OU cible
    $existingUser = Get-ADUser -Filter "Name -eq '$($user.Name)'" -SearchBase $targetOU -ErrorAction SilentlyContinue
    
    # Gérer le conflit si un doublon est trouvé
    if ($existingUser) {
        Write-Warning "CONFLIT DETECTE : Un utilisateur avec le nom '$($user.Name)' existe deja dans QUARANTINE !"
        Write-Host "  Utilisateur existant : $($existingUser.SamAccountName)" -ForegroundColor Red
        Write-Host "  DN existant          : $($existingUser.DistinguishedName)" -ForegroundColor Red
        Write-Host ""
        
        # Proposer des options pour résoudre le conflit
        Write-Host "Options disponibles :" -ForegroundColor Yellow
        Write-Host "  1. Renommer l'utilisateur actuel avant le deplacement" -ForegroundColor White
        Write-Host "  2. Annuler l'operation" -ForegroundColor White
        $choice = Read-Host "Votre choix (1/2)"
        
        # Option 1 : Renommer l'utilisateur avec un timestamp
        if ($choice -eq '1') {
            # Générer un nouveau nom unique avec horodatage
            $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $newName = "$($user.Name)-$timestamp"
            Write-Host "Nouveau nom propose : $newName" -ForegroundColor Cyan
            $confirmRename = Read-Host "Confirmer le renommage ? (O/N)"
            
            if ($confirmRename -eq 'O' -or $confirmRename -eq 'o') {
                # Renommer l'objet AD
                Rename-ADObject -Identity $user.DistinguishedName -NewName $newName -ErrorAction Stop
                Write-Host "Utilisateur renomme en : $newName" -ForegroundColor Green
                
                # Recharger l'objet utilisateur après le renommage
                $user = Get-ADUser -Identity $UserLogin -Properties Name, DisplayName, DistinguishedName, Enabled
            } else {
                Write-Host "Operation annulee." -ForegroundColor Yellow
                exit 0
            }
        } 
        # Option 2 : Annuler l'opération
        else {
            Write-Host "Operation annulee." -ForegroundColor Yellow
            exit 0
        }
    }

    # ========================================
    # ÉTAPE 5 : VÉRIFICATION DU STATUT ACTIF/INACTIF
    # ========================================
    
    # Si l'utilisateur est déjà désactivé, demander confirmation pour continuer
    if (-not $user.Enabled) {
        Write-Warning "L'utilisateur est deja desactive."
        $continueAnyway = Read-Host "Voulez-vous quand meme le deplacer vers l'OU QUARANTINE ? (O/N)"
        if ($continueAnyway -ne 'O' -and $continueAnyway -ne 'o') {
            Write-Host "Operation annulee." -ForegroundColor Yellow
            exit 0
        }
    }

    # ========================================
    # ÉTAPE 6 : CONFIRMATION FINALE
    # ========================================
    
    # Afficher un résumé des actions à effectuer
    Write-Host "`nActions a effectuer :" -ForegroundColor Yellow
    if ($user.Enabled) {
        Write-Host "  1. Desactivation du compte" -ForegroundColor White
    }
    Write-Host "  $(if($user.Enabled){'2'}else{'1'}). Deplacement vers : $targetOU" -ForegroundColor White
    Write-Host ""
    
    # Demander la confirmation finale
    $confirmation = Read-Host "Confirmez-vous ces actions ? (O/N)"
    
    if ($confirmation -ne 'O' -and $confirmation -ne 'o') {
        Write-Host "`nOperation annulee par l'utilisateur." -ForegroundColor Yellow
        exit 0
    }

    # ========================================
    # ÉTAPE 7 : DÉSACTIVATION DU COMPTE
    # ========================================
    
    # Désactiver le compte uniquement s'il est encore actif
    if ($user.Enabled) {
        Write-Host "`nDesactivation du compte..." -ForegroundColor Gray
        Disable-ADAccount -Identity $UserLogin -ErrorAction Stop
        Write-Host "Compte desactive avec succes" -ForegroundColor Green
    }

    # ========================================
    # ÉTAPE 8 : DÉPLACEMENT VERS QUARANTINE
    # ========================================
    
    Write-Host "Deplacement vers l'OU QUARANTINE..." -ForegroundColor Gray
    
    # Déplacer l'objet AD vers l'OU de quarantaine
    Move-ADObject -Identity $user.DistinguishedName -TargetPath $targetOU -ErrorAction Stop
    Write-Host "Compte deplace avec succes" -ForegroundColor Green

    # ========================================
    # AFFICHAGE DU RÉSUMÉ FINAL
    # ========================================
    
    Write-Host "`n=== Operation terminee avec succes ===" -ForegroundColor Green
    
    # Récupérer l'état final de l'utilisateur
    $updatedUser = Get-ADUser -Identity $UserLogin -Properties Name, DistinguishedName, Enabled
    
    # Afficher les informations finales
    Write-Host "  Nom            : $($updatedUser.Name)" -ForegroundColor White
    Write-Host "  Site           : SITE_$userSite" -ForegroundColor Cyan
    Write-Host "  Nouveau DN     : $($updatedUser.DistinguishedName)" -ForegroundColor White
    Write-Host "  Statut         : $(if($updatedUser.Enabled){'Active'}else{'Desactive'})" -ForegroundColor White

# ========================================
# GESTION DES ERREURS
# ========================================

} catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
    # Erreur : Utilisateur introuvable
    Write-Error "Utilisateur '$UserLogin' introuvable dans Active Directory."
    exit 1
    
} catch [Microsoft.ActiveDirectory.Management.ADException] {
    # Erreurs spécifiques à Active Directory
    Write-Error "Erreur Active Directory : $($_.Exception.Message)"
    
    # Identifier le type d'erreur AD et fournir des conseils
    if ($_.Exception.Message -like "*organizational unit does not exist*") {
        Write-Warning "L'OU cible '$targetOU' n'existe pas. Veuillez verifier la configuration."
    } 
    elseif ($_.Exception.Message -like "*nom deja utilise*" -or $_.Exception.Message -like "*already exists*") {
        Write-Warning "Un utilisateur avec ce nom existe deja dans l'OU cible."
        Write-Warning "Relancez le script, l'option de renommage vous sera proposee."
    }
    exit 1
    
} catch {
    # Erreur générique non prévue
    Write-Error "Erreur inattendue : $($_.Exception.Message)"
    exit 1
}