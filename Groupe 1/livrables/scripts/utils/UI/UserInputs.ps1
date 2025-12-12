<#
.Synopsis
    User input utilities for UI interactions.

.DESCRIPTION
    Contains functions to handle user inputs for managing Active Directory users.
#>

function Read-HostWithEscape {
    param([string]$Prompt)

    Write-Host "$Prompt : " -NoNewline
    $input = ""

    while ($true) {
        $key = [Console]::ReadKey($true)

        if ($key.Key -eq 'Escape') {
            Write-Host ""
            return $null
        }
        elseif ($key.Key -eq 'Enter') {
            Write-Host ""
            return $input
        }
        elseif ($key.Key -eq 'Backspace' -and $input.Length -gt 0) {
            $input = $input.Substring(0, $input.Length - 1)
            Write-Host "`b `b" -NoNewline
        }
        elseif ($key.KeyChar -match '[\w\s\-]') {
            $input += $key.KeyChar
            Write-Host $key.KeyChar -NoNewline
        }
    }
}