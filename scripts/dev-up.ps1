param(
    [switch] $Build
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example. Review passwords before using this outside local development."
}

$args = @("compose", "up", "-d")
if ($Build) {
    $args += "--build"
}

docker @args
