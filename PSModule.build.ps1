#TODO: Temporary
import-module -force C:\Users\JGrote\Documents\Github\PowerCD\BuildOutput\PowerCD\0.6.0\PowerCD.psm1
. PowerCD.Tasks

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
            #'Microsoft.Extensions.Configuration.Json' = '2.*'
            #'Microsoft.Extensions.Configuration.FileExtensions' = '2.*'
            'Microsoft.Extensions.Configuration.EnvironmentVariables' = '2.*'
            #'NetEscapades.Configuration.Yaml' = '1.*'
        }
        Get-PSModuleNugetDependencies $PSModuleNugetDependencies -Destination (join-path $PCDSetting.Environment.BuildOutput '/PowerConfig/0.1.0/lib') -verbose
    }
    Nuget.PowerCD
}

task Clean Clean.PowerCD
task Build Version.PowerCD,BuildPSModule.PowerCD,SetPSModuleVersion.PowerCD,UpdatePSModulePublicFunctions.PowerCD,Nuget.PowerCD
task Test TestPester.PowerCD
task . Clean,Build,Test