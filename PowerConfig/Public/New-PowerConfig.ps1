using namespace Microsoft.Extensions

<#
.SYNOPSIS
    Create a new Powerconfig Object
#>
function New-PowerConfig {
    [CmdletBinding()]
    param()

    #TODO: Intelligent Defaults
    #BUG: For whatever reason, triggers on just [ConfigurationBuilder]::new()
    [Configuration.ConfigurationBuilder]::new()
}