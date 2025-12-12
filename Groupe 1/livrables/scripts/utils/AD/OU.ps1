<#
.SYNOPSIS
  Helpers for AD scripts.

.DESCRIPTION
  Small helpers used by multiple scripts (display, validation).
#>

function Show-ADGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object[]] $InputObjects
    )

    process {
        Write-Host "`n=== Groupes AD disponibles ===" -ForegroundColor Cyan
        foreach ($obj in $InputObjects) {
            if ($null -eq $obj) { continue }

            if ($obj -is [psobject] -and $obj.PSObject.Properties['Name']) {
                $name = $obj.Name
            }
            elseif ($obj -is [string]) {
                if ($obj -match ',') {
                    $rdn = ($obj -split ',')[0]
                    $name = $rdn -replace '^(CN|OU)=',''
                }
                else {
                    $name = $obj
                }
            }
            else {
                $name = $obj.ToString()
            }

            Write-Host "  - $name"
        }
        Write-Host ""
    }

    end { return }
}

function Select-OUGroup {
    [CmdletBinding()]
    param (
        [string]$SearchBase
    )

    $myGroups = Get-UsersGroups

    return Select-FromList -Title "Sélectionnez un groupe" -Options $myGroups
}

function Get-UsersGroups {
    [CmdletBinding()]
    param (
        [string]$SearchBase
    )

    if (-not $SearchBase) {
        $DomainDN = (Get-ADDomain).DistinguishedName
        $SearchBase = "OU=Users,OU=Xanadu,$DomainDN"
    }

    $myGroups = Get-ADOrganizationalUnit -Filter * -SearchBase $SearchBase -SearchScope OneLevel |
        Select-Object -ExpandProperty Name |
        Sort-Object

    return $myGroups
}


