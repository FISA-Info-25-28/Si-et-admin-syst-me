<#
.SYNOPSIS
    Script de sauvegarde locale pour XANADU (Full / Différentielle / Incrémentielle).

.DESCRIPTION
    Ce script réalise des sauvegardes de dossiers de données vers un stockage local dédié.
    Il supporte trois modes :
        - Complète : tous les fichiers sont copiés
        - Différentielle : fichiers modifiés depuis la dernière sauvegarde complète
        - Incrémentielle : fichiers modifiés depuis la dernière sauvegarde (complète ou incrémentielle)

    L'état des dernières sauvegardes est enregistré dans un fichier JSON (métadonnées),
    permettant de calculer les jeux de fichiers à inclure pour les sauvegardes différentielles
    et incrémentielles. Un fichier de log est généré à chaque exécution.

.PARAMETER Type
    Type de sauvegarde : "full", "dif" ou "inc".

.PARAMETER Policy
    Classe de criticité de la sauvegarde. Permet de séparer physiquement les backups
    et d'appliquer des durées de rétention différentes par policy.

    Exemples de valeurs possibles :
        - "Critical"  : données métiers critiques
        - "Important" : données importantes mais non vitales
        - "Standard"  : données classiques
        - "Logs"      : journaux techniques

    Les valeurs exactes sont contrôlées par [ValidateSet] dans la déclaration des paramètres.

.EXAMPLE
    .\Backup-Local.ps1 -Type full -IncludesFile "C:\Backups\includes.txt" -Policy Critical

.EXAMPLE
    .\Backup-Local.ps1 -Type dif -IncludesFile "C:\Backups\includes.txt" -Policy Standard

.EXAMPLE
    .\Backup-Local.ps1 -Type inc -IncludesFile "C:\Backups\includes.txt" -Policy Important
#>

# region PARAMETERS
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("full", "dif", "inc")]
    [string]$Type,

    [Parameter(Mandatory = $true)]
    [string]$IncludesFile,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Critical", "Important", "Standard")]
    [string]$Policy
)
#endregion PARAMETERS

# region GLOBAL_VARIABLES

# Timestamp pour nommer le dossier de sauvegarde et le log
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
# Fonction pour générer un ID court aléatoire
function New-ShortID {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    -join ((1..6) | ForEach-Object { $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] })
}
$BackupID = New-ShortID

# Racine globale de stockage des sauvegardes locales
# Exemple d'arborescence finale :
#   C:\Backups\Local\Critical\
#   C:\Backups\Local\Important\
#   C:\Backups\Local\Standard\
$LocalBackupRoot = "C:\Backups\Local"

# Sous-répertoire dédié à la policy (permet de séparer les rétentions par criticité)
$PolicyRoot = Join-Path $LocalBackupRoot $Policy

# Dossier des logs (séparés par policy)
$LogRoot = Join-Path $LocalBackupRoot "Logs"
$LogFile = Join-Path $LogRoot "Backup_${Policy}_$Type.log"

#region LOGGING
# Fonction de log
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    $line = "[{0} - {1}] [{2}] {3}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"),$BackupID, $Level, $Message

    Add-Content -Path $LogFile -Value $line
}
# endregion LOGGING

#region INPUT_VALIDATION


if (-not (Test-Path $IncludesFile)) {
    Write-Log "Le fichier include liste ($IncludesFile) est introuvable." "ERROR"
    exit 1
}

$SourcePaths = Get-Content $IncludesFile | Where-Object { $_ -and $_.Trim() -ne "" }
# endregion INPUT_VALIDATION

#region ENVIRONMENT_INITIALIZATION

# Fichier de métadonnées pour suivre les dernières sauvegardes
$MetadataFile = Join-Path $PolicyRoot "backup_state.json"

# Création des dossiers si nécessaires
foreach ($path in @($LocalBackupRoot, $PolicyRoot, $LogRoot)) {
    if (-not (Test-Path $path)) {
        New-Item -Path $path -ItemType Directory -Force | Out-Null
    }
}

# Nom logique du backup :
#   <Policy>_<Type>_<timestamp>_<ID>
#   Exemple : Critical_full_20250206_143000_AB12CD
$BackupLabel = "${Policy}_${Type}_${timestamp}_${BackupID}"

$CurrentBackupPath = Join-Path $PolicyRoot $BackupLabel

# Création du dossier de sauvegarde courant
New-Item -Path $CurrentBackupPath -ItemType Directory -Force | Out-Null

Write-Log "Demarrage de la sauvegarde locale. Type = $Type; Policy = $Policy"

#endregion ENVIRONMENT_INITIALIZATION

#region LOAD_METADATA

# Structure d'état par défaut
$state = [ordered]@{
    LastFullDate    = $null
    LastBackupDate  = $null
}

