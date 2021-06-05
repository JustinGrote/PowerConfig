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
    Restore-PressNugetPackages -Packages $PSModuleNugetDependencies -Destination (join-path $PressSetting.Build.ModuleOutDir 'lib/netstandard2.0') -NoRestore -verbose
    Restore-PressNugetPackages -Packages $PSModuleNugetDependencies -Target 'net5.0' -Destination (join-path $PressSetting.Build.ModuleOutDir 'lib/net5.0') -NoRestore -verbose
}

Task Press.Test Press.Test.PS7,Press.Test.PS51

Task Press.Test.PS7 {
    $TestResults = Start-Job -Name 'PesterTest' -ScriptBlock {
        Import-Module C:\Users\JGrote\Projects\PowerConfig\PowerConfig\PowerConfig.psd1
        Invoke-Pester -PassThru
    } | Receive-Job -Wait
    if ($TestResults.Result -ne 'Passed') {
        throw "Failed $($TestResults.FailedCount) tests"
    }
}

Task Press.Test.PS51 {
    $TestResults = Start-Job -PSVersion 5.1 -Name 'PesterTest' -ScriptBlock {
        Import-Module C:\Users\JGrote\Projects\PowerConfig\PowerConfig\PowerConfig.psd1
        Invoke-Pester -PassThru
    } | Receive-Job -Wait
    if ($TestResults.Result -ne 'Passed') {
        throw "Failed $($TestResults.FailedCount) tests"
    }
}