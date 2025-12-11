<#
.SYNOPSIS
    Script d’alerte automatique pour les sauvegardes/restaurations XANADU.

.DESCRIPTION
    Analyse les fichiers de log produits par :
        - backup_file.ps1 (sauvegardes locales)
        - script de restauration éventuel

    Principes :
        - Chaque backup écrit dans :
              C:\Backups\Local\<Policy>\Logs\Backup_<Policy>_<Type>.log
        - La détectection d’erreurs est simple :
            * Lignes contenant [ERROR]
            * Lignes contenant "terminée avec erreurs"
            * Mot-clés "fail", "fatal", "échec", etc.
            * Fichiers de log vides

        - En cas d’erreur :
            → Mail envoyé via Poste.io
            → Log incriminé joint
            → Trace écrite dans Alert.log

.PARAMETER LogsRoot
    Racine où sont stockés les logs des backups.
    Exemple : C:\Backups\Local (chaque Policy possède son dossier).

#>

# =====================================================================
# REGION : PARAMÈTRES
# =====================================================================
param(
    [string]$LogsRoot = "C:\Backups\Local\Logs"
)

# =====================================================================
# REGION : VARIABLES GLOBALES  (à personnaliser)
# =====================================================================

# SMTP interne (poste.io)
$SmtpServer = "192.168.X.X"       # <-- À PERSONNALISER
$SmtpPort   = 587                 # 25 si pas de TLS, 587 recommandé

# Compte utilisé pour envoyer les alertes
$MailFrom   = "sauvegardes@xanadu.local"     # <-- À PERSONNALISER
$MailUser   = "sauvegardes@xanadu.local"     # <-- À PERSONNALISER
$MailPass   = "CHANGE_ME"                    # <-- À PERSONNALISER

# Destinataires des alertes
$MailTo     = @("admin@xanadu.local")        # tableau possible

# Objet et log interne du script d’alerte
$MailSubject = "[XANADU] ALERTE : Erreur dans une sauvegarde/restauration"
$AlertLog    = Join-Path $LogsRoot "Alert.log"

# =====================================================================
# REGION : LOGGING
# =====================================================================

function Write-AlertLog {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $AlertLog -Value $line
}

# =====================================================================
# REGION : EXTRACTION DES MÉTADONNÉES À PARTIR DU CHEMIN DU LOG
# =====================================================================

function Get-BackupMetadataFromLogPath {
    param([string]$LogPath)

    $logName = Split-Path $LogPath -Leaf

    $policy = $null
    $type   = $null

    if ($logName -match '^Backup_([A-Za-z]+)_([a-z]+)(?:_external)?\.log$') {
        $policy = $matches[1]
        $type   = $matches[2]
    }

    return [PSCustomObject]@{
        Policy    = $policy
        Type      = $type
        External  = ($logName -like "*external*")
    }
}


# =====================================================================
# REGION : DETECTION DES ERREURS DANS LES LOGS
# =====================================================================

function Get-LastLogsWithErrors {
    param([string]$Root)

    # Récupère tous les logs de toutes les policies
    $logs = Get-ChildItem -Path $Root -File -Filter "*.log"

    $alerts = @()

    foreach ($log in $logs) {

        # Fichier vide = suspect
        if ((Get-Item $log.FullName).Length -eq 0) {
            $alerts += $log.FullName
            continue
        }

        $content = Get-Content $log.FullName -ErrorAction SilentlyContinue

        # Détection simple mais efficace
        if ($content -match "\[ERROR\]" -or
            $content -match "terminée avec erreurs" -or
            $content -match "fail|fatal|échec|incident") {

            $alerts += $log.FullName
        }
    }

    return $alerts
}

# =====================================================================
# REGION : ENVOI DE MAIL D’ALERTE
# =====================================================================

function Send-ErrorAlert {
    param([string]$LogPath)

    # Extraction des méta-informations
    $meta = Get-BackupMetadataFromLogPath -LogPath $LogPath

    $metaText = @"
Type        : $($meta.Type)
Criticité   : $($meta.Policy)
Externalisé : $($meta.External)
"@

    # Corps du message
    $body = @"
Une erreur a été détectée dans les opérations de sauvegarde/restauration XANADU.

Détails :
$metaText

Fichier concerné :
$LogPath

Résumé des dernières lignes :
$(Get-Content $LogPath | Select-Object -Last 20 | Out-String)

Veuillez consulter le fichier joint pour plus de détails.
"@

    try {
        $securePassword = ConvertTo-SecureString $MailPass -AsPlainText -Force
        $credential     = New-Object System.Management.Automation.PSCredential($MailUser, $securePassword)

        Send-MailMessage `
            -From $MailFrom `
            -To $MailTo `
            -Subject $MailSubject `
            -Body $body `
            -Attachments $LogPath `
            -SmtpServer $SmtpServer `
            -Port $SmtpPort `
            -UseSsl `
            -Credential $credential `
            -ErrorAction Stop

        Write-AlertLog "Alerte envoyee (log : $LogPath)" "INFO"
    }
    catch {
        Write-AlertLog "Echec de l envoi du mail : $($_.Exception.Message)" "ERROR"
    }
}

# =====================================================================
# REGION : EXECUTION PRINCIPALE
# =====================================================================

Write-AlertLog "Analyse des logs dans $LogsRoot"

# Recherche des logs problématiques
$badLogs = Get-LastLogsWithErrors -Root $LogsRoot

if ($badLogs.Count -eq 0) {
    Write-AlertLog "Aucune anomalie detectee." "INFO"
    exit 0
}

Write-AlertLog "$($badLogs.Count) log(s) presentent des anomalies." "WARN"

foreach ($log in $badLogs) {
    Write-AlertLog "Anomalie detectee dans : $log" "WARN"
}

foreach ($log in $badLogs) {
    Send-ErrorAlert -LogPath $log
}

exit 0
