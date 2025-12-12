#Requires -Version 5.1

<#
.SYNOPSIS
    Analyzes the state of a domain controller and reports any problems to help with troubleshooting.
.DESCRIPTION
    Analyzes the state of a domain controller and reports any problems to help with troubleshooting. Optionally, set a WYSIWYG custom field.
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

function Initialize-EventLogSource {
    $source = "XanaduScripts"
    $logName = "Application"

    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($source)) {
            [System.Diagnostics.EventLog]::CreateEventSource($source, $logName)
            Write-Host "Source '$source' créée dans le journal '$logName'." -ForegroundColor Green
            # Attendre un peu que Windows enregistre la source
            Start-Sleep -Seconds 2
        }
    }
    catch {
        Write-Host "[Warning] Impossible de créer la source Event Log: $_" -ForegroundColor Yellow
        Write-Host "Exécutez une fois en tant qu'Administrateur pour créer la source." -ForegroundColor Yellow
        return $false
    }
    return $true
}

function Get-DCDiagResults {
    param (
        [string]$Mode
    )

    $results = @()

    $ADTests = @(
        "Replications",        # Réplication AD
        "ObjectsReplicated",   # Objets répliqués
        "NCSecDesc",           # Permissions partitions AD
        "KnowsOfRoleHolders",  # Rôles FSMO
        "VerifyReferences",    # Intégrité références AD
        "CrossRefValidation",  # Cross-references
        "CheckSDRefDom",       # Security Descriptors
        "MachineAccount",      # Compte machine AD
        "RidManager",          # Pool RID
        "Intersite",           # Réplication inter-sites
        "KccEvent"             # Topologie réplication
    )
    $DCTests = @(
        "Connectivity",      # Connectivité réseau
        "Advertising",       # Annonces DNS
        "Services",          # Services Windows
        "NetLogons",         # Service Netlogon
        "SysVolCheck",       # Partage SYSVOL
        "FrsEvent",          # Réplication SYSVOL (FRS)
        "DFSREvent",         # Réplication SYSVOL (DFS-R)
        "SystemLog",         # Erreurs système
        "LocatorCheck"       # Localisation DC
    )
    $DCDiagTestsToRun = switch ($Mode) {
        "DC"  { $DCTests }
        "AD"  { $ADTests }
        "All" { $DCTests + $ADTests }
    }
    foreach ($DCTest in $DCDiagTestsToRun) {
        $outputFile = "$env:TEMP\dc-diag-$DCTest.txt"
        $DCDiag = Start-Process -FilePath "DCDiag.exe" -ArgumentList "/test:$DCTest", "/f:$outputFile" -PassThru -Wait -NoNewWindow

        if ($DCDiag.ExitCode -ne 0) {
            Write-Host "[Error] Running $DCTest!" -ForegroundColor Red
            continue
        }

        $RawContent = Get-Content -Path $outputFile -Raw -ErrorAction SilentlyContinue
        $RawLines = Get-Content -Path $outputFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim() }

        # Joindre tout en une chaîne pour le parsing (gère les retours à la ligne)
        $FullText = $RawContent -replace "`r`n", " " -replace "`n", " "

        $Status = "Unknown"
        
        if ($FullText -match "Le test $DCTest.+a réussi" -or $FullText -match "passed test $DCTest") {
            $Status = "Passed"
        }
        elseif ($FullText -match "Le test $DCTest.+a échoué" -or $FullText -match "failed test $DCTest") {
            $Status = "Failed"
        }

        $results += [PSCustomObject]@{
            Test   = $DCTest
            Status = $Status
            Result = $RawResult
        }
    }
    return $results
}

function Verify-DCIntegrity {
    <#
    .SYNOPSIS
        Point d'entrée principal du script.
    .EXAMPLE
        Verify-DCIntegrity -Mode "All"
        Exécute tous les tests DCDiag.
    .EXAMPLE
        Verify-DCIntegrity -Mode "DC"
        Exécute uniquement les tests liés au contrôleur de domaine.
    .EXAMPLE
        Verify-DCIntegrity -Mode "AD"
        Exécute uniquement les tests liés à Active Directory.
    .PARAMETER Mode
        Spécifie le mode des tests à exécuter. Valeurs possibles : "All", "DC", "AD". Par défaut : "All".
    .NOTES
        Auteur : Vincent CAUSSE
    #>
    [CmdletBinding(DefaultParameterSetName='Encode')]
    param (
        [Parameter()]
        [ValidateSet("All", "DC", "AD")]
        [string]$Mode = "All"
    )

    begin {
        $script:EventLogEnabled = Initialize-EventLogSource

        function Test-IsDomainController {
            $OS = if ($PSVersionTable.PSVersion.Major -lt 5) {
                Get-WmiObject -Class Win32_OperatingSystem
            }
            else {
                Get-CimInstance -ClassName Win32_OperatingSystem
            }

            if ($OS.ProductType -eq "2") {
                return $true
            }
        }
    }
    process {
        if (!(Test-IsDomainController)) {
            Write-Host "[Error] Ce script doit être exécuté sur un Domain Controller." -ForegroundColor Red
            return
        }

        # Exécuter les tests
        Write-Host "`nExécution des tests DCDiag (Mode: $Mode)..." -ForegroundColor Cyan
        $TestResults = Get-DCDiagResults -Mode $mode


        # Trier les résultats
        $PassingTests = $TestResults | Where-Object { $_.Status -match "pass" }
        $FailedTests = $TestResults | Where-Object { $_.Status -match "fail" }

        # Afficher les résultats
        Write-Host "`n=== RÉSULTATS ===" -ForegroundColor Cyan

        if ($PassingTests) {
            Write-Host "`n[OK] Tests réussis ($($PassingTests.Count)):" -ForegroundColor Green
            Write-Host ($PassingTests.Test -join ", ")
        }

        if ($FailedTests) {
            Write-Host "`n[ERREUR] Tests échoués ($($FailedTests.Count)):" -ForegroundColor Red
            Write-Host ($FailedTests.Test -join ", ")

            Write-Host "`n--- Détails des erreurs ---" -ForegroundColor Yellow
            foreach ($test in $FailedTests) {
                Write-Host "`n>> $($test.Test)" -ForegroundColor Red
                Write-Host ($test.Result | Out-String)

                Write-DCDiagToEventLog -TestName $test.Test `
                    -Status $test.Status `
                    -Details ($test.Result | Out-String)
            }
        }
        else {
            Write-Host "`nTous les tests sont passés !" -ForegroundColor Green
        }

        $summaryMessage = @"
            DCDiag Verification Complete (Mode: $Mode)
            Passed: $($PassingTests.Count)
            Failed: $($FailedTests.Count)
            Failed Tests: $($FailedTests.Test -join ', ')
"@

        $summaryType = if ($FailedTests.Count -eq 0) { "Information" } else { "Error" }
        Write-EventLog -LogName "Application" -Source "XanaduScripts" -EventId 3000 -EntryType $summaryType -Message $summaryMessage

        # Retourner les résultats pour usage ultérieur
        return [PSCustomObject]@{
            Mode        = $Mode
            Passed      = $PassingTests
            Failed      = $FailedTests
            TotalPassed = $PassingTests.Count
            TotalFailed = $FailedTests.Count
        }
    }

}