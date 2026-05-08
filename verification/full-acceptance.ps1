param(
    [string] $BaseUrl = "http://localhost:8081",
    [string] $Username = "admin",
    [string] $Password = "admin",
    [string] $ReportDir = "verification/reports"
)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$apiBase = "$BaseUrl/api/v1"
$run = Get-Date -Format "yyyyMMdd-HHmmss"
$runStartedAt = Get-Date
$prefix = "Codex Smoke $run"
$results = New-Object System.Collections.Generic.List[object]
$created = New-Object System.Collections.Generic.List[object]

New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

function Add-Result {
    param(
        [string] $Group,
        [string] $Name,
        [string] $Entry,
        [string] $Method,
        [object] $StatusCode,
        [string] $Result,
        [string] $Summary,
        [object] $Ids = "",
        [string] $Cleanup = "",
        [string] $Next = ""
    )

    $script:results.Add([pscustomobject]@{
        time = (Get-Date).ToString("s")
        group = $Group
        name = $Name
        entry = $Entry
        method = $Method
        statusCode = $StatusCode
        result = $Result
        summary = $Summary
        ids = $Ids
        cleanup = $Cleanup
        next = $Next
    }) | Out-Null
}

function Get-ErrorText {
    param($ErrorRecord)
    if ($ErrorRecord.Exception.Response) {
        try {
            $reader = New-Object IO.StreamReader($ErrorRecord.Exception.Response.GetResponseStream())
            $text = $reader.ReadToEnd()
            if (-not [string]::IsNullOrWhiteSpace($text)) { return $text }
        } catch { }
    }
    return $ErrorRecord.Exception.Message
}

function Get-ErrorCode {
    param($ErrorRecord)
    if ($ErrorRecord.Exception.Response) { return [int] $ErrorRecord.Exception.Response.StatusCode }
    return ""
}

function Shorten {
    param([string] $Text, [int] $Max = 240)
    $s = ([string] $Text) -replace "\s+", " "
    if ($s.Length -gt $Max) { return $s.Substring(0, $Max) + "..." }
    return $s
}

function Result-If {
    param([bool] $Condition, [string] $WhenTrue = "PASS", [string] $WhenFalse = "FAIL")
    if ($Condition) { return $WhenTrue }
    return $WhenFalse
}

function Get-CurrentRunLogLines {
    param([string] $Text)

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($line in (([string] $Text) -split "`r?`n")) {
        if ($line -match "^\[(?<ts>\d{4}-\d{2}-\d{2}T[^]]+)\]") {
            try {
                $entryTime = [DateTimeOffset]::Parse($Matches.ts).UtcDateTime
                if ($entryTime -ge $script:runStartedAt.ToUniversalTime()) {
                    $lines.Add($line) | Out-Null
                }
            } catch {
                $lines.Add($line) | Out-Null
            }
        }
    }
    return ($lines -join "`n")
}

function Invoke-Api {
    param(
        [string] $Method,
        [string] $Path,
        [object] $Body = $null,
        [int] $TimeoutSec = 45
    )

    $params = @{
        Method = $Method
        Uri = "$apiBase/$Path"
        Headers = $script:headers
        TimeoutSec = $TimeoutSec
        ErrorAction = "Stop"
    }
    if ($null -ne $Body) {
        $params.ContentType = "application/json"
        $params.Body = ($Body | ConvertTo-Json -Depth 40 -Compress)
    }

    $resp = Invoke-WebRequest @params
    $content = $null
    if ($resp.Content) {
        try { $content = $resp.Content | ConvertFrom-Json -ErrorAction Stop } catch { $content = $resp.Content }
    }
    return [pscustomobject]@{ status = [int] $resp.StatusCode; content = $content; raw = $resp.Content }
}

function New-Entity {
    param([string] $Scope, [object] $Body)
    $r = Invoke-Api POST $Scope $Body 60
    if ($r.content -and $r.content.id) {
        $script:created.Add([pscustomobject]@{ scope = $Scope; id = $r.content.id }) | Out-Null
    }
    return $r
}

function Remove-Created {
    for ($i = $script:created.Count - 1; $i -ge 0; $i--) {
        $item = $script:created[$i]
        try {
            Invoke-Api DELETE "$($item.scope)/$($item.id)" $null 30 | Out-Null
            Add-Result "Cleanup" "$($item.scope) $($item.id)" "/$($item.scope)/$($item.id)" DELETE 200 PASS "deleted" $item.id "deleted"
        } catch {
            Add-Result "Cleanup" "$($item.scope) $($item.id)" "/$($item.scope)/$($item.id)" DELETE (Get-ErrorCode $_) FAIL (Get-ErrorText $_) $item.id "not cleaned" "Manual cleanup may be required"
        }
    }
}

