<#
.SYNOPSIS
    Script de quarantaine automatique des comptes utilisateurs inactifs pour environnement Active Directory multi-sites.

.DESCRIPTION
    Ce script analyse les comptes utilisateurs actifs dans plusieurs sites AD et met automatiquement 
    en quarantaine ceux qui n'ont pas eu d'activité depuis un nombre de jours défini.
    
    Pour chaque site configuré, le script :
    - Recherche les comptes actifs dans l'OU spécifique du site
    - Identifie les comptes inactifs (LastLogonDate > seuil ou jamais connectés)
    - Exclut les comptes systèmes et les OUs protégées
    - Désactive les comptes inactifs
    - Déplace les comptes dans l'OU de quarantaine du site
    
    Le script génère un rapport détaillé par site et un résumé global des opérations.

.PARAMETER InactiveDays
    Nombre de jours d'inactivité avant mise en quarantaine (par défaut : 60 jours)

#>

# ========================================
# QUARANTAINE AUTOMATIQUE - MULTI-SITES
# ========================================

# Configuration fixe
$InactiveDays = 60  # Seuil d'inactivité en jours avant mise en quarantaine

# Définition des sites et de leurs OUs respectives
$sites = @(
    @{
        Name = "SITE_ATLANTIS"
        SearchOU = "OU=SITE_ATLANTIS,DC=xanadu,DC=local"  # OU racine où rechercher les utilisateurs
        QuarantineOU = "OU=Users,OU=QUARANTINE,OU=SITE_ATLANTIS,DC=xanadu,DC=local"  # OU de destination pour les comptes en quarantaine
        ExcludedOUs = @(
            "OU=Users,OU=QUARANTINE,OU=SITE_ATLANTIS,DC=xanadu,DC=local",  # Exclure les comptes déjà en quarantaine
            "OU=ServiceAccounts,DC=xanadu,DC=local"  # Exclure les comptes de service
        )
    },
    @{
        Name = "SITE_SPRINGFIELD"
        SearchOU = "OU=SITE_SPRINGFIELD,DC=xanadu,DC=local"
        QuarantineOU = "OU=Users,OU=QUARANTINE,OU=SITE_SPRINGFIELD,DC=xanadu,DC=local"
        ExcludedOUs = @(
            "OU=Users,OU=QUARANTINE,OU=SITE_SPRINGFIELD,DC=xanadu,DC=local",
            "OU=ServiceAccounts,DC=xanadu,DC=local"
        )
    }
)

# Liste des comptes utilisateurs à exclure systématiquement (comptes systèmes AD)
$excludedUsers = @("Administrator", "Guest", "krbtgt")

# ========================================
# FONCTION : Set-UserQuarantine
# ========================================
# Désactive un compte utilisateur et le déplace vers l'OU de quarantaine
#
# Paramètres :
#   - UserLogin : SamAccountName de l'utilisateur
#   - TargetOU : Distinguished Name de l'OU de quarantaine cible
#
# Retour :
#   - $true si l'opération a réussi
#   - $false en cas d'erreur
# ========================================
function Set-UserQuarantine {
    param(
        [string]$UserLogin,
        [string]$TargetOU
    )

    try {
        # Récupération des informations du compte utilisateur
        $user = Get-ADUser -Identity $UserLogin -Properties Name, DistinguishedName, Enabled, LastLogonDate -ErrorAction Stop

        # Désactivation du compte s'il est encore actif
        if ($user.Enabled) {
            Disable-ADAccount -Identity $user.SamAccountName -ErrorAction Stop
            Write-Host "   Compte desactive: $($user.Name)" -ForegroundColor Yellow
        }

        # Déplacement du compte vers l'OU de quarantaine
        Move-ADObject -Identity $user.DistinguishedName -TargetPath $TargetOU -ErrorAction Stop
        Write-Host "   Compte deplace en quarantaine: $($user.Name)" -ForegroundColor Green

        return $true
    }
    catch {
        # Gestion des erreurs avec affichage du message d'exception
        Write-Warning "   Erreur pour $UserLogin : $($_.Exception.Message)"
        return $false
    }
}

# ===== SCRIPT PRINCIPAL =====

# Affichage du titre et des paramètres d'exécution
Write-Host "`n╔═══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  QUARANTAINE AUTOMATIQUE MULTI-SITES  ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "Seuil d'inactivite: $InactiveDays jours`n"

# Initialisation des compteurs globaux
$totalSuccess = 0  # Nombre total de comptes traités avec succès
$totalErrors = 0   # Nombre total d'erreurs rencontrées
$totalInactive = 0 # Nombre total de comptes inactifs détectés

