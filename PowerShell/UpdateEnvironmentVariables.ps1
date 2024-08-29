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

Write-Host '$Env:BUILD_SOURCESDIRECTORY - For example, enter something like:'

$environmentVariables = Get-ChildItem -Path Env:\ | %{"['{0}','{1}']" -f $_.Name,$_.Value}
$environmentVariables = $environmentVariables | Where {$_ -like '*ql_*'} 
$environmentVariables -join ','
$environmentVariables = "[$environmentVariables]"

Write-Host $environmentVariables

$deployParams = @{
	CrmConnectionString = "$CrmConnectionString"
	EnvironmentVariablesJson = $environmentVariables
}

& "$frameworkPath\UpdateEnvironmentVariables.ps1" @deployParams
