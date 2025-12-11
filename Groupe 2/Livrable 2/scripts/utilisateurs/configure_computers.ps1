# ========================================
# configure_new_computer.ps1
# Script de configuration automatique d'un nouveau poste physique
# ========================================
# 
# Description:
#   Configure automatiquement un poste nouvellement joint au domaine :
#   - Renommage selon la nomenclature PCX-SERVICE
#   - Déplacement dans l'OU appropriée selon site et service
#   - Attribution du VLAN correspondant
#   - Journalisation complète des opérations
#
# Prérequis:
#   - Droits administrateur sur le poste et dans l'AD
#   - Module ActiveDirectory installé
#   - Le poste doit déjà être joint au domaine
#
# Exemples d'utilisation:
#   .\configure_new_computer.ps1                              # Détecte automatiquement le nom du PC local
#   .\configure_new_computer.ps1 -AutoNumber                  # Détecte le PC local + numéro auto
#   .\configure_new_computer.ps1 -ComputerName "DESKTOP-ABC123"
#   .\configure_new_computer.ps1 -ComputerName "PC-TEMP" -PCNumber 5
#
# ========================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Nom actuel de l'ordinateur dans AD (détecté automatiquement si non fourni)")]
    [string]$ComputerName = "",

    [Parameter(Mandatory = $false, HelpMessage = "Numéro du PC (sera auto-généré si non fourni)")]
    [int]$PCNumber = 0,

    [Parameter(Mandatory = $false, HelpMessage = "Générer automatiquement le numéro de PC")]
    [switch]$AutoNumber
)

# ========================================
# CONFIGURATION MULTI-SITES
# ========================================

$sites = @{
    "ATLANTIS" = @{
        Services = @("CGF", "COMMERCIAL", "BDE", "JURIDIQUE", "RH", "DIRECTION", "INFO")
    }
    "SPRINGFIELD" = @{
        Services = @("LABO")
    }
}

# ========================================
# IMPORT DES FONCTIONS COMMUNES
# ========================================

# Import du module Active Directory
try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Error "Le module ActiveDirectory n'est pas disponible. Installez les outils RSAT."
    exit 1
}

# Import des fonctions de journalisation si disponible
# $logScriptPath = Join-Path $PSScriptRoot "logs.ps1"
# if (Test-Path $logScriptPath) {
#     . $logScriptPath
#     $useCustomLog = $true
# } else {
#     Write-Warning "Le fichier logs.ps1 est introuvable. Journalisation basique activée."
#     $useCustomLog = $false
# }

# ========================================
# FONCTIONS
# ========================================

# Fonction de journalisation de secours
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    $color = switch ($Level) {
        "INFO"    { "White" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "SUCCESS" { "Green" }
    }
    
    Write-Host $logMessage -ForegroundColor $color
    
    # Écriture dans un fichier log
    $logDir = Join-Path $PSScriptRoot "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $logFile = Join-Path $logDir "configure_computer_$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $logMessage
}