function Remove-Smoke-Jobs {
    if (-not $script:headers) { return }
    try {
        $path = "Job?where[0][type]=contains&where[0][attribute]=name&where[0][value]=" + [uri]::EscapeDataString("Codex Smoke") + "&maxSize=50"
        $jobs = Invoke-Api GET $path $null 30
        foreach ($job in @($jobs.content.list)) {
            try {
                Invoke-Api DELETE "Job/$($job.id)" $null 30 | Out-Null
                Add-Result "Cleanup" "Job $($job.id)" "/Job/$($job.id)" DELETE 200 PASS "deleted" $job.id "deleted"
            } catch {
                Add-Result "Cleanup" "Job $($job.id)" "/Job/$($job.id)" DELETE (Get-ErrorCode $_) FAIL (Get-ErrorText $_) $job.id "not cleaned" "Manual cleanup may be required"
            }
        }
    } catch {
        Add-Result "Cleanup" "Codex Smoke jobs" "/Job" GET (Get-ErrorCode $_) BLOCK (Get-ErrorText $_) "" "unknown" "Manual cleanup may be required"
    }
}

try {
    $web = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/" -TimeoutSec 20 -ErrorAction Stop
    Add-Result "Baseline" "Frontend shell" $BaseUrl GET $web.StatusCode PASS "HTML length=$($web.Content.Length)"
} catch {
    Add-Result "Baseline" "Frontend shell" $BaseUrl GET "" FAIL (Get-ErrorText $_) "" "" "Check docker compose ps/logs"
}

try {
    $basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${Username}:${Password}"))
    $login = Invoke-RestMethod -Method Get -Uri "$apiBase/App/user" -Headers @{ "Authorization" = "Basic $basic"; "X-Requested-With" = "XMLHttpRequest" } -TimeoutSec 30 -ErrorAction Stop
    $script:headers = @{ "Authorization-Token" = $login.authorizationToken; "X-Requested-With" = "XMLHttpRequest" }
    Add-Result "Auth" "Admin login" "/App/user" GET 200 PASS "authorizationToken acquired"
} catch {
    Add-Result "Auth" "Admin login" "/App/user" GET (Get-ErrorCode $_) FAIL (Get-ErrorText $_) "" "" "Verify admin password"
}

