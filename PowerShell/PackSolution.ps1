[CmdletBinding()]

param
(
    [switch]$Unmanaged #Optional parameter for unmanaged solution
)

$ErrorActionPreference = "Stop"
$dataFileName = "data.zip"

#Script Location
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
Write-Verbose "Script Path: $scriptPath"

Write-Verbose "ConnectionString = $connectionString"

$XmlDocumentLoction = "$scriptPath\Package\PkgFolder\ImportConfig.xml"
[xml]$XmlDocument = Get-Content -Path $XmlDocumentLoction
$XmlDocument.configdatastorage.solutions.configsolutionfile.SetAttribute("solutionpackagefilename", "")
$XmlDocument.configdatastorage.SetAttribute("crmmigdataimportfile", "")
$XmlDocument.Save($XmlDocumentLoction)

$matches = Get-ChildItem -Path "$scriptPath\Package\PkgFolder" -Filter *.zip | ForEach-Object {
    Remove-Item $_.FullName
}

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

$packParams = @{
    UnpackedFilesFolder = "$scriptPath\Customizations"
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

if (Test-Path -Path "$scriptPath\ConfigurationData")
{
    $packCMDataParams = @{
        dataFile = "$scriptPath\Package\PkgFolder\$dataFileName"
        extractFolder = "$scriptPath\ConfigurationData"
        combineDataXmlFile = $true
    }

    & "$frameworkPath\PackCMData.ps1" @packCMDataParams

    $XmlDocument.configdatastorage.SetAttribute("crmmigdataimportfile", $dataFileName)
    $XmlDocument.Save($XmlDocumentLoction)
}

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

$XmlDocument.configdatastorage.solutions.configsolutionfile.SetAttribute("solutionpackagefilename", $solutionFile.Name)
$XmlDocument.Save($XmlDocumentLoction)

Write-Verbose "Make PkgFolder available for WPF app."
Copy-Item -Path "$scriptPath\Package\*" -Destination "$scriptPath\Tools\PackageDeployment" -Recurse -Force