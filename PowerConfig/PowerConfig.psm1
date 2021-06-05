
#region SourceInit
$PSDebugBuild = $true
#endregion SourceInit

$libroot = Resolve-Path "$PSScriptRoot/lib"
if ($PSDebugBuild) {
    $libroot = Resolve-Path "$PSScriptRoot/../BuildOutput/PowerConfig/lib"
}

$libPath = Resolve-Path $(
    if ($PSEdition -eq 'Desktop') {
        "$libroot/netstandard2.0"
    } else {
        "$libroot/net5.0"
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
# $bindingRedirectHandler = [ResolveEventHandler]{
#     param($sender,$assembly)
#     try {
#         Write-Debug "BindingRedirectHandler: Resolving $($assembly.name)"
#         $assemblyShortName = $assembly.name.split(',')[0]
#         $matchingAssembly = [System.AppDomain]::CurrentDomain.GetAssemblies() | Where-Object fullname -match ("^" + [Regex]::Escape($assemblyShortName))
#         if ($matchingAssembly.count -eq 1) {
#             Write-Debug "BindingRedirectHandler: Redirecting $($assembly.name) to $($matchingAssembly.Location)"
#             return $MatchingAssembly
#         }
#     } catch {
#         #Write-Error will blackhole, which is why write-host is required. This should never occur so it should be a red flag
#         write-host -fore red "BindingRedirectHandler ERROR: $PSITEM"
#         return $null
#     }
#     return $null
# }
# [Appdomain]::CurrentDomain.Add_AssemblyResolve($bindingRedirectHandler)


# if ('AddYamlFile' -notin (get-typedata "Microsoft.Extensions.Configuration.ConfigurationBuilder").members.keys) {
#     Update-TypeData -TypeName Microsoft.Extensions.Configuration.ConfigurationBuilder -MemberName AddYamlFile -MemberType ScriptMethod -Value {
#         param([String]$Path)
#         [Microsoft.Extensions.Configuration.YamlConfigurationExtensions]::AddYamlFile($this, $Path)
#     }
# }