<#
.SYNOPSIS
Takes an enumerable keyvaluepair from Microsoft.Extensions.Configuration and converts it to a nested hashtable
#>

#Create a "type accelerator" of sorts
class SortedDictionary : System.Collections.Generic.SortedDictionary[string,object] {}

function ConvertTo-NestedHashTable {
    [CmdletBinding()]
    param (
        [Collections.Generic.KeyValuePair[String,String][]]$InputObject
    )

    #First group the entries by hierarchy
    $depthGroups = $InputObject | Group-Object {
        $PSItem.key.split(':').count
    }
    $result = [ordered]@{}

    foreach ($DepthItem in $DepthGroups) {
        $depth = $DepthItem.Name
        foreach ($ConfigItem in ($DepthItem.Group)) {
            $ConfigItemLevels = $ConfigItem.key.split(':')

            #Iterate through the levels and create them if not already present
            $lastLevel = $result
            For ($i=0;$i -lt ($ConfigItemLevels.count -1);$i++) {
                if ($lastLevel[$ConfigItemLevels[$i]] -isnot [hashtable]) {
                    $lastLevel[$ConfigItemLevels[$i]] = [ordered]@{}
                }
                #Step up to the new level for the next activity
                $lastLevel = $lastLevel[$ConfigItemLevels[$i]]
            }

            #Assign the value now that the levels have been created
            $valueKey = $ConfigItemLevels[($ConfigItemLevels.count -1)]
            $lastLevel.$valueKey = $ConfigItem.Value
        }
    }

    return $result
}