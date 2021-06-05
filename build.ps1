<#
.SYNOPSIS
Bootstraps Invoke-Build and starts it with supplied parameters.
.NOTES
If you already have Invoke-Build installed, just use Invoke-Build instead of this script. This is for CI/CD environments like Appveyor, Jenkins, or Azure DevOps pipelines.
.EXAMPLE
.\build.ps1
Starts Invoke-Build with the default parameters
#>

#This script bootstraps Invoke-Build, using a local copy if available
$BootStrapInvokeBuildPath = "$PSScriptRoot/Scripts/BootstrapInvokeBuild.ps1"
[String]$BootStrapInvokeBuildContent = if (Test-Path $BootStrapInvokeBuildPath) {
    Get-Content -Raw $BootStrapInvokeBuildPath
} else {
    Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/JustinGrote/Press/main/Scripts/BootstrapInvokeBuild.ps1'
}

$BootStrapInvokeBuild = [ScriptBlock]::Create($BootStrapInvokeBuildContent)
. $BootStrapInvokeBuild @args