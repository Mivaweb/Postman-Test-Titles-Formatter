# Author: Michaël Vanbrabandt
# Date: 25-03-2024

# Subject: Postman Test title formatter
# Description: Edit Postman test titles by including predefined prefix, folder and request names.

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidateScript({Test-Path $_ -PathType Leaf})]
    [String]$TestFilePath,

    [Parameter(Mandatory=$true)]
    [String]$TestTitlePrefix
)

# Install and import Newtonsoft.Json library
Install-Module -Name Newtonsoft.Json -Force -Scope CurrentUser -Verbose:$false
Import-Module -Name Newtonsoft.Json -DisableNameChecking

function Edit-TestItem {
    param (
        [string]$Prefix,
        $Item
    )

    $itemName = "$($Prefix + '_' + $Item.Item('name').ToString())"
    Write-Output "Item prefix: $itemName"

    if ($null -ne $Item.Item('item')) {
        $Item.Item('item') | ForEach-Object {
            Edit-TestItem -Prefix $itemName -Item $_
        }
    }

    if ($null -ne $Item.Item('event')) {
        $testEvent = $Item.Item('event') | Where-Object { $_.listen -eq "test" }

        if ($null -ne $testEvent) {
            $exec = $testEvent.Item('script').Item('exec')

            $exec | ForEach-Object {
                $e = $_.ToString()

                if ($e -match '.test\(\"([\w\s]+)\"') {
                    $innerTestTitle = $matches[1]
                    $itemName = Format-TestTitle "$($itemName + '_' + $innerTestTitle)"
                    $e = $e -replace $innerTestTitle, $itemName
                    $_.Value = $e
                }
            }
        }
    }
}

function Format-TestTitle {
    param (
        [string]$Title
    )

    $title = $Title.Trim() -replace '\s+', ' ' -replace '\s', '_'
    return $title
}

Write-Output ("Processing editing " + $TestFilePath)

# Read JSON content
$testsContent = Get-Content -Path $TestFilePath -Raw | Out-String
$testsContentJson = [Newtonsoft.Json.Linq.JObject]::Parse($testsContent)

Write-Output ("Total items: $($testsContentJson.Item('item').Count)")

$testsContentJson.item | ForEach-Object {
    Edit-TestItem -Prefix $TestTitlePrefix -Item $_
}

# Write updated JSON content
$testsContentJson.ToString() | Set-Content -Path $TestFilePath -Encoding utf8