<#
.SYNOPSIS
    Helpers for UI displays

.DESCRIPTION
  Small helpers used by multiple scripts (display, validation).
#>

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

function Select-FromList {
    <#
    .SYNOPSIS
        Menu interactif avec navigation clavier.
    .DESCRIPTION
        Affiche une liste d'options navigable avec les flèches haut/bas.
        Entrée pour sélectionner, Échap pour annuler.
    .PARAMETER Title
        Titre affiché au-dessus du menu.
    .PARAMETER Options
        Tableau de chaînes représentant les choix.
    .EXAMPLE
        $choice = Select-FromList -Title "Choisir un groupe" -Options @("GRP_Compta", "GRP_Juridique", "GRP_RH")
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,

        [Parameter(Mandatory=$true)]
        [string[]]$Options
    )

    if ($Options.Count -eq 0) {
        Write-Host "Aucune option disponible." -ForegroundColor Red
        return $null
    }


    $selectedIndex = 0
    $cursorVisible = [Console]::CursorVisible
    [Console]::CursorVisible = $false

    Write-Host "`n$Title (q pour quitter)" -ForegroundColor Cyan
    Write-Host ("=" * $Title.Length) -ForegroundColor Cyan

    $menuStartPos = $Host.UI.RawUI.CursorPosition

    try {
        while ($true) {
            $Host.UI.RawUI.CursorPosition = $menuStartPos
            for ($i = 0; $i -lt $Options.Count; $i++) {
                $lineContent = if ($i -eq $selectedIndex) {
                    " -> $($Options[$i])"
                    $color = 'DarkGreen'
                } else {
                    "    $($Options[$i])"
                    $color = 'White'
                }
                Write-Host "$lineContent" -ForegroundColor $color
            }
            $key = [Console]::ReadKey($true)

            switch ($key.Key) {
                'UpArrow' {
                    if ($selectedIndex -gt 0) { $selectedIndex-- }
                    else { $selectedIndex = $Options.Count - 1 }
                }
                'DownArrow' {
                    if ($selectedIndex -lt $Options.Count - 1) { $selectedIndex++ }
                    else { $selectedIndex = 0 }
                }
                'Enter' {
                    $endPos = [System.Management.Automation.Host.Coordinates]::new(0, $menuStartPos.Y + $Options.Count)
                    $Host.UI.RawUI.CursorPosition = $endPos
                    Write-Host ""
                    return $Options[$selectedIndex]
                }
                'Escape' {
                    $endPos = [System.Management.Automation.Host.Coordinates]::new(0, $menuStartPos.Y + $Options.Count)
                    $Host.UI.RawUI.CursorPosition = $endPos
                    Write-Host ""
                    return $null
                }
                'q' {
                    $endPos = [System.Management.Automation.Host.Coordinates]::new(0, $menuStartPos.Y + $Options.Count)
                    $Host.UI.RawUI.CursorPosition = $endPos
                    Write-Host ""
                    return 'Quitter'
                }
            }
        }
    }
    finally {
        [Console]::CursorVisible = $cursorVisible
    }
}

