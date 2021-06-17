using namespace Microsoft.Extensions.Configuration

<#
.SYNOPSIS
    Create a new Powerconfig Object
.EXAMPLE
New-PowerConfig -For Test
Will create a powerconfig that will merge in config files in this order:
<CurrentFolder>/Test.json
<CurrentFolder>/Test.yaml
<CurrentFolder>/Test.toml
$HOME/.config/Test.json
$HOME/.config/Test.yaml
$HOME/.config/Test.toml


Environment Variables Prefixed with Test_ e.g.:
TEST_MYSETTING
TEST_MYSETTING2
TEST_MYCATEGORY__MYSETTING
TEST_MYCATEGORY__MYSUBCATEGORY__MYSETTING

#>
function New-PowerConfig {
    [CmdletBinding()]
    param(
        # Provides a default configuration that looks for json/yaml/toml config files in:
        # 1. The same folder as the invoking script
        # 2. $HOME/.config/
        [ValidatePattern('^[a-zA-Z][a-zA-Z0-9]+?$')][String]$For
    )

    $configBuilder = [ConfigurationBuilder]::new()

    if ($For) {
        $configBuilder                                                                  |
            Add-PowerConfigJsonSource -Path $(Resolve-FullPath $PWD/$For.json)          |
            Add-PowerConfigYamlSource -Path $(Resolve-FullPath $PWD/$For.yaml)          |
            Add-PowerConfigTomlSource -Path $(Resolve-FullPath $PWD/$For.toml)          |
            Add-PowerConfigJsonSource -Path $(Resolve-FullPath $HOME/.config/$For.json) |
            Add-PowerConfigYamlSource -Path $(Resolve-FullPath $HOME/.config/$For.yaml) |
            Add-PowerConfigTomlSource -Path $(Resolve-FullPath $HOME/.config/$For.toml) |
            Add-PowerConfigEnvironmentVariableSource -Prefix "$($For.ToUpper())_"
    }

    return $configBuilder
}