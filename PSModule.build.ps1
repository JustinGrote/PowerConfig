#requires -version 5.1

#PowerCD Bootstrap
. $PSScriptRoot\PowerCD.buildinit.ps1

#Bootstrap package management in a new process. If you try to do it same-process you can't import it because the DLL from the old version is already loaded
#YOU MUST DO THIS IN A NEW SESSION PRIOR TO RUNNING ANY PACKAGEMANGEMENT OR POWERSHELLGET COMMANDS
#NOTES: Tried using a runspace but install-module would crap out on older PS5.x versions.

function BootstrapPSGet {
    $psGetVersionMinimum = '2.2.1'
    $PowershellGetModules = get-module PowershellGet -listavailable | where version -ge $psGetVersionMinimum
    if ($PowershellGetModules) {
        write-verbose "PowershellGet $psGetVersionMinimum found. Skipping bootstrap..."
        return
    }

    write-verbose "PowershellGet $psGetVersionMinimum not detected. Bootstrapping..."
    Start-Job -Verbose -Name "BootStrapPSGet" {
        $psGetVersionMinimum = '2.2.1'
        $progresspreference = 'silentlycontinue'
        Install-Module PowershellGet -MinimumVersion $psGetVersionMinimum -Scope CurrentUser -AllowClobber -SkipPublisherCheck -Force
    } | Receive-Job -Wait -Verbose
    Remove-Job -Name "BootStrapPSGet"
    Import-Module PowershellGet -MinimumVersion 2.2 -ErrorAction Stop
}
BootStrapPSGet

#endregion Bootstrap

. PowerCD.Tasks

Enter-Build {
    Initialize-PowerCD
}

task PowerCD.Nuget {
    function PowerCD.Nuget {
        [CmdletBinding()]
        param (
            [Parameter(ValueFromRemainingArguments)]$Args
        )
        $PSModuleNugetDependencies = @{
            'Microsoft.Extensions.Configuration.CommandLine' = '3.1.3'
            'Microsoft.Extensions.Configuration.Json' = '3.1.3'
            'Microsoft.Extensions.Configuration.EnvironmentVariables' = '3.1.3'
            'NetEscapades.Configuration.Yaml' = '2.0'
            #These are required so that NetEscapades.Configuration.YAML doesn't downgrade them
            'Microsoft.Extensions.Configuration' = '3.1.3'
            'Microsoft.Extensions.Configuration.FileExtensions' = '3.1.3'
        }
        Get-PSModuleNugetDependencies $PSModuleNugetDependencies -Destination (join-path $PCDSetting.BuildModuleOutput 'lib') -NoRestore -verbose
    }
    PowerCD.Nuget
}

task PowerCD.Test {
    Test-PowerCDPester -CodeCoverage $null -Show All -ModuleManifestPath $PCDSetting.OutputModuleManifest -UseJob
}

task Clean PowerCD.Clean
task Build PowerCD.Build,PowerCD.Nuget
task Package PowerCD.Package
task Test PowerCD.Test
task . Clean,Build,Test,Package