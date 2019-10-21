using namespace Microsoft.Extensions.Configuration
function Get-PowerConfig {
    param (
        [Microsoft.Extensions.Configuration.ConfigurationBuilder][Parameter(Mandatory,ValueFromPipeline)]$InputObject
    )

    $RenderedPowerConfig = $InputObject.build()
    [ConfigurationExtensions]::AsEnumerable($RenderedPowerConfig)
}