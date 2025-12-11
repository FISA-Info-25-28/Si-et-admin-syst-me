<#
.SYNOPSIS
    Script de création automatique de comptes utilisateurs Active Directory avec gestion multi-sites et attribution de droits.

.DESCRIPTION
    Ce script crée un compte utilisateur Active Directory dans un environnement multi-sites (ATLANTIS et SPRINGFIELD).
    Il permet de :
    - Sélectionner interactivement le site et le service de destination
    - Créer un compte utilisateur avec nom d'utilisateur unique
    - Générer un mot de passe temporaire sécurisé
    - Ajouter l'utilisateur au groupe de son service
    - Attribuer des droits sur les fichiers (lecture, écriture, modification) pour les utilisateurs standards
    - Attribuer automatiquement tous les droits admin pour les comptes administrateurs
    - Enregistrer les opérations dans les logs
    
    Architecture des sites :
    - SITE_ATLANTIS (Siège) : BDE, CGF, COMMERCIAL, DIRECTION, JURIDIQUE, RH
    - SITE_SPRINGFIELD (Distant) : LABO
    
    Groupes de droits sur fichiers :
    - Shadow_r_[SERVICE] : Droits de lecture
    - Shadow_w_[SERVICE] : Droits d'écriture
    - Shadow_m_[SERVICE] : Droits de modification
    - Admin_[SERVICE] : Droits administrateurs complets

.PARAMETER FirstName
    Prénom de l'utilisateur (obligatoire, lettres uniquement)

.PARAMETER LastName
    Nom de famille de l'utilisateur (obligatoire, lettres uniquement)

.PARAMETER Description
    Description du rôle ou du poste de l'utilisateur (obligatoire)

.PARAMETER isAdmin
    Booléen indiquant si l'utilisateur doit avoir des droits administrateurs ($true ou $false)

#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FirstName,

    [Parameter(Mandatory = $true)]
    [string]$LastName,

    [Parameter(Mandatory = $true)]
    [string]$Description,

    [Parameter(Mandatory = $true)]
    [boolean]$isAdmin
)

# ========================================
# CONFIGURATION MULTI-SITES
# ========================================

# Définition de l'architecture des sites et de leurs services respectifs
$sites = @{
    "ATLANTIS" = @("BDE", "CGF", "COMMERCIAL", "DIRECTION", "JURIDIQUE", "RH")      # Site principal (siège)
    "SPRINGFIELD" = @("LABO")                                                        # Site distant
}

# Définition des préfixes des groupes de droits sur les fichiers
# Ces groupes contrôlent les permissions NTFS sur les partages réseau
$roleGroups = @(
    "Shadow_r_",    # Lecture seule (Read)
    "Shadow_w_",    # Écriture (Write)
    "Shadow_m_",    # Modification (Modify)
    "Admin_"        # Administration complète
)

# ========================================
# IMPORT DES FONCTIONS COMMUNES
# ========================================

# Charger le fichier de fonctions partagées (génération de mots de passe, validation, etc.)
$functionsScriptPath = Join-Path $PSScriptRoot "user_functions.ps1"
if (-not (Test-Path $functionsScriptPath)) {
    Write-Error "Le fichier user_functions.ps1 est introuvable dans le même repertoire que ce script."
    Write-Error "Chemin recherche : $functionsScriptPath"
    exit 1
}
. $functionsScriptPath

# Charger le système de journalisation
$logScriptPath = Join-Path $PSScriptRoot "logs.ps1"
if (-not (Test-Path $logScriptPath)) {
    Write-Error "Le fichier logs.ps1 est introuvable dans le même repertoire que ce script."
    Write-Error "Chemin recherche : $logScriptPath"
    exit 1
}
. $logScriptPath

# ========================================
# FONCTIONS
# ========================================

<#
.SYNOPSIS
    Permet à l'utilisateur de sélectionner interactivement un site et un service.

.DESCRIPTION
    Cette fonction affiche un menu interactif en deux étapes :
    1. Sélection du site (ATLANTIS ou SPRINGFIELD)
    2. Sélection du service parmi ceux disponibles sur le site choisi
    
    La fonction récupère dynamiquement les groupes AD correspondant aux services
    disponibles sur le site sélectionné.

