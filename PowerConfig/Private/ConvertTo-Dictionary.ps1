function ConvertTo-Dictionary {
    [CmdletBinding()]
    param (
        [System.Collections.HashTable]$Hashtable
    )
    #Make a string dictionary that the memorycollection requires
    $dictionary = [System.Collections.Generic.Dictionary[String,String]]::new()

    #Take the hashtable values and import them into the dictionary
    $hashtable.keys.foreach{
        $null = $Dictionary.Add($PSItem,$HashTable[$PSItem])
    }

    return $dictionary
}