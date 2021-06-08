Import-Module (Resolve-Path $PSScriptRoot/../Press/BuildOutput/Press/Press.psd1) -Force
. Press.Tasks

Task RestoreNugetPackages -After 'Press.CopyModuleFiles' {
    $PSModuleNugetDependencies = @{
        'Microsoft.Extensions.Configuration.Json'                 = '5.0.0'
        'Microsoft.Extensions.Configuration.EnvironmentVariables' = '5.0.0'
        'Microsoft.Extensions.Configuration.CommandLine'          = '5.0.0'
        'Alexinea.Extensions.Configuration.Toml'                  = '5.0.0'
        'Alexinea.Extensions.Configuration.Yaml'                  = '5.0.0'
    }
    Restore-PressNugetPackages -Packages $PSModuleNugetDependencies -Target 'net5.0' -Destination (join-path $PressSetting.Build.ModuleOutDir 'lib/pwsh') -NoRestore -verbose
    Restore-PressNugetPackages -Packages $PSModuleNugetDependencies -Target 'net461' -Destination (join-path $PressSetting.Build.ModuleOutDir 'lib/winps') -NoRestore -verbose
}