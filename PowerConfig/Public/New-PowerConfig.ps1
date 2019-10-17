using namespace Microsoft.Extensions.Configuration

<#
.SYNOPSIS
    Create a new Powerconfig Object
#>
function New-PowerConfig {
    [CmdletBinding()]
    param()

    #TODO: Intelligent Defaults
    [ConfigurationBuilder]::new()
}