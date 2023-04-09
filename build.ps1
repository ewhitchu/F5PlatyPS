<#
.SYNOPSIS
    Builds the MarkDown/MAML DLL and assembles the final package in out\platyPS.
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    $Configuration = "Debug",
    [switch]$SkipDocs,
    [string]$DotnetCli
)

function Find-DotnetCli()
{
    [string] $DotnetCli = ''
    $dotnetCmd = Get-Command dotnet
    return $dotnetCmd.Path
}


if (-not $DotnetCli) {
    $DotnetCli = Find-DotnetCli
}

if (-not $DotnetCli) {
    throw "dotnet cli is not found in PATH, install it from https://docs.microsoft.com/en-us/dotnet/core/tools"
} else {
    Write-Host "Using dotnet from $DotnetCli"
}

if (Get-Variable -Name IsCoreClr -ValueOnly -ErrorAction SilentlyContinue) {
    $framework = 'netstandard2.1'
} else {
    $framework = 'net481'
}

& $DotnetCli publish ./src/Markdown.MAML -f $framework --output=$pwd/publish /p:Configuration=$Configuration

$assemblyPaths = (
    (Resolve-Path "publish/Markdown.MAML.dll").Path,
    (Resolve-Path "publish/YamlDotNet.dll").Path
)

# copy artifacts
New-Item -Type Directory out -ErrorAction SilentlyContinue > $null
Copy-Item -Rec -Force src\F5PlatyPS out
foreach($assemblyPath in $assemblyPaths)
{
	$assemblyFileName = [System.IO.Path]::GetFileName($assemblyPath)
	$outputPath = "out\F5PlatyPS\$assemblyFileName"
	if ((-not (Test-Path $outputPath)) -or
		(Test-Path $outputPath -OlderThan (Get-ChildItem $assemblyPath).LastWriteTime))
	{
		Copy-Item $assemblyPath out\F5PlatyPS
	} else {
		Write-Host -Foreground Yellow "Skip $assemblyFileName copying"
	}
}

# copy schema file and docs
Copy-Item .\F5PlatyPS.schema.md out\F5PlatyPS
New-Item -Type Directory out\F5PlatyPS\docs -ErrorAction SilentlyContinue > $null
Copy-Item .\docs\* out\F5PlatyPS\docs\

# copy template files
New-Item -Type Directory out\F5PlatyPS\templates -ErrorAction SilentlyContinue > $null
Copy-Item .\templates\* out\F5PlatyPS\templates\

# put the right module version
if ($env:APPVEYOR_REPO_TAG_NAME)
{
    $manifest = cat -raw out\F5PlatyPS\F5PlatyPS.psd1
    $manifest = $manifest -replace "ModuleVersion = '0.0.1'", "ModuleVersion = '$($env:APPVEYOR_REPO_TAG_NAME)'"
    Set-Content -Value $manifest -Path out\F5PlatyPS\F5PlatyPS.psd1 -Encoding Ascii
}

# dogfooding: generate help for the module
Remove-Module F5PlatyPS -ErrorAction SilentlyContinue
Import-Module $pwd\out\F5PlatyPS

if (-not $SkipDocs) {
    New-ExternalHelp docs -OutputPath out\F5PlatyPS\en-AU -Force
    # reload module, to apply generated help
    Import-Module $pwd\out\F5PlatyPS -Force
}

