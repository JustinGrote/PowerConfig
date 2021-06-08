
#region SourceInit
$PSDebugBuild = $true
#endregion SourceInit

$libroot = Resolve-Path "$PSScriptRoot/lib"
if ($PSDebugBuild) {
    $libroot = Resolve-Path "$PSScriptRoot/../BuildOutput/PowerConfig/lib"
}

$libPath = Resolve-Path $(
    if ($PSEdition -eq 'Desktop') {
        "$libroot/winps"
    } else {
        "$libroot/pwsh"
    }
)
Write-Verbose "Loading PowerConfig Assemblies from $libPath"
Add-Type -Path "$libPath/*.dll"

try {
    Update-TypeData -Erroraction Stop -TypeName Microsoft.Extensions.Configuration.ConfigurationBuilder -MemberName AddYamlFile -MemberType ScriptMethod -Value {
        param([String]$Path)
        [Microsoft.Extensions.Configuration.YamlConfigurationExtensions]::AddYamlFile($this, $Path)
    }
} catch {
    if ([String]$PSItem -match 'The member .+ is already present') {
        Write-Verbose "Extension Method already present"
        $return
    }
    #Write-Error $PSItem.exception
}

try {
    Update-TypeData -Erroraction Stop -TypeName Microsoft.Extensions.Configuration.ConfigurationBuilder -MemberName AddJsonFile -MemberType ScriptMethod -Value {
        param([String]$Path)
        [Microsoft.Extensions.Configuration.JsonConfigurationExtensions]::AddJsonFile($this, $Path)
    }
} catch {
    if ([String]$PSItem -match 'The member .+ is already present') {
        Write-Verbose "Extension Method already present"
        $return
    }
    #Write-Error $PSItem.exception
}

#region SourceInit
$publicFunctions = @()
foreach ($ScriptPathItem in 'Private','Public') {
    $ScriptSearchFilter = [io.path]::Combine($PSScriptRoot, $ScriptPathItem, '*.ps1')
    $ScriptExcludeFilter = {$PSItem -notlike '*.tests.ps1' -and $PSItem -notlike '*.build.ps1'}
    Get-ChildItem $ScriptSearchFilter |
        Where-Object -FilterScript $ScriptExcludeFilter |
        Foreach-Object {
            if ($ScriptPathItem -eq 'Public') {$PublicFunctions += $PSItem.BaseName}
            . $PSItem
        }
}
Export-ModuleMember -Function $publicFunctions
#endregion SourceInit

#Fix a Powershell 5.1 issue where the strong type of the assembly for Microsoft.Extensions.FileProviders doesn't match
#This creates a generic binding redirect
#.NET Core Style Assembly Handler, where it will redirect to an already loaded assembly if present
if ($PSEdition -eq 'Desktop') {
    Register-BindingRedirectHandler
}
# TODO: Figure out how to use this binding handler with classes


# if ('AddYamlFile' -notin (get-typedata "Microsoft.Extensions.Configuration.ConfigurationBuilder").members.keys) {
#     Update-TypeData -TypeName Microsoft.Extensions.Configuration.ConfigurationBuilder -MemberName AddYamlFile -MemberType ScriptMethod -Value {
#         param([String]$Path)
#         [Microsoft.Extensions.Configuration.YamlConfigurationExtensions]::AddYamlFile($this, $Path)
#     }
# }