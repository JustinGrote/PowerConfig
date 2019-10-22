using namespace System.IO
using namespace System.IO.Path
function GenerateAzDevopsMatrix {
    $os = @(
        'windows-latest'
        'vs2017-win2016'
        'ubuntu-latest'
        'macOS-latest'
    )

    $psversion = @(
        'pwsh'
        'powershell'
    )

    $exclude = 'ubuntu-latest-powershell','macOS-latest-powershell'

    $entries = @{}
    foreach ($osItem in $os) {
        foreach ($psverItem in $psversion) {
            $entries."$osItem-$psverItem" = @{os=$osItem;psversion=$psverItem}
        }
    }

    $exclude.foreach{
        $entries.Remove($PSItem)
    }

    $entries.keys | sort | foreach {
        "      $PSItem`:"
        "        os: $($entries[$PSItem].os)"
        "        psversion: $($entries[$PSItem].psversion)"
    }

}


#requires -Version 2.0
<#
    .NOTES
    ===========================================================================
     Filename              : Merge-Hashtables.ps1
     Created on            : 2014-09-04
     Created by            : Frank Peter Schultze
    ===========================================================================

    .SYNOPSIS
        Create a single hashtable from two hashtables where the second given
        hashtable will override.

    .DESCRIPTION
        Create a single hashtable from two hashtables. In case of duplicate keys
        the function the second hashtable's key values "win". Merge-Hashtables
        supports nested hashtables.

    .EXAMPLE
        $configData = Merge-Hashtables -First $defaultData -Second $overrideData

    .INPUTS
        None

    .OUTPUTS
        System.Collections.Hashtable
#>
function Merge-Hashtables
{
    [CmdletBinding()]
    Param
    (
        #Identifies the first hashtable
        [Parameter(Mandatory=$true)]
        [Hashtable]
        $First
    ,
        #Identifies the second hashtable
        [Parameter(Mandatory=$true)]
        [Hashtable]
        $Second
    )

    function Set-Keys ($First, $Second)
    {
        @($First.Keys) | Where-Object {
            $Second.ContainsKey($_)
        } | ForEach-Object {
            if (($First.$_ -is [Hashtable]) -and ($Second.$_ -is [Hashtable]))
            {
                Set-Keys -First $First.$_ -Second $Second.$_
            }
            else
            {
                $First.Remove($_)
                $First.Add($_, $Second.$_)
            }
        }
    }

    function Add-Keys ($First, $Second)
    {
        @($Second.Keys) | ForEach-Object {
            if ($First.ContainsKey($_))
            {
                if (($Second.$_ -is [Hashtable]) -and ($First.$_ -is [Hashtable]))
                {
                    Add-Keys -First $First.$_ -Second $Second.$_
                }
            }
            else
            {
                $First.Add($_, $Second.$_)
            }
        }
    }

    # Do not touch the original hashtables
    $firstClone  = $First.Clone()
    $secondClone = $Second.Clone()

    # Bring modified keys from secondClone to firstClone
    Set-Keys -First $firstClone -Second $secondClone

    # Bring additional keys from secondClone to firstClone
    Add-Keys -First $firstClone -Second $secondClone

    # return firstClone
    $firstClone
}


