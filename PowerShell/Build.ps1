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

if ($Solutions)
{
    Write-Verbose "Using Solutions: $Solutions"
}
else
{

	throw "No solution supplied"
}

if ($TargetVersion)
{
    Write-Verbose "Using TargetVersion: $TargetVersion"
}
else
{
	Write-Verbose "No target version supplied. Keep existing solution version."
}

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

if ($CrmConnectionString)
{
	Write-Verbose "Using supplied connection string"
}
else
{
	Write-Verbose "Using connection store"
	$CrmConnectionString = GetXrmConnectionFromConfig($key);
}

#Clean up PkgFolder
$matches = Get-ChildItem -Path "$scriptPath\Package\PkgFolder" -Filter *.zip | ForEach-Object {
    Remove-Item $_.FullName
}

foreach ($Solution in $Solutions)
{
    if ($TargetVersion)
    {
        $exportParams = @{
            CrmConnectionString = "$CrmConnectionString"
            SolutionName = "$Solution"
            ExportManaged = $true
            ExportUnmanaged = $true
            RequiredVersion = "$TargetVersion"
            UpdateVersion = $true
            ExportIncludeVersionInSolutionName = $false
            ExportSolutionOutputPath = "$env:TEMP"
            ExportAutoNumberingSettings = $true
            ExportCalendarSettings = $true
            ExportCustomizationSettings = $true
            ExportEmailTrackingSettings = $true
            ExportExternalApplications = $true
            ExportGeneralSettings = $true
            ExportIsvConfig = $true
            ExportMarketingSettings = $true
            ExportOutlookSynchronizationSettings = $true
            ExportRelationshipRoles = $true
            ExportSales = $true
            ExportAsync = $Async
            AsyncWaitTimeout = 600
            Timeout = 600
        }
    }
    else
    {
        $exportParams = @{
            CrmConnectionString = "$CrmConnectionString"
            SolutionName = "$Solution"
            ExportManaged = $true
            ExportUnmanaged = $true
            UpdateVersion = $false
            ExportIncludeVersionInSolutionName = $false
            ExportSolutionOutputPath = "$env:TEMP"
            ExportAutoNumberingSettings = $true
            ExportCalendarSettings = $true
            ExportCustomizationSettings = $true
            ExportEmailTrackingSettings = $true
            ExportExternalApplications = $true
            ExportGeneralSettings = $true
            ExportIsvConfig = $true
            ExportMarketingSettings = $true
            ExportOutlookSynchronizationSettings = $true
            ExportRelationshipRoles = $true
            ExportSales = $true
            ExportAsync = $Async
            AsyncWaitTimeout = 600
            Timeout = 600
        }
    }

    & "$frameworkPath\ExportSolution.ps1" @exportParams

    $extractParams = @{
        UnpackedFilesFolder = "$scriptPath\Customizations\$Solution"
        mappingFile = "$scriptPath\mapping.xml"
        PackageType = "Both"
        solutionName = $Solution
        connectionString = "$CrmConnectionString"
        solutionFile = "$env:TEMP\$Solution.zip"
	    CoreToolsPath = "$scriptPath\Tools\CoreTools"
        sourceLoc = "$null"
        localize = $false
	    TreatUnpackWarningsAsErrors = $false
    }

    & "$frameworkPath\ExtractSolution.ps1" @extractParams

    $packParams = @{
        UnpackedFilesFolder = "$scriptPath\Customizations\$Solution"
        mappingFile = "$scriptPath\mapping.xml"
        PackageType = "Both"
        IncrementReleaseVersion = $false
        OutputPath = "$scriptPath\Package\PkgFolder"
        sourceLoc = "$null"
        localize = $false
        CoreToolsPath = "$scriptPath\Tools\CoreTools"
	    TreatUnpackWarningsAsErrors = $false
    }

    & "$frameworkPath\PackSolution.ps1" @packParams
}

& .\ExportConfigurationData.ps1 -CrmConnectionString $CrmConnectionString -Key $Key

if ($Unmanaged.IsPresent)
{
    & .\UpdateConfigFile.ps1 -Unmanaged -Solutions $Solutions
}
else
{
    & .\UpdateConfigFile.ps1 -Solutions $Solutions
}

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