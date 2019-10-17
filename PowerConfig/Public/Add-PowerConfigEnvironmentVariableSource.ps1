using namespace Microsoft.Extensions.Configuration
function Add-PowerConfigEnvironmentVariableSource {
    [CmdletBinding()]
    param (
        #The PowerConfig object to operate on
        [Microsoft.Extensions.Configuration.ConfigurationBuilder][Parameter(Mandatory,ValueFromPipeline)]$InputObject,
        #The prefix for your environment variables. Default is no prefix
        [String]$Prefix = ''
    )

    [EnvironmentVariablesExtensions]::AddEnvironmentVariables($InputObject, $Prefix)
}