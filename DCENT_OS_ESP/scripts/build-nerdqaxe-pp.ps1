param(
    [string]$CargoTargetDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$manifestPath = Join-Path $repoRoot "esp-targets.json"
$targetMatrixTool = Join-Path $repoRoot "scripts\target_matrix.py"
$previousCargoTargetDir = $env:CARGO_TARGET_DIR
$previousSdkconfigDefaults = $env:ESP_IDF_SDKCONFIG_DEFAULTS

if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Could not find the ESP target manifest: $manifestPath"
}

if ([string]::IsNullOrWhiteSpace($CargoTargetDir)) {
    if (-not [string]::IsNullOrWhiteSpace($env:CARGO_TARGET_DIR)) {
        $CargoTargetDir = $env:CARGO_TARGET_DIR
    }
    else {
        $CargoTargetDir = "C:\bt\nerdqaxe-pp-rev51"
    }
}

$pythonCommand = Get-Command python -ErrorAction SilentlyContinue
$pythonArgs = @()
if ($null -eq $pythonCommand) {
    $pythonCommand = Get-Command py -ErrorAction SilentlyContinue
    if ($null -eq $pythonCommand) {
        throw "Python 3 is required. Install Python, or set up the 'python' command."
    }
    $pythonArgs = @("-3")
}

Push-Location $repoRoot
try {
    & $pythonCommand.Source @pythonArgs $targetMatrixTool validate
    if ($LASTEXITCODE -ne 0) {
        throw "ESP target registry validation failed. No build was started."
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $rows = @($manifest.targets | Where-Object { $_.board_target -eq "nerdqaxe-pp" })
    if ($rows.Count -ne 1) {
        throw "Expected exactly one nerdqaxe-pp target in esp-targets.json."
    }

    $target = $rows[0]
    if ($target.feature -ne "nerdqaxe-pp" -or $target.asic -ne "BM1370" -or $target.chip_count -ne 4) {
        throw "nerdqaxe-pp no longer maps to the expected 4x BM1370 build. Review the target registry first."
    }
    if ($target.release_scope -ne "internal" -or $target.install_policy -ne "lab-only") {
        throw "nerdqaxe-pp is no longer marked internal/lab-only. Review the release policy before building."
    }

    Write-Warning "This builds only the experimental NerdQaxe++ target. It does not package or flash firmware."
    Write-Warning "The target registry still has open hardware and qualification blockers; a successful compile is not board validation."
    Write-Host "Building $($target.board_target): $($target.chip_count)x $($target.asic)"

    New-Item -ItemType Directory -Force -Path $CargoTargetDir | Out-Null
    $env:CARGO_TARGET_DIR = $CargoTargetDir
    $env:ESP_IDF_SDKCONFIG_DEFAULTS = "sdkconfig.defaults"

    cargo build --locked --release -p dcentaxe --no-default-features --features nerdqaxe-pp
    if ($LASTEXITCODE -ne 0) {
        throw "cargo build failed. Review the first compiler/toolchain error above."
    }

    $elfPath = Join-Path $CargoTargetDir "xtensa-esp32s3-espidf\release\dcentaxe"
    if (-not (Test-Path -LiteralPath $elfPath)) {
        throw "Cargo reported success, but the expected ELF was not found: $elfPath"
    }

    $hash = (Get-FileHash -LiteralPath $elfPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host "Build succeeded. ELF: $elfPath"
    Write-Host "SHA-256: $hash"
    Write-Host "This ELF is not a factory .bin and this script does not flash the device."
}
finally {
    if ([string]::IsNullOrWhiteSpace($previousCargoTargetDir)) {
        Remove-Item Env:CARGO_TARGET_DIR -ErrorAction SilentlyContinue
    }
    else {
        $env:CARGO_TARGET_DIR = $previousCargoTargetDir
    }
    if ([string]::IsNullOrWhiteSpace($previousSdkconfigDefaults)) {
        Remove-Item Env:ESP_IDF_SDKCONFIG_DEFAULTS -ErrorAction SilentlyContinue
    }
    else {
        $env:ESP_IDF_SDKCONFIG_DEFAULTS = $previousSdkconfigDefaults
    }
    Pop-Location
}
