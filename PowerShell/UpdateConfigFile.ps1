[CmdletBinding()]

param
(
    [switch]$Unmanaged, #Optional parameter for unmanaged solution
    [string[]]$Solutions #Logical name  crm solution
)

$ErrorActionPreference = "Stop"

#Script Location
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
Write-Verbose "Script Path: $scriptPath"

$XmlDocumentLoction = "$scriptPath\Package\PkgFolder\ImportConfig.xml"
[xml]$XmlDocument = Get-Content -Path $XmlDocumentLoction
if ($XmlDocument.configdatastorage.solutions.GetType().fullname -ne "System.String")
{
    $XmlDocument.configdatastorage.solutions.RemoveAll()
}
$XmlDocument.Save($XmlDocumentLoction)

$solutionFileList = New-Object Collections.Generic.List[String]
foreach ($Solution in $Solutions)
{
    if ($Unmanaged)
    {
        $solutionFileName = $Solution + ".zip"
    }
    else
    {
        $solutionFileName = $Solution + "_managed.zip"
    }
    $solutionFileList.Add($solutionFileName)
}

foreach ($solutionFile in $solutionFileList) 
{
    $xmlSolutionConfig = $XmlDocument.CreateElement("configsolutionfile")
    $xmlAtt = $XmlDocument.CreateAttribute("solutionpackagefilename")
    $xmlAtt.Value = $solutionFile
    $xmlSolutionConfig.Attributes.Append($xmlAtt)
    $xmlAtt = $XmlDocument.CreateAttribute("requiredimportmode")
    $xmlAtt.Value = "async"
    $xmlSolutionConfig.Attributes.Append($xmlAtt)
    $XmlDocument.configdatastorage.SelectSingleNode("solutions").AppendChild($xmlSolutionConfig);
}
$XmlDocument.Save($XmlDocumentLoction)

Write-Verbose "Make PkgFolder available for WPF app."
Copy-Item -Path "$scriptPath\Package\*" -Destination "$scriptPath\Tools\PackageDeployment" -Recurse -Force