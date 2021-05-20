#requires -module PowerConfig
#Abbreviated Setup

$myconfig = Import-PowerShellDataFile ./config.psd1
$myconfig.ServerConfig.CurrentDate = [String](Get-Date)
$myconfig.ServerConfig.LovesDogs = 'Heck yeah!'

$config = New-PowerConfig
| Add-PowerConfigJsonSource -Path (Resolve-Path ./config.json)
| Add-PowerConfigYamlSource -Path (Resolve-Path ./config.yml)
| Add-PowerConfigTomlSource -Path (Resolve-Path ./config.toml)
| Add-PowerConfigEnvironmentVariableSource -Prefix 'PCDEMO_'
| Add-PowerConfigObject -Object $myconfig


($config | Get-PowerConfig)
($config | Get-PowerConfig).ServerConfig
($config | Get-PowerConfig).ClientConfig