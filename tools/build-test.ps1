param(
    [string]$LazBuild = 'C:\lazarus\lazbuild.exe',
    [string]$MainProject = 'BuildDatabase.lpi',
    [string]$TestProject = 'BuildDatabase.test.lpi',
    [string]$TestTarget = 'R:\Temp\BuildDatabase-test'
)

$ErrorActionPreference = 'Stop'

function Get-NormalizedProjectText {
    param([string]$Path)

    $text = Get-Content -Raw -Path $Path

    # Ignore the deliberate test-harness target path/name difference.
    $text = [regex]::Replace(
        $text,
        '<Target>\s*<Filename Value="[^"]*"/>\s*</Target>',
        '<Target><Filename Value="__IGNORED_TARGET__"/></Target>',
        'Singleline'
    )

    # Normalize line endings for comparison.
    return ($text -replace "`r`n", "`n")
}

function Update-TestProject {
    Copy-Item -Path $MainProject -Destination $TestProject -Force

    [xml]$xml = Get-Content -Raw -Path $TestProject
    $targetNode = $xml.CONFIG.CompilerOptions.Target.Filename
    if ($null -eq $targetNode) {
        throw "Could not find CONFIG/CompilerOptions/Target/Filename in $TestProject"
    }

    $targetNode.Value = $TestTarget

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $writer = [System.Xml.XmlWriter]::Create((Resolve-Path $TestProject), $settings)
    try {
        $xml.Save($writer)
    }
    finally {
        $writer.Close()
    }
}

if (!(Test-Path 'R:\Temp')) {
    New-Item -ItemType Directory -Path 'R:\Temp' -Force | Out-Null
}

$needsRefresh = $true
if (Test-Path $TestProject) {
    $mainNorm = Get-NormalizedProjectText $MainProject
    $testNorm = Get-NormalizedProjectText $TestProject
    $needsRefresh = ($mainNorm -ne $testNorm)
}

if ($needsRefresh) {
    Write-Host "Refreshing $TestProject from $MainProject"
    Update-TestProject
}
else {
    Write-Host "$TestProject is current"
}

Write-Host "Building test target: $TestTarget.exe"
& $LazBuild --no-write-project $TestProject
exit $LASTEXITCODE
