<#
.SYNOPSIS
    Script de restauration des sauvegardes locales XANADU.

.DESCRIPTION
    Ce script permet de restaurer tout ou partie d'un backup créé par le système
    de sauvegarde local. Il offre quatre modes d'utilisation :

        1. Restauration complète d’un backup
        2. Restauration ciblée d’un fichier spécifique
        3. Affichage du contenu détaillé d’un backup (mode -List)
        4. Affichage de la liste de tous les backups disponibles (mode automatique)

    Fonctionnement du mode automatique :
        - Si aucun paramètre -BackupLabel n’est fourni,
          le script détecte tous les backups présents dans BackupRoot
          et propose une sélection interactive.
          Exemple : [1] full_20241201_203011_AB12C3

    Gestion des collisions :
        Aucun fichier existant n’est écrasé.
        En cas de conflit, le fichier restauré reçoit un suffixe horodaté :
            Exemple : contrat_2025-12-04_10-30-22_restore.pdf

    Toutes les opérations sont consignées dans Restore.log.

.PARAMETER BackupRoot
    Chemin racine contenant les backups locaux.

.PARAMETER BackupLabel
    Nom du backup à restaurer (ex : full_20241204_135954_A7X9Q2)
    Si absent → le script liste tous les backups et propose un choix.

.PARAMETER TargetPath
    Répertoire dans lequel les données seront restaurées.
    Par défaut : C:\Restore

.PARAMETER FileToRestore
    Terme de recherche d’un fichier spécifique.
    Le script restaure tous les fichiers contenant ce terme dans leur nom.

.PARAMETER List
    Affiche le contenu du backup spécifié, sans restaurer.

.EXAMPLE
    # 1. Restauration complète
    .\Restore.ps1 -BackupRoot "C:\Backups\Local" -BackupLabel full_20241204_135954_A7X9Q2

.EXAMPLE
    # 2. Restauration ciblée d’un fichier contenant "contrat"
    .\Restore.ps1 -BackupRoot "C:\Backups\Local" -BackupLabel full_20241204_135954_A7X9Q2 -FileToRestore contrat

.EXAMPLE
    # 3. Lister tout le contenu d’un backup (arborescence et fichiers)
    .\Restore.ps1 -BackupRoot "C:\Backups\Local" -BackupLabel inc_20241205_023110_Z8Q1XK -List

.EXAMPLE
    # 4. Lister tous les backups disponibles (mode automatique)
    #    puis sélectionner le backup à restaurer
    .\Restore.ps1 -BackupRoot "C:\Backups\Local"

.NOTES
    • Aucun fichier existant n’est écrasé.
    • L’arborescence d’origine est entièrement reconstruite.
    • Compatible avec exécution interactive ou programmée.
#>



#region PARAMETERS
param(
    [string]$BackupRoot = "C:\Backups",

    # Emplacement : Local ou External
    [ValidateSet("Local", "External")]
    [string]$Location = $null,

    # Ex : Full_20241204_135954_A7X9Q2
    [string]$BackupLabel = $null,

    # Cible de restauration
    [string]$TargetPath = "C:\Restore",

    # Permet une restauration ciblée d'un fichier
    [string]$FileToRestore = $null,

    [Switch]$List
)
#endregion PARAMETERS


#region GLOBALS

$LogFile = Join-Path $TargetPath "Logs\Restore.log"
function New-ShortID {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    -join ((1..6) | ForEach-Object { $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] })
}
$BackupID = New-ShortID
#endregion GLOBALS


#region LOGGING
if (-not (Test-Path $LogFile)) {
    New-Item -Path $LogFile -ItemType File -Force | Out-Null
}
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )
    $line = "[{0} - {1}] [{2}] {3}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $BackupID, $Level, $Message
    Add-Content -Path $LogFile -Value $line
}
#endregion LOGGING


#region VALIDATION
function Get-AvailableBackups {
    param(
        [string]$BackupRoot,
        [string]$Location = $null
    )

    $backups = @()

    if ($Location) {
        $locations = @(Join-Path $BackupRoot $Location)
    }
    else {
        $locations = @()
        $localPath = Join-Path $BackupRoot "Local"
        $externalPath = Join-Path $BackupRoot "External"
        if (Test-Path $localPath) { $locations += $localPath }
        if (Test-Path $externalPath) { $locations += $externalPath }
    }

    foreach ($locationPath in $locations) {
        $locationName = Split-Path $locationPath -Leaf
        $policies = Get-ChildItem -Path $locationPath -Directory -ErrorAction SilentlyContinue

        foreach ($policy in $policies) {
            $folders = Get-ChildItem -Path $policy.FullName -Directory |
                       Where-Object { $_.Name -match '^[A-Za-z]+_(full|dif|inc)_' }

            foreach ($f in $folders) {
                $backups += [PSCustomObject]@{
                    Location = $locationName
                    Policy   = $policy.Name
                    Name     = $f.Name
                    FullPath = $f.FullName
                }
            }
        }
    }

    return $backups
}


if (-not (Test-Path $BackupRoot)) {
    Write-Log "Repertoire de sauvegarde introuvable : $BackupRoot" "ERROR"
    exit 1
}

# Si aucun BackupLabel n'est fourni → on affiche la liste