# Traitement de chaque site configuré
foreach ($site in $sites) {
    # Affichage du nom du site en cours de traitement
    Write-Host "`n┌─────────────────────────────────────┐" -ForegroundColor Magenta
    Write-Host "│ SITE: $($site.Name.PadRight(30)) │" -ForegroundColor Magenta
    Write-Host "└─────────────────────────────────────┘" -ForegroundColor Magenta

    # Vérification de l'existence de l'OU de quarantaine cible
    try {
        $null = Get-ADOrganizationalUnit -Identity $site.QuarantineOU -ErrorAction Stop
        Write-Host " OU Quarantaine validee" -ForegroundColor Green
    }
    catch {
        Write-Error " L'OU cible n'existe pas: $($site.QuarantineOU)"
        continue  # Passer au site suivant si l'OU n'existe pas
    }

    # Récupération de tous les utilisateurs actifs du site
    try {
        $allUsers = Get-ADUser -Filter {Enabled -eq $true} -SearchBase $site.SearchOU -SearchScope Subtree -Properties Name, SamAccountName, LastLogonDate, DistinguishedName | Where-Object {
            
            # Filtrage : exclure les comptes spécifiques (Administrator, Guest, etc.)
            if ($excludedUsers -contains $_.SamAccountName) {
                return $false
            }
            
            # Filtrage : exclure les utilisateurs situés dans les OUs interdites
            $userDN = $_.DistinguishedName
            $isInExcludedOU = $false
            
            foreach ($excludedOU in $site.ExcludedOUs) {
                if ($userDN -like "*$excludedOU*") {
                    $isInExcludedOU = $true
                    break
                }
            }
            
            return -not $isInExcludedOU
        }

        Write-Host "Utilisateurs actifs analyses: $($allUsers.Count)" -ForegroundColor Cyan
    }
    catch {
        Write-Warning "Erreur lors de la recherche dans $($site.SearchOU): $($_.Exception.Message)"
        continue  # Passer au site suivant en cas d'erreur
    }

    # Calcul de la date limite pour déterminer l'inactivité
    $limitDate = (Get-Date).AddDays(-$InactiveDays)

    # Identification des utilisateurs inactifs (LastLogonDate < date limite ou jamais connectés)
    $inactiveUsers = $allUsers | Where-Object {
        $null -eq $_.LastLogonDate -or $_.LastLogonDate -lt $limitDate
    } | Select-Object Name, SamAccountName, 
        @{Name='LastLogonDate';Expression={
            if ($null -eq $_.LastLogonDate) { "Jamais" } else { $_.LastLogonDate }
        }},
        @{Name='InactiveDays';Expression={
            if ($null -eq $_.LastLogonDate) { 
                "Jamais connecté" 
            } else { 
                (New-TimeSpan -Start $_.LastLogonDate -End (Get-Date)).Days 
            }
        }}

    Write-Host "Utilisateurs inactifs detectes: $($inactiveUsers.Count)`n" -ForegroundColor Yellow
    $totalInactive += $inactiveUsers.Count

    # Si aucun utilisateur inactif, passer au site suivant
    if ($inactiveUsers.Count -eq 0) {
        Write-Host "Aucun utilisateur a traiter pour ce site.`n" -ForegroundColor Gray
        continue
    }

    # Affichage de la liste des utilisateurs inactifs sous forme de tableau
    $inactiveUsers | Format-Table Name, SamAccountName, LastLogonDate, InactiveDays -AutoSize

    # Initialisation des compteurs par site
    $siteSuccess = 0
    $siteErrors = 0

    # Traitement de chaque utilisateur inactif (désactivation + déplacement)
    foreach ($user in $inactiveUsers) {
        Write-Host "Traitement: $($user.Name)..." -ForegroundColor Gray
        
        if (Set-UserQuarantine -UserLogin $user.SamAccountName -TargetOU $site.QuarantineOU) {
            $siteSuccess++
        } else {
            $siteErrors++
        }
    }

    # Affichage du résumé pour le site traité
    Write-Host "`n--- Résumé $($site.Name) ---" -ForegroundColor Cyan
    Write-Host "Succès  : $siteSuccess" -ForegroundColor Green
    Write-Host "Erreurs : $siteErrors" -ForegroundColor Red

    # Mise à jour des compteurs globaux
    $totalSuccess += $siteSuccess
    $totalErrors += $siteErrors
}

# ========================================
# RÉSUMÉ GLOBAL DE L'EXÉCUTION
# ========================================
Write-Host "`n╔═══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          RÉSUMÉ GLOBAL                ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host "Total inactifs détectés : $totalInactive"
Write-Host "Total traités avec succès : $totalSuccess" -ForegroundColor Green
Write-Host "Total erreurs : $totalErrors" -ForegroundColor Red
Write-Host "Quarantaine automatique terminée." -ForegroundColor Cyan