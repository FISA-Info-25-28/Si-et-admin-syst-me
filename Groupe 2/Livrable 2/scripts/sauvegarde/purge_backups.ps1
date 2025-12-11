<#
.SYNOPSIS
    Script de purge des sauvegardes locales XANADU.

.DESCRIPTION
    - Applique des règles de rétention par criticité (Policy) à partir d'un JSON.
    - Prend en compte l'externalisation (external_state.json).
    - Supprime les sauvegardes incrémentielles et différentielles
      plus anciennes que la dernière sauvegarde complète (full) de la même Policy.
    - Garantit qu'il reste au moins UNE sauvegarde complète par Policy,
      sauf si elle dépasse l'âge maximal RGPD (par défaut 150 jours).
    - Règles de rétention différentes pour les sauvegardes externalisées / non externalisées.

    Structure attendue :
        BackupRoot
            retention.json     (fichier de règles de rétention)
            \Local
                \Critical
                    \full_...
                    \dif_...
                    \inc_...
                \Important
                \Standard
                \Logs              (ignoré par la purge)
                external_state.json
                \Logs\Purge.log    (log de ce script)
            \External
                \Critical
                \Important
                \Standard

.PARAMETER BackupRoot
    Racine des sauvegardes locales.
    Exemple : C:\Backups\Local

.PARAMETER RetentionConfigPath
    Chemin du fichier JSON de rétention.
    Exemple : C:\Backups\Local\retention.json

.PARAMETER MaxAgeDays
    Âge maximal (en jours) avant suppression forcée (RGPD).
    Par défaut : 150 (≈5 mois)

.PARAMETER DryRun
    Si présent, aucune suppression réelle.
    Le script indique uniquement ce qu'il ferait.

.EXAMPLE
    .\purge_backups.ps1 -BackupRoot "C:\Backups" -RetentionConfigPath "C:\Backups\Local\retention.json"

.EXAMPLE
    .\purge_backups.ps1 -DryRun
#>

#region PARAMETERS
param(
    [string]$BackupRoot = "C:\Backups",
    [string]$RetentionConfigPath = "C:\Backups\retention.json",
    [int]$MaxAgeDays = 150,
    [switch]$DryRun
)
#endregion PARAMETERS

#region GLOBALS / LOGGING

# Dossier Logs + fichier de log de purge
$LogsDir = Join-Path $BackupRoot "Logs"
if (-not (Test-Path $LogsDir)) {
    New-Item -Path $LogsDir -ItemType Directory -Force | Out-Null
}
$PurgeLog = Join-Path $LogsDir "Purge.log"

function Write-PurgeLog {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $PurgeLog -Value $line
    Write-Host $line
}

Write-PurgeLog "=== Demarrage purge (BackupRoot=$BackupRoot, DryRun=$DryRun) ==="

# Date courante
$Now = Get-Date

#endregion GLOBALS / LOGGING

#region VERIFICATIONS PREALABLES

if (-not (Test-Path $BackupRoot)) {
    Write-PurgeLog "Repertoire de sauvegarde introuvable : $BackupRoot" "ERROR"
    exit 1
}

if (-not (Test-Path $RetentionConfigPath)) {
    Write-PurgeLog "Fichier de configuration de retention introuvable : $RetentionConfigPath" "ERROR"
    exit 1
}

# Chargement du JSON de retention
try {
    $retentionRaw = Get-Content -Path $RetentionConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json
    $RetentionConfig = @{}
    $retentionRaw.PSObject.Properties | ForEach-Object {
        $RetentionConfig[$_.Name] = $_.Value
    }
    Write-PurgeLog "Configuration de retention chargee depuis $RetentionConfigPath"
}
catch {
    Write-PurgeLog "Erreur lors du chargement du JSON de retention : $($_.Exception.Message)" "ERROR"
    exit 1
}

#endregion VERIFICATIONS PREALABLES

#region FONCTIONS UTILITAIRES

function Convert-BackupFolderName {
    <#
        Analyse le nom de dossier de sauvegarde et renvoie un objet typé.

        Format attendu :
            <Policy>_<Type>_yyyyMMdd_HHmmss_<ID>

        Exemple :
            Critical_full_20251210_162032_444LDH
            Important_dif_20250101_010203_AB12CD
    #>
    param(
        [string]$Name
    )

    if ($Name -match '^(?<Policy>Critical|Important|Standard)_(?<Type>full|dif|inc)_(?<Date>\d{8})_(?<Time>\d{6})_(?<Id>[A-Z0-9]{6})$') {
        $dateStr = $matches.Date + $matches.Time     # "yyyyMMddHHmmss"
        try {
            $backupDate = [datetime]::ParseExact($dateStr, "yyyyMMddHHmmss", $null)
        }
        catch {
            return $null
        }

        return [PSCustomObject]@{
            Policy     = $matches.Policy
            Type       = $matches.Type
            Name       = $Name
            BackupDate = $backupDate
            Id         = $matches.Id
        }
    }

    return $null
}

