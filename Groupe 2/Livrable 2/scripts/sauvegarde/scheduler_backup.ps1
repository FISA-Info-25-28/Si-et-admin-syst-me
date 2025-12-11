<#
.SYNOPSIS
    Gestion des tâches planifiées pour l'exécution automatique de backup_file.ps1
    dans le contexte XANADU.

.DESCRIPTION
    Ce script permet :
      - de créer ou recréer une tâche planifiée Windows pour le script de sauvegarde,
      - d'utiliser une expression CRON-like simple (M H DOM MON DOW),
      - de fonctionner en mode interactif si aucun paramètre n'est fourni,
      - de lister, supprimer ou modifier les tâches XANADU existantes.

    Fonctionnalités principales :
      - Création d'une tâche planifiée avec appel à backup_file.ps1
      - Passage des paramètres -Type et -IncludesFile au script de backup
      - Logs détaillés dans un fichier Scheduler.log
      - Gestion d'un préfixe standard pour toutes les tâches : "XANADU_"
      - Mode liste (-List) permettant :
            * d'afficher toutes les tâches XANADU_*
            * de supprimer une tâche
            * de modifier son CRON (via recréation de la tâche)

.PARAMETER Cron
    Expression CRON-like : "M H DOM MON DOW"
    Exemple : "*/30 * * * *" → toutes les 30 minutes
              "0 1 * * *"   → tous les jours à 01:00

.PARAMETER Type
    Type de sauvegarde : full / dif / inc

.PARAMETER Includes
    Chemin du fichier includes.txt utilisé par backup_file.ps1

.PARAMETER Policy
    Criticité de la sauvegarde : détermine le dossier d’écriture et la rétention.
    Valeurs possibles :
        - Critical
        - Important
        - Standard (par défaut)
        - Logs

.PARAMETER TaskName
    Nom logique de la tâche (sans le préfixe XANADU_).
    Exemple : "backup_file" → tâche réelle "XANADU_backup_file"

.PARAMETER List
    Si présent, affiche la liste des tâches XANADU_* et permet
    de les supprimer ou modifier.

.EXAMPLE
    # Création d'une tâche planifiée incrémentielle toutes les 30 minutes
    .\Scheduler.ps1 -Cron "*/30 * * * *" -Type inc -Includes "C:\Scripts\includes.txt" -TaskName "backup_file"

.EXAMPLE
    # Mode interactif (type, includes, cron saisis à la main)
    .\Scheduler.ps1

.EXAMPLE
    # Lister les tâches XANADU, avec options de suppression / modification
    .\Scheduler.ps1 -List

.NOTES
    - Nécessite le module ScheduledTasks (Windows Server 2012+ / PowerShell 5.1+).
    - Les logs sont écrits en UTF-8 dans Scheduler.log.
#>

param(
    [string]$Cron = $null,
    [ValidateSet("full", "dif", "inc", "")]
    [string]$Type = $null,
    [string]$Includes = $null,

    [ValidateSet("Critical", "Important", "Standard", "")]
    [string]$Policy = "Standard",

    [string]$TaskName = "backup_file",
    [switch]$List
)

#region VARIABLES GLOBALES

# À adapter
$BackupScriptPath   = "C:\Users\Administrateur\Documents\script\backup_file.ps1"
$DefaultBackupType  = "full"
$DefaultIncludesFile = "C:\Users\Administrateur\Documents\script\includes.txt"
$Prefix = "XANADU_"

# Log du scheduler

# Création du dossiers si nécessaires
$LogRoot = "C:\Backups\Local\Logs"
if (-not (Test-Path $LogRoot)) {
    New-Item -Path $LogRoot -ItemType Directory -Force | Out-Null
}
$SchedulerLog = "C:\Backups\Local\Logs\Scheduler.log"
#endregion VARIABLES GLOBALES

#region LOGGING

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO","WARN","ERROR")]
        [string]$Level = "INFO"
    )

    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $SchedulerLog -Value $line
}

Write-Log "---- Execution Scheduler.ps1 ----"

#endregion LOGGING

#region FONCTIONS UTILITAIRES

