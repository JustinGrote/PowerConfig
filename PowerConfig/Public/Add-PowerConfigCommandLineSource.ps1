using namespace Microsoft.Extensions.Configuration
function Add-PowerConfigCommandLineSource {
    [CmdletBinding(PositionalBinding=$false)]
    param (
        #The PowerConfig object to operate on
        [Microsoft.Extensions.Configuration.ConfigurationBuilder][Parameter(Mandatory)]$InputObject,
        # A hashtable that remaps arguments to their intented destination, for instance @{'-f'='force'} remaps the shorthand -f to the force key
        [HashTable]$ArgumentMap,
        #The arguments that were passed to your script. You can pass the arguments directly to this script, or supply them as a variable similar to $args (an array of strings, one statement per string)
        [Parameter(Mandatory,ValueFromRemainingArguments)]$ArgumentList
    )

    #Couldn't cast a hashtable directly because it was seeing it as new properties, so here is a workaround
    $ArgumentMapDictionary = [Collections.Generic.Dictionary[String,String]]::new()
    $ArgumentMap.keys.foreach{
        $ArgumentMapDictionary[$PSItem] = $ArgumentMap[$PSItem]
    }

    [CommandLineConfigurationExtensions]::AddCommandLine($InputObject, $ArgumentList, $ArgumentMapDictionary)
}