#endregion FONCTIONS UTILITAIRES

#region ENUMERATION DES SAUVEGARDES

$allBackups = @()

# On limite aux dossiers Criticité : Critical / Important / Standard
$policyDirs = Get-ChildItem -Path $BackupRoot -Directory |
              Where-Object { $_.Name -in @("Critical","Important","Standard") }

# Traiter les sauvegardes dans \Local et \External
$locationsToProcess = @("Local", "External")

foreach ($location in $locationsToProcess) {
    $locationPath = Join-Path $BackupRoot $location

    if (-not (Test-Path $locationPath)) {
        Write-PurgeLog "Repertoire $location introuvable : $locationPath, ignore." "WARN"
        continue
    }

    $policyDirs = Get-ChildItem -Path $locationPath -Directory |
                  Where-Object { $_.Name -in @("Critical","Important","Standard") }

    if ($policyDirs.Count -eq 0) {
        Write-PurgeLog "Aucune Policy trouvee dans $locationPath" "WARN"
        continue
    }

    foreach ($policyDir in $policyDirs) {

        $policyName = $policyDir.Name

        # Si la Policy n'est pas dans le JSON de retention, on l'ignore
        if (-not $RetentionConfig.ContainsKey($policyName)) {
            Write-PurgeLog "Aucune regle de retention pour la Policy '$policyName', dossiers ignores." "WARN"
            continue
        }

        # Tous les dossiers de backup de cette Policy
        $folders = Get-ChildItem -Path $policyDir.FullName -Directory

        foreach ($folder in $folders) {

            $parsed = Convert-BackupFolderName -Name $folder.Name
            if (-not $parsed) {
                Write-PurgeLog "Nom de dossier ignore (format non reconnu) : $($folder.FullName)" "WARN"
                continue
            }

            $ageDays = ($Now - $parsed.BackupDate).TotalDays
            $isExternal = ($location -eq "External")

            $allBackups += [PSCustomObject]@{
                Policy        = $parsed.Policy
                Type          = $parsed.Type       # full / dif / inc
                Name          = $parsed.Name
                FullPath      = $folder.FullName
                BackupDate    = $parsed.BackupDate
                AgeDays       = [math]::Floor($ageDays)
                External      = $isExternal
                ToDelete      = $false            # sera calculé plus tard
                Reason        = ""                # raison de la purge (pour le log)
                ForcedRGPD    = $false
            }
        }
    }
}

if ($allBackups.Count -eq 0) {
    Write-PurgeLog "Aucune sauvegarde trouvee dans $BackupRoot. Rien a purger." "INFO"
    Write-PurgeLog "=== Fin purge (aucune sauvegarde) ==="
    exit 0
}

#endregion ENUMERATION DES SAUVEGARDES

#region APPLICATION DES REGLES PAR POLICY

# Groupement par Policy
$groupedByPolicy = $allBackups | Group-Object -Property Policy