function Select-HashTable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory,ValueFromPipeline)][Hashtable]$Hashtable,
        [String[]]$Include,
        [String[]]$Exclude
    )

    if (-not $Include) {$Include = $HashTable.Keys}

    $filteredHashTable = @{}
    $HashTable.keys.where{
        $PSItem -in $Include
    }.where{
        $PSItem -notin $Exclude
    }.foreach{
        $filteredHashTable[$PSItem] = $HashTable[$PSItem]
    }
    return $FilteredHashTable
}
<#
.SYNOPSIS
This function prepares a powershell module from a source powershell` module directory
.DESCRIPTION
This function can also optionally "compile" the module, which is place all relevant powershell code in a single .psm1 file. This improves module load performance.
If you choose to compile, place any script lines you use to dot-source the other files in your .psm1 file into a #region SourceInit region block, and this function will replace it with the "compiled" scriptblock
#>
function Build-PowerCDModule {
    [CmdletBinding()]
    param (
        #Path to the Powershell Module Manifest representing the file you wish to compile
        $PSModuleManifest = $PCDSetting.BuildEnvironment.PSModuleManifest,
        #Path to the build destination. This should be non-existent or deleted by Clean prior
        $Destination = $pcdSetting.BuildModuleOutput,
        #By Default this command expects a nonexistent destination, specify this to allow for a "Dirty" copy
        [Switch]$Force,
        #By default, the build will consolidate all relevant module files into a single .psm1 file. This enables the module to load faster. Specify this if you want to instead copy the files as-is
        [Switch]$NoCompile,
        #If you chose compile, specify this for the region block in your .psm1 file to replace with the compiled code. If not specified, it will just append to the end of the file. Defaults to 'SourceInit' for #region SourceInit
        [String]$SourceRegionName = 'SourceInit',
        #Files that are considered for inclusion to the 'compiled' module. This by default includes .ps1 files only. Uses Filesystem Filter syntax
        [String[]]$PSFileInclude = '*.ps1',
        #Files that are considered for inclusion to the 'compiled' module. This excludes any files that have two periods before ps1 (e.g. .build.ps1, .tests.ps1). Uses Filesystem Filter syntax
        [String[]]$PSFileExclude = '*.*.ps1',
        #If a prerelease tag exists, the build will touch a prerelease warning file into the root of the module folder. Specify this parameter to disable this behavior.
        [Switch]$NoPreReleaseFile
    )

    $SourceModuleDir = Split-Path $PSModuleManifest

    #Verify a clean build folder
    try {
        $DestinationDirectory = New-Item -ItemType Directory -Path $Destination -ErrorAction Stop
    } catch [IO.IOException] {
        if ($PSItem.exception.message -match 'already exists\.$') {
            throw "Folder $Destination already exists. Make sure that you cleaned your Build Output directory. To override this behavior, specify -Force"
        } else {
            throw $PSItem
        }
    }

    #TODO: Use this one command and sort out the items later
    #$FilesToCopy = Get-ChildItem -Path $PSModuleManifestDirectory -Filter '*.ps*1' -Exclude '*.tests.ps1' -Recurse

    $SourceManifest = Import-PowershellDataFile -Path $PSModuleManifest

    #TODO: Allow .psm1 to be blank and generate it on-the-fly
    if (-not $SourceManifest.RootModule) {throw "The source manifest at $PSModuleManifest does not have a RootModule specified. This is required to build the module."}
    $SourceRootModulePath = Join-Path $SourceModuleDir $sourceManifest.RootModule
    $SourceRootModule = Get-Content -Raw $SourceRootModulePath

    $pcdSetting.ModuleManifest = $SourceManifest

    #Cannot use Copy-Item Directly because the filtering isn't advanced enough (can't exclude)
    $SourceFiles = Get-ChildItem -Path $SourceModuleDir -Include $PSFileInclude -Exclude $PSFileExclude -File -Recurse
    if (-not $NoCompile) {
        #TODO: Apply ordering if important (e.g. classes)

        #Collate the files, pulling out using lines because these have to go first
        [String[]]$UsingLines = @()
        [String]$CombinedSourceFiles = ((Get-Content -Raw $SourceFiles) -split '\r?\n' | Where-Object {
            if ($_ -match '^using .+$') {
                $UsingLines += $_
                return $false
            }
            return $true
        }) -join [Environment]::NewLine

        #If a SourceInit region was set, inject the files there, otherwise just append to the end.
        $sourceRegionRegex = "(?s)#region $SourceRegionName.+#endregion $SourceRegionName"
        if ($SourceRootModule -match $sourceRegionRegex) {
            #Need to escape the $ in the replacement string
            $RegexEscapedCombinedSourceFiles = [String]$CombinedSourceFiles.replace('$','$$')
            $SourceRootModule = $SourceRootModule -replace $sourceRegionRegex,$RegexEscapedCombinedSourceFiles
        } else {
            #Just add them to the end of the file
            $SourceRootModule += [Environment]::NewLine + $CombinedSourceFiles
        }

        #Use a stringbuilder to piece the portions of the config back together, with using statements up-front
        [Text.StringBuilder]$OutputRootModule = ''
        $UsingLines | Select-Object -Unique | Foreach-Object {
            [void]$OutputRootModule.AppendLine($PSItem)
        }
        [void]$OutputRootModule.AppendLine($SourceRootModule)
        [String]$SourceRootModule = $OutputRootModule

        #Strip non-help-related comments and whitespace
        #[String]$SourceRootModule = Remove-CommentsAndWhiteSpace $SourceRootModule
    } else {
        #TODO: Track all files in the source directory to ensure none get missed on the second step

        #In order to get relative paths we have to be in the directory we want to be relative to
        Push-Location (Split-Path $PSModuleManifest)

        $SourceFiles | Foreach-Object {
            #Powershell 6+ Preferred way.
            #TODO: Enable when dropping support for building on 5.x
            #$RelativePath = [io.path]::GetRelativePath($SourceModuleDir,$PSItem.fullname)

            #Powershell 3.x compatible "Ugly" Regex method
            #$RelativePath = $PSItem.FullName -replace [Regex]::Escape($SourceModuleDir),''

            $RelativePath = Resolve-Path $PSItem.FullName -Relative

            #Copy-Item doesn't automatically create directory structures when copying files vs. directories
            $DestinationPath = Join-Path $DestinationDirectory $RelativePath
            $DestinationDir = Split-Path $DestinationPath
            if (-not (Test-Path $DestinationDir)) {New-Item -ItemType Directory $DestinationDir > $null}
            Copy-Item -Path $PSItem -Destination $DestinationPath
        }

        #Return after processing relative paths
        Pop-Location
    }

    #Output the (potentially) modified Root Module
    $SourceRootModule | Out-File -FilePath (join-path $DestinationDirectory $SourceManifest.RootModule)

    #Copy the Module Manifest
    [String]$PCDSetting.OutputModuleManifest = Copy-Item -PassThru -Path $PSModuleManifest -Destination $DestinationDirectory
    $ENV:PowerCDModuleManifest = $PCDSetting.OutputModuleManifest

    #Add a prerelease
    if ($PCDSetting.PreRelease) {
        "This is a prerelease build and not meant for deployment!" > (Join-Path $DestinationDirectory "PRERELEASE-$($PCDSetting.VersionLabel)")
    }


}
function Compress-PowerCDModule {
    [CmdletBinding()]
    param(
        #Path to the directory to archive
        [Parameter(Mandatory)]$Path,
        #Output for Zip File Name
        [Parameter(Mandatory)]$Destination
    )

    $CompressArchiveParams = @{
        Path = $Path
        DestinationPath = $Destination
    }

    $CurrentProgressPreference = $GLOBAL:ProgressPreference
    $GLOBAL:ProgressPreference = 'SilentlyContinue'
    Compress-Archive @CompressArchiveParams
    $GLOBAL:ProgressPreference = $CurrentProgressPreference
    write-verbose ("Zip File Output:" + $CompressArchiveParams.DestinationPath)
}
<#
.SYNOPSIS
Fetch the names of public functions in the specified folder using AST
.DESCRIPTION
This is a better method than grabbing the names of the .ps1 file and "hoping" they line up.
This also only gets parent functions, child functions need not apply
#>

function Get-PowerCDPublicFunctions {
    [CmdletBinding()]
    param(
        #The path to the public module directory containing the modules. Defaults to the "Public" folder where the source module manifest resides.
        [String]$PublicModulePath = (Join-Path (Split-Path $PCDSetting.BuildEnvironment.PSModuleManifest) 'Public')
    )

    $PublicFunctionCode = Get-ChildItem $PublicModulePath -Filter '*.ps1'

    #using statements have to be first, so we have to pull them out and move them to the top
    [String[]]$UsingLines = @()
    [String]$PublicFunctionCodeWithoutUsing = (Get-Content $PublicFunctionCode.FullName | Where-Object {
        if ($_ -match '^using .+$') {
            $UsingLines += $_
            return $false
        }
        return $true
    }) -join [Environment]::NewLine

    #Rebuild PublicFunctionCode with a stringbuilder to put all the using up top
    [Text.StringBuilder]$PublicFunctionCode = ''
    $UsingLines | Select-Object -Unique | Foreach-Object {
        [void]$PublicFunctionCode.AppendLine($PSItem)
    }
    [void]$PublicFunctionCode.AppendLine($PublicFunctionCodeWithoutUsing)

    [ScriptBlock]::Create($PublicFunctionCode).AST.EndBlock.Statements | Where-Object {
        $PSItem -is [Management.Automation.Language.FunctionDefinitionAst]
    } | Foreach-Object Name
}
#TODO: Move this to Microsoft.Extensions.Configuration
function Get-PowerCDSetting {
    [CmdletBinding()]
    param (
        #Build Output Directory Name. Defaults to Get-BuildEnvironment Default which is 'BuildOutput'
        $BuildOutput = 'BuildOutput'
    )

    $Settings = [ordered]@{}

    $Settings.BuildEnvironment = (Get-BuildEnvironment -BuildOutput $BuildOutput -As Hashtable).AsReadOnly()

    $Settings.General = [ordered]@{
        # Root directory for the project
        ProjectRoot = $Settings.BuildEnvironment.ProjectPath

        # Root directory for the module
        SrcRootDir = $Settings.BuildEnvironment.ModulePath

        # The name of the module. This should match the basename of the PSD1 file
        ModuleName = $Settings.BuildEnvironment.ProjectName

        # Module version
        ModuleVersion = (Import-PowerShellDataFile -Path $Settings.BuildEnvironment.PSModuleManifest).ModuleVersion

        # Module manifest path
        ModuleManifestPath = $Settings.BuildEnvironment.PSModuleManifest
    }

    $Settings.Build = [ordered]@{
        Dependencies = @('StageFiles', 'BuildHelp')

        # Default Output directory when building a module
        OutDir = $Settings.BuildEnvironment.BuildOutput

        # Module output directory
        # This will be computed in 'Initialize-PSBuild' so we can allow the user to
        # override the top-level 'OutDir' above and compute the full path to the module internally
        ModuleOutDir = $Settings.BuildEnvironment.BuildOutput

        # Controls whether to "compile" module into single PSM1 or not
        CompileModule = $true

        # List of files to exclude from output directory
        Exclude = @()
    }


    $Settings.Test = [ordered]@{
        # Enable/disable Pester tests
        Enabled = $true

        # Directory containing Pester tests
        RootDir = Join-Path -Path $Settings.BuildEnvironment.ProjectPath -ChildPath tests

        # Specifies an output file path to send to Invoke-Pester's -OutputFile parameter.
        # This is typically used to write out test results so that they can be sent to a CI
        # system like AppVeyor.
        OutputFile = ([IO.Path]::Combine($Settings.Environment.BuildOutput,"$($Settings.Environment.ProjectName)-TestResults_PS$($psversiontable.psversion)`_$(get-date -format yyyyMMdd-HHmmss).xml"))

        # Specifies the test output format to use when the TestOutputFile property is given
        # a path.  This parameter is passed through to Invoke-Pester's -OutputFormat parameter.
        OutputFormat = 'NUnitXml'

        ScriptAnalysis = [ordered]@{
            # Enable/disable use of PSScriptAnalyzer to perform script analysis
            Enabled = $true

            # When PSScriptAnalyzer is enabled, control which severity level will generate a build failure.
            # Valid values are Error, Warning, Information and None.  "None" will report errors but will not
            # cause a build failure.  "Error" will fail the build only on diagnostic records that are of
            # severity error.  "Warning" will fail the build on Warning and Error diagnostic records.
            # "Any" will fail the build on any diagnostic record, regardless of severity.
            FailBuildOnSeverityLevel = 'Error'

            # Path to the PSScriptAnalyzer settings file.
            SettingsPath = Join-Path $PSScriptRoot -ChildPath ScriptAnalyzerSettings.psd1
        }

        CodeCoverage = [ordered]@{
            # Enable/disable Pester code coverage reporting.
            Enabled = $false

            # Fail Pester code coverage test if below this threshold
            Threshold = .75

            # CodeCoverageFiles specifies the files to perform code coverage analysis on. This property
            # acts as a direct input to the Pester -CodeCoverage parameter, so will support constructions
            # like the ones found here: https://github.com/pester/Pester/wiki/Code-Coverage.
            Files = @(
                Join-Path -Path $Settings.BuildEnvironment.ModulePath -ChildPath '*.ps1'
                Join-Path -Path $Settings.BuildEnvironment.ModulePath -ChildPath '*.psm1'
            )
        }
    }

    $Settings.Help  = [ordered]@{
        # Path to updateable help CAB
        UpdatableHelpOutDir = Join-Path -Path $Settings.Build.ModuleOutDir -ChildPath 'UpdatableHelp'

        # Default Locale used for help generation, defaults to en-US
        DefaultLocale = (Get-UICulture).Name

        # Convert project readme into the module about file
        ConvertReadMeToAboutHelp = $false
    }

    $Settings.Docs = [ordered]@{
        # Directory PlatyPS markdown documentation will be saved to
        RootDir = Join-Path -Path $Settings.Build.ModuleOutDir -ChildPath 'docs'
    }

    $Settings.Publish = [ordered]@{
        # PowerShell repository name to publish modules to
        PSRepository = 'PSGallery'

        # API key to authenticate to PowerShell repository with
        PSRepositoryApiKey = $env:PSGALLERY_API_KEY

        # Credential to authenticate to PowerShell repository with
        PSRepositoryCredential = $null
    }

    # Enable/disable generation of a catalog (.cat) file for the module.
    # [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    # $catalogGenerationEnabled = $true

    # # Select the hash version to use for the catalog file: 1 for SHA1 (compat with Windows 7 and
    # # Windows Server 2008 R2), 2 for SHA2 to support only newer Windows versions.
    # [System.Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssigments', '')]
    # $catalogVersion = 2

    return $Settings
}

