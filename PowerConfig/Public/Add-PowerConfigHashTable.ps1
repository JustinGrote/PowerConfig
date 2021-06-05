using namespace Microsoft.Extensions.Configuration
using namespace Microsoft.Extensions.Configuration.Memory
using namespace System.Collections
using namespace System.Collections.Generic

class HashTableConfigurationProvider : ConfigurationProvider {
    hidden [HashTableConfigurationSource]$source

    HashTableConfigurationProvider ($source) {
        $flatHashTable = ConvertTo-FlatDictionary $source.hashtable
        $flatHashTable.GetEnumerator().Foreach{
            $this.Set($PSItem.Name, $PSItem.Value)
        }
    }
}

class HashTableConfigurationSource : IConfigurationSource {
    #The hashtable reference that will be used for the memoryconfigsource
    [hashtable]$hashtable
    HashTableConfigurationSource ([hashtable]$hashtable) {
        $this.hashtable = $hashtable
    }

    [IConfigurationProvider] Build([IConfigurationBuilder]$builder) {
        return [HashTableConfigurationProvider]::new($this)
    }
}

function Add-PowerConfigHashTable {
    [CmdletBinding()]
    param (
        #The PowerConfig object to operate on
        [Microsoft.Extensions.Configuration.ConfigurationBuilder][Parameter(Mandatory,ValueFromPipeline)]$InputObject,
        #The hashtable to add to your configuration values. Use colons (:) to separate sections of configuration.
        [Parameter(Mandatory,Position=0)][Hashtable]$Object
    )

    $InputObject.Add(
        [HashTableConfigurationSource]::new($Object)
    )
}