if ($script:headers) {
    foreach ($ep in @("Metadata", "Settings", "I18n", "background")) {
        try {
            $r = Invoke-Api GET $ep $null 60
            Add-Result "Baseline" $ep "/$ep" GET $r.status PASS "endpoint available; bytes=$($r.raw.Length)"
        } catch {
            Add-Result "Baseline" $ep "/$ep" GET (Get-ErrorCode $_) FAIL (Get-ErrorText $_)
        }
    }

    try {
        $modules = docker compose exec -T web sh -lc "cd /var/www/localhost && cat data/modules.json" 2>&1 | Out-String
        $ok = $modules -match "MyCompany" -and $modules -match "Import" -and $modules -match "Export"
        Add-Result "Modules" "Installed modules" "data/modules.json" CLI "" (Result-If $ok) (Shorten $modules) "" "" "Expected Import/Export/MyCompany"
    } catch {
        Add-Result "Modules" "Installed modules" "data/modules.json" CLI "" FAIL $_.Exception.Message
    }

    try {
        $schema = docker compose exec -T web php console.php sql diff --show 2>&1 | Out-String
        $ok = $schema -match "No database changes were detected"
        Add-Result "Schema" "SQL diff" "php console.php sql diff --show" CLI "" (Result-If $ok) (Shorten $schema 500) "" "" "Review and apply safe schema diff if expected"
    } catch {
        Add-Result "Schema" "SQL diff" "php console.php sql diff --show" CLI "" FAIL $_.Exception.Message
    }

    try {
        $oa = Invoke-WebRequest -UseBasicParsing -Uri "$BaseUrl/openapi.json" -TimeoutSec 60 -ErrorAction Stop
        $oj = $oa.Content | ConvertFrom-Json
        $pathCount = @($oj.paths.PSObject.Properties).Count
        $opCount = 0
        foreach ($p in $oj.paths.PSObject.Properties) {
            $opCount += @($p.Value.PSObject.Properties | Where-Object { $_.Name -match "^(get|post|put|patch|delete)$" }).Count
        }
        Add-Result "OpenAPI" "OpenAPI read" "/openapi.json" GET $oa.StatusCode PASS "paths=$pathCount ops=$opCount"
    } catch {
        Add-Result "OpenAPI" "OpenAPI read" "/openapi.json" GET (Get-ErrorCode $_) FAIL (Get-ErrorText $_)
    }

    foreach ($scope in @("Account", "Contact", "Product", "File", "ImportFeed", "ExportFeed", "Job")) {
        try {
            $listPath = "${scope}?maxSize=3"
            $r = Invoke-Api GET $listPath $null 30
            Add-Result "EntityList" $scope "/$listPath" GET $r.status PASS "list read"
        } catch {
            Add-Result "EntityList" $scope "/${scope}?maxSize=3" GET (Get-ErrorCode $_) FAIL (Get-ErrorText $_)
        }
    }

    $accId = $null; $conId = $null; $prodId = $null; $folderId = $null

    try {
        $acc = New-Entity Account @{ name = "$prefix Account" }; $accId = $acc.content.id
        Invoke-Api PUT "Account/$accId" @{ name = "$prefix Account Updated" } | Out-Null
        Invoke-Api GET "Account/$accId" | Out-Null
        Add-Result "CRUD" "Account CRUD" "/Account" POSTGETPUTDELETE 200 PASS "created/updated/read; id=$accId" $accId
    } catch {
        Add-Result "CRUD" "Account CRUD" "/Account" POSTGETPUTDELETE (Get-ErrorCode $_) FAIL (Get-ErrorText $_)
    }

    try {
        $con = New-Entity Contact @{ firstName = "Codex"; lastName = "Smoke"; name = "$prefix Contact" }; $conId = $con.content.id
        Invoke-Api PUT "Contact/$conId" @{ firstName = "Codex"; lastName = "Smoke"; name = "$prefix Contact Updated" } | Out-Null
        Invoke-Api GET "Contact/$conId" | Out-Null
        Add-Result "CRUD" "Contact CRUD" "/Contact" POSTGETPUTDELETE 200 PASS "created/updated/read; id=$conId" $conId
    } catch {
        Add-Result "CRUD" "Contact CRUD" "/Contact" POSTGETPUTDELETE (Get-ErrorCode $_) FAIL (Get-ErrorText $_)
    }

    try {
        $prod = New-Entity Product @{ name = "$prefix Product"; number = "CS-$run" }; $prodId = $prod.content.id
        Invoke-Api PUT "Product/$prodId" @{ name = "$prefix Product Updated" } | Out-Null
        Invoke-Api GET "Product/$prodId" | Out-Null
        Add-Result "CRUD" "Product CRUD" "/Product" POSTGETPUTDELETE 200 PASS "created/updated/read; id=$prodId" $prodId
    } catch {
        Add-Result "CRUD" "Product CRUD" "/Product" POSTGETPUTDELETE (Get-ErrorCode $_) FAIL (Get-ErrorText $_)
    }

    if ($accId -and $conId) {
        try {
            Invoke-Api POST "Account/$accId/contacts" @{ id = $conId } | Out-Null
            Invoke-Api GET "Account/$accId/contacts?maxSize=10" | Out-Null
            Invoke-Api DELETE "Account/$accId/contacts" @{ id = $conId } | Out-Null
            Add-Result "Relations" "Account.contacts link/unlink" "/Account/$accId/contacts" POSTGETDELETE 200 PASS "link/read/unlink completed" @{ account = $accId; contact = $conId }
        } catch {
            Add-Result "Relations" "Account.contacts link/unlink" "/Account/$accId/contacts" POSTGETDELETE (Get-ErrorCode $_) FAIL (Get-ErrorText $_) @{ account = $accId; contact = $conId }
        }
    }

    try {
        $folder = New-Entity Folder @{ name = "$prefix Folder" }; $folderId = $folder.content.id
        $fileText = "$prefix file content"
        $fileContent = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($fileText))
        $file = New-Entity File @{ name = "$prefix File.txt"; fileSize = $fileText.Length; fileContents = "data:text/plain;base64,$fileContent"; folderId = $folderId }
        $fileId = $file.content.id
        $fr = Invoke-Api GET "File/$fileId"
        $hasSignal = $fr.raw -match "download|url|File.txt"
        Add-Result "File" "File create metadata" "/File" POSTGET 200 PASS "metadata read; download/name signal=$hasSignal" $fileId
    } catch {
        Add-Result "File" "File create metadata" "/File" POSTGET (Get-ErrorCode $_) FAIL (Get-ErrorText $_)
    }

    try {
        $importCode = ("codex_import_" + $run).ToLower()
        $imp = New-Entity ImportFeed @{
            name = "$prefix ImportFeed"; code = $importCode; maxPerJob = 0; executeAs = "system"; isActive = $true;
            repeatProcessing = "mistake"; type = "simple"; processingType = "configurator"; fileDataAction = "create_update";
            format = "JSON"; decimalMark = "."; entity = "Account"; delimiter = "~"; fieldDelimiterForRelation = "|";
            emptyValue = ""; nullValue = "Null"; skipValue = "Skip"; markForNoRelation = "Null";
            markForUnlinkedAttribute = "N/A"; folderId = $folderId; data = @{}
        }
        $impId = $imp.content.id
        New-Entity ImportConfiguratorItem @{ name = "id"; column = @("ID"); importFeedId = $impId; entityIdentifier = $true; sortOrder = 0; locale = "main" } | Out-Null
        New-Entity ImportConfiguratorItem @{ name = "name"; column = @("Name"); importFeedId = $impId; sortOrder = 10; locale = "main" } | Out-Null
        Invoke-Api GET "ImportFeed/action/verifyFeedByCode?code=$importCode" | Out-Null
        Invoke-Api POST "ImportFeed/action/importData" @{ code = $importCode; json = @(@{ ID = "codex-$run"; Name = "$prefix Imported Account" }) } 120 | Out-Null
        docker compose exec -T web php console.php cron | Out-Null
        Start-Sleep -Seconds 3
        $search = "Account?where[0][type]=contains&where[0][attribute]=name&where[0][value]=" + [uri]::EscapeDataString("$prefix Imported Account") + "&maxSize=10"
        $found = Invoke-Api GET $search $null 30
        $imported = @($found.content.list | Where-Object { $_.name -like "*Imported Account*" })
        if ($imported.Count) { $created.Add([pscustomobject]@{ scope = "Account"; id = $imported[0].id }) | Out-Null }
        $impResult = Result-If ($imported.Count -gt 0) "PASS" "BLOCK"
        $impAccount = $null
        if ($imported.Count) { $impAccount = $imported[0].id }
        Add-Result "Import" "ImportFeed importData" "/ImportFeed/action/importData" POSTCLI 200 $impResult "importedAccounts=$($imported.Count)" @{ feed = $impId; account = $impAccount } "" "If blocked, inspect ImportJobLog"
    } catch {
        Add-Result "Import" "ImportFeed importData" "/ImportFeed/action/importData" POSTCLI (Get-ErrorCode $_) FAIL (Get-ErrorText $_)
    }

    try {
        $exportCode = ("codex_export_" + $run).ToLower()
        $exp = New-Entity ExportFeed @{
            name = "$prefix ExportFeed"; code = $exportCode; type = "simple"; fileType = "json"; entity = "Account";
            folderId = $folderId; localeId = "main"; isActive = $true; limit = 100; data = @{};
            fileNameMask = "codex-smoke.json"; template = "{{ entities|json_encode }}"; emptyValue = "";
            nullValue = "Null"; markForNoRelation = "Null"; markForUnlinkedAttribute = "N/A";
            delimiter = "~"; fieldDelimiterForRelation = "|"
        }
        $expId = $exp.content.id
        New-Entity ExportConfiguratorItem @{ name = "id"; type = "Field"; columnType = "name"; exportFeedId = $expId; sortOrder = 0 } | Out-Null
        New-Entity ExportConfiguratorItem @{ name = "name"; type = "Field"; columnType = "name"; exportFeedId = $expId; sortOrder = 10 } | Out-Null
        Invoke-Api GET "ExportFeed/action/verifyFeedByCode?code=$exportCode" | Out-Null
        $ed = Invoke-Api GET "ExportFeed/action/exportData?code=$exportCode&offset=0" $null 120
        $contains = $ed.raw -match [regex]::Escape($prefix)
        $expResult = Result-If $contains "PASS" "BLOCK"
        Add-Result "Export" "ExportFeed exportData" "/ExportFeed/action/exportData" GET $ed.status $expResult "containsCodexSmoke=$contains" $expId "" "If blocked, inspect ExportFeed config/filter"
    } catch {
        Add-Result "Export" "ExportFeed exportData" "/ExportFeed/action/exportData" GET (Get-ErrorCode $_) FAIL (Get-ErrorText $_)
    }

    try {
        $cron = docker compose exec -T web php console.php cron 2>&1 | Out-String
        Add-Result "Cron" "Console cron" "php console.php cron" CLI "" PASS (Shorten $cron)
    } catch {
        Add-Result "Cron" "Console cron" "php console.php cron" CLI "" FAIL $_.Exception.Message
    }

    try {
        $logs = docker compose exec -T web sh -lc "cd /var/www/localhost && find data/logs -maxdepth 1 -type f -print -exec tail -n 120 {} \;" 2>&1 | Out-String
        $currentLogs = Get-CurrentRunLogLines $logs
        $fatal = $currentLogs -match "Fatal error|Uncaught|Log\.ERROR"
        $currentWarnings = $currentLogs -match "Log\.WARNING|E_WARNING|Undefined array key"
        if ($fatal) {
            Add-Result "Logs" "AtroCore logs" "data/logs" CLI "" FAIL (Shorten $currentLogs 700) "" "" "Review fatal/unhandled log errors"
        } elseif ($currentWarnings) {
            Add-Result "Logs" "AtroCore logs" "data/logs" CLI "" BLOCK (Shorten $currentLogs 700) "" "" "Non-fatal warnings detected during this run; review before production"
        } else {
            Add-Result "Logs" "AtroCore logs" "data/logs" CLI "" PASS "no fatal/error/warning entries after $($runStartedAt.ToString("s"))"
        }
    } catch {
        Add-Result "Logs" "AtroCore logs" "data/logs" CLI "" FAIL $_.Exception.Message
    }
}

