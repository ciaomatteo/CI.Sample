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

Write-Verbose "ConnectionString = $connectionString"

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

$matches = Get-ChildItem -Path "$scriptPath\Tools\Microsoft.Xrm.Tooling.PackageDeployment.Powershell\*" | Sort-Object Name -Descending
if ($matches.Length -gt 0)
{
	$packageDeploymentPath = $matches[0].FullName
	Write-Verbose "Using PackageDeployment: $packageDeploymentPath"
}
else
{
	throw "PackageDeployment not found in tools folder"
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

$deployParams = @{
	CrmConnectionString = "$CrmConnectionString"
	PackageName = "Xrm.CI.Framework.Sample.CRMPackage"
	PackageDirectory = "$scriptPath\Package"
    LogsDirectory = "$env:TEMP"
	PackageDeploymentPath = "$packageDeploymentPath"
	ToolingConnectorModulePath = "$crmConnectorPath"
	CoreToolsPath = "$scriptPath\Tools\CoreTools"
}

& "$frameworkPath\DeployPackage.ps1" @deployParams
