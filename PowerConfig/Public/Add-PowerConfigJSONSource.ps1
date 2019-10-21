using namespace Microsoft.Extensions.Configuration
function Add-PowerConfigJsonSource {
    [CmdletBinding()]
    param (
        #The PowerConfig object to operate on
        [Microsoft.Extensions.Configuration.ConfigurationBuilder][Parameter(Mandatory,ValueFromPipeline)]$InputObject,
        #The prefix for your environment variables. Default is no prefix
        [Parameter(Mandatory)]$Path,
        #Specify this parameter if the configuration file is mandatory. PowerConfig will show an error if this file is not present.
        [Switch]$Mandatory,
        #By default, if the file changes the configuration will automatically be updated. If you want to disable this behavior, specify this parameter.
        [Switch]$NoRefresh
    )

    [JsonConfigurationExtensions]::AddJsonFile($InputObject, $Path, !$Mandatory, !$NoRefresh)
}