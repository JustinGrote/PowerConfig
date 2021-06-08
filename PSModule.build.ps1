#requires -version 7
$PressTestBuildPath = "$PSScriptRoot/../Press/BuildOutput/Press/Press.psd1"
if (Test-Path $PressTestBuildPath) {
    Import-Module (Resolve-Path $PSScriptRoot/../Press/BuildOutput/Press/Press.psd1) -Force
} else {
    Install-Module PowerConfig -Force -AcceptLicense -PassThru -RequiredVersion '0.1.3'
    Import-Module PowerConfig
    Install-Module Press -AllowPrerelease -Force -AcceptLicense -PassThru
    Import-Module Press
}
. Press.Tasks

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

#TODO: Fix the custom exclude to work in Press
Task Press.CopyModuleFiles @{
    Inputs  = {
        Get-ChildItem -File -Recurse $PressSetting.General.SrcRootDir
    }
    Outputs = {
        $buildItems = Get-ChildItem -File -Recurse $PressSetting.Build.ModuleOutDir
        if ($buildItems) { $buildItems } else { 'EmptyBuildOutputFolder' }
    }
    #(Join-Path $PressSetting.BuildEnvironment.BuildOutput $ProjectName)
    Jobs    = {
        Remove-BuildItem $PressSetting.Build.ModuleOutDir

        $copyResult = Copy-PressModuleFiles @commonParams `
            -Destination $PressSetting.Build.ModuleOutDir `
            -PSModuleManifest $PressSetting.BuildEnvironment.PSModuleManifest `
            -PSFileExclude @( #This is what changed
                '*.*.ps1'
                'LoadAssemblies.ps1'
            ) `
            -Include "PowerConfig/LoadAssemblies.ps1"

        $PressSetting.OutputModuleManifest = $copyResult.OutputModuleManifest
    }
}