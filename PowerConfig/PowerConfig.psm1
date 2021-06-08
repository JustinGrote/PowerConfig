
#PSES on Windows 5.1 is currently unsupported
try {
    if ([Microsoft.Extensions.Configuration.ConfigurationBuilder].Assembly.Location -match 'PowershellEditorServices') {
        throw [NotSupportedException]'Sorry, PowerConfig is currently not supported if Powershell Editor Services is loaded on Windows Powershell due to a conflict. See: https://github.com/PowerShell/PowerShellEditorServices/issues/1499'
    }
} catch {
    if ($PSItem.FullyQualifiedErrorId -ne 'TypeNotFound') {throw}
}

$libroot = Resolve-Path "$PSScriptRoot/lib"

#If this is a "debug build", use the assemblies from buildoutput
if (Test-Path "$PSScriptRoot/../BuildOutput/PowerConfig/lib") {
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

# if ('AddYamlFile' -notin (get-typedata "Microsoft.Extensions.Configuration.ConfigurationBuilder").members.keys) {
#     Update-TypeData -TypeName Microsoft.Extensions.Configuration.ConfigurationBuilder -MemberName AddYamlFile -MemberType ScriptMethod -Value {
#         param([String]$Path)
#         [Microsoft.Extensions.Configuration.YamlConfigurationExtensions]::AddYamlFile($this, $Path)
#     }
# }