function Get-FullTaskName {
    param(
        [string]$LogicalName
    )

    return "${Prefix}$LogicalName"
}

function Test-BackupScriptPath {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Log "Script de sauvegarde introuvable : $Path" "ERROR"
        throw "Le chemin $Path est invalide."
    }
}

function Test-IncludesPath {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Log "Fichier includes introuvable : $Path" "ERROR"
        throw "Le fichier includes.txt est introuvable : $Path"
    }
}

#endregion FONCTIONS UTILITAIRES

#region FONCTIONS CRON
function Test-IsNumericCronField {
    param([string]$Value)

    return ($Value -match '^\d+$')
}

function Test-IsWildcard {
    param([string]$Value)

    return ($Value -eq "*")
}

function Test-IsRange {
    param([string]$Value)

    return ($Value -match '^\d+-\d+$')
}

function Test-IsStep {
    param([string]$Value)

    return ($Value -match '^\*/\d+$')
}

function New-DailyTriggerFromHourMinute {
    param([string]$Hour, [string]$Minute)

    Write-Log "Creation trigger quotidien : ${Hour}:${Minute}"
    return New-ScheduledTaskTrigger -Daily -At "${Hour}:${Minute}"
}

function New-WeeklyTrigger {
    param(
        [string[]]$Days,
        [string]$Hour,
        [string]$Minute
    )

    Write-Log "Creation trigger hebdomadaire : jours=($($Days -join ',')) a ${Hour}:${Minute}"

    return New-ScheduledTaskTrigger -Weekly -DaysOfWeek $Days -At "${Hour}:${Minute}"
}

function New-MonthlyTrigger {
    param(
        [int[]]$Days,
        [string]$Hour,
        [string]$Minute
    )

    Write-Log "Creation trigger mensuel : jours=($($Days -join ',')) a ${Hour}:${Minute}"

    return New-ScheduledTaskTrigger -Monthly -DaysOfMonth $Days -At "${Hour}:${Minute}"
}

function Convert-CronToTrigger {
    param([Parameter(Mandatory=$true)] $CronFields)

    $minute = $CronFields.Minute
    $hour   = $CronFields.Hour
    $dom    = $CronFields.DOM
    $dow    = $CronFields.DOW

    # --------------------------------------------------------
    # Cas 1 : Toutes les X minutes → */X
    # --------------------------------------------------------
    if (Test-IsStep $minute) {
        $interval = [int]($minute -replace '^\*/', '')
        Write-Log "Trigger repetitif toutes les $interval minutes"

        return New-ScheduledTaskTrigger `
            -Once `
            -At (Get-Date).Date `
            -RepetitionInterval (New-TimeSpan -Minutes $interval) `
            -RepetitionDuration (New-TimeSpan -Days 30)
    }

    # --------------------------------------------------------
    # Cas 2 : Hebdomadaire → DOW pas égal à *
    # Exemple : 0 3 * * 3 → mercredi à 03:00
    # --------------------------------------------------------
    if (-not (Test-IsWildcard $dow)) {

        $dowList = @()

        foreach ($d in $dow -split ",") {
            switch ($d) {
                "0" { $dowList += "Sunday" }
                "1" { $dowList += "Monday" }
                "2" { $dowList += "Tuesday" }
                "3" { $dowList += "Wednesday" }
                "4" { $dowList += "Thursday" }
                "5" { $dowList += "Friday" }
                "6" { $dowList += "Saturday" }
                default { throw "Jour de semaine non valide : $d" }
            }
        }

        return New-WeeklyTrigger -Days $dowList -Hour $hour -Minute $minute
    }

    # --------------------------------------------------------
    # Cas 3 : Mensuel → DOM pas égal à *
    # Exemple : 0 2 1 * * → tous les 1ers du mois à 02:00
    # --------------------------------------------------------
    if (-not (Test-IsWildcard $dom)) {

        $domList = @()

        foreach ($d in $dom -split ",") {
            if (-not (Test-IsNumericCronField $d)) {
                throw "Jour du mois non valide : $d"
            }
            $domList += [int]$d
        }

        return New-MonthlyTrigger -Days $domList -Hour $hour -Minute $minute
    }

    # --------------------------------------------------------
    # Cas 4 : Fallback → exécution quotidienne à l’heure donnée
    # --------------------------------------------------------
    return New-DailyTriggerFromHourMinute -Hour $hour -Minute $minute
}
function Convert-CronExpression {
    param([string]$CronExpression)

    $parts = $CronExpression.Split(" ")

    if ($parts.Count -ne 5) {
        Write-Log "Expression CRON invalide : $CronExpression" "ERROR"
        throw "Format CRON invalide (attendu : M H DOM MON DOW)"
    }

    return [PSCustomObject]@{
        Minute = $parts[0]
        Hour   = $parts[1]
        DOM    = $parts[2]
        Month  = $parts[3]
        DOW    = $parts[4]
    }
}

