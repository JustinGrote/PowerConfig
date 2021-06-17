function Resolve-FullPath {
<#
.SYNOPSIS
Similar to Resolve-Path without erroring if the path doesn't exist
#>

    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)][String]$Path
    )
    return [IO.Path]::GetFullPath($Path)
}