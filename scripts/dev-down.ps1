param(
    [switch] $Volumes
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$args = @("compose", "down")
if ($Volumes) {
    $args += "--volumes"
}

docker @args
