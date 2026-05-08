param(
    [string] $BaseUrl = "http://localhost:8080",
    [string] $Username = "admin",
    [string] $Password = "admin",
    [switch] $RequireInstalled
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Assert-Status {
    param([string] $Name, [scriptblock] $Block)
    try {
        & $Block
        Write-Host "[PASS] $Name"
    } catch {
        Write-Host "[FAIL] $Name - $($_.Exception.Message)"
        throw
    }
}

Assert-Status "Frontend shell" {
    $response = Invoke-WebRequest -UseBasicParsing "$BaseUrl/" -TimeoutSec 20
    if ($response.StatusCode -ne 200) { throw "HTTP $($response.StatusCode)" }
}

$homeResponse = Invoke-WebRequest -UseBasicParsing "$BaseUrl/" -TimeoutSec 20
if (-not $RequireInstalled -and $homeResponse.Content -match "install/install.js") {
    Write-Host "[PASS] Installer page detected for a clean database"
    Write-Host "[SKIP] Login/API checks require completing the web installer first"
    exit 0
}

$token = $null
Assert-Status "Login" {
    $basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${Password}"))
    $response = Invoke-RestMethod -Method Get -Uri "$BaseUrl/api/v1/App/user" -Headers @{ "X-Requested-With" = "XMLHttpRequest"; "Authorization" = "Basic $basic" } -TimeoutSec 30
    $script:token = $response.authorizationToken
    if (-not $script:token) { throw "authorizationToken missing" }
}

$headers = @{
    "Authorization-Token" = $token
    "X-Requested-With" = "XMLHttpRequest"
}

Assert-Status "Metadata" {
    $metadata = Invoke-WebRequest -UseBasicParsing -Method Get -Uri "$BaseUrl/api/v1/Metadata" -Headers $headers -TimeoutSec 30
    if ($metadata.Content -notmatch '"entityDefs"|"app"|"action"') { throw "metadata payload missing expected keys" }
}

Assert-Status "SQL diff" {
    $schema = docker compose exec -T web php console.php sql diff --show 2>&1 | Out-String
    if ($schema -notmatch "No database changes were detected") {
        throw "Schema diff is not clean: $schema"
    }
}

Assert-Status "Cron" {
    docker compose exec -T web php console.php cron
}