function Get-PowerCDVersion {
    [CmdletBinding()]
    param()

    #TODO: FEATURE: Fallback to module version if GitVersion doesn't work

    #TODO: Move this to dedicated dependency handler
    if (-not $IsMacOS) {
        $GitVersionPackagePath = Import-PowerCDRequirement GitVersion.CommandLine -Package
        $GitVersionEXE = [IO.Path]::Combine($GitVersionPackagePath,'tools','GitVersion.exe')
    } else {
        & brew install GitVersion
        $GitversionEXE = 'gitversion'
    }


    #If this commit has a tag on it, temporarily remove it so GitVersion calculates properly
    #Fixes a bug with GitVersion where tagged commits don't increment on non-master builds.
    $currentTag = git tag --points-at HEAD

    if ($currentTag) {
        write-build DarkYellow "Task $($task.name) - Git Tag $currentTag detected. Temporarily removing for GitVersion calculation."
        git tag -d $currentTag
    }

    #Strip prerelease tags, GitVersion can't handle them with Mainline deployment with version 4.0
    #TODO: Restore these for local repositories, otherwise they just come down with git pulls
    #FIXME: Remove this because
    #git tag --list v*-* | % {git tag -d $PSItem}

    try {
        #Calculate the GitVersion
        write-verbose "Executing GitVersion to determine version info"

        if ($isLinux -and -not $isAppveyor) {
            #TODO: Find a more platform-independent way of changing GitVersion executable permissions (Mono.Posix library maybe?)
            #https://www.nuget.org/packages/Mono.Posix.NETStandard/1.0.0
            chmod +x $GitVersionEXE
        }

        $GitVersionOutput = & $GitVersionEXE /nofetch
        if (-not $GitVersionOutput) {throw "GitVersion returned no output. Are you sure it ran successfully?"}

        #Since GitVersion doesn't return error exit codes, we look for error text in the output
        if ($GitVersionOutput -match '^[ERROR|INFO] \[') {throw "An error occured when running GitVersion.exe in $buildRoot"}
        $SCRIPT:GitVersionInfo = $GitVersionOutput | ConvertFrom-JSON -ErrorAction stop

        if ($PCDSetting.Debug) {
            & $gitversionexe /nofetch /diag | write-debug
        }

        $GitVersionInfo | format-list | out-string | write-verbose

        [Version]$PCDSetting.Version     = $GitVersionInfo.MajorMinorPatch

        #TODO: Older packagemanagement don't support hyphens in Nuget name for some reason. Restore when fixed
        #[String]$PCDSetting.PreRelease   = $GitVersionInfo.NuGetPreReleaseTagV2
        #[String]$PCDSetting.VersionLabel = $GitVersionInfo.NuGetVersionV2
        #Remove separator characters for now, for instance in branch names
        [String]$PCDSetting.PreRelease   = $GitVersionInfo.NuGetPreReleaseTagV2 -replace '[\/\\\-]',''
        [String]$PCDSetting.VersionLabel = $PCDSetting.Version,$PCDSetting.PreRelease -join '-'

        if ($PCDSetting.BuildEnvironment.BuildOutput) {
            $PCDSetting.BuildModuleOutput = [io.path]::Combine($PCDSetting.BuildEnvironment.BuildOutput,$PCDSetting.BuildEnvironment.ProjectName,$PCDSetting.Version)
        }
    } catch {
        write-warning "There was an error when running GitVersion.exe $buildRoot`: $PSItem. The output of the command (if any) is below...`r`n$GitVersionOutput"
        & $GitVersionexe
    } finally {
        #Restore the tag if it was present
        #TODO: Evaluate if this is still necessary
        # if ($currentTag) {
        #     write-build DarkYellow "Task $($task.name) - Restoring tag $currentTag."
        #     git tag $currentTag -a -m "Automatic GitVersion Release Tag Generated by Invoke-Build"
        # }
    }

    return $GitVersionOutput

    # #GA release detection
    # if ($BranchName -eq 'master') {
    #     $Script:IsGARelease = $true
    #     $Script:ProjectVersion = $ProjectBuildVersion
    # } else {
    #     #The regex strips all hypens but the first one. This shouldn't be necessary per NuGet spec but Update-ModuleManifest fails on it.
    #     $SCRIPT:ProjectPreReleaseVersion = $GitVersionInfo.nugetversion -replace '(?<=-.*)[-]'
    #     $SCRIPT:ProjectVersion = $ProjectPreReleaseVersion
    #     $SCRIPT:ProjectPreReleaseTag = $SCRIPT:ProjectPreReleaseVersion.split('-')[1]
    # }

    # write-build Green "Task $($task.name)` - Calculated Project Version: $ProjectVersion"

    # #Tag the release if this is a GA build
    # if ($BranchName -match '^(master|releases?[/-])') {
    #     write-build Green "Task $($task.name)` - In Master/Release branch, adding release tag v$ProjectVersion to this build"

    #     $SCRIPT:isTagRelease = $true
    #     if ($BranchName -eq 'master') {
    #         write-build Green "Task $($task.name)` - In Master branch, marking for General Availability publish"
    #         [Switch]$SCRIPT:IsGARelease = $true
    #     }
    # }

    # #Reset the build dir to the versioned release directory. TODO: This should probably be its own task.
    # $SCRIPT:BuildReleasePath = Join-Path $BuildProjectPath $ProjectBuildVersion
    # if (-not (Test-Path -pathtype Container $BuildReleasePath)) {New-Item -type Directory $BuildReleasePath | out-null}
    # $SCRIPT:BuildReleaseManifest = Join-Path $BuildReleasePath (split-path $env:BHPSModuleManifest -leaf)
    # write-build Green "Task $($task.name)` - Using Release Path: $BuildReleasePath"
}
<#
.SYNOPSIS
Retrieves the dotnet dependencies for a powershell module
.NOTES
This process basically builds a C# Powershell Standard Library and identifies the resulting assemblies. There is probably a more lightweight way to do this.
.EXAMPLE
Get-PSModuleNugetDependencies @{'System.Text.Json'='4.6.0'}
#>
function Get-PSModuleNugetDependencies {
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName='String')]
    param (
        #A list of nuget packages to include. You can specify a nuget-style version with a / separator e.g. yamldotnet/3.2.*
        [Parameter(ParameterSetName='String',Mandatory,Position=0)][String[]]$PackageName,
        #Which packages and their associated versions to include, in hashtable form. Supports Nuget Versioning: https://docs.microsoft.com/en-us/nuget/concepts/package-versioning#version-ranges-and-wildcards
        [Parameter(ParameterSetName='Hashtable',Mandatory,Position=0)][HashTable]$Packages,
        #Which .NET Framework target to use. Defaults to .NET Standard 2.0 and is what you should use for PS5+ compatible modules
        [String]$Target = 'netstandard2.0',
        #Full name of the target framework, used for fetching the JSON-formatted dependencies TODO: Resolve this
        [String]$TargetFullName = '.NETStandard,Version=v2.0',
        #Where to output the resultant assembly files. Default is a new folder 'lib' in the current directory.
        [Parameter(Position=1)][String]$Destination,
        #Which PS Standard library to use. Defaults to 5.1.0.
        [String]$PowershellTarget = '5.1.0',
        [String]$BuildPath = (Join-Path ([io.path]::GetTempPath()) "PSModuleDeps-$((New-Guid).Guid)"),
        #Name of the build project. You normally don't need to change this.
        [String]$BuildProjectName = 'PSModuleDeps',
        #Whether to output the resultant copied file paths
        [Switch]$PassThru,
        #Whether to do an online restore check of the dependencies. Disable this to speed up the process at the risk of compatibility.
        [Switch]$NoRestore
    )

    if ($PSCmdlet.ParameterSetName -eq 'String') {
        $Packages = @{}
        $PackageName.Foreach{
            $PackageVersion = $PSItem -split '/'
            if ($PackageVersion.count -eq 2) {
                $Packages[$PackageVersion[0]] = $PackageVersion[1]
            } else {
                $Packages[$PSItem] = '*'
            }
        }
    }

    #Add Powershell Standard Library
    $Packages['PowerShellStandard.Library'] = $PowershellTarget

    if (-not ([version](dotnet --version) -ge 2.2)) {throw 'dotnet 2.2 or later is required. Make sure you have the .net core SDK 2.x+ installed'}

    #Add starter Project for netstandard 2.0
    $BuildProjectFile = Join-Path $BuildPath "$BuildProjectName.csproj"
    New-Item -ItemType Directory $BuildPath -Force > $null