if (-not $BackupLabel) {

    Write-Log "Aucun backup specifie. Proposition d'une selection interactive."

    $available = @(Get-AvailableBackups -BackupRoot $BackupRoot -Location $Location)

    if ($available.Count -eq 0) {
        Write-Log "Aucun backup disponible." "ERROR"
        exit 1
    }

    Write-Log "Backups disponibles :"
    $i = 1
    foreach ($b in $available) {
        Write-Log "  [$i] $($b.Name) [$($b.Location)] (Policy: $($b.Policy))"
        Write-Host "$i) $($b.Name) [$($b.Location)] (Policy: $($b.Policy))"
        $i++
    }

    # Verification de la saisie
    $choiceRaw = Read-Host "Selectionner un numero"
    $choice = $choiceRaw.Trim()

    if (-not ($choice -match '^\d+$')) {
        Write-Host "Selection invalide. Entrez un nombre entier" -ForegroundColor Red
        exit 1
    }

    $choice = [int]$choice

    if ($choice -lt 1 -or $choice -gt $available.Count) {
        Write-Host "Selection invalide. Entrez un nombre entre 1 et $($available.Count)" -ForegroundColor Red
        exit 1
    }

    $selected = $available[[int]$choice - 1]
    $BackupLabel = $selected.Name
    $BackupPath  = $selected.FullPath
    Write-Log "Backup selectionne : $BackupLabel (Policy : $($selected.Policy))"
}
else {
    $available = Get-AvailableBackups -BackupRoot $BackupRoot
    $selected = $available | Where-Object { $_.Name -eq $BackupLabel }

    if (-not $selected) {
        Write-Log "Le backup '$BackupLabel' est introuvable dans les dossiers Policies." "ERROR"
        exit 1
    }

    $BackupPath = $selected.FullPath
    Write-Log "Backup specifie : $BackupLabel (Policy : $($selected.Policy))"
}

if (-not (Test-Path $BackupPath)) {
    Write-Log "Le backup '$BackupLabel' n'existe pas dans $BackupRoot" "ERROR"
    exit 1
}

# Création du dossier de restauration
if (-not (Test-Path $TargetPath)) {
    New-Item -Path $TargetPath -ItemType Directory -Force | Out-Null
}
#endregion VALIDATION


#region RENAME_LOGIC
function Test-NewSplitPathFeatures {
    # Teste si Split-Path supporte -LeafBase (introduit dans PowerShell 7)
    try {
        $null = Split-Path $PSCommandPath -LeafBase
        return $true
    }
    catch {
        return $false
    }
}

function Get-RestoredFilePath {
    param(
        [string]$OriginalPath
    )

    if (-not (Test-Path $OriginalPath)) {
        return $OriginalPath
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $dir = Split-Path $OriginalPath -Parent

    if (Test-NewSplitPathFeatures) {
        # PowerShell 7+
        $name = Split-Path $OriginalPath -LeafBase
        $ext  = Split-Path $OriginalPath -Extension
    }
    else {
        # Windows PowerShell 5.1
        $leaf = Split-Path $OriginalPath -Leaf
        $name = [System.IO.Path]::GetFileNameWithoutExtension($leaf)
        $ext  = [System.IO.Path]::GetExtension($leaf)
    }

    $candidate = Join-Path $dir "${name}_${timestamp}_restore$ext"

    $i = 1
    while (Test-Path $candidate) {
        $candidate = Join-Path $dir "${name}_${timestamp}_restore_$i$ext"
        $i++
    }

    return $candidate
}
#endregion RENAME_LOGIC


#region RESTORE_LOGIC
Write-Log "Debut de la restauration depuis $BackupLabel"

# Mode 1 : restauration d'un fichier specifique

if ($List) {
    Write-Log "Affichage du contenu du backup $BackupLabel"

    $files = Get-ChildItem -Path $BackupPath -Recurse -File

    foreach ($f in $files) {
        $relative = $f.FullName.Substring($BackupPath.Length).TrimStart('\','/')
        Write-Host $relative
    }

    Write-Log "Liste du backup affichee."
    exit 0
}

if ($FileToRestore) {

    Write-Log "Mode : restauration ciblee du fichier '$FileToRestore'"

    $found = Get-ChildItem -Path $BackupPath -Recurse -File |
             Where-Object { $_.Name -like "*$FileToRestore*" }

    if ($found.Count -eq 0) {
        Write-Log "Le fichier '$FileToRestore' est introuvable dans le backup." "ERROR"
        exit 1
    }

    foreach ($file in $found) {

        $relative = $file.FullName.Substring($BackupPath.Length).TrimStart('\','/')
        $target = Join-Path $TargetPath $relative

        $finalTarget = Get-RestoredFilePath -OriginalPath $target

        $destDir = Split-Path $finalTarget -Parent
        if (-not (Test-Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path $file.FullName -Destination $finalTarget -Force
        Write-Log "Fichier restaure : $finalTarget"
    }

    Write-Log "Restauration ciblee terminee."
    exit 0
}


# Mode 2 : restauration complete du backup
Write-Log "Mode : restauration complete du backup."

$files = Get-ChildItem -Path $BackupPath -Recurse -File

foreach ($file in $files) {

    $relative = $file.FullName.Substring($BackupPath.Length).TrimStart('\','/')
    $target = Join-Path $TargetPath $relative
    $finalTarget = Get-RestoredFilePath -OriginalPath $target

    $destDir = Split-Path $finalTarget -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -Path $destDir -ItemType Directory -Force | Out-Null
    }

    Copy-Item -Path $file.FullName -Destination $finalTarget -Force
    Write-Log "Restaure : $finalTarget"
}
#endregion RESTORE_LOGIC


#region END
Write-Log "Restauration terminee avec succes."
exit 0
#endregion END
