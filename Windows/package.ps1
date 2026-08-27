#!/usr/bin/env pwsh
# Build the Windows release: one self-contained .exe per architecture, zipped, checksummed.
#
# The macOS twin is Packaging/package.sh, and this mirrors its guarantees: the tests run first
# and a failure aborts the build; the version is injected, never hand-edited; the build number is
# the commit count; and the privacy invariant is proven on the artifact rather than trusted — here
# by scanning the built assembly for any reference to a networking type, the Windows stand-in for
# package.sh checking the sandbox entitlement.
#
#     Windows/package.ps1 [version]      # version defaults to 0.0.0-dev
#
# Unsigned: no code-signing certificate is provisioned. Like an ad-hoc-signed macOS build, the
# first launch shows SmartScreen — "More info -> Run anyway" — which the README documents.

param([string]$Version = "0.0.0-dev")

$ErrorActionPreference = "Stop"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
$env:DOTNET_NOLOGO = "1"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

$Build = (& git rev-list --count HEAD 2>$null)
if (-not $Build) { $Build = "1" }
$Informational = "$Version+build.$Build"

$Rids = @("win-x64", "win-arm64")
$Dist = Join-Path $RepoRoot "dist"
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

# 1. The suite first, as package.sh does — the accuracy contract and the fixture, all 163 tests.
Write-Host "==> Running tests"
& dotnet test --solution (Join-Path $RepoRoot "Windows/Kibo.slnx") -c Release
if ($LASTEXITCODE -ne 0) { throw "tests failed" }

foreach ($Rid in $Rids) {
    Write-Host "==> Publishing $Rid"
    $Out = Join-Path $Dist "win/$Rid"
    & dotnet publish (Join-Path $RepoRoot "Windows/Kibo.App/Kibo.App.csproj") `
        -c Release -r $Rid -p:Version=$Version "-p:InformationalVersion=$Informational" -o $Out
    if ($LASTEXITCODE -ne 0) { throw "publish failed for $Rid" }

    # 2. Prove the artifact references no networking type. The single-file bundle is not a PE the
    #    scanner can open, so it scans the loose Release DLLs the build phase left beside it.
    $BinDir = Join-Path $RepoRoot "Windows/Kibo.App/bin/Release/net10.0-windows/$Rid"
    $env:KIBO_APP_ASSEMBLY = (Join-Path $BinDir "Kibo.dll") + ";" + (Join-Path $BinDir "Kibo.Core.dll")
    Write-Host "==> Confirming $Rid references no network types"
    & dotnet test --project (Join-Path $RepoRoot "Windows/Kibo.Core.Tests") -c Release --no-build `
        -- --filter-method "*NoNetworkTests*"
    if ($LASTEXITCODE -ne 0) { throw "no-network scan failed for $Rid" }
    Remove-Item Env:\KIBO_APP_ASSEMBLY

    # 3. Zip, checksum, and a versionless copy so releases/latest/download never goes stale.
    $Exe = Join-Path $Out "Kibo.exe"
    $Zip = Join-Path $Dist "Kibo-$Version-$Rid.zip"
    Compress-Archive -Path $Exe -DestinationPath $Zip -Force
    $Hash = (Get-FileHash -Algorithm SHA256 $Zip).Hash.ToLower()
    "$Hash  $(Split-Path $Zip -Leaf)" | Set-Content -NoNewline "$Zip.sha256"
    Copy-Item $Zip (Join-Path $Dist "Kibo-$Rid.zip") -Force

    $Size = [math]::Round((Get-Item $Zip).Length / 1MB, 1)
    Write-Host "==> $(Split-Path $Zip -Leaf)  ${Size} MB  sha256 $Hash"
}

Write-Host ""
Write-Host "Unsigned build. On first launch Windows SmartScreen shows a warning:"
Write-Host "  More info -> Run anyway."
