[CmdletBinding()]

param
(
    [string]$Solution, #Logical name  crm solution
    [string]$TargetVersion, #Optional target version for solution
    [switch]$Unmanaged, #Optional parameter for unmanaged solution
    [string]$CrmConnectionString, #The connection string as per CRM Sdk
	[string]$Key, #The key for the stored connection string
    [bool]$Async, #Export async (recommended, but only available in newer instances)
    [string]$TenantId, #Needed by SolutionChecker
    [string]$ApplicationId, #Needed by SolutionChecker
    [string]$ApplicationSecret #Needed by SolutionChecker
)

$ErrorActionPreference = "Stop"

if ($Solution)
{
    Write-Verbose "Using Solution: $Solution"
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
        AsyncWaitTimeout = 360
        Timeout = 360
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
        AsyncWaitTimeout = 360
        Timeout = 360
    }
}

 & "$frameworkPath\ExportSolution.ps1" @exportParams

$extractParams = @{
    UnpackedFilesFolder = "$scriptPath\Customizations"
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

& .\ExportConfigurationData.ps1 -CrmConnectionString $CrmConnectionString -Key $Key

if ($Unmanaged.IsPresent)
{
    & .\PackSolution.ps1 -Unmanaged
}
else
{
    & .\PackSolution.ps1
}

if ($TenantId -and $ApplicationId -and $ApplicationSecret)
{
    $matches = Get-ChildItem -Path "$scriptPath\Package\PkgFolder" -Filter *.zip | ForEach-Object {
        if ($Unmanaged)
        {
            if (!$_.Name.EndsWith("_managed.zip"))
            {
                $solutionFile = $_
            }
        }
        else
        {
            if (!$_.Name.Equals($dataFileName))
            {
                $solutionFile = $_
            }
        }
    }

    $checkParams = @{
        SolutionFile = $solutionFile.FullName
        OutputPath = "$scriptPath\CheckerResults"
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