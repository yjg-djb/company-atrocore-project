param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $Command
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if ($Command.Count -eq 0) {
    docker compose exec web php console.php
} else {
    docker compose exec web php console.php @Command
}