.OUTPUTS
    Hashtable contenant :
    - Site : Nom du site sélectionné (ATLANTIS ou SPRINGFIELD)
    - Group : Objet ADGroup du service sélectionné

.EXAMPLE
    $selection = Select-SiteAndGroup
    # Retourne : @{ Site = "ATLANTIS"; Group = [ADGroup pour "RH"] }
#>
function Select-SiteAndGroup {
    param()

    # ========================================
    # ÉTAPE 1 : SÉLECTION DU SITE
    # ========================================
    Write-Host "`n=== SELECTION DU SITE ===" -ForegroundColor Cyan
    Write-Host "[0] SITE_ATLANTIS (Siege)" -ForegroundColor White
    Write-Host "[1] SITE_SPRINGFIELD (Distant)" -ForegroundColor White
    Write-Host "Ou tapez 'Q' pour quitter`n" -ForegroundColor Yellow
    Write-Host "Votre choix: " -ForegroundColor Green -NoNewline
    $siteChoice = Read-Host

    # Gérer l'annulation
    if ($siteChoice -eq 'Q' -or $siteChoice -eq 'q') {
        Write-Host "Annule." -ForegroundColor Red
        exit
    }

    # Variables pour stocker le site sélectionné et ses services
    $siteName = $null
    $availableServices = $null

    # Déterminer le site en fonction du choix
    switch ($siteChoice) {
        '0' {
            $siteName = "ATLANTIS"
            $availableServices = $sites["ATLANTIS"]
        }
        '1' {
            $siteName = "SPRINGFIELD"
            $availableServices = $sites["SPRINGFIELD"]
        }
        default {
            Write-Host "Choix invalide" -ForegroundColor Red
            exit 1
        }
    }

    # ========================================
    # ÉTAPE 2 : SÉLECTION DU SERVICE
    # ========================================
    Write-Host "`n=== SELECTION DU SERVICE ===" -ForegroundColor Cyan
    Write-Host "Services disponibles sur SITE_$siteName :" -ForegroundColor Yellow
    Write-Host "Ou tapez 'Q' pour quitter`n" -ForegroundColor Yellow
    
    # Récupérer les groupes AD correspondant aux services du site
    # Filtre les groupes AD dont le nom correspond aux services disponibles
    $groups = @(Get-ADGroup -Filter * | Where-Object { 
        $availableServices -contains $_.Name 
    } | Sort-Object Name)

    # Vérifier qu'il existe au moins un groupe
    if ($groups.Count -eq 0) {
        Write-Host "Aucun groupe disponible sur ce site." -ForegroundColor Red
        exit 1
    }

    # Afficher la liste numérotée des services disponibles
    for ($i = 0; $i -lt $groups.Count; $i++) {
        Write-Host "[$i] $($groups[$i].Name)"
    }

    # Demander la sélection du service
    Write-Host "`nVotre choix: " -ForegroundColor Green -NoNewline
    $groupChoice = Read-Host

    # Gérer l'annulation
    if ($groupChoice -eq 'Q' -or $groupChoice -eq 'q') {
        Write-Host "Annule." -ForegroundColor Red
        exit
    }
    
    $numero = $groupChoice.Trim()

    # Valider que la saisie est un nombre valide
    if ($numero -match '^\d+$') {
        $index = [int]$numero
        # Vérifier que l'index est dans les limites
        if ($index -ge 0 -and $index -lt $groups.Count) {
            # Retourner le site et le groupe sélectionné
            return @{
                Site = $siteName
                Group = $groups[$index]
            }
        }
        else {
            Write-Host "Numero invalide: $numero" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "Entree invalide: $numero" -ForegroundColor Red
        exit 1
    }
}

<#
.SYNOPSIS
    Gère interactivement l'attribution d'un type de droit sur les fichiers pour un utilisateur.

.DESCRIPTION
    Cette fonction demande à l'administrateur si l'utilisateur doit avoir un droit spécifique
    (lecture, écriture ou modification) sur les fichiers du service.
    Si la réponse est positive, l'utilisateur est ajouté au groupe AD correspondant.

.PARAMETER Username
    SamAccountName de l'utilisateur

.PARAMETER RightType
    Type de droit à attribuer (read, write, modify)

.PARAMETER GroupName
    Nom complet du groupe AD auquel ajouter l'utilisateur (ex: Shadow_r_RH)

.EXAMPLE
    HandleRight -Username "j.dupont" -RightType "read" -GroupName "Shadow_r_RH"
    
    Demande si j.dupont doit avoir les droits de lecture et l'ajoute au groupe si oui
#>
function HandleRight {
    param(
        [string]$Username,
        [string]$RightType,
        [string]$GroupName
    )

    # Demander confirmation à l'administrateur
    Write-Host "L'utilisateur '$Username' a-t-il le droit $RightType sur les fichiers ? (o/N)" -ForegroundColor Yellow
    $rightResponse = Read-Host

    # Valider la réponse (o/O/n/N ou Entrée pour passer)
    while ($rightResponse -ne 'o' -and $rightResponse -ne 'O' -and 
           $rightResponse -ne 'n' -and $rightResponse -ne 'N' -and 
           $rightResponse -ne '') {
        Write-Host "Entree invalide. Veuillez répondre par 'o' pour oui, 'n' pour non, ou appuyer sur Entree pour passer." -ForegroundColor Red
        $rightResponse = Read-Host
    }

    # Si réponse positive, ajouter au groupe
    if ($rightResponse -eq 'o' -or $rightResponse -eq 'O') {
        try {
            # Vérifier que le groupe existe
            $null = Get-ADGroup -Identity $GroupName -ErrorAction Stop
            # Ajouter l'utilisateur au groupe
            Add-ADGroupMember -Identity $GroupName -Members $Username -ErrorAction Stop
            Write-Host "L'utilisateur '$Username' a ete ajoute au groupe '$GroupName'" -ForegroundColor Green
        } catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] {
            # Le groupe n'existe pas dans AD
            Write-Warning "Le groupe '$GroupName' n'existe pas. Impossible d'attribuer les droits $RightType."
        } catch {
            # Autre erreur (permissions insuffisantes, etc.)
            Write-Warning "Erreur lors de l'ajout au groupe '$GroupName': $($_.Exception.Message)"
        }
    } else {
        Write-Host "L'utilisateur '$Username' n'aura pas les droits $RightType." -ForegroundColor Yellow
    }
}

