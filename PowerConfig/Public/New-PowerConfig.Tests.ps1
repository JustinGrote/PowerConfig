Describe "New-PowerConfig" {
    BeforeAll {
        Import-Module (Resolve-Path $PSScriptRoot\..\PowerConfig.psd1) -Force
    }

    It 'Accepts "<_>" for the For Parameter' {
        {New-PowerConfig -For $_} | Should -Throw
    } -TestCases @(
        'spaces '
        ' spaces'
        ' spaces '
        'specia!lcharacters'
        '_underscores'
        '1234StartsWithNumber'
    )

    It 'Does not Accept "<_>" for the For Parameter' {
        New-PowerConfig -For $_
    } -TestCases @(
        'alph3Numerics'
        'lowercase'
        'UPPERCASE'
        'CoMBINaTION'
    )

}