if (Test-Path $MetadataFile) {
    try {
        $json = Get-Content -Path $MetadataFile -Raw
        if ($json.Trim().Length -gt 0) {
            $loaded = $json | ConvertFrom-Json
            $state.LastFullDate   = $loaded.LastFullDate
            $state.LastBackupDate = $loaded.LastBackupDate
        }
        Write-Log "Metadonnées chargees depuis $MetadataFile"
    }
    catch {
        Write-Log "Impossible de lire le fichier de metadonnees. Une sauvegarde complete sera forcee." "WARN"
        $Type = "full"
    }
}

# Si aucune sauvegarde complète n'a jamais été faite, on force une complète
if (($Type -ne "full") -and (-not $state.LastFullDate)) {
    Write-Log "Aucune sauvegarde complete precedente trouvee. Forcage en 'full'." "WARN"
    $Type = "full"
}

#endregion LOAD_METADATA

#region DETERMINE_BACKUP_SCOPE

$referenceDate = $null

switch ($Type) {
    "full" {
        Write-Log "Sauvegarde complete : tous les fichiers seront copies."
    }
    "dif" {
        $referenceDate = [datetime]$state.LastFullDate
        Write-Log "Sauvegarde differentielle : fichiers modifies depuis la derniere complete du $referenceDate."
    }
    "inc" {
        $referenceDate = [datetime]$state.LastBackupDate
        Write-Log "Sauvegarde incrementielle : fichiers modifies depuis la derniere sauvegarde du $referenceDate."
    }
}

#endregion DETERMINE_BACKUP_SCOPE

#region SCAN_SOURCES

$filesToBackup = @()
$nbSourcesOK = 0

foreach ($source in $SourcePaths) {

    if (-not (Test-Path $source)) {
        Write-Log "Chemin source introuvable : $source" "WARN"
        continue
    }

    $nbSourcesOK++

    if ($null -eq $referenceDate) {
        # Complète : tous les fichiers
        $selection = Get-ChildItem -Path $source -Recurse -File -ErrorAction SilentlyContinue
    } else {
        # dif / inc : uniquement fichiers plus récents que la référence
        $selection = Get-ChildItem -Path $source -Recurse -File -ErrorAction SilentlyContinue |
                     Where-Object { $_.LastWriteTime -gt $referenceDate }
    }

    if ($selection.Count -eq 0) {
        Write-Log "Aucun fichier a sauvegarder pour la source : $source"
    }

    foreach ($file in $selection) {
        # On garde aussi l'info de la racine source pour reconstruire l'arborescence
        $filesToBackup += [PSCustomObject]@{
            SourceRoot = $source
            File       = $file
        }
    }
}

if ($nbSourcesOK -eq 0) {
    Write-Log "Aucune source valide. Arret de la sauvegarde." "ERROR"
    exit 2
}

Write-Log ("Nombre total de fichiers a sauvegarder : {0}" -f $filesToBackup.Count)

#endregion SCAN_SOURCES

#region BACKUP_EXECUTION

$copied = 0
$errors = 0

foreach ($item in $filesToBackup) {
    $file      = $item.File
    $sourceRoot = $item.SourceRoot

    # Chemin relatif par rapport à la racine source
    $relativePath = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')

    # Dossier racine dans la sauvegarde pour cette source
    $sourceName = Split-Path $sourceRoot -Leaf
    $targetRootForSource = Join-Path $CurrentBackupPath $sourceName

    # Chemin complet de destination
    $destFile = Join-Path $targetRootForSource $relativePath
    $destDir  = Split-Path $destFile -Parent

    try {
        if (-not (Test-Path $destDir)) {
            New-Item -Path $destDir -ItemType Directory -Force | Out-Null
        }

        Copy-Item -Path $file.FullName -Destination $destFile -Force -ErrorAction Stop
        $copied++
    }
    catch {
        Write-Log "Erreur lors de la copie de '$($file.FullName)' vers '$destFile' : $($_.Exception.Message)" "ERROR"
        $errors++
    }
}

Write-Log "Copie terminee. Fichiers copies : $copied ; erreurs : $errors"

#endregion BACKUP_EXECUTION

#region UPDATE_METADATA

$now = Get-Date

switch ($Type) {
    "full" {
        $state.LastFullDate   = $now
        $state.LastBackupDate = $now
    }
    "dif" {
        # On ne change pas la date de Full, uniquement la date du dernier backup
        $state.LastBackupDate = $now
    }
    "inc" {
        $state.LastBackupDate = $now
    }
}

try {
    $state | ConvertTo-Json | Set-Content -Path $MetadataFile -Encoding UTF8
    Write-Log "MMetadonnees mises a jour dans $MetadataFile"
}
catch {
    Write-Log "Erreur lors de l'ecriture des metadonnees : $($_.Exception.Message)" "ERROR"
}

#endregion UPDATE_METADATA

#region END

if ($errors -gt 0) {
    Write-Log "Sauvegarde terminee avec erreurs. VVerifier le log pour plus de details." "WARN"
    exit 1
}
else {
    Write-Log "Sauvegarde terminee avec succes."
    exit 0
}

#endregion END
