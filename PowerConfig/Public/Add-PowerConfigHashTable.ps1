using namespace Microsoft.Extensions.Configuration
using namespace Microsoft.Extensions.Configuration.Memory
using namespace System.Collections
using namespace System.Collections.Generic

class HashTableConfigurationProvider : ConfigurationProvider {
    hidden [HashTableConfigurationSource]$source

    HashTableConfigurationProvider ($source) {
        $flatHashTable = ConvertTo-FlatHashTable $source.hashtable
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

function ConvertTo-FlatHashTable ([iDictionary]$Dictionary,[String]$delimiter) {
<#
.SYNOPSIS
Converts a nested hashtable into a set of key value pairs
#>
    $nameValuePairs = Get-FlatNameValuePairs -Delimiter $delimiter -InputObject $Dictionary
    $hashTable = @{}
    $nameValuePairs.foreach{
        $hashTable[$PSItem.Name] = $PSItem.Value
    }
    return $hashTable
}

function Get-FlatNameValuePairs {
    [CmdletBinding()]
    param(
        $InputObject,
        #Used for recursion to remember the path
        $pathStack = [Stack]::new(),
        $delimiter = ':'
    )
    process
    {
        if ($inputObject -is [iDictionary]) {
            $inputObject.GetEnumerator().Foreach{
                $pathStack.Push($PSItem.Name)
                Get-FlatNameValuePairs $PSItem $PathStack
            }
        } elseif ($inputObject.Value -is [iDictionary]) {
            $inputObject.Value.GetEnumerator().Foreach{
                $pathStack.Push($PSItem.Name)
                Get-FlatNameValuePairs $PSItem $PathStack
            }
            [void]$pathStack.Pop()
        } else {
            $pathStackArray = $pathStack.ToArray()
            [Array]::Reverse($pathStackArray)
            $keyName = $pathStackArray -join $delimiter
            if ($pathStack.count -gt 0) {
                [void]$pathStack.Pop()
            }
            return [DictionaryEntry]::new($keyName, $InputObject.Value)
        }
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