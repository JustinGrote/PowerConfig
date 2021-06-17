Import-Module ../../PowerConfig/Powerconfig.psd1 -force
$f = New-PowerConfig -For Zoo
$f | Get-PowerConfig