foreach ($group in $groupedByPolicy) {

    $policyName = $group.Name
    $backups = $group.Group

    $config = $RetentionConfig[$policyName]
    $keepFull = [int]$config.KeepFull
    $retentionDaysLocal     = [int]$config.RetentionDays
    $retentionDaysExternal  = [int]$config.RetentionExternalDay

    Write-PurgeLog "Traitement de la Policy '$policyName' (KeepFull=$keepFull, Ret=$retentionDaysLocal j, RetExt=$retentionDaysExternal j)."

    # --- 1) Toute les sauvegardes full ---
    $fullBackups = $backups | Where-Object { $_.Type -eq "full" } | Sort-Object BackupDate -Descending

    # --- 2) Règle RGPD : tout backup plus vieux que MaxAgeDays est supprimé, sans exception ---
    foreach ($b in $backups) {
        if ($b.AgeDays -ge $MaxAgeDays) {
            $b.ToDelete = $true
            $b.ForcedRGPD = $true
            $b.Reason = "RGPD: age >= $MaxAgeDays jours"
        }
    }

    # --- 3) Supprimer dif/inc plus anciens que la derniere full (si au moins une full existe) ---
    if ($fullBackups.Count -gt 0) {
        $latestFull = $fullBackups[0]
        foreach ($b in $backups | Where-Object { $_.Type -ne "full" -and $_.ToDelete -eq $false }) {
            if ($b.BackupDate -lt $latestFull.BackupDate) {
                $b.ToDelete = $true
                $b.Reason = "dif/inc plus ancien que la derniere full ($($latestFull.Name))"
            }
        }
    }

    # --- 4) Application des retentions (local vs externalise) ---
    foreach ($b in $backups | Where-Object { $_.ToDelete -eq $false }) {

        $retLimit = if ($b.External) { $retentionDaysExternal } else { $retentionDaysLocal }

        if ($retLimit -gt 0 -and $b.AgeDays -ge $retLimit) {

            if ($b.Type -eq "full") {
                # On marque comme eligible, mais on respectera KeepFull + "au moins 1 full"
                $b.ToDelete = $true
                $b.Reason = "Full agee de $($b.AgeDays) j >= retention ($retLimit j)"
            }
            else {
                # dif/inc : suppression directe
                $b.ToDelete = $true
                $b.Reason = "dif/inc agee de $($b.AgeDays) j >= retention ($retLimit j)"
            }
        }
    }

    # --- 5) Respect de KeepFull (nombre de full à conserver) + au moins UNE full si possible ---

    if ($fullBackups.Count -gt 0) {


        # Full non marquées (déjà conservées pour diverses raisons)
        $fullMarkedKeep = $fullBackups | Where-Object { $_.ToDelete -eq $false }

        # 5.1) Toujours garder au moins la derniere full (si pas RGPD)
        if ($fullMarkedKeep.Count -eq 0) {

            # On tente de recuperer la plus recente parmi celles marquees, sauf si RGPD
            $candidate = $fullBackups |
                         Where-Object { $_.ForcedRGPD -eq $false } |
                         Sort-Object BackupDate -Descending |
                         Select-Object -First 1

            if ($candidate) {
                $candidate.ToDelete = $false
                $candidate.Reason = "Conservee pour garantir au moins une full pour la Policy $policyName"
                Write-PurgeLog "Full '$($candidate.Name)' recuperee de la purge pour assurer au moins une full."
            }
            else {
                Write-PurgeLog "Toutes les fulls de la Policy $policyName sont au-dela du MaxAge RGPD. Aucune full conservee." "WARN"
            }
        }

        # 5.2) Appliquer KeepFull : conserver les N full les plus recentes (hors RGPD)
        $fullSorted = $fullBackups | Sort-Object BackupDate -Descending
        $fullToKeepByPolicy = $fullSorted |
                              Where-Object { $_.ForcedRGPD -eq $false } |
                              Select-Object -First $keepFull

        foreach ($f in $fullToKeepByPolicy) {
            $f.ToDelete = $false
            if (-not $f.Reason) {
                $f.Reason = "Conservee (KeepFull=$keepFull)"
            }
        }

        # Les autres fulls non RGPD peuvent rester marquees a supprimer (si ToDelete = $true).
    }
    else {
        Write-PurgeLog "Aucune full trouvee pour la Policy $policyName. Seules dif/inc sont gerees." "WARN"
    }
}

#endregion APPLICATION DES REGLES PAR POLICY

#region EXECUTION DE LA PURGE

$toDelete = $allBackups | Where-Object { $_.ToDelete -eq $true }
$toKeep   = $allBackups | Where-Object { $_.ToDelete -eq $false }

Write-PurgeLog "Recapitulatif :"
Write-PurgeLog ("  Backups totales : {0}" -f $allBackups.Count)
Write-PurgeLog ("  A conserver      : {0}" -f $toKeep.Count)
Write-PurgeLog ("  A supprimer      : {0}" -f $toDelete.Count)

foreach ($b in $toDelete) {
    if ($DryRun) {
        Write-PurgeLog "[DRY-RUN] Suppression de '$($b.FullPath)' (Policy=$($b.Policy), Type=$($b.Type), Age=$($b.AgeDays) j, Externalise=$($b.External)) - Raison : $($b.Reason)"
    }
    else {
        try {
            Remove-Item -Path $b.FullPath -Recurse -Force -ErrorAction Stop
            Write-PurgeLog "Supprime : '$($b.FullPath)' (Policy=$($b.Policy), Type=$($b.Type), Age=$($b.AgeDays) j, Externalise=$($b.External)) - Raison : $($b.Reason)"
        }
        catch {
            Write-PurgeLog "Erreur lors de la suppression de '$($b.FullPath)' : $($_.Exception.Message)" "ERROR"
        }
    }
}

if ($DryRun) {
    Write-PurgeLog "Purge simulee (DryRun=ON), aucune suppression reelle."
}

Write-PurgeLog "=== Fin purge ==="
exit 0

#endregion EXECUTION DE LA PURGE
