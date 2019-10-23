Describe "PowerConfig" {
    if ($env:PowerCDModuleManifest) {Import-Module $env:PowerCDModuleManifest -Force}

    Context "Yaml" {
        It "Reads a Yaml File" {
            $yamlConfig = New-PowerConfig | Add-PowerConfigYamlSource -Path (Join-Path $PSScriptRoot 'Mocks/Test.yaml') | Get-PowerConfig
            $yamlConfig | Should -BeOfType System.Collections.Specialized.OrderedDictionary
            $yamlConfig.environment.level1.level2 | Should -Be 'Level2Value'
            $yamlConfig.test.test1 | Should -Be 'test'
        }
    }

    Context "Json" {
        It "Reads a Json File" {
            $yamlConfig = New-PowerConfig | Add-PowerConfigJsonSource -Path (Join-Path $PSScriptRoot 'Mocks/Test.json') | Get-PowerConfig
            $yamlConfig | Should -BeOfType System.Collections.Specialized.OrderedDictionary
            $yamlConfig.environment.level1.level2 | Should -Be 'Level2Value'
            $yamlConfig.test.test1 | Should -Be 'test'
        }
    }
    
    Context "Environment" {
        It "Processes Environment Variables" {
            $env:PowerConfigTest_Test1__OK = 5
            $env:PowerConfigTest_Test2 = 6
            $envConfig = New-PowerConfig | Add-PowerConfigEnvironmentVariableSource -Prefix PowerConfigTest_ | Get-PowerConfig
            $envConfig.Test2 | Should -be 6
            $envConfig.Test1.OK | Should -be 5
        }
    }

    Context "CommandLine" {
        It "Parses Command Line Arguments" {
            $argumentlist = "/test5=whatever","/test6","another","--config",'OK',"-c=test7"
            $argumentmap = @{'-c'='test7'}
            $cmdLineConfig = Add-PowerConfigCommandLineSource -InputObject (New-PowerConfig) -ArgumentMap $argumentMap -ArgumentList $argumentlist | Get-PowerConfig
            $cmdLineConfig.test5 | Should -be 'whatever'
            $cmdLineConfig.test6 | Should -be 'another'
            $cmdLineConfig.test7 | Should -be 'test7'
            $cmdLineConfig.config | Should -be 'OK'
        }
    }

    Context "Object" {
        It "Accepts a generic Object" {
            $h = @{test1=1;test2=2;test3=@{test4=4}}
            $objConfig = Add-PowerConfigObject -InputObject (New-PowerConfig) -Object $h | Get-PowerConfig
            $objConfig.test1 | Should -Be 1
            $objConfig.test3.test4 | Should -Be 4
        }
    }

    Context "Overrides" {
        $myconfig = New-PowerConfig | Add-PowerConfigYamlSource -Path (Join-Path $PSScriptRoot 'Mocks/Test.yaml')
        
        It "Loads the base yaml file" {
            (Get-PowerConfig $myconfig).override.overrideme | Should -Be 'yaml'
            (Get-PowerConfig $myconfig).overrideme | Should -Be 'yaml'
        }

        It "Loads the json and overrides existing values" {
            $myconfig | Add-PowerConfigJsonSource -Path (Join-Path $PSScriptRoot 'Mocks/Test.json')
            (Get-PowerConfig $myconfig).override.overrideme | Should -Be 'json'
            (Get-PowerConfig $myconfig).overrideme | Should -Be 'json'
        }

        It "Loads a generic PSObject and overrides existing values" {
            $myconfig | Add-PowerConfigObject -Object ([PSCustomObject]@{overrideme='psobject';override=@{overrideme='psobject'}})
            (Get-PowerConfig $myconfig).override.overrideme | Should -Be 'psobject'
            (Get-PowerConfig $myconfig).overrideme | Should -Be 'psobject'
        }

        It "Detects an environment variable change and processes the override" {
            $ENV:PowerConfigPester_overrideme = $null
            $ENV:PowerConfigPester_override__overrideme = $null
            $myConfig | Add-PowerConfigEnvironmentVariableSource -Prefix 'PowerConfigPester_'
            (Get-PowerConfig $myconfig).override.overrideme | Should -Be 'psobject'
            $ENV:PowerConfigPester_overrideme = 'env'
            $ENV:PowerConfigPester_override__overrideme = 'env'
            (Get-PowerConfig $myconfig).overrideme | Should -Be 'env'
            (Get-PowerConfig $myconfig).override.overrideme | Should -Be 'env'
        }
    }

    Context "Complex Settings Object" {
        $myConfig = New-PowerConfig | Add-PowerConfigObject -Object (Import-Clixml -Path (Join-Path $PSScriptRoot 'Mocks/SettingsExample.clixml')) | Get-PowerConfig
        It "Loads the Object Config" {
            $myConfig | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
        }
        It "Can read multiple parts of the config successfully" {
            $myConfig.general.projectroot | should -Be 'C:\Users\JGrote\Documents\Github\PowerCD'
            $myConfig.general.modulename | should -Be 'PowerCD'
            $myConfig.build.moduleoutdir = 'C:\Users\JGrote\Documents\Github\PowerCD\BuildOutput'
            $myConfig.build.outdir = 'C:\Users\JGrote\Documents\Github\PowerCD\BuildOutput'
        }
    }
}