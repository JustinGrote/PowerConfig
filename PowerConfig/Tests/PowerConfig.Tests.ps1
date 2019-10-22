Describe "PowerConfig" {
    # Context "Yaml" {
    #     It "Adds a Yaml File" {
    #         New-PowerConfig | Add-PowerConfigYamlSource -Path (Join-Path $PSScriptRoot 'Mocks/Test.yaml') | Get-PowerConfig | Write-Host
    #     }
    # }

    if ($env:PowerCDModuleManifest) {Import-Module $env:PowerCDModuleManifest -Force}
    Context "Environment" {
        It "Finds Environment Variables" {
            $env:PowerConfigTest_Test1__OK = 5
            $env:PowerConfigTest_Test2 = 6
            New-PowerConfig | Add-PowerConfigEnvironmentVariableSource -Prefix PowerConfigTest_ | Get-PowerConfig | Write-Host
        }
    }

    Context "CommandLine" {
        It "Parses Command Line Arguments" {
            $argumentlist = "/test5=whatever","/test6","another","--config",'OK',"-c=test7"
            $argumentmap = @{'-c'='test7'}
            Add-PowerConfigCommandLineSource -InputObject (New-PowerConfig) -ArgumentMap $argumentMap -ArgumentList $argumentlist | Get-PowerConfig | write-host
        }
    }
}