@"
<Project Sdk="Microsoft.NET.Sdk">

<PropertyGroup>
    <TargetFramework>$Target</TargetFramework>
    <AutoGenerateBindingRedirects>true</AutoGenerateBindingRedirects>
</PropertyGroup>
<ItemGroup>
<PackageReference Include="PowerShellStandard.Library" Version="$PowerShellTarget">
  <PrivateAssets>All</PrivateAssets>
</PackageReference>
</ItemGroup>

</Project>
"@ > $BuildProjectFile

    foreach ($ModuleItem in $Packages.keys) {

        $dotnetArgs = 'add',$BuildProjectFile,'package',$ModuleItem

        if ($Packages[$ModuleItem] -ne $true) {
            if ($NoRestore) {
                $dotNetArgs += '--no-restore'
            }
            $dotnetArgs += '--version'
            $dotnetArgs += $Packages[$ModuleItem]
        }
        write-verbose "Executing: dotnet $dotnetArgs"
        & dotnet $dotnetArgs | Write-Verbose
    }

    & dotnet publish -o $BuildPath $BuildProjectFile | Write-Verbose

    function ConvertFromModuleDeps ($Path) {
        $runtimeDeps = Get-Content -raw $Path | ConvertFrom-Json
        $depResult = [ordered]@{}
        $runtimeDeps.targets.$TargetFullName.psobject.Properties.name |
            Where-Object {$PSItem -notlike "$BuildProjectName*"} |
            Sort-Object |
            Foreach-Object {
                $depInfo = $PSItem -split '/'
                $depResult[$depInfo[0]] = $depInfo[1]
            }
        return $depResult
    }
    #Use return to end script here and don't actually copy the files
    $ModuleDeps = ConvertFromModuleDeps -Path $BuildPath/obj/project.assets.json

    if (-not $Destination) {
        #Output the Module Dependencies and end here
        Remove-Item $BuildPath -Force -Recurse
        return $ModuleDeps
    }

    if ($PSCmdlet.ShouldProcess($Destination,"Copy Resultant DLL Assemblies")) {
        New-Item -ItemType Directory $Destination -Force > $null
        $CopyItemParams = @{
            Path = "$BuildPath/*.dll"
            Exclude = "$BuildProjectName.dll"
            Destination = $Destination
            Force = $true
        }

        if ($PassThru) {$CopyItemParams.PassThru = $true}
        Copy-Item @CopyItemParams
        Remove-Item $BuildPath -Force -Recurse
    }
}

