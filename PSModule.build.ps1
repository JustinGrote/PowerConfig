#requires -version 7
$PressTestBuildPath = "$PSScriptRoot/../Press/BuildOutput/Press/Press.psd1"
if (Test-Path $PressTestBuildPath) {
    Import-Module (Resolve-Path $PSScriptRoot/../Press/BuildOutput/Press/Press.psd1) -Force
} else {
    Install-Module Press -AllowPrerelease -Force -AcceptLicense -PassThru
    Import-Module Press
    Install-Module PowerConfig -Force -AcceptLicense -PassThru
    Import-Module PowerConfig
}
. Press.Tasks

Task CopyLoadAssembliesBootstrapScript -After 'Press.CopyModuleFiles' {
    $destination = "$($PressSetting.Build.ModuleOutDir)/Scripts/LoadAssemblies.ps1"
    #This will create the intermediate scripts directory as well
    New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Write-Verbose
    Copy-Item "$($PressSetting.General.SrcRootDir)/Scripts/LoadAssemblies.ps1" $destination -force
}

Task RestoreNugetPackages -After 'Press.CopyModuleFiles' {
    #We want a newer target for Net5 because it uses System.Text.Json among other really good improvements
    $Net5Target = @{
        'Microsoft.Extensions.Configuration.Json'                 = '5.0.0'
        'Microsoft.Extensions.Configuration.EnvironmentVariables' = '5.0.0'
        'Microsoft.Extensions.Configuration.CommandLine'          = '5.0.0'
        'Alexinea.Extensions.Configuration.Toml'                  = '5.0.0'
        'Alexinea.Extensions.Configuration.Yaml'                  = '5.0.0'
    }

    #Powershell 5.1 must target 2.2.0 due to Powershell Editor Services using it and not able to hide it behind an AssemblyLoadContext
    $NetStandardTarget = @{
        'Microsoft.Extensions.Configuration.Json'                 = '2.2.0'
        'Microsoft.Extensions.Configuration.EnvironmentVariables' = '2.2.0'
        'Microsoft.Extensions.Configuration.CommandLine'          = '2.2.0'
        'Microsoft.Extensions.Configuration.FileExtensions'       = '2.2.0'
        'Microsoft.Extensions.Configuration'                      = '2.2.0'
        'Microsoft.Extensions.Configuration.Abstractions'         = '2.2.0'
        'Alexinea.Extensions.Configuration.Toml'                  = '2.2.0'
        'Alexinea.Extensions.Configuration.Yaml'                  = '2.2.0'
    }
    Restore-PressNugetPackages -Packages $Net5Target -Target 'net5.0' -Destination (join-path $PressSetting.Build.ModuleOutDir 'lib/pwsh') -NoRestore -verbose
    Restore-PressNugetPackages -Packages $NetStandardTarget -Target 'net461' -Destination (join-path $PressSetting.Build.ModuleOutDir 'lib/winps') -NoRestore -verbose
}

#FIXME: Copy the bindingredirecthandler