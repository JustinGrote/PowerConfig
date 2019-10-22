#TODO: Temporary Included Dependency, move to using the module once the refactor is more stable
import-module -force .\Build\PowerCD
. PowerCD.Tasks

Enter-Build {
    Initialize-PowerCD
}

task Nuget.PowerCD {
    function Nuget.PowerCD {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromRemainingArguments)]$Args
        )
        $PSModuleNugetDependencies = @{
            'Microsoft.Extensions.Configuration.CommandLine' = '2.0.0'
            'Microsoft.Extensions.Configuration.Json' = '2.0.0'
            'Microsoft.Extensions.Configuration.FileExtensions' = '2.0.0'
            'Microsoft.Extensions.Configuration.EnvironmentVariables' = '2.0.0'
            'NetEscapades.Configuration.Yaml' = '1.6'            
        }
        Get-PSModuleNugetDependencies $PSModuleNugetDependencies -Destination (join-path $PCDSetting.BuildEnvironment.BuildOutput '/PowerConfig/0.1.0/lib') -NoRestore -verbose
    }
    Nuget.PowerCD
}

task TestPester.PowerCD {
    Test-PowerCDPester -CodeCoverage $null -Show All -ModuleManifestPath $PCDSetting.OutputModuleManifest -UseJob
}

task Clean Clean.PowerCD
task Build Build.PowerCD,Nuget.PowerCD
task Package Package.PowerCD
task Test Test.PowerCD
task . Clean,Build,Test,Package