#endregion FONCTIONS CRON

#region FONCTIONS DE TÂCHE PLANIFIÉES

function New-BackupAction {
    param(
        [string]$BackupScript,
        [string]$Type,
        [string]$Includes,
        [string]$Policy
    )

    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$BackupScript`" -Type $Type -IncludesFile `"$Includes`" -Policy $Policy"
    Write-Log "Action generee : $BackupScript avec Type=$Type et Includes=$Includes et Policy=$Policy"

    return New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments
}

function Register-BackupTask {
    param(
        [string]$TaskName,
        [Microsoft.Management.Infrastructure.CimInstance]$Trigger,
        [Microsoft.Management.Infrastructure.CimInstance]$Action
    )

    try {
        $existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Log "Tache existante trouvee : $TaskName, suppression en cours."
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop
            Write-Log "Tache existante supprimee."
        }
    }
    catch {
        Write-Log "Impossible de verifier/supprimer l'ancienne tache : $($_.Exception.Message)" "WARN"
    }

    try {
        Register-ScheduledTask -TaskName $TaskName -Trigger $Trigger -Action $Action -RunLevel Highest -ErrorAction Stop
        Write-Log "Tache planifiee creee avec succes : $TaskName"
        Write-Host "Tache planifiee creee avec succes : $TaskName" -ForegroundColor Green
    }
    catch {
        Write-Log "Erreur lors de la creation de la tache : $($_.Exception.Message)" "ERROR"
        throw "Echec de creation de la tache planifiee."
    }
}

function Get-XanaduTasks {
    return Get-ScheduledTask | Where-Object { $_.TaskName -like "$Prefix*" }
}

