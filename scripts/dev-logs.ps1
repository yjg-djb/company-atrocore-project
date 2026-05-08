param(
    [string] $Service = "web",
    [int] $Tail = 200
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

docker compose logs --tail $Tail -f $Service
