<#
.SYNOPSIS
    Externalisation des sauvegardes locales XANADU vers le site distant (SFTP).

.DESCRIPTION
    - Parcourt le répertoire de sauvegarde local (C:\Backups\Local par défaut)
    - Détecte les dossiers de sauvegarde (full_*, dif_*, inc_*)
    - Ne transfère QUE les sauvegardes non encore externalisées (via external_state.json)
    - Envoie les dossiers par SFTP vers le site distant (WinSCP .NET)
    - Log détaillé dans Logs\Externalize.log
    - Codes de retour :
        0 = OK
        1 = Erreur de configuration (chemin, DLL WinSCP, etc.)
        2 = Aucune sauvegarde à externaliser
        3 = Erreur de connexion SFTP
        4 = Erreur de transfert

.PARAMETER Type
    Type de sauvegarde à externaliser : full, dif, inc ou all (par défaut : all).

.PARAMETER BackupRoot
    Racine des sauvegardes locales (par défaut : C:\Backups\Local).

.PARAMETER DryRun
    Si présent, aucune donnée n’est réellement transférée.
    Le script indique seulement ce qu’il ferait.
#>

#region PARAMETERS
param(
    [ValidateSet("full","dif","inc","all")]
    [string]$Type = "all",

    [string]$BackupRoot = "C:\Backups\Local",

    [switch]$DryRun
)
#endregion PARAMETERS

#region CONFIGURATION SFTP (À ADAPTER)
# ► À personnaliser quand tu auras les infos de l’expert réseau

# Hôte SFTP du site distant (Springfield ou Atlantis selon le sens)
$SftpHost   = "10.0.0.10"          # TODO : IP/nom du serveur SFTP distant
$SftpPort   = 22                   # En général 22
$SftpUser   = "svc_backup"         # Compte de service SFTP
$SftpPass   = "ChangeMe!"          # OU bien utilise un coffre-fort + SecureString
$RemoteBase = "C:\Backups\External"    # Répertoire racine distant

# Chemin vers la DLL WinSCP .NET (à adapter selon installation)
$WinScpDllPath = "C:\Program Files (x86)\WinSCP\WinSCPnet.dll"
#endregion CONFIGURATION SFTP

#region GLOBALS / LOGGING

# Dossier Logs
$LogRoot = Join-Path $BackupRoot "Logs"
if (-not (Test-Path $LogRoot)) {
    New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogRoot "Externalize.log"

# ID court pour tracer une exécution
function New-ShortID {
    $chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    -join ((1..6) | ForEach-Object { $chars[(Get-Random -Minimum 0 -Maximum $chars.Length)] })
}
$RunID = New-ShortID

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    $line = "[{0} - {1}] [{2}] {3}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $RunID, $Level, $Message
    Add-Content -Path $LogFile -Value $line
}

Write-Log "=== Demarrage externalisation (Type=$Type, DryRun=$DryRun) ==="

#endregion GLOBALS / LOGGING

#region VÉRIFICATIONS PRÉALABLES

# 1) Vérifier la racine des sauvegardes
if (-not (Test-Path $BackupRoot)) {
    Write-Log "Repertoire de sauvegarde introuvable : $BackupRoot" "ERROR"
    exit 1
}

# 2) Charger la DLL WinSCP
if (-not (Test-Path $WinScpDllPath)) {
    Write-Log "DLL WinSCP introuvable : $WinScpDllPath. Installer WinSCP ou corriger le chemin." "ERROR"
    exit 1
}

try {
    Add-Type -Path $WinScpDllPath -ErrorAction Stop
    Write-Log "DLL WinSCP chargee avec succes."
}
catch {
    Write-Log "Erreur lors du chargement de la DLL WinSCP : $($_.Exception.Message)" "ERROR"
    exit 1
}

# 3) Fichier d’état des externalisations
$StateFile = Join-Path $BackupRoot "external_state.json"

$state = @{
    SentBackups = @{}   # clé = Nom du dossier, valeur = objet (FirstSent, LastSent, LastStatus)
}

if (Test-Path $StateFile) {
    try {
        $json = Get-Content -Path $StateFile -Raw
        if ($json.Trim().Length -gt 0) {
            $loaded = $json | ConvertFrom-Json
            if ($loaded.SentBackups) {
                $state.SentBackups = $loaded.SentBackups.PSObject.Copy()
            }
        }
        Write-Log "Etat d'externalisation charge depuis $StateFile"
    }
    catch {
        Write-Log "Impossible de lire $StateFile, un nouvel etat sera recree." "WARN"
    }
}

#endregion VÉRIFICATIONS PRÉALABLES

#region DÉTECTION DES BACKUPS À ENVOYER

# Récupération de tous les dossiers de backup
$allBackups = Get-ChildItem -Path $BackupRoot -Directory |
    Where-Object { $_.Name -match "^(full|dif|inc)_" }

if ($Type -ne "all") {
    $prefix = "$Type`_"
    $allBackups = $allBackups | Where-Object { $_.Name.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) }
}

if (-not $allBackups -or $allBackups.Count -eq 0) {
    Write-Log "Aucune sauvegarde locale trouvee pour le type '$Type'." "WARN"
    exit 2
}