function Write-CustomLog {
    param(
        [string]$Category,
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    if ($useCustomLog) {
        # Utilise la fonction du fichier logs.ps1
        # & Write-CustomLog -Category $Category -Message $Message -Level $Level
    } else {
        # Utilise la fonction de secours
        Write-Log -Message "[$Category] $Message" -Level $Level
    }
}

# Fonction pour sélectionner un site et un service
function Select-SiteAndService {
    param()

    Write-Host "`n=== SELECTION DU SITE ===" -ForegroundColor Cyan
    Write-Host "[0] SITE_ATLANTIS (Siège)" -ForegroundColor White
    Write-Host "[1] SITE_SPRINGFIELD (Distant)" -ForegroundColor White
    Write-Host "Ou tapez 'Q' pour quitter`n" -ForegroundColor Yellow
    Write-Host "Votre choix: " -ForegroundColor Green -NoNewline
    $siteChoice = Read-Host

    if ($siteChoice -eq 'Q' -or $siteChoice -eq 'q') {
        Write-Host "Annulé." -ForegroundColor Red
        exit
    }

    $siteName = $null
    $availableServices = $null

    switch ($siteChoice) {
        '0' {
            $siteName = "ATLANTIS"
            $availableServices = $sites["ATLANTIS"].Services
        }
        '1' {
            $siteName = "SPRINGFIELD"
            $availableServices = $sites["SPRINGFIELD"].Services
        }
        default {
            Write-Host "Choix invalide" -ForegroundColor Red
            exit 1
        }
    }

    # Sélection du service
    Write-Host "`n=== SELECTION DU SERVICE ===" -ForegroundColor Cyan
    Write-Host "Services disponibles sur SITE_$siteName :" -ForegroundColor Yellow
    Write-Host "Ou tapez 'Q' pour quitter`n" -ForegroundColor Yellow
    
    for ($i = 0; $i -lt $availableServices.Count; $i++) {
        Write-Host "[$i] $($availableServices[$i])"
    }

    Write-Host "`nVotre choix: " -ForegroundColor Green -NoNewline
    $serviceChoice = Read-Host

    if ($serviceChoice -eq 'Q' -or $serviceChoice -eq 'q') {
        Write-Host "Annulé." -ForegroundColor Red
        exit
    }
    
    $index = [int]$serviceChoice
    if ($index -ge 0 -and $index -lt $availableServices.Count) {
        $serviceName = $availableServices[$index]
        return @{
            Site    = $siteName
            Service = $serviceName
        }
    } else {
        Write-Host "Choix invalide" -ForegroundColor Red
        exit 1
    }
}

# Fonction pour obtenir le prochain numéro de PC disponible
function Get-NextPCNumber {
    param(
        [string]$Service
    )
    
    Write-CustomLog -Category "configure_computer" -Message "Recherche du prochain numéro disponible pour le service $Service" -Level "INFO"
    
    # Rechercher tous les ordinateurs avec le préfixe PCX-SERVICE
    $pattern = "PC*-$Service"
    $existingComputers = Get-ADComputer -Filter "Name -like '$pattern'" -Properties Name | Select-Object -ExpandProperty Name
    
    if ($existingComputers.Count -eq 0) {
        Write-CustomLog -Category "configure_computer" -Message "Aucun ordinateur existant trouvé. Numéro 1 sera utilisé" -Level "INFO"
        return 1
    }
    
    # Extraire les numéros existants
    $existingNumbers = @()
    foreach ($computerName in $existingComputers) {
        if ($computerName -match '^PC(\d+)-') {
            $existingNumbers += [int]$matches[1]
        }
    }
    
    if ($existingNumbers.Count -eq 0) {
        return 1
    }
    
    # Trouver le premier numéro disponible
    $existingNumbers = $existingNumbers | Sort-Object
    $nextNumber = 1
    
    foreach ($num in $existingNumbers) {
        if ($num -eq $nextNumber) {
            $nextNumber++
        } else {
            break
        }
    }
    
    Write-CustomLog -Category "configure_computer" -Message "Prochain numéro disponible : $nextNumber" -Level "INFO"
    return $nextNumber
}

# Fonction pour calculer le VLAN
function Get-ComputerVLAN {
    param(
        [string]$Service
    )
    
    $vlan = $serviceVLAN[$Service]
    
    if ($null -eq $vlan) {
        Write-CustomLog -Category "configure_computer" -Message "VLAN non trouvé pour le service $Service" -Level "ERROR"
        throw "Service non reconnu : $Service"
    }
    
    # Calculer le réseau IP correspondant
    $network = "192.168.$vlan.0/24"
    
    Write-CustomLog -Category "configure_computer" -Message "VLAN assigné : $vlan (Réseau: $network)" -Level "INFO"
    return @{
        VLAN = $vlan
        Network = $network
    }
}

# Fonction pour renommer l'ordinateur dans AD
function Rename-ADComputerSafely {
    param(
        [string]$CurrentName,
        [string]$NewName
    )
    
    try {
        # Vérifier si le nouveau nom existe déjà
        $existingComputer = Get-ADComputer -Filter "Name -eq '$NewName'" -ErrorAction SilentlyContinue
        if ($existingComputer) {
            Write-CustomLog -Category "configure_computer" -Message "Un ordinateur nommé '$NewName' existe déjà dans l'AD" -Level "ERROR"
            throw "Le nom '$NewName' est déjà utilisé"
        }
        
        # Récupérer l'objet ordinateur
        $computer = Get-ADComputer -Identity $CurrentName -ErrorAction Stop
        
        # Renommer
        Rename-ADObject -Identity $computer.DistinguishedName -NewName $NewName -ErrorAction Stop
        Write-CustomLog -Category "configure_computer" -Message "Ordinateur renommé de '$CurrentName' à '$NewName' dans l'AD" -Level "SUCCESS"
        
        return $true
    } catch {
        Write-CustomLog -Category "configure_computer" -Message "Erreur lors du renommage : $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Fonction pour déplacer l'ordinateur dans la bonne OU
function Move-ComputerToOU {
    param(
        [string]$ComputerName,
        [string]$Site,
        [string]$Service
    )
    
    $targetOU = "OU=Computers,OU=$Service,OU=SITE_$Site,DC=xanadu,DC=local"
    
    try {
        # Vérifier que l'OU existe
        $ou = Get-ADOrganizationalUnit -Identity $targetOU -ErrorAction Stop
        
        # Récupérer l'ordinateur
        $computer = Get-ADComputer -Identity $ComputerName -ErrorAction Stop
        
        # Déplacer
        Move-ADObject -Identity $computer.DistinguishedName -TargetPath $targetOU -ErrorAction Stop
        Write-CustomLog -Category "configure_computer" -Message "Ordinateur déplacé vers l'OU : $targetOU" -Level "SUCCESS"
        
        return $true
    } catch {
        Write-CustomLog -Category "configure_computer" -Message "Erreur lors du déplacement vers l'OU : $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# Fonction pour configurer le VLAN dans les attributs AD (pour référence)
function Set-ComputerVLAN {
    param(
        [string]$ComputerName,
        [int]$VLAN,
        [string]$Network
    )
    
    try {
        $computer = Get-ADComputer -Identity $ComputerName -ErrorAction Stop
        
        # Stocker le VLAN dans l'attribut Description
        $description = "VLAN: $VLAN | Réseau: $Network | Configuré le $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Set-ADComputer -Identity $computer -Description $description -ErrorAction Stop
        
        Write-CustomLog -Category "configure_computer" -Message "VLAN $VLAN attribué à l'ordinateur (Réseau: $Network)" -Level "SUCCESS"
        Write-Host "`n  CONFIGURATION SWITCH REQUISE " -ForegroundColor Yellow
        Write-Host "Action manuelle nécessaire sur le switch réseau :" -ForegroundColor Yellow
        Write-Host "  - Ordinateur         : $ComputerName" -ForegroundColor White
        Write-Host "  - Port à configurer  : [À identifier selon le plan réseau]" -ForegroundColor White
        Write-Host "  - VLAN à assigner    : $VLAN" -ForegroundColor Cyan
        Write-Host "  - Réseau IP          : $Network" -ForegroundColor Cyan
        Write-Host "  - Service            : $($computer.Name -replace 'PC\d+-', '')" -ForegroundColor White
        Write-Host ""
        
        return $true
    } catch {
        Write-CustomLog -Category "configure_computer" -Message "Erreur lors de l'attribution du VLAN : $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# ========================================
# SCRIPT PRINCIPAL
# ========================================

Write-CustomLog -Category "configure_computer" -Message "===== DÉMARRAGE DU SCRIPT DE CONFIGURATION =====" -Level "INFO"

# Vérifier les privilèges administrateur
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-CustomLog -Category "configure_computer" -Message "Ce script doit être exécuté en tant qu'administrateur" -Level "ERROR"
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "CONFIGURATION D'UN NOUVEAU POSTE" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Détection automatique du nom de l'ordinateur si non fourni
if ([string]::IsNullOrWhiteSpace($ComputerName)) {
    $ComputerName = $env:COMPUTERNAME
    Write-Host "Détection automatique du nom de l'ordinateur : $ComputerName" -ForegroundColor Green
    Write-CustomLog -Category "configure_computer" -Message "Nom de l'ordinateur détecté automatiquement : $ComputerName" -Level "INFO"
} else {
    Write-Host "Nom de l'ordinateur spécifié : $ComputerName" -ForegroundColor Cyan
    Write-CustomLog -Category "configure_computer" -Message "Nom de l'ordinateur spécifié manuellement : $ComputerName" -Level "INFO"
}
Write-Host ""

# Vérifier que l'ordinateur existe dans l'AD
try {
    $computer = Get-ADComputer -Identity $ComputerName -Properties DistinguishedName, Description -ErrorAction Stop
    Write-CustomLog -Category "configure_computer" -Message "Ordinateur '$ComputerName' trouvé dans l'AD" -Level "SUCCESS"
    Write-Host "Ordinateur actuel : $($computer.Name)" -ForegroundColor Green
    Write-Host "DN actuel         : $($computer.DistinguishedName)" -ForegroundColor White
    Write-Host ""
} catch {
    Write-CustomLog -Category "configure_computer" -Message "Ordinateur '$ComputerName' introuvable dans l'AD : $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

# Sélection du site et du service
$selection = Select-SiteAndService
$siteName = $selection.Site
$serviceName = $selection.Service

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Configuration sélectionnée :" -ForegroundColor Cyan
Write-Host "  Site    : SITE_$siteName" -ForegroundColor Yellow
Write-Host "  Service : $serviceName" -ForegroundColor Yellow
Write-Host "========================================`n" -ForegroundColor Cyan

Write-CustomLog -Category "configure_computer" -Message "Configuration sélectionnée - Site: $siteName, Service: $serviceName" -Level "INFO"

# Déterminer le numéro de PC
if ($AutoNumber -or $PCNumber -eq 0) {
    $PCNumber = Get-NextPCNumber -Service $serviceName
    Write-Host "Numéro de PC auto-généré : $PCNumber" -ForegroundColor Cyan
} else {
    Write-Host "Numéro de PC spécifié : $PCNumber" -ForegroundColor Cyan
}

# Construire le nouveau nom
$newComputerName = "PC$PCNumber-$serviceName"
Write-Host "Nouveau nom : $newComputerName" -ForegroundColor Green

# Calculer le VLAN
$vlanInfo = Get-ComputerVLAN -Service $serviceName
$vlan = $vlanInfo.VLAN
$network = $vlanInfo.Network
Write-Host "VLAN assigné : $vlan" -ForegroundColor Green
Write-Host "Réseau IP    : $network" -ForegroundColor Green

# Confirmer les actions
Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "Actions à effectuer :" -ForegroundColor Yellow
Write-Host "  1. Renommer '$ComputerName' en '$newComputerName'" -ForegroundColor White
Write-Host "  2. Déplacer vers OU=Computers,OU=$serviceName,OU=SITE_$siteName" -ForegroundColor White
Write-Host "  3. Assigner VLAN $vlan (Réseau: $network)" -ForegroundColor White
Write-Host "========================================`n" -ForegroundColor Yellow

$confirmation = Read-Host "Confirmer ces actions ? (O/N)"

if ($confirmation -ne 'O' -and $confirmation -ne 'o') {
    Write-Host "`nOpération annulée par l'utilisateur." -ForegroundColor Yellow
    Write-CustomLog -Category "configure_computer" -Message "Opération annulée par l'utilisateur" -Level "WARNING"
    exit 0
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "DÉBUT DE LA CONFIGURATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$success = $true

# Étape 1 : Renommer l'ordinateur
Write-Host "[1/3] Renommage de l'ordinateur..." -ForegroundColor Cyan
if (-not (Rename-ADComputerSafely -CurrentName $ComputerName -NewName $newComputerName)) {
    $success = $false
    Write-Host "      Échec du renommage" -ForegroundColor Red
} else {
    Write-Host "      Renommage réussi" -ForegroundColor Green
    $ComputerName = $newComputerName  # Mettre à jour le nom pour les étapes suivantes
}

# Étape 2 : Déplacer vers la bonne OU
if ($success) {
    Write-Host "[2/3] Déplacement vers l'OU appropriée..." -ForegroundColor Cyan
    if (-not (Move-ComputerToOU -ComputerName $ComputerName -Site $siteName -Service $serviceName)) {
        $success = $false
        Write-Host "      Échec du déplacement" -ForegroundColor Red
    } else {
        Write-Host "      Déplacement réussi" -ForegroundColor Green
    }
}

# Étape 3 : Configurer le VLAN
if ($success) {
    Write-Host "[3/3] Attribution du VLAN..." -ForegroundColor Cyan
    if (-not (Set-ComputerVLAN -ComputerName $ComputerName -VLAN $vlan -Network $network)) {
        $success = $false
        Write-Host "      Échec de l'attribution du VLAN" -ForegroundColor Red
    } else {
        Write-Host "      VLAN attribué" -ForegroundColor Green
    }
}

# Résumé final
Write-Host "`n========================================" -ForegroundColor Cyan
if ($success) {
    Write-Host "CONFIGURATION TERMINÉE AVEC SUCCÈS" -ForegroundColor Green
    Write-CustomLog -Category "configure_computer" -Message "Configuration réussie pour $newComputerName" -Level "SUCCESS"
} else {
    Write-Host "CONFIGURATION TERMINÉE AVEC DES ERREURS" -ForegroundColor Red
    Write-CustomLog -Category "configure_computer" -Message "Configuration échouée pour $ComputerName" -Level "ERROR"
}
Write-Host "========================================`n" -ForegroundColor Cyan

# Afficher le résumé
$finalComputer = Get-ADComputer -Identity $ComputerName -Properties DistinguishedName, Description
Write-Host "Résumé final :" -ForegroundColor Cyan
Write-Host "  Nom         : $($finalComputer.Name)" -ForegroundColor White
Write-Host "  Site        : SITE_$siteName" -ForegroundColor White
Write-Host "  Service     : $serviceName" -ForegroundColor White
Write-Host "  VLAN        : $vlan" -ForegroundColor White
Write-Host "  Réseau IP   : $network" -ForegroundColor White
Write-Host "  OU          : $($finalComputer.DistinguishedName)" -ForegroundColor White
Write-Host "  Description : $($finalComputer.Description)" -ForegroundColor White
Write-Host ""

Write-Host "⚠️  ACTIONS MANUELLES REQUISES :" -ForegroundColor Yellow
Write-Host "  1. Configurer le port du switch avec le VLAN $vlan" -ForegroundColor White
Write-Host "  2. Vérifier que le PC obtient une IP dans $network" -ForegroundColor White
Write-Host "  3. Redémarrer le poste '$newComputerName' pour appliquer le nouveau nom" -ForegroundColor White
Write-Host "  4. Vérifier la connectivité réseau après redémarrage" -ForegroundColor White
Write-Host ""

Write-CustomLog -Category "configure_computer" -Message "===== FIN DU SCRIPT DE CONFIGURATION =====" -Level "INFO"

if ($success) {
    exit 0
} else {
    exit 1
}