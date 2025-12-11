<#
.SYNOPSIS
    Script de création automatique de comptes utilisateur et administrateur pour le département INFORMATIQUE.

.DESCRIPTION
    Ce script crée automatiquement deux comptes Active Directory pour un nouvel employé du département INFORMATIQUE :
    1. Un compte utilisateur standard (prénom.nom)
    2. Un compte administrateur associé (adm_prénom.nom)
    
    Le script effectue les opérations suivantes :
    - Génère des noms d'utilisateur uniques basés sur le prénom et le nom
    - Crée les comptes dans l'OU du département INFORMATIQUE sur le site ATLANTIS
    - Génère des mots de passe sécurisés pour chaque compte
    - Configure les adresses email (@xanadu.com)
    - Ajoute les comptes au groupe du département
    - Ajoute le compte admin au groupe "Admins"
    - Force le changement de mot de passe à la première connexion
    
    Le département INFORMATIQUE est toujours situé sur le site ATLANTIS.

.PARAMETER FirstName
    Prénom de l'utilisateur (obligatoire, lettres uniquement)

.PARAMETER LastName
    Nom de famille de l'utilisateur (obligatoire, lettres uniquement)

.PARAMETER Description
    Description du rôle ou du poste de l'utilisateur (obligatoire)

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FirstName,

    [Parameter(Mandatory = $true)]
    [string]$LastName,

    [Parameter(Mandatory = $true)]
    [string]$Description
)

# ========================================
# CONFIGURATION
# ========================================

# Département cible (fixe pour ce script)
$departmentOU = "INFORMATIQUE"

# Site du département INFORMATIQUE (toujours ATLANTIS)
$siteName = "ATLANTIS"

# OU cible où seront créés les comptes utilisateurs
$targetUserOU = "OU=Users,OU=$departmentOU,OU=SITE_$siteName,DC=xanadu,DC=local"

# Groupe des administrateurs du domaine
$adminGroupName = "Admins"

# ========================================
# IMPORT DES FONCTIONS COMMUNES
# ========================================

# Chemin vers le fichier de fonctions partagées
$functionsScriptPath = Join-Path $PSScriptRoot "user_functions.ps1"

# Vérifier l'existence du fichier de fonctions
if (-not (Test-Path $functionsScriptPath)) {
    Write-Error "Le fichier user_functions.ps1 est introuvable dans le même repertoire que ce script."
    Write-Error "Chemin recherche : $functionsScriptPath"
    exit 1
}

# Charger les fonctions communes (dot-sourcing)
. $functionsScriptPath

# ========================================
# FONCTIONS
# ========================================

<#
.SYNOPSIS
    Crée un nouvel utilisateur Active Directory dans le domaine Xanadu.

.DESCRIPTION
    Cette fonction encapsule la création d'un compte utilisateur AD avec :
    - Génération automatique d'un mot de passe sécurisé
    - Création d'un nom complet unique
    - Configuration de l'adresse email
    - Activation du compte avec obligation de changer le mot de passe

.PARAMETER FirstName
    Prénom de l'utilisateur

.PARAMETER LastName
    Nom de famille de l'utilisateur

.PARAMETER Username
    Nom d'utilisateur (SamAccountName) déjà vérifié comme unique

.PARAMETER Description
    Description du compte (rôle, poste)

.PARAMETER OUPath
    Distinguished Name de l'OU de destination

.PARAMETER IsAdminAccount
    Indique si c'est un compte administrateur (pour les conventions de nommage)

.OUTPUTS
    Hashtable contenant :
    - FullName : Nom complet de l'utilisateur
    - Username : SamAccountName
    - Password : Mot de passe en clair (à communiquer à l'utilisateur)
    - Email : Adresse email générée
#>
function New-XanaduUser {
    param(
        [string]$FirstName,
        [string]$LastName,
        [string]$Username,
        [string]$Description,
        [string]$OUPath,
        [boolean]$IsAdminAccount
    )
    
    # Générer un mot de passe sécurisé aléatoire
    $passwordObj = New-GenericPassword -Username $Username
    $Password = $passwordObj.SecureString      # Format SecureString pour AD
    $PlainPassword = $passwordObj.PlainText    # Format texte pour affichage
    
    # Générer un nom complet unique (gère les homonymes automatiquement)
    $FullName = Get-UniqueFullName -FirstName $FirstName -LastName $LastName -OUPath $OUPath
    
    # Construire l'adresse email selon la convention @xanadu.com
    $Mail = "$Username@xanadu.com"
    
    # Paramètres de création de l'utilisateur AD
    $userParams = @{
        Name                  = $FullName                  # Nom d'affichage
        GivenName             = $FirstName                 # Prénom
        Surname               = $LastName                  # Nom de famille
        SamAccountName        = $Username                  # Login
        AccountPassword       = $Password                  # Mot de passe sécurisé
        EmailAddress          = $Mail                      # Email
        Description           = $Description               # Description du rôle
        Path                  = $OUPath                    # OU de destination
        ChangePasswordAtLogon = $true                      # Forcer le changement de MDP
        Enabled               = $true                      # Activer le compte immédiatement
        ErrorAction           = 'Stop'                     # Arrêter en cas d'erreur
    }
    
    # Créer le compte utilisateur dans Active Directory
    New-ADUser @userParams
    
    # Retourner les informations du compte créé
    return @{
        FullName = $FullName
        Username = $Username
        Password = $PlainPassword
        Email = $Mail
    }
}

# ========================================
# SCRIPT PRINCIPAL
# ========================================

# Vérifier que le script est exécuté avec des privilèges administrateur
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Ce script doit être execute en tant qu'administrateur."
    exit 1
}

