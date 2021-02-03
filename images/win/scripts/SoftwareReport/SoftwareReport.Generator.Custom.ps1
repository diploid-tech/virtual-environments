Import-Module MarkdownPS
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Android.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Browsers.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.CachedTools.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Common.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Databases.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Helpers.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.Tools.psm1") -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot "SoftwareReport.VisualStudio.psm1") -DisableNameChecking

$markdown = ""

$OSName = Get-OSName
$markdown += New-MDHeader "$OSName" -Level 1

$OSVersion = Get-OSVersion
$markdown += New-MDList -Style Unordered -Lines @(
    "$OSVersion"
    "Image Version: $env:ImageVersion"
)

if (Test-IsWin19)
{
    $markdown += New-MDHeader "Enabled windows optional features" -Level 2
    $markdown += New-MDList -Style Unordered -Lines @(
        "Windows Subsystem for Linux"
    )
}

$markdown += New-MDHeader "Installed Software" -Level 2

$markdown += New-MDHeader "Package Management" -Level 3
$markdown += New-MDList -Style Unordered -Lines @(
    (Get-ChocoVersion),
    (Get-HelmVersion)
)

$markdown += New-MDHeader "Tools" -Level 3
$markdown += New-MDList -Style Unordered -Lines @(
    (Get-AzCopyVersion),
    (Get-DockerVersion),
    (Get-DockerComposeVersion),
    (Get-GitVersion),
    (Get-JQVersion),
    (Get-KubectlVersion),
    (Get-OpenSSLVersion),
    (Get-7zipVersion)
)

$markdown += New-MDHeader "CLI Tools" -Level 3
$markdown += New-MDList -Style Unordered -Lines @(
    (Get-AzureCLIVersion),
    (Get-AzureDevopsExtVersion)
)

$markdown += New-MDHeader "Browsers" -Level 3
$markdown += New-MDList -Style Unordered -Lines @(
    (Get-BrowserVersion -Browser "edge")
)

$markdown += New-MDHeader ".NET Core SDK" -Level 3
$sdk = Get-DotnetSdks
$markdown += "``Location $($sdk.Path)``"
$markdown += New-MDNewLine
$markdown += New-MDList -Lines $sdk.Versions -Style Unordered

$markdown += New-MDHeader ".NET Core Runtime" -Level 3
Get-DotnetRuntimes | Foreach-Object {
    $path = $_.Path
    $versions = $_.Versions
    $markdown += "``Location: $path``"
    $markdown += New-MDNewLine
    $markdown += New-MDList -Lines $versions -Style Unordered
}

$markdown | Out-File -FilePath "C:\InstalledSoftware.md"
