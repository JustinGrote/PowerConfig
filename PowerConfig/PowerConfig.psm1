#Load Assemblies
if (Test-Path $PSScriptRoot/lib) {
    Add-Type -Path $PSScriptRoot/lib/*.dll
}

Update-TypeData -TypeName Microsoft.Extensions.Configuration.ConfigurationBuilder -MemberName AddYamlFile -MemberType ScriptMethod -Value {
    param([String]$Path)
    [Microsoft.Extensions.Configuration.YamlConfigurationExtensions]::AddYamlFile($this, $Path)
}