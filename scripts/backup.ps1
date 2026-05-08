param(
    [string] $OutputDir = "backups"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path ".env")) {
    throw "Missing .env. Copy .env.example to .env first."
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$target = Join-Path $root $OutputDir
New-Item -ItemType Directory -Force -Path $target | Out-Null

$dbFile = Join-Path $target "postgres-$timestamp.dump"
$uploadFile = Join-Path $target "upload-$timestamp.tar"

docker compose exec -T db sh -lc 'pg_dump -U "$POSTGRES_PIM_USER" -d "$POSTGRES_PIM_DB" -Fc' > $dbFile
docker compose exec -T web sh -lc 'cd /var/www/localhost && tar -cf - upload' > $uploadFile

Write-Host "Database backup: $dbFile"
Write-Host "Upload backup:   $uploadFile"
