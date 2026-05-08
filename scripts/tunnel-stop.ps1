param(
    [string] $Name = "company-atrocore-quick-tunnel"
)

$existing = docker ps -a --filter "name=$Name" --format "{{.ID}}"
if ($existing) {
    docker rm -f $Name | Out-Null
    Write-Host "Stopped Cloudflare quick tunnel container '$Name'."
} else {
    Write-Host "Cloudflare quick tunnel container '$Name' is not running."
}
