[CmdletBinding()]

param
(
    [string[]]$Solutions, #Logical name  crm solution
    [string]$TargetVersion, #Optional target version for solution
    [switch]$Unmanaged, #Optional parameter for unmanaged solution
    [string]$CrmConnectionString, #The connection string as per CRM Sdk
	[string]$Key, #The key for the stored connection string
    [bool]$Async, #Optional export async (recommended, but only available in newer instances)
    [string]$TenantId, #Optional parameter for SolutionChecker
    [string]$ApplicationId, #Optional parameter for SolutionChecker
    [string]$ApplicationSecret #Optional parameter for SolutionChecker
)

$ErrorActionPreference = "Stop"

#Script Location
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
Write-Verbose "Script Path: $scriptPath"

Write-Verbose "ConnectionString = $connectionString"

$matches = Get-ChildItem -Path "$scriptPath\Tools\Microsoft.PowerApps.Checker.PowerShell\*" | Sort-Object Name -Descending
if ($matches.Length -gt 0)
{
	$crmCheckerPath = $matches[0].FullName
	Write-Verbose "Using CrmChecker: $crmCheckerPath"
}
else
{
	throw "CrmConnector not found in tools folder"
}

#This needs to be executed prior to Xrm Cmdlets
Import-module "$crmCheckerPath\Microsoft.PowerApps.Checker.PowerShell.psd1"

$matches = Get-ChildItem -Path "$scriptPath\Tools\XrmCIFramework*" | Sort-Object Name -Descending
if ($matches.Length -gt 0)
{
	$frameworkPath = $matches[0].FullName
	Write-Verbose "Using XrmCIFramework: $frameworkPath"
}
else
{
	throw "XrmCIFramework not found in tools folder"
}

Import-Module "$frameworkPath\Xrm.Framework.CI.PowerShell.Cmdlets.psd1"

if ($TenantId -and $ApplicationId -and $ApplicationSecret)
{
    if (!(Test-Path "$scriptPath\CheckerResults" -PathType Container)) {
        New-Item -ItemType Directory -Force -Path "$scriptPath\CheckerResults"
    }

    $solutionFileList = New-Object Collections.Generic.List[String]
    $matches = Get-ChildItem -Path "$scriptPath\Package\PkgFolder" -Filter *.zip | ForEach-Object {
        if ($Unmanaged)
        {
            if (!$_.Name.EndsWith("_managed.zip") -and !$_.Name.Equals($dataFileName))
            {
                $solutionFileList.Add($_.FullName)
            }
        }
        else
        {
            if ($_.Name.EndsWith("_managed.zip") -and !$_.Name.Equals($dataFileName))
            {
                $solutionFileList.Add($_.FullName)
            }
        }
    }

    foreach ($solutionFile in $solutionFileList) 
    {
        $folderName = [io.path]::GetFileNameWithoutExtension($solutionFile)
        if (!(Test-Path "$scriptPath\CheckerResults\$folderName" -PathType Container)) {
            New-Item -ItemType Directory -Force -Path "$scriptPath\CheckerResults\$folderName"
        }
        $checkParams = @{
            SolutionFile = $solutionFile
            OutputPath = "$scriptPath\CheckerResults\$folderName"
            TenantId = "$TenantId"
            ApplicationId = "$ApplicationId"
            ApplicationSecret = "$ApplicationSecret"
            PowerAppsCheckerPath = $crmCheckerPath
            Ruleset = "Solution Checker"
            Geography = "Europe"
            SecondsBetweenChecks = 15
            LocaleName = "en"
            MaxStatusChecks = 25
        }
        & "$frameworkPath\CheckSolution.ps1" @checkParams
    }
}