# ========================================
# SCRIPT PRINCIPAL
# ========================================

# Vérifier que le script est exécuté avec des privilèges administrateur Windows
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
    # SÉLECTION DU SITE ET DU SERVICE
    # ========================================
    
    # Afficher le menu interactif et récupérer la sélection
    $selection = Select-SiteAndGroup
    $siteName = $selection.Site      # Nom du site (ATLANTIS ou SPRINGFIELD)
    $group = $selection.Group        # Objet ADGroup du service sélectionné

    # ========================================
    # GÉNÉRATION DU NOM D'UTILISATEUR
    # ========================================
    
    # Construire le nom d'utilisateur au format : première_lettre.nom
    try {
        $firstLetter = $FirstName.Substring(0,1)
    } catch {
        Write-Error "Le prenom est vide. Impossible de generer le nom d'utilisateur."
        exit 1
    }
    $Username = "$firstLetter.$LastName".ToLower()
    
    # Vérifier l'unicité et ajouter un numéro si nécessaire
    $Username = Get-UniqueUsername -BaseUsername $Username

    # ========================================
    # CONFIGURATION DU COMPTE
    # ========================================
    
    # Définir l'adresse email selon la convention @xanadu.com
    $Mail = "$Username@xanadu.com"

    # Construire le chemin complet de l'OU de destination
    # Format : OU=Users,OU=[SERVICE],OU=SITE_[SITE],DC=xanadu,DC=local
    $Path = "OU=Users,OU=$($group.Name),OU=SITE_$siteName,DC=xanadu,DC=local"

    # Générer un nom complet unique (gère les homonymes)
    $FullName = Get-UniqueFullName -FirstName $FirstName -LastName $LastName -OUPath $Path

    # Générer un mot de passe temporaire sécurisé
    $passwordObj = New-GenericPassword -Username $Username
    $Password = $passwordObj.SecureString      # Format SecureString pour AD
    $PlainPassword = $passwordObj.PlainText    # Format texte pour affichage

    # ========================================
    # CRÉATION DU COMPTE DANS ACTIVE DIRECTORY
    # ========================================
    
    # Paramètres de création de l'utilisateur
    $userParams = @{
        Name                  = $FullName                  # Nom d'affichage
        GivenName             = $FirstName                 # Prénom
        Surname               = $LastName                  # Nom de famille
        SamAccountName        = $Username                  # Login
        AccountPassword       = $Password                  # Mot de passe sécurisé
        EmailAddress          = $Mail                      # Email
        Description           = $Description               # Description du rôle
        Path                  = $Path                      # OU de destination
        ChangePasswordAtLogon = $true                      # Forcer le changement au premier login
        Enabled               = $true                      # Activer le compte immédiatement
        ErrorAction           = 'Stop'                     # Arrêter en cas d'erreur
    }
    
    # Créer le compte dans Active Directory
    New-ADUser @userParams
    
    # ========================================
    # AFFICHAGE DES INFORMATIONS DU COMPTE CRÉÉ
    # ========================================
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "L'utilisateur '$FullName' a ete cree avec succes !" -ForegroundColor Green
    Write-Host "Site: SITE_$siteName" -ForegroundColor Cyan
    Write-Host "Service: $($group.Name)" -ForegroundColor Cyan
    Write-Host "Login: $Username" -ForegroundColor Yellow
    Write-Host "Mot de passe temporaire: $PlainPassword" -ForegroundColor Yellow
    Write-Host "IMPORTANT: L'utilisateur devra changer son mot de passe a la premiere connexion" -ForegroundColor Magenta
    Write-Host "========================================`n" -ForegroundColor Cyan

    # ========================================
    # AJOUT AU GROUPE PRINCIPAL DU SERVICE
    # ========================================
    
    # Ajouter l'utilisateur au groupe de son service
    Add-ADGroupMember -Identity $group.Name -Members $Username -ErrorAction Stop
    Write-Host "L'utilisateur '$Username' a ete ajoute au groupe '$($group.Name)'" -ForegroundColor Green    

    # ========================================
    # ATTRIBUTION DES DROITS SUR LES FICHIERS
    # ========================================
    
    if ($isAdmin) {
        # Si compte administrateur : ajouter automatiquement à tous les groupes de droits
        Write-Host "`nAttribution des droits administrateurs..." -ForegroundColor Cyan
        
        # Construire les noms complets des groupes admin pour ce service
        $groupNames = $roleGroups | ForEach-Object { "$_$($group.Name)" }
        
        # Ajouter l'utilisateur à tous les groupes de droits en une seule opération
        Add-ADPrincipalGroupMembership -Identity $Username -MemberOf $groupNames
        Write-Host "L'utilisateur '$Username' a ete ajoute aux groupes admin" -ForegroundColor Green
    } else {
        # Si compte utilisateur standard : demander interactivement pour chaque droit
        Write-Host "`nConfiguration des droits sur les fichiers..." -ForegroundColor Cyan
        
        # Gérer les droits de lecture
        HandleRight -Username $Username -RightType "read" -GroupName "Shadow_r_$($group.Name)"
        
        # Gérer les droits d'écriture
        HandleRight -Username $Username -RightType "write" -GroupName "Shadow_w_$($group.Name)"
        
        # Gérer les droits de modification
        HandleRight -Username $Username -RightType "modify" -GroupName "Shadow_m_$($group.Name)"
    }

    # ========================================
    # JOURNALISATION
    # ========================================
    
    # Enregistrer l'opération dans les logs système
    Write-CustomLog -Category "create_user" -Message "Utilisateur '$Username' cree dans le service '$($group.Name)' du site 'SITE_$siteName'." -Level "INFO" 
    
    # TODO : Implémenter la gestion automatique des répertoires personnels
    # Créer automatiquement le dossier /partage/users/$Username avec les bonnes permissions
    
} catch {
    # Gestion globale des erreurs non prévues
    Write-Host "Echec de la creation de l'utilisateur : $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}