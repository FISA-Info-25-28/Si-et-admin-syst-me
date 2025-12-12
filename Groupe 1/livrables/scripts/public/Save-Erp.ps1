function Save-Erp {
    <#
    .SYNOPSIS
        Sauvegarde et vérifie la base SQLite de XanaduERP sur le NAS.
    .PARAMETER Mode
        All    : (par défaut) sauvegarde puis vérifie la dernière sauvegarde.
        Save   : uniquement la sauvegarde.
        Verify : uniquement la vérification de la dernière sauvegarde.
    .NOTES
        Auteur : Vincent CAUSSE
    #>
    [CmdletBinding(DefaultParameterSetName='Encode')]
     param(
        [Parameter()]
        [ValidateSet("All", "Save", "Verify")]
        [string]$Mode = "All"
    )

    begin {
        # CONFIG
        $script:DbPath  = "C:\inetpub\wwwroot\XanaudERPBack\cmd\xanadu.db"
        $script:NasRoot = "\\192.168.1.98\Partage\commun\backups_sqlite"

        function Write-Info($msg) {
            Write-Host "[INFO] $msg"
        }

        function Write-ErrorMsg($msg) {
            Write-Host "[ERROR] $msg" -ForegroundColor Red
        }

        function Save-Database {
            if (-not (Test-Path $script:DbPath)) {
                Write-ErrorMsg "Base SQLite introuvable : $($script:DbPath)"
                return
            }
            if (-not (Test-Path $script:NasRoot)) {
                Write-ErrorMsg "Dossier NAS inexistant : $($script:NasRoot)"
                return
            }

            $srcObj   = Get-Item $script:DbPath
            $src      = $srcObj.FullName
            $ts       = Get-Date -Format "yyyy-MM-dd_HH-mm"
            $destFile = Join-Path $script:NasRoot "xanadu_$ts.db"

            Write-Info "Copie de '$src' vers '$destFile'..."
            Copy-Item -LiteralPath $src -Destination $destFile -Force
            Write-Info "Sauvegarde terminée."

            # Rotation 30 jours
            Get-ChildItem $script:NasRoot -Filter "xanadu_*.db" |
                Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
                ForEach-Object {
                    Write-Info "Suppression ancienne sauvegarde : $($_.FullName)"
                    Remove-Item $_.FullName -Force
                }
        }

        function Verify-LastBackup {
            if (-not (Test-Path $script:NasRoot)) {
                Write-ErrorMsg "Dossier de sauvegarde NAS inexistant : $($script:NasRoot)"
                return
            }

            $last = Get-ChildItem $script:NasRoot -Filter "xanadu_*.db" |
                    Sort-Object LastWriteTime -Descending |
                    Select-Object -First 1

            if (-not $last) {
                Write-ErrorMsg "Aucune sauvegarde trouvée dans $($script:NasRoot)."
                return
            }

            Write-Info "Dernière sauvegarde : $($last.FullName)"
            Write-Info ("Taille : {0:N0} octets" -f $last.Length)
            Write-Info ("Date  : {0}" -f $last.LastWriteTime)
        }
    }

    process {
        switch ($Mode) {
            "Save"   { Save-Database }
            "Verify" { Verify-LastBackup }
            "All"    { Save-Database; Verify-LastBackup }
        }
    }
}