function Import-PowerCDRequirement {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)][String[]]$ModuleName,
        [String]$Version,
        [Switch]$Package,
        [Switch]$Force
    )
    process {
        foreach ($ModuleName in $ModuleName) {

            #Get a temporary directory
            $tempModulePath = [io.path]::Combine([io.path]::GetTempPath(), 'PowerCD', $ModuleName)
            $ModuleManifestPath = Join-Path $tempModulePath "$ModuleName.psd1"
            $tempfile = join-path $tempModulePath "$ModuleName.zip"

            if ((Test-Path $tempfile) -and -not $Force) {
                Write-Verbose "$ModuleName already found in $tempModulePath"
            }
            else {
                if (Test-Path $tempModulePath) {
                    Remove-Item $tempfile -Force
                    Remove-Item $tempModulePath -Recurse -Force
                }

                New-Item -ItemType Directory -Path $tempModulePath > $null

                #Fetch and import the module
                [uri]$baseURI = 'https://powershellgallery.com/api/v2/package/'
                if ($Package) {
                    [uri]$baseURI = 'https://www.nuget.org/api/v2/package/'
                }

                [uri]$moduleURI = [uri]::new($baseURI, "$ModuleName/")

                if ($Version) {
                    #Ugly syntax for what is effectively "Join-Path" for URIs
                    $moduleURI = [uri]::new($moduleURI,"$version/")
                }

                Write-Verbose "Fetching $ModuleName from $moduleURI"
                (New-Object Net.WebClient).DownloadFile($moduleURI, $tempfile)

                $CurrentProgressPreference = $ProgressPreference
                $GLOBAL:ProgressPreference = 'silentlycontinue'
                Expand-Archive $tempfile $tempModulePath -Force -ErrorAction stop
                $GLOBAL:ProgressPreference = $CurrentProgressPreference
            }

            if (-not $Package) {
                write-verbose "Importing $ModuleName from $ModuleManifestPath"
                Import-Module $ModuleManifestPath -Force -Scope Global
            }
            else {
                $tempModulePath
            }
        }
    }
}
<#
.SYNOPSIS
Initializes the build environment and detects various aspects of the environment
#>