# Filtrer celles déjà envoyées
$pendingBackups = @()
foreach ($b in $allBackups) {
    if (-not $state.SentBackups.ContainsKey($b.Name)) {
        $pendingBackups += $b
    }
}

if ($pendingBackups.Count -eq 0) {
    Write-Log "Toutes les sauvegardes du type '$Type' ont deja ete externalisees. Rien a faire."
    exit 2
}

Write-Log ("Sauvegardes a externaliser : {0}" -f (($pendingBackups | Select-Object -ExpandProperty Name) -join ", "))

#endregion DÉTECTION DES BACKUPS À ENVOYER

#region SESSION SFTP

# Si DryRun : on ne se connecte pas, on simule
if ($DryRun) {
    Write-Log "Mode DryRun active : aucune connexion SFTP, aucune donnee transferee."
}
else {
    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol   = [WinSCP.Protocol]::Sftp
        HostName   = $SftpHost
        PortNumber = $SftpPort
        UserName   = $SftpUser
        Password   = $SftpPass
        # TODO : sécuriser le fingerprint réel du serveur SFTP
        SshHostKeyPolicy = [WinSCP.SshHostKeyPolicy]::GiveUp
    }

    $session = New-Object WinSCP.Session
    # Log WinSCP détaillé séparé si tu veux
    $session.SessionLogPath = Join-Path $LogRoot "Externalize_WinSCP.log"

    try {
        $session.Open($sessionOptions)
        Write-Log "Connexion SFTP ouverte vers ${SftpHost}:${SftpPort}."
    }
    catch {
        Write-Log "Erreur lors de l'ouverture de la session SFTP : $($_.Exception.Message)" "ERROR"
        exit 3
    }
}

#endregion SESSION SFTP

#region TRANSFERTS

$transferErrors = 0

foreach ($backup in $pendingBackups) {

    Write-Log "Traitement de la sauvegarde '$($backup.Name)'"

    $localPath  = $backup.FullName

    # Ajout du suffixe _external pour identifier les backups externalises
    $remoteName = "${($backup.Name)}_external"
    Write-Log "Nom distant de la sauvegarde : $remoteName (suffixe _external ajoute)"

    $remotePath = "${RemoteBase}/${remoteName}"

    if ($DryRun) {
        Write-Log "DryRun : [SIMULATION] Creation du dossier distant '$remotePath' et transfert de '$localPath\*'."
        continue
    }

    try {
        # Creer le dossier distant
        Write-Log "Creation du repertoire distant : $remotePath"
        $session.CreateDirectory($remotePath)

        # Options de transfert
        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary

        # Transfert recursif
        Write-Log "Debut du transfert de '$localPath\*' vers '$remotePath'."
        $result = $session.PutFiles("$localPath\*", $remotePath, $false, $transferOptions)

        

        if (-not $result.IsSuccess) {
            Write-Log "Echec du transfert de '$($backup.Name)'. Details :" "ERROR"
            foreach ($e in $result.Failures) {
                Write-Log (" - {0} -> {1} : {2}" -f $e.FileName, $e.Destination, $e.Message) "ERROR"
            }
            $transferErrors++
            $state.SentBackups[$backup.Name] = [PSCustomObject]@{
                FirstSent   = $null
                LastSent    = Get-Date
                LastStatus  = "FAILED"
                RemotePath  = $remotePath
            }
        }
        else {
            Write-Log "Transfert reussi pour '$($backup.Name)'."
            $now = Get-Date
            if ($state.SentBackups.ContainsKey($backup.Name) -and $state.SentBackups[$backup.Name].FirstSent) {
                $first = $state.SentBackups[$backup.Name].FirstSent
            }
            else {
                $first = $now
            }

            $state.SentBackups[$backup.Name] = [PSCustomObject]@{
                FirstSent   = $first
                LastSent    = $now
                LastStatus  = "SUCCESS"
                RemotePath  = $remotePath
            }
        }
    }
    catch {
        Write-Log "Exception lors du transfert de '$($backup.Name)' : $($_.Exception.Message)" "ERROR"
        $transferErrors++
    }
}

# Fermer la session SFTP si utilisée
if (-not $DryRun -and $session) {
    $session.Dispose()
    Write-Log "Session SFTP fermee."
}

#endregion TRANSFERTS

#region SAUVEGARDE DE L’ÉTAT

try {
    $state | ConvertTo-Json -Depth 5 | Set-Content -Path $StateFile -Encoding UTF8
    Write-Log "Etat d'externalisation mis a jour dans $StateFile."
}
catch {
    Write-Log "Erreur lors de l'ecriture du fichier d'etat $StateFile : $($_.Exception.Message)" "ERROR"
}

#endregion SAUVEGARDE DE L’ÉTAT

#region FIN

if ($DryRun) {
    Write-Log "Externalisation simulee (DryRun), aucune erreur de transfert reelle."
    Write-Log "=== Fin externalisation (DryRun) ==="
    exit 0
}

if ($transferErrors -gt 0) {
    Write-Log "Externalisation terminee avec $transferErrors erreur(s) de transfert." "WARN"
    Write-Log "=== Fin externalisation (avec erreurs) ==="
    exit 4
}
else {
    Write-Log "Externalisation terminee avec succes, aucune erreur de transfert."
    Write-Log "=== Fin externalisation (OK) ==="
    exit 0
}

#endregion FIN