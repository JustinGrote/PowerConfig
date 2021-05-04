#requires -module PowerConfig

Write-Host -fore Green "First, we start a new PowerConfig"
$c = New-PowerConfig

#Show the result
$c | Out-Default

Write-Host -fore Green "Now we add our JSON config"
$c | Add-PowerConfigJsonSource -Path (Resolve-Path config.json) | Out-Null

#Show the result
$c.sources | ft @{N='SourceType';E={$PSItem.Gettype().Name}},'Path'

Write-Host -fore Cyan "Now we can see that we have settings!"
$settings = $c | Get-PowerConfig

Write-Host "==Root=="
$settings | Out-Default | Write-Host

Write-Host "==ServerConfig=="
$settings.ServerConfig | Out-Default | Write-Host

Write-Host -fore Green "Now we add a YAML config"
$c | Add-PowerConfigYamlSource -Path (Resolve-Path config.yml) | Out-Null
#Show the result
$c.sources | ft @{N='SourceType';E={$PSItem.Gettype().Name}},'Path'

Write-Host -fore Cyan "Now our settings have merged! Later added sources take precedence over earlier ones"
$settings = $c | Get-PowerConfig

Write-Host "==Root=="
Write-Host -fore Cyan "Note: ClientConfig now exists!"
$settings | Out-Default | Write-Host

Write-Host "==ServerConfig=="
Write-Host -fore Cyan "Note: LovesDogs and IsAwesome were overwritten, and FavoriteHobby was added"
$settings.ServerConfig | Out-Default | Write-Host

Write-Host -fore Green "Lets start accepting environment variables!"
$c | Add-PowerConfigEnvironmentVariableSource -Prefix 'PCDEMO_' | Out-Null

#Nested settings are denoted with double underscores
$ENV:PCDEMO_ServerConfig__LovesDogs = 'Definitely!'

Write-Host -fore Cyan "LovesDogs has changed based on the environment variable!"
Write-Host "==ServerConfig=="
$c | Get-PowerConfig | % ServerConfig | Out-Default | Write-Host

Write-Host -fore Green "We can also use Powershell objects, either directly or imported from a .psd1! (This gets converted into json on the backend)"

$myconfig = Import-PowerShellDataFile ./config.psd1
$myconfig.ServerConfig.CurrentDate = [String](Get-Date)
$myconfig.ServerConfig.LovesDogs = 'Heck yeah!'
$c | Add-PowerConfigObject -Object $myconfig | Out-Null

Write-Host -Fore Cyan "Note: LikesPowershellObjects and CurrentDate were added, and LovesDogs changed"
$c | Get-PowerConfig | % ServerConfig | Out-Default | Write-Host


Write-Host "Now try changing the config files, the merged config will automatically update as config files are processed"