function Initialize-PowerCD {
    [CmdletBinding()]
    param (
        #Specify this if you don't want initialization to switch to the folder build root
        [Switch]$SkipSetBuildRoot
    )

    #Import Prerequisites
    Import-PowerCDRequirement @(
        'Pester'
        'BuildHelpers'
        'PSScriptAnalyzer'
    )

    #. $PSScriptRoot\Get-PowerCDSetting.ps1
    Set-Variable -Name PCDSetting -Scope Global -Option ReadOnly -Force -Value (Get-PowerCDSetting)

    #Detect if we are in a continuous integration environment (Appveyor, etc.) or otherwise running noninteractively
    if ($ENV:CI -or $CI -or ($PCDSetting.BuildEnvironment.buildsystem -and $PCDSetting.BuildEnvironment.buildsystem -ne 'Unknown')) {
        #write-build Green 'Build Initialization - Detected a Noninteractive or CI environment, disabling prompt confirmations'
        $SCRIPT:CI = $true
        $ConfirmPreference = 'None'
        #Disabling Progress speeds up the build because Write-Progress can be slow and can also clutter some CI displays
        $ProgressPreference = "SilentlyContinue"
    }
}

function Invoke-PowerCDClean {
    [CmdletBinding()]
    param (
        $buildProjectPath = $PCDSetting.BuildEnvironment.ProjectPath,
        $buildOutputPath  = $PCDSetting.BuildEnvironment.BuildOutput,
        $buildProjectName = $PCDSetting.BuildEnvironment.ProjectName
    )

    #Taken from Invoke-Build because it does not preserve the command in the scope this function normally runs
    #Copyright (c) Roman Kuzmin
    function Remove-BuildItem([Parameter(Mandatory=1)][string[]]$Path) {
        if ($Path -match '^[.*/\\]*$') {*Die 'Not allowed paths.' 5}
        $v = $PSBoundParameters['Verbose']
        try {
            foreach($_ in $Path) {
                if (Get-Item $_ -Force -ErrorAction 0) {
                    if ($v) {Write-Verbose "remove: removing $_" -Verbose}
                    Remove-Item $_ -Force -Recurse -ErrorAction stop
                }
                elseif ($v) {Write-Verbose "remove: skipping $_" -Verbose}
            }
        }
        catch {
            throw $_
        }
    }

    #Reset the BuildOutput Directory
    if (test-path $buildProjectPath) {
        Write-Verbose "Removing and resetting Build Output Path: $buildProjectPath"
        Remove-BuildItem $buildOutputPath
    }

    New-Item -Type Directory $BuildOutputPath > $null

    #Unmount any modules named the same as our module
    Remove-Module $buildProjectName -erroraction silentlycontinue
}


