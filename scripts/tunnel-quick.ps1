param(
    [string] $ServiceUrl = "http://web:80",
    [string] $Network = "company-atrocore-project_default",
    [string] $Name = "company-atrocore-quick-tunnel"
)

$ErrorActionPreference = "Stop"

$existing = docker ps -a --filter "name=$Name" --format "{{.ID}}"
if ($existing) {
    docker rm -f $Name | Out-Null
}

docker run -d --name $Name --network $Network cloudflare/cloudflared:latest tunnel --no-autoupdate --url $ServiceUrl | Out-Null

$url = $null
for ($i = 0; $i -lt 45; $i++) {
    $logs = cmd /c "docker logs $Name 2>&1" | Out-String
    if ($logs -match "https://[a-zA-Z0-9-]+\.trycloudflare\.com") {
        $url = $Matches[0]
        break
    }
    Start-Sleep -Seconds 1
}

if (-not $url) {
    cmd /c "docker logs $Name 2>&1"
    throw "Cloudflare quick tunnel URL was not found in logs."
}

Write-Host "Cloudflare Quick Tunnel URL:"
Write-Host $url
Write-Host ""
Write-Host "Keep the container '$Name' running while you need external access."
Write-Host "Stop it with: powershell -ExecutionPolicy Bypass -File .\scripts\tunnel-stop.ps1"
