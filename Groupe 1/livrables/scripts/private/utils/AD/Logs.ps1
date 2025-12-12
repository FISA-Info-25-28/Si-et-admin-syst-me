#Requires -Version 5.1
<#
.SYNOPSIS
    Analyzes the state of a domain controller and reports any problems to help with troubleshooting.
.DESCRIPTION
    Analyzes the state of a domain controller and reports any problems to help with troubleshooting.
.EXAMPLE
    (No Parameters)
    Retrieving Directory Server Diagnosis Test Results.
    Passing Tests: CheckSDRefDom, Connectivity, CrossRefValidation, DFSREvent, FrsEvent, Intersite, KccEvent, KnowsOfRoleHolders, MachineAccount, NCSecDesc, NetLogons, ObjectsReplicated, Replications, RidManager, Services, SystemLog, SysVolCheck, VerifyReferences
    [Alert] Failed Tests Detected!
    Failed Tests: Advertising, LocatorCheck
.NOTES
    Minimum OS Architecture Supported: Windows 10, Windows Server 2016
    Release Notes: Initial Release
#>


function Write-DCDiagToEventLog {
    param (
        [string]$TestName,
        [string]$Status,
        [string]$Details
    )

    if (-not $script:EventLogEnabled) { return }

    # Créer la source si elle n'existe pas
    $source = "XanaduScripts"
    $logName = "Application"
    $entryType = if ($Status -match "pass") { "Information" } else { "Warning" }
    $eventId = if ($Status -match "pass") { 1000 } else { 2000 }

    # Définir le type d'événement
    $entryType = if ($Status -match "pass") { "Information" } else { "Warning" }
    $eventId = if ($Status -match "pass") { 1000 } else { 2000 }

    try {
        Write-EventLog -LogName "Application" `
            -Source $source `
            -EventId $eventId `
            -EntryType $entryType `
            -Message "DCDiag Test: $TestName`nStatus: $Status`n`nDetails:`n$Details"
    }
    catch {
        Write-Host "[Warning] Impossible d'écrire dans l'Event Log: $_" -ForegroundColor Yellow
    }
}
