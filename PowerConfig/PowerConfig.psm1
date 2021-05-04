#Load Assemblies
function Import-Assembly {
<#
.SYNOPSIS
Adds Binding Redirects for Certain Assemblies to make them more flexibly compatible with Windows Powershell
#>
    [CmdletBinding()]
    param(
        #Path to the dependencies that you wish to add a binding redirect for
        [Parameter(Mandatory)][IO.FileInfo[]]$Path
    )
    if ($PSEdition -ne 'Desktop') {
        Write-Warning "Import-Assembly is only required on Windows Powershell and not Powershell Core. Skipping..."
        return
    }

    $pathAssemblies = $path.foreach{
        [reflection.assemblyname]::GetAssemblyName($PSItem)
    }
    $loadedAssemblies = [AppDomain]::CurrentDomain.GetAssemblies()
    #Bootstrap the required types in case this loads really early
    $null = Add-Type -AssemblyName mscorlib

    $onAssemblyResolveEventHandler = [ResolveEventHandler] {
        param($sender, $assemblyToResolve)

        try {
            $ErrorActionPreference = 'stop'
            [String]$assemblyToResolveStrongName = $AssemblyToResolve.Name
            [String]$assemblyToResolveName = $assemblyToResolveStrongName.split(',')[0]
            Write-Verbose "Import-Assembly: Resolving $AssemblyToResolveStrongName"

            #Try loading from our custom assembly list
            $bindingRedirectMatch = $pathAssemblies.where{
                $PSItem.Name -eq $assemblyToResolveName
            }
            if ($bindingRedirectMatch) {
                Write-Verbose "Import-Assembly: Creating a 'binding redirect' to $BindingRedirectMatch"
                return [reflection.assembly]::LoadFrom($bindingRedirectMatch.CodeBase)
            }

            #Bugfix for System.Management.Automation.resources which comes up from time to time
            #TODO: Find the underlying reason why it asks for en instead of en-us
            if ($AssemblyToResolveStrongName -like 'System.Management.Automation.Resources*') {
                $AssemblyToResolveStrongName = $AssemblyToResolveStrongName -replace 'Culture\=en\-us', 'Culture=en'
                Write-Verbose "BUGFIX: $AssemblyToResolveStrongName"
            }

            Add-Type -AssemblyName $AssemblyToResolveStrongName -ErrorAction Stop
            return [System.AppDomain]::currentdomain.GetAssemblies() | Where-Object fullname -eq $AssemblyToResolveStrongName
            #Add Type doedsn't Assume successful and return the object. This will be null if it doesn't exist and will fail resolution anyways

        } catch {
            Write-Host -fore red "Error finding $AssemblyToResolveName`: $($PSItem.exception.message)"
            return $null
        }

        #Return a null as a last resort
        return $null
    }
    [AppDomain]::CurrentDomain.add_AssemblyResolve($onAssemblyResolveEventHandler)

    Add-Type -Path $Path

    [System.AppDomain]::CurrentDomain.remove_AssemblyResolve($onAssemblyResolveEventHandler)
}

$ImportAssemblies = Get-Item "$PSScriptRoot/lib/*.dll"
if ($PSEdition -eq 'Desktop') {
    Import-Assembly -Path $ImportAssemblies
} else {
    Add-Type -Path $ImportAssemblies
}

#Add Back Extension Methods for ease of use
#TODO: Make this a method


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