try {
    # ========================================
    # VALIDATION DES ENTRÉES
    # ========================================
    
    # Valider que le prénom contient uniquement des lettres
    if ($FirstName -match '^[a-zA-Z]+$' -eq $false) {
        Write-Error "Le prenom contient des caracteres invalides. Seules les lettres sont autorisees."
        exit 1
    }

    # Valider que le nom contient uniquement des lettres
    if ($LastName -match '^[a-zA-Z]+$' -eq $false) {
        Write-Error "Le nom contient des caracteres invalides. Seules les lettres sont autorisees."
        exit 1
    }

    # ========================================
    # AFFICHAGE DU TITRE ET DES INFORMATIONS
    # ========================================
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "CREATION DE COMPTES POUR LE DEPARTEMENT INFORMATIQUE" -ForegroundColor Cyan
    Write-Host "Site: SITE_$siteName" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    Write-Host "Utilisateur : $FirstName $LastName" -ForegroundColor White
    Write-Host "Description : $Description" -ForegroundColor White
    Write-Host ""

    # ========================================
    # ÉTAPE 1 : CRÉER LE COMPTE UTILISATEUR
    # ========================================
    
    Write-Host "=== CREATION DU COMPTE UTILISATEUR ===" -ForegroundColor Yellow
    
    # Construire le nom d'utilisateur standard (format : première_lettre.nom)
    $firstLetter = $FirstName.Substring(0,1)
    $userLogin = "$firstLetter.$LastName".ToLower()
    
    # Vérifier l'unicité du nom d'utilisateur (ajoute un numéro si nécessaire)
    $userLogin = Get-UniqueUsername -BaseUsername $userLogin
    
    Write-Host "Creation du compte : $userLogin" -ForegroundColor Gray
    
    # Créer le compte utilisateur dans Active Directory
    $userResult = New-XanaduUser -FirstName $FirstName `
                                  -LastName $LastName `
                                  -Username $userLogin `
                                  -Description $Description `
                                  -OUPath $targetUserOU `
                                  -IsAdminAccount $false
    
    # Afficher les informations du compte créé
    Write-Host "Compte utilisateur cree avec succes" -ForegroundColor Green
    Write-Host "  Nom complet : $($userResult.FullName)" -ForegroundColor White
    Write-Host "  Login       : $($userResult.Username)" -ForegroundColor White
    Write-Host "  Email       : $($userResult.Email)" -ForegroundColor White
    Write-Host "  Mot de passe: $($userResult.Password)" -ForegroundColor Yellow
    Write-Host ""

    # Ajouter l'utilisateur au groupe de son département
    Add-ADGroupMember -Identity $departmentOU -Members $userLogin -ErrorAction Stop
    Write-Host "Ajoute au groupe '$departmentOU'" -ForegroundColor Green
    Write-Host ""

    # ========================================
    # ÉTAPE 2 : CRÉER LE COMPTE ADMINISTRATEUR
    # ========================================
    
    Write-Host "=== CREATION DU COMPTE ADMINISTRATEUR ===" -ForegroundColor Yellow
    
    # Construire le nom d'utilisateur admin (format : adm_prénom.nom)
    $adminLogin = "adm_$userLogin"
    
    # Vérifier l'unicité du nom d'utilisateur admin
    $adminLogin = Get-UniqueUsername -BaseUsername $adminLogin
    
    Write-Host "Creation du compte : $adminLogin" -ForegroundColor Gray
    
    # Créer le compte administrateur dans Active Directory
    $adminResult = New-XanaduUser -FirstName $FirstName `
                                   -LastName $LastName `
                                   -Username $adminLogin `
                                   -Description "$Description (Admin)" `
                                   -OUPath $targetUserOU `
                                   -IsAdminAccount $true
    
    # Afficher les informations du compte admin créé
    Write-Host "Compte administrateur cree avec succes" -ForegroundColor Green
    Write-Host "  Nom complet : $($adminResult.FullName)" -ForegroundColor White
    Write-Host "  Login       : $($adminResult.Username)" -ForegroundColor White
    Write-Host "  Email       : $($adminResult.Email)" -ForegroundColor White
    Write-Host "  Mot de passe: $($adminResult.Password)" -ForegroundColor Yellow
    Write-Host ""

    # Ajouter le compte admin au groupe du département
    Add-ADGroupMember -Identity $departmentOU -Members $adminLogin -ErrorAction Stop
    Write-Host "Ajoute au groupe '$departmentOU'" -ForegroundColor Green

    # Ajouter le compte admin au groupe Admins du domaine
    try {
        Add-ADGroupMember -Identity $adminGroupName -Members $adminLogin -ErrorAction Stop
        Write-Host "Ajoute au groupe '$adminGroupName'" -ForegroundColor Green
    } catch {
        # Gestion des erreurs si le groupe n'existe pas ou droits insuffisants
        Write-Warning "Impossible d'ajouter au groupe '$adminGroupName': $($_.Exception.Message)"
        Write-Warning "Verifiez que le groupe existe et que vous avez les droits necessaires."
    }

    # ========================================
    # MESSAGE DE SUCCÈS FINAL
    # ========================================
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "CREATION TERMINEE AVEC SUCCES" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan

} catch {
    # Gestion globale des erreurs non prévues
    Write-Host "`nEchec de la creation des comptes : $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}