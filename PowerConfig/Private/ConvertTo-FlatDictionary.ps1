#Big Thanks to IISResetMe: https://gist.github.com/IISResetMe/2fdb0c7097545b4c86ddf60fe7fb5056#file-flatten-ps1-L5
function ConvertTo-FlatDictionary {
    [CmdletBinding()]
    param(
        [IDictionary]$Dictionary,
        [string]$KeyDelimiter = ':'
    )

    $newDict = @{}

    $stackOfTrees = [Stack]::new()
    foreach($kvp in $Dictionary.GetEnumerator()){
        $stackOfTrees.Push(@($kvp.Key,$kvp.Value))
    }

    while($stackOfTrees.Count -gt 0)
    {
        $prefix,$next = $stackOfTrees.Pop()
        if($next -is [IDictionary]){
            foreach($kvp in $next.GetEnumerator())
            {
                $stackOfTrees.Push(@("${prefix}${KeyDelimiter}$($kvp.Key)", $kvp.Value))
            }
        }
        else {
            $newDict["${prefix}"] = $next
        }
    }

    return $newDict
}