Remove-Created
Remove-Smoke-Jobs

foreach ($scope in @("Account", "Contact", "Product", "File", "ImportFeed", "ExportFeed", "Job")) {
    if ($script:headers) {
        try {
            $path = "${scope}?where[0][type]=contains&where[0][attribute]=name&where[0][value]=" + [uri]::EscapeDataString("Codex Smoke") + "&maxSize=20"
            $r = Invoke-Api GET $path $null 30
            $count = @($r.content.list).Count
            $cleanupResult = Result-If ($count -eq 0)
            $cleanupText = "residue"
            if ($count -eq 0) { $cleanupText = "clean" }
            Add-Result "CleanupCheck" "$scope Codex Smoke residue" "/$scope" GET $r.status $cleanupResult "remaining=$count" "" $cleanupText "Manual cleanup may be required"
        } catch {
            Add-Result "CleanupCheck" "$scope Codex Smoke residue" "/$scope" GET (Get-ErrorCode $_) BLOCK (Get-ErrorText $_) "" "unknown" "Entity may not support name filter"
        }
    }
}

$jsonPath = Join-Path $ReportDir "full-acceptance-$run.json"
$mdPath = Join-Path $ReportDir "full-acceptance-$run.md"
$results | ConvertTo-Json -Depth 20 | Set-Content -Encoding UTF8 $jsonPath

