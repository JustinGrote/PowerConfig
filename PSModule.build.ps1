#TODO: Temporary
if ($PSEdition -eq 'Desktop' -and ((get-module -Name 'Microsoft.PowerShell.Utility').CompatiblePSEditions -eq 'Core')) {
    Write-Verbose 'Powershell 5.1 was started inside of pwsh, removing non-WindowsPowershell paths'
    $env:PSModulePath = ($env:PSModulePath -split [io.path]::PathSeparator | where {$_ -match 'WindowsPowershell'}) -join [io.path]::PathSeparator
    $ModuleToImport = Get-Module Microsoft.Powershell.Utility -ListAvailable |
        Where-Object Version -lt 6.0.0 |
        Sort-Object Version -Descending |
        Select-Object -First 1
    Remove-Module 'Microsoft.Powershell.Utility'
    Import-Module $ModuleToImport -Force
}

import-module -force C:\Users\JGrote\Documents\Github\PowerCD\BuildOutput\PowerCD
. PowerCD.Tasks

Import-PowerCDModuleFast -ModuleName PowerShellGet -Version 2.1.3
try {
    Import-PowerCDModuleFast @(
        'BuildHelpers'
        'PSScriptAnalyzer'
    )
} catch [IO.FileLoadException] {
    write-warning "An Assembly is currently in use. This happens if you try to update a module with a DLL that's already loaded. Please run a 'Clean' task as a separate process prior to starting Invoke-Build. This will exit cleanly to avoid a CI failure now."
}

#Reimport Pester
#TODO: FIX PESTER PROBLEM!
Get-Module Pester | Remove-Module
Get-TypeData Gherkin* | Remove-TypeData
Import-PowerCDModuleFast Pester

Enter-Build {
    #Bootstrap PCDSetting since we normally use PowerConfig to get this setting anyways causing a circular dependency
    $GLOBAL:PCDSetting = (Get-PowerCDSetting)
}

task Nuget.PowerCD {
    function Nuget.PowerCD {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromRemainingArguments)]$Args
        )
        $PSModuleNugetDependencies = @{
            'Microsoft.Extensions.Configuration.CommandLine' = '2.*'
            'Microsoft.Extensions.Configuration.Json' = '2.*'
            'Microsoft.Extensions.Configuration.FileExtensions' = '2.*'
            'Microsoft.Extensions.Configuration.EnvironmentVariables' = '2.*'
            'NetEscapades.Configuration.Yaml' = '1.6'
        }
        Get-PSModuleNugetDependencies $PSModuleNugetDependencies -Destination (join-path $PCDSetting.BuildEnvironment.BuildOutput '/PowerConfig/0.1.0/lib') -verbose
    }
    Nuget.PowerCD
}

#TODO: Make task for this
task CopyBuildTasksFile {
    Copy-Item $BuildRoot\PowerCD\PowerCD.tasks.ps1 -Destination (get-item $BuildRoot\BuildOutput\PowerCD\*\)[0]
}

task PackageZip {
    [String]$ZipFileName = $PCDSetting.BuildEnvironment.ProjectName + '-' + $PCDSetting.VersionLabel + '.zip'
    $CompressArchiveParams = @{
        Path = $PCDSetting.BuildEnvironment.ModulePath
        DestinationPath = join-path $PCDSetting.BuildEnvironment.BuildOutput $ZipFileName
    }
    $CurrentProgressPreference = $GLOBAL:ProgressPreference
    $GLOBAL:ProgressPreference = 'SilentlyContinue'
    Compress-Archive @CompressArchiveParams
    $GLOBAL:ProgressPreference = $CurrentProgressPreference
    write-verbose ("Zip File Output:" + $CompressArchiveParams.DestinationPath)
}

task Clean Clean.PowerCD
task Build Version.PowerCD,BuildPSModule.PowerCD,SetPSModuleVersion.PowerCD,UpdatePSModulePublicFunctions.PowerCD,Nuget.PowerCD
task Package PackageZip,PackageNuget.PowerCD
task Test TestPester.PowerCD
task . Clean,Build,Test,Package