function Show-XanaduTasksAndManage {
    $tasks = Get-XanaduTasks

    if (-not $tasks) {
        Write-Host "Aucune tache planifiee associee au systeme XANADU."
        return
    }

    Write-Host "`n=== TACHES PLANIFIEES XANADU ===`n"

    $indexed = @()
    $i = 1

    foreach ($t in $tasks) {
        $info = Get-ScheduledTaskInfo -TaskName $t.TaskName

        $indexed += [PSCustomObject]@{
            Index   = $i
            Name    = $t.TaskName
            NextRun = $info.NextRunTime
            LastRun = $info.LastRunTime
            State   = $info.State
        }

        Write-Host "[$i] $($t.TaskName)"
        Write-Host "    Next Run : $($info.NextRunTime)"
        Write-Host "    Last Run : $($info.LastRunTime)"
        Write-Host "    State    : $($info.State)"
        Write-Host "--------------------------------"
        $i++
    }

    Write-Host ""
    Write-Host "Choisir une action : D = Delete une tache, M = Modify CRON, Q = Quitter"
    $action = Read-Host "Action"

    switch ($action.ToUpper()) {

        "D" {
            $idx = Read-Host "Numero de la tache a supprimer"

            if ($idx -notmatch '^\d+$' -or $idx -lt 1 -or $idx -gt $indexed.Count) {
                Write-Host "Index invalide." -ForegroundColor Red
                return
            }

            $taskToDelete = $indexed[$idx - 1].Name

            Write-Host "Suppression de : $taskToDelete..."
            try {
                Unregister-ScheduledTask -TaskName $taskToDelete -Confirm:$false -ErrorAction Stop
                Write-Host "Tache supprimee."
                Write-Log "Tache supprimee via -List : $taskToDelete"
            }
            catch {
                Write-Host "Erreur lors de la suppression." -ForegroundColor Red
                Write-Log "Erreur suppression : $($_.Exception.Message)" "ERROR"
            }
        }

        "M" {
            $idx = Read-Host "Numero de la tache a modifier"

            if ($idx -notmatch '^\d+$' -or $idx -lt 1 -or $idx -gt $indexed.Count) {
                Write-Host "Index invalide." -ForegroundColor Red
                return
            }

            $taskToMod = $indexed[$idx - 1].Name
            $logicalName = $taskToMod -replace "^$Prefix",""

            Write-Host "Modification de la tache : $taskToMod"

            $newCron = Read-Host "Nouvelle expression CRON (ex: */20 * * * *)"
            if (-not $newCron) {
                Write-Host "Aucun CRON donne. Annulation."
                return
            }

            # Relance du scheduler avec nouveau CRON (Type et Includes par défaut)
            & $PSCommandPath -Cron $newCron `
                 -Type $DefaultBackupType `
                 -Includes $DefaultIncludesFile `
                 -TaskName $logicalName
        }

        "Q" {
            Write-Host "Quitter."
        }

        default {
            Write-Host "Action inconnue." -ForegroundColor Red
        }
    }
}

#endregion FONCTIONS DE TÂCHE PLANIFIÉES

#region MAIN

# Mode LIST uniquement
if ($List) {
    Show-XanaduTasksAndManage
    exit 0
}

# Determination du nom complet de la tache
$FullTaskName = Get-FullTaskName -LogicalName $TaskName

# Mode interactif si aucun parametre fourni
$Interactive = $false
if (-not $Cron -and -not $Type -and -not $Includes) {
    $Interactive = $true
    Write-Log "Passage en mode interactif."
}

if ($Interactive) {
    Write-Host ""
    Write-Host "=== CONFIGURATION DE LA TACHE PLANIFIEE ===" -ForegroundColor Cyan
    Write-Host ""

    # Type
    $Type = Read-Host "Type de sauvegarde (full/dif/inc) [default: $DefaultBackupType]"
    if (-not $Type) { $Type = $DefaultBackupType }

    # Includes
    $Includes = Read-Host "Chemin fichier includes.txt [default: $DefaultIncludesFile]"
    if (-not $Includes) { $Includes = $DefaultIncludesFile }

    # Policy
    $Policy = Read-Host "Criticite (Critical/Important/Standard) [default: Standard]"
    if (-not $Policy) { $Policy = "Standard" }

    # Name
    $defaultName = Get-FullTaskName -LogicalName "${Policy}_${Type}"
    $FullTaskName = Read-Host "Nom complet de la tache planifiee [default: $defaultName]"
    if (-not $FullTaskName) { 
        $FullTaskName = $defaultName
    }
    else {
        $FullTaskName = Get-FullTaskName -LogicalName $FullTaskName
    }

    # Cron
    Write-Host ""
    Write-Host "Saisir une expression CRON-like (ex : */30 * * * *)"
    $Cron = Read-Host "Expression CRON"

    if (-not $Cron) {
        Write-Host "Aucune expression CRON fournie. Annulation." -ForegroundColor Yellow
        Write-Log  "Aucune expression CRON fournie. Sortie du scheduler."
        exit 0
    }

    Write-Log "Mode interactif : Type=$Type ; Includes=$Includes ; Cron=$Cron"
}

try {
    Test-BackupScriptPath -Path $BackupScriptPath
    Test-IncludesPath     -Path $Includes

    $cronFields = Convert-CronExpression -CronExpression $Cron
    $trigger    = Convert-CronToTrigger -CronFields $cronFields
    $action     = New-BackupAction -BackupScript $BackupScriptPath -Type $Type -Includes $Includes -Policy $Policy

    Register-BackupTask -TaskName $FullTaskName -Trigger $trigger -Action $action
}
catch {
    Write-Log "Erreur dans le scheduler : $($_.Exception.Message)" "ERROR"
    Write-Error $_.Exception.Message
    exit 1
}

#endregion MAIN

exit 0
