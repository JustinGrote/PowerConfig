function Register-BindingRedirectHandler {
<#
.SYNOPSIS
Used to add automatic binding redirection to related modules for Powerconfig, particularly the CompilerServices.Unsafe module
#>
    $bindingRedirectHandler = [ResolveEventHandler]{
        param($sender,$assembly)
        try {
            Write-Debug "BindingRedirectHandler: Resolving $($assembly.name)"
            $assemblyShortName = $assembly.name.split(',')[0]
            $matchingAssembly = [AppDomain]::CurrentDomain.GetAssemblies() |
                Where-Object fullname -match ("^" + [Regex]::Escape($assemblyShortName))
            if ($matchingAssembly.count -eq 1) {
                Write-Debug "BindingRedirectHandler: Redirecting $($assembly.name) to $($matchingAssembly.Location)"
                return $MatchingAssembly
            }
        } catch {
            #Write-Error will blackhole, which is why write-host is required. This should never occur so it should be a red flag
            write-host -fore red "BindingRedirectHandler ERROR: $PSITEM"
            return $null
        }
        return $null
    }
    [Appdomain]::CurrentDomain.Add_AssemblyResolve($bindingRedirectHandler)
}