function New-PowerCDNugetPackage {
    [CmdletBinding()]
    param (
        #Path to the module to build
        [Parameter(Mandatory)][IO.FileInfo]$Path,
        #Where to output the new module package. Specify a folder
        [Parameter(Mandatory)][IO.DirectoryInfo]$Destination
    )

    $ModuleManifest = Get-Item $Path/*.psd1 | where {(Get-Content -Raw $PSItem) -match "ModuleVersion ?= ?\'.+\'"} | Select -First 1
    if (-not $ModuleManifest) {throw "No module manifest found in $Path. Please ensure a powershell module is present in this directory."}
    $ModuleName = $ModuleManifest.basename

    #TODO: Get this to work with older packagemanagement
    # $ModuleMetadata = Import-PowerShellDataFile $ModuleManifest

    # #Use some PowershellGet private methods to create a nuspec file and create a nupkg. This is much faster than the "slow" method referenced below
    # $NewNuSpecFileParams = @{
    #     OutputPath = $Path
    #     Id = $ModuleName
    #     Version = ($ModuleMetaData.ModuleVersion,$ModuleMetaData.PrivateData.PSData.Prerelease -join '-')
    #     Description = $ModuleMetaData.Description
    #     Authors = $ModuleMetaData.Author
    # }

    # #Fast Method but skips some metadata. Doesn't matter for non-powershell gallery publishes
    # #TODO: Add all the metadata from the publish process
    # $NuSpecPath = & (Get-Module PowershellGet) New-NuSpecFile @NewNuSpecFileParams
    # #$DotNetCommandPath = & (Get-Module PowershellGet) {$DotnetCommandPath}
    # #$NugetExePath = & (Get-Module PowershellGet) {$NugetExePath}
    # $NugetExePath = (command nuget -All -erroraction stop | where name -match 'nuget(.exe)?$').Source
    # $NewNugetPackageParams = @{
    #     NuSpecPath = $NuSpecPath
    #     NuGetPackageRoot = $Destination
    # }

    # if ($DotNetCommandPath) {
    #     $NewNugetPackageParams.UseDotNetCli = $true
    # } elseif ($NugetExePath) {
    #     $NewNugetPackageParams.NugetExePath = $NuGetExePath
    # }else {
    #     throw "Neither nuget or dotnet was detected by PowershellGet. Please check you have one or the other installed."
    # }

    # $nuGetPackagePath = & (Get-Module PowershellGet) New-NugetPackage @NewNugetPackageParams
    # write-verbose "Created NuGet Package at $nuGetPackagePath"
    # #Slow Method, maybe fallback to this
    # #Creates a temporary repository and registers it, uses publish-module which results in a nuget package

    try {
        $SCRIPT:tempRepositoryName = "$ModuleName-build-$(get-date -format 'yyyyMMdd-hhmmss')"
        Unregister-PSRepository -Name $tempRepositoryName -ErrorAction SilentlyContinue
        Register-PSRepository -Name $tempRepositoryName -SourceLocation ([String]$Destination)
        If (Get-Item -ErrorAction SilentlyContinue (join-path $Path "$ModuleName*.nupkg")) {
            Write-Build Green "Nuget Package for $ModuleName already generated. Skipping. Delete the package to retry"
        } else {
            $CurrentProgressPreference = $GLOBAL:ProgressPreference
            $GLOBAL:ProgressPreference = 'SilentlyContinue'
            Publish-Module -Repository $tempRepositoryName -Path $Path -Force
            $GLOBAL:ProgressPreference = $CurrentProgressPreference
        }
    }
    catch {Write-Error $PSItem}
    finally {
        Unregister-PSRepository $tempRepositoryName
    }
}

<#
.SYNOPSIS
Removes Comments and whitespace not related to comment-based help to "minify" a powershell script
.NOTES
Original Script From: https://www.madwithpowershell.com/2017/09/remove-comments-and-whitespace-from.html
#>
function Remove-CommentsAndWhiteSpace {
    # We are not restricting scriptblock type as Tokenize() can take several types
    Param (
        [parameter( ValueFromPipeline = $True )]
        $Scriptblock
    )

    Begin {
        # Intialize collection
        $Items = @()
    }

    Process {
        # Collect all of the inputs together
        $Items += $Scriptblock
    }

    End {
        ## Process the script as a single unit

        # Convert input to a single string if needed
        $OldScript = $Items -join [environment]::NewLine

        # If no work to do
        # We're done
        If ( -not $OldScript.Trim( " `n`r`t" ) ) { return }

        # Use the PowerShell tokenizer to break the script into identified tokens
        $Tokens = [System.Management.Automation.PSParser]::Tokenize( $OldScript, [ref]$Null )

        # Define useful, allowed comments
        $AllowedComments = @(
            'requires'
            '.SYNOPSIS'
            '.DESCRIPTION'
            '.PARAMETER'
            '.EXAMPLE'
            '.INPUTS'
            '.OUTPUTS'
            '.NOTES'
            '.LINK'
            '.COMPONENT'
            '.ROLE'
            '.FUNCTIONALITY'
            '.FORWARDHELPCATEGORY'
            '.REMOTEHELPRUNSPACE'
            '.EXTERNALHELP' )

        # Strip out the Comments, but not useful comments
        # (Bug: This will break comment-based help that uses leading # instead of multiline <#,
        # because only the headings will be left behind.)

        $Tokens = $Tokens.ForEach{
            If ( $_.Type -ne 'Comment' ) {
                $_
            } Else {
                $CommentText = $_.Content.Substring( $_.Content.IndexOf( '#' ) + 1 )
                $FirstInnerToken = [System.Management.Automation.PSParser]::Tokenize( $CommentText, [ref]$Null ) |
                    Where-Object { $_.Type -ne 'NewLine' } |
                    Select-Object -First 1
                If ( $FirstInnerToken.Content -in $AllowedComments ) {
                    $_
                }
            } }

        # Initialize script string
        $NewScriptText = ''
        $SkipNext = $False

        # If there are at least 2 tokens to process...
        If ( $Tokens.Count -gt 1 ) {
            # For each token (except the last one)...
            ForEach ( $i in ( 0..($Tokens.Count - 2) ) ) {
                # If token is not a line continuation and not a repeated new line or semicolon...
                If (    -not $SkipNext -and
                    $Tokens[$i  ].Type -ne 'LineContinuation' -and (
                        $Tokens[$i  ].Type -notin ( 'NewLine', 'StatementSeparator' ) -or
                        $Tokens[$i + 1].Type -notin ( 'NewLine', 'StatementSeparator', 'GroupEnd' ) ) ) {
                    # Add Token to new script
                    # For string and variable, reference old script to include $ and quotes
                    If ( $Tokens[$i].Type -in ( 'String', 'Variable' ) ) {
                        $NewScriptText += $OldScript.Substring( $Tokens[$i].Start, $Tokens[$i].Length )
                    } Else {
                        $NewScriptText += $Tokens[$i].Content
                    }

                    # If the token does not never require a trailing space
                    # And the next token does not never require a leading space
                    # And this token and the next are on the same line
                    # And this token and the next had white space between them in the original...
                    If (    $Tokens[$i  ].Type -notin ( 'NewLine', 'GroupStart', 'StatementSeparator' ) -and
                        $Tokens[$i + 1].Type -notin ( 'NewLine', 'GroupEnd', 'StatementSeparator' ) -and
                        $Tokens[$i].EndLine -eq $Tokens[$i + 1].StartLine -and
                        $Tokens[$i + 1].StartColumn - $Tokens[$i].EndColumn -gt 0 ) {
                        # Add a space to new script
                        $NewScriptText += ' '
                    }

                    # If the next token is a new line or semicolon following
                    # an open parenthesis or curly brace, skip it
                    $SkipNext = $Tokens[$i].Type -eq 'GroupStart' -and $Tokens[$i + 1].Type -in ( 'NewLine', 'StatementSeparator' )
                }

                # Else (Token is a line continuation or a repeated new line or semicolon)...
                Else {
                    # [Do not include it in the new script]

                    # If the next token is a new line or semicolon following
                    # an open parenthesis or curly brace, skip it
                    $SkipNext = $SkipNext -and $Tokens[$i + 1].Type -in ( 'NewLine', 'StatementSeparator' )
                }
            }
        }

        # If there is a last token to process...
        If ( $Tokens ) {
            # Add last token to new script
            # For string and variable, reference old script to include $ and quotes
            If ( $Tokens[$i].Type -in ( 'String', 'Variable' ) ) {
                $NewScriptText += $OldScript.Substring( $Tokens[-1].Start, $Tokens[-1].Length )
            } Else {
                $NewScriptText += $Tokens[-1].Content
            }
        }

        # Trim any leading new lines from the new script
        $NewScriptText = $NewScriptText.TrimStart( "`n`r;" )

        # Return the new script as the same type as the input
        If ( $Items.Count -eq 1 ) {
            If ( $Items[0] -is [scriptblock] ) {
                # Return single scriptblock
                return [scriptblock]::Create( $NewScriptText )
            } Else {
                # Return single string
                return $NewScriptText
            }
        } Else {
            # Return array of strings
            return $NewScriptText.Split( "`n`r", [System.StringSplitOptions]::RemoveEmptyEntries )
        }
    }
}
<#
.SYNOPSIS
Sets the version on a powershell Module
#>
function Set-PowerCDVersion {
    [CmdletBinding()]
    param (
        #Path to the module manifest to update
        [String]$Path = $PCDSetting.OutputModuleManifest,
        #Version to set for the module
        [Version]$Version = $PCDSetting.Version,
        #Prerelease tag to add to the module, if any
        [String]$PreRelease= $PCDSetting.Prerelease
    )
    #Default is to update version so no propertyname specified
    Update-Metadata -Path $Path -Value $Version

    Update-Metadata -Path $Path -PropertyName PreRelease -Value $PreRelease
}

#Pester Testing
function Test-PowerCDPester {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]$ModuleManifestPath,
        $PesterResultFile = ([IO.Path]::Combine($PCDSetting.BuildEnvironment.BuildOutput,"$($PCDSetting.BuildEnvironment.ProjectName)-$($PCDSetting.VersionLabel)-TestResults_PS$($psversiontable.psversion)`_$(get-date -format yyyyMMdd-HHmmss).xml")),
        $CodeCoverageOutputFile = ([IO.Path]::Combine($PCDSetting.BuildEnvironment.BuildOutput,"$($PCDSetting.BuildEnvironment.ProjectName)-$($PCDSetting.VersionLabel)-CodeCoverage_PS$($psversiontable.psversion)`_$(get-date -format yyyyMMdd-HHmmss).xml")),
        [String[]]$Exclude = 'PowerCD.tasks.ps1',
        $CodeCoverage = (Get-ChildItem -Path (Join-Path $ModuleDirectory '*') -Include *.ps1,*.psm1 -Exclude $Exclude -Recurse),
        $Show = 'None',
        [Switch]$UseJob
    )

    #Try autodetecting the "furthest out module manifest"
    # if (-not $ModuleManifestPath) {
    #     try {
    #         $moduleManifestCandidatePath = Join-Path (Join-Path $PWD '*') '*.psd1'
    #         $moduleManifestCandidates = Get-Item $moduleManifestCandidatePath -ErrorAction stop
    #         $moduleManifestPath = ($moduleManifestCandidates | Select-Object -last 1).fullname
    #     } catch {
    #         throw "Did not detect any module manifests in $BuildProjectPath. Did you run 'Invoke-Build Build' first?"
    #     }
    # }

    #TODO: Update for new logging method
    #write-verboseheader "Starting Pester Tests..."
    Write-Verbose "Task $($task.name)` -  Testing $moduleManifestPath"

    $PesterParams = @{
        #TODO: Fix for source vs built object
        # Script       = @{
        #     Path = "Tests"
        #     Parameters = @{
        #         ModulePath = (Split-Path $moduleManifestPath)
        #     }
        # }
        OutputFile   = $PesterResultFile
        OutputFormat = 'NunitXML'
        PassThru     = $true
        OutVariable  = 'TestResults'
        Show         = $Show
    }

    if ($CodeCoverage) {
        $PesterParams.CodeCoverage = $CodeCoverage
        $PesterParams.CodeCoverageOutputFile = $CodeCoverageOutputFile
    }

    #If we are in vscode, add the VSCodeMarkers
    if ($host.name -match 'Visual Studio Code') {
        Write-Verbose "Detected Visual Studio Code, adding test markers"
        $PesterParams.PesterOption = (New-PesterOption -IncludeVSCodeMarker)
    }

    if ($UseJob) {
        #Bootstrap PowerCD Prereqs
        $PowerCDModules = get-item (Join-Path ([io.path]::GetTempPath()) '/PowerCD/*/*.psd1')

        $PesterJob = {
            #Move to same folder as was started
            Set-Location $USING:PWD
            #Prepare the Destination Module Directory Environment
            $ENV:PowerCDModuleManifest = $USING:ModuleManifestPath
            #Bring in relevant environment
            $USING:PowerCDModules | Import-Module -Force
            $PesterParams = $USING:PesterParams
            Invoke-Pester @PesterParams
        }

        $TestResults = Start-Job -ScriptBlock $PesterJob | Receive-Job -Wait
    } else {
        $ENV:PowerCDModuleManifest = $ModuleManifestPath
        $TestResults = Invoke-Pester @PesterParams
    }

    # In Appveyor? Upload our test results!
    #TODO: Consolidate Test Result Upload
    # If ($ENV:APPVEYOR) {
    #     $UploadURL = "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)"
    #     write-verbose "Detected we are running in AppVeyor! Uploading Pester Results to $UploadURL"
    #     (New-Object 'System.Net.WebClient').UploadFile(
    #         "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
    #         $PesterResultFile )
    # }

    #TODO: Fix to fail
    # Failed tests?
    # Need to error out or it will proceed to the deployment. Danger!
    if ($TestResults.failedcount -isnot [int] -or $TestResults.FailedCount -gt 0) {
        $testFailedMessage = "Failed '$($TestResults.FailedCount)' tests, build failed"
        throw $testFailedMessage
        #TODO: Rewrite to use BuildHelpers
        # if ($isAzureDevOps) {
        #     Write-Host "##vso[task.logissue type=error;]$testFailedMessage"
        # }
        $SCRIPT:SkipPublish = $true
    }
    # "`n"
}
<#
.SYNOPSIS
This function sets a module manifest for the various function exports that are present in a module such as private/public functions, classes, etc.
#>

