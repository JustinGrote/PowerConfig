#This is needed because assemblies must be loaded before classes that reference them in Windows Powershell 5.1
#It should be referenced from "ScriptsToProcess" in the manifest file

#PSES on Windows 5.1 is currently unsupported
try {
    if ([Microsoft.Extensions.Configuration.ConfigurationBuilder].Assembly.Location -match 'PowershellEditorServices') {
        throw [NotSupportedException]'Sorry, PowerConfig is currently not supported if Powershell Editor Services is loaded on Windows Powershell due to a conflict. See: https://github.com/PowerShell/PowerShellEditorServices/issues/1499'
    }
} catch {
    if ($PSItem.FullyQualifiedErrorId -ne 'TypeNotFound') {throw}
}

<#
.SYNOPSIS
Used to add automatic binding redirection to related modules for Powerconfig to redirect CompilerServices to the net5.0 assembly version
.NOTES
CompilerServices.Unsafe won't load without this
Reference: https://github.com/PowerShell/PowerShellStandard/issues/72
#>
if ($PSEdition -ne 'Desktop') {
    $bindingRedirectHandler = [ResolveEventHandler] {
        param($sender, $assembly)
        try {
            Write-Debug "BindingRedirectHandler: Resolving $($assembly.name)"
            #Skip Powershell Assemblies
            if ($assembly.name -like '*Management.Automation*') { return $null }
            $assemblyShortName = $assembly.name.split(',')[0]
            $matchingAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
                Where-Object fullname -Match ('^' + [Regex]::Escape($assemblyShortName))
            if ($matchingAssembly.count -eq 1) {
                Write-Debug "BindingRedirectHandler: Redirecting $($assembly.name) to $($matchingAssembly.Location)"
                return $MatchingAssembly
            }
        } catch {
            #Write-Error will blackhole, which is why write-host is required. This should never occur so it should be a red flag
            Write-Host -fore red "BindingRedirectHandler ERROR: $PSITEM"
            return $null
        }
        return $null
    }
    [Appdomain]::CurrentDomain.Add_AssemblyResolve($bindingRedirectHandler)
}

$libroot = "$PSScriptRoot/../lib"

#If this is a "debug build", use the assemblies from buildoutput
$debugLibPath = "$PSScriptRoot/../../BuildOutput/PowerConfig/lib"
if (Test-Path $debugLibPath) {
    $libroot = Resolve-Path $debugLibPath
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
