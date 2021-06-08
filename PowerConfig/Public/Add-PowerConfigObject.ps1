using namespace Microsoft.Extensions.Configuration
function Add-PowerConfigObject {
    [CmdletBinding()]
    param (
        #The PowerConfig object to operate on
        [Microsoft.Extensions.Configuration.ConfigurationBuilder][Parameter(Mandatory,ValueFromPipeline)]$InputObject,
        #The hashtable to add to your configuration values. Use colons (:) to separate sections of configuration
        [Parameter(Mandatory)][Object]$Object,
        #How deep to go on nested properties. You should normally not touch this and instead filter your inputs first
        $Depth = 5,
        #Optional path to save the converted Json. This is normally a temporary file and you shouldn't need to change this.
        $JsonTempFile = [io.path]::GetTempFileName()
    )

    $WarningPreference = 'SilentlyContinue'
    $ObjectJson = $Object | ConvertTo-Json -Compress -ErrorAction Stop | Out-File -FilePath $JsonTempFile
    [JsonConfigurationExtensions]::AddJsonFile($InputObject,$JsonTempFile)

    #TODO: Use the stream method when we can bump to Configuration Extensions 3.0
    #$JsonStream = ConvertFrom-StringToMemoryStream $ObjectJson
    #[JsonConfigurationExtensions]::AddJsonStream($InputObject,$JsonStream)
}