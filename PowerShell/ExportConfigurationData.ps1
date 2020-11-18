[CmdletBinding()]

param
(
    [string]$CrmConnectionString, #The connection string as per CRM Sdk
	[string]$Key #The key for the stored connection string
)

$ErrorActionPreference = "Stop"

#Script Location
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
Write-Verbose "Script Path: $scriptPath"

#Print Parameters
Write-Verbose "ConnectionString = $CrmConnectionString"
Write-Verbose "Key = $Key"

#Variables
$dataFileName = "data.zip"
$DataFile = "$env:TEMP\configuration_data_$(get-date -f yyyyMMdd-HHmmss).zip"
$XmlDocumentLoction = "$scriptPath\Package\PkgFolder\ImportConfig.xml"
[xml]$XmlDocument = Get-Content -Path $XmlDocumentLoction
$XmlDocument.configdatastorage.SetAttribute("crmmigdataimportfile", "")
$XmlDocument.Save($XmlDocumentLoction)

Write-Verbose "ConnectionString = $connectionString"


Remove-Item "$scriptPath\ConfigurationData" -Recurse -ErrorAction Ignore

$matches = Get-ChildItem -Path "$scriptPath\Tools\XrmCIFramework*" | Sort-Object Name -Descending
if ($matches.Length -gt 0)
{
	$frameworkPath = $matches[0].FullName
	Write-Verbose "Using XrmCIFramework: $frameworkPath"
}
else
{
	throw "XrmCIFramework not found in nuget packages"
}

$matches = Get-ChildItem -Path "$scriptPath\Tools\Microsoft.Xrm.Tooling.ConfigurationMigration\*" | Sort-Object Name -Descending
if ($matches.Length -gt 0)
{
	$configurationMigrationPath = $matches[0].FullName
	Write-Verbose "Using ConfigurationMigration: $configurationMigrationPath"
}
else
{
	throw "ConfigurationMigration not found in tools folder"
}

$matches = Get-ChildItem -Path "$scriptPath\Tools\Microsoft.Xrm.Tooling.CrmConnector.PowerShell\*" | Sort-Object Name -Descending
if ($matches.Length -gt 0)
{
	$crmConnectorPath = $matches[0].FullName
	Write-Verbose "Using CrmConnector: $crmConnectorPath"
}
else
{
	throw "CrmConnector not found in tools folder"
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

if (Test-Path -Path "$scriptPath\Schema.xml")
{
    $exportParams = @{
	    crmConnectionString = "$CrmConnectionString"
	    crmConnectionTimeout = 360
	    dataFile = $DataFile
	    schemaFile = "$scriptPath\Schema.xml"
	    logsDirectory = "$env:TEMP"
	    configurationMigrationModulePath = "$configurationMigrationPath"
	    toolingConnectorModulePath = "$crmConnectorPath"
    }

    & "$frameworkPath\ExportCMData.ps1" @exportParams

    $extractParams = @{
	    dataFile = $DataFile
	    extractFolder = "$scriptPath\ConfigurationData"
	    sortExtractedData = $true
	    splitExtractedData = $true
    }

    & "$frameworkPath\ExtractCMData.ps1" @extractParams

    $packCMDataParams = @{
        dataFile = "$scriptPath\Package\PkgFolder\$dataFileName"
        extractFolder = "$scriptPath\ConfigurationData"
        combineDataXmlFile = $true
    }

    & "$frameworkPath\PackCMData.ps1" @packCMDataParams

    $XmlDocument.configdatastorage.SetAttribute("crmmigdataimportfile", $dataFileName)
    $XmlDocument.Save($XmlDocumentLoction)
}
else
{
    Write-Verbose "No reference data schema given at $scriptPath\Schema.xml."
}