$pass = @($results | Where-Object result -eq "PASS").Count
$fail = @($results | Where-Object result -eq "FAIL").Count
$block = @($results | Where-Object result -eq "BLOCK").Count

$md = New-Object System.Collections.Generic.List[string]
$md.Add("# AtroCore Docker Full Acceptance $run") | Out-Null
$md.Add("") | Out-Null
$md.Add("- BaseUrl: $BaseUrl") | Out-Null
$md.Add("- Summary: PASS=$pass FAIL=$fail BLOCK=$block") | Out-Null
$md.Add("- Prefix: $prefix") | Out-Null
$md.Add("") | Out-Null
$md.Add("| Group | Name | Entry | Method | Status | Result | Summary | Cleanup | Next |") | Out-Null
$md.Add("|---|---|---|---|---:|---|---|---|---|") | Out-Null
foreach ($r in $results) {
    $summary = (Shorten $r.summary 180) -replace "\|", "/"
    $next = (Shorten $r.next 120) -replace "\|", "/"
    $line = "| $($r.group) | $($r.name) | ``$($r.entry)`` | $($r.method) | $($r.statusCode) | $($r.result) | $summary | $($r.cleanup) | $next |"
    $md.Add($line) | Out-Null
}
$md | Set-Content -Encoding UTF8 $mdPath

Write-Host "Report JSON: $jsonPath"
Write-Host "Report MD:   $mdPath"
Write-Host "Summary: PASS=$pass FAIL=$fail BLOCK=$block"
if ($fail -gt 0) { exit 1 }
