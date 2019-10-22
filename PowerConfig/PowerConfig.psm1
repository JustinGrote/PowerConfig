#Load Assemblies
if (Test-Path $PSScriptRoot/lib) {
    Add-Type -Path $PSScriptRoot/lib/*.dll
}


<#
.SYNOPSIS
Loads modules with a dynamic binding redirect, overriding their prepared assembly version. 
.DESCRIPTION
This is useful if you want to use a package you know is compatible with an upstream version but has a non-explicit dependency
.NOTES
This does not work for assemblies native to Powershell or Pwsh, you will probably get an "already loaded" error
#>
# function Import-Assembly {
#     [CmdletBinding()]
#     param(
#         #Path to the dependency that you wish to add a binding redirect for
#         [Parameter(Mandatory)][String[]]$Path,
#         #Path to the assembly or assemblies you wish to load after the binding redirect has been created
#         [Parameter(Mandatory)][String[]]$AssembliesToLoad
#     )


#      $RedirectedAssemblies = $Path.Foreach{
#         $Assembly = [Reflection.Assembly]::LoadFrom($PSItem)
#         $AssemblyName = ($Assembly.FullName -split ',')[0]
#         $RedirectedAssemblies[$AssemblyName] = $Assembly
#     }

#     $onAssemblyResolveEventHandler = [System.ResolveEventHandler] {
#         param($sender, $assemblyToResolve)
#         write-host -fore Magenta ($assemblyToResolve | fl -prop * -force | out-string)

#         return $null
#     }
# }

# # Load your target version of the assembly
# $newtonsoft = [System.Reflection.Assembly]::LoadFrom("C:\Users\JGrote\Documents\Github\PowerConfig\BuildOutput\PowerConfig\0.1.0\lib\Newtonsoft.Json.dll")
# $onAssemblyResolveEventHandler = [System.ResolveEventHandler] {
#   param($sender, $e)
#   # You can make this condition more or less version specific as suits your requirements
#   if ($e.Name.StartsWith("Microsoft.Extensions.Configuration.FileExtensions")) {
#     return $newtonsoft
#   }
#   foreach($assembly in [System.AppDomain]::CurrentDomain.GetAssemblies()) {
#     if ($assembly.FullName -eq $e.Name) {
#       return $assembly
#     }
#   }
#   return $null
# }
# [System.AppDomain]::CurrentDomain.add_AssemblyResolve($onAssemblyResolveEventHandler)

# # Rest of your script....

# # Detach the event handler (not detaching can lead to stack overflow issues when closing PS)
# [System.AppDomain]::CurrentDomain.remove_AssemblyResolve($onAssemblyResolveEventHandler)

#Add Back Extension Methods for ease of use

if ('AddYamlFile' -notin (get-typedata "Microsoft.Extensions.Configuration.ConfigurationBuilder").members.keys) {
    Update-TypeData -TypeName Microsoft.Extensions.Configuration.ConfigurationBuilder -MemberName AddYamlFile -MemberType ScriptMethod -Value {
        param([String]$Path)
        [Microsoft.Extensions.Configuration.YamlConfigurationExtensions]::AddYamlFile($this, $Path)
    }
}