function Update-PowerCDPublicFunctions {
    param(
        #Path to the module manifest to update
        [String]$Path = $PCDSetting.OutputModuleManifest,
        #Specify to override the auto-detected function list
        [String[]]$Functions = $PCDSetting.Functions,
        #Paths to the module public function files
        [String]$PublicFunctionPath = (Join-Path $PCDSetting.BuildEnvironment.ModulePath 'Public')
    )

    if (-not $Functions) {
        write-verbose "Autodetecting Public Functions in $Path"
        $Functions = Get-PowerCDPublicFunctions $PublicFunctionPath
    }

    if (-not $Functions) {
        write-warning "No functions found in the powershell module. Did you define any yet? Create a new one called something like New-MyFunction.ps1 in the Public folder"
        return
    }

    Update-Metadata -Path $Path -PropertyName FunctionsToExport -Value $Functions
}

#Module Startup
Set-Alias PowerCD.Tasks $PSScriptRoot/PowerCD.tasks.ps1

if (-not $PublicFunctions) {
    $ModuleManifest = Join-Path $PSScriptRoot 'PowerCD.psd1'
    # $PublicFunctions = if (Get-Command Import-PowershellDataFile -ErrorAction Silently Continue) {
    #     Import-PowershellDataFile -Path $ModuleManifest
    # } else {

    #     #Some Powershell Installs don't have microsoft.powershell.utility for some reason.
    #     #TODO: Bootstrap microsoft.powershell.utility maybe?
    #     #Last Resort
    #     #Import-LocalizedData -BaseDirectory $PSScriptRoot -FileName 'powercd.psd1'
    # }
    $PublicFunctions = Import-PowershellDataFile -Path $ModuleManifest
    Export-ModuleMember -Alias PowerCD.Tasks -Function $publicFunctions.FunctionsToExport
}

Export-ModuleMember -Alias PowerCD.Tasks -Function $publicFunctions


