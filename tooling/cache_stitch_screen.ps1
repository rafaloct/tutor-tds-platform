param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-zA-Z0-9]+$')][string]$ScreenId,
    [ValidatePattern('^[a-zA-Z0-9]+$')][string]$SourceScreenId
)
$ErrorActionPreference = 'Stop'
$projectId = '3740249934950673416'
$repoRoot = Split-Path $PSScriptRoot -Parent
$folder = Join-Path $repoRoot ".stitch/designs/$ScreenId"
if ($SourceScreenId) { $folder = Join-Path $repoRoot ".stitch/designs/$SourceScreenId/derivatives/$ScreenId" }
$metadataPath = Join-Path $folder 'metadata.json'
if (Test-Path -LiteralPath $metadataPath) {
    $existing = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
    foreach ($file in $existing.sha256.PSObject.Properties.Name) {
        $hash = (Get-FileHash -LiteralPath (Join-Path $folder $file) -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -ne $existing.sha256.$file) { throw 'Cache changed: investigate before fetching again.' }
    }
    if ($existing.assetKind -eq 'imported_reference_image' -and $existing.htmlStatus -eq 'NOT_APPLICABLE_IMPORTED_IMAGE') {
        Write-Output "Verified imported image cache: $ScreenId; HTML N/A, derivative required for UI."
        exit 0
    }
    if (-not (Test-Path -LiteralPath (Join-Path $folder 'screen.html'))) {
        throw 'Screenshot cache verified; HTML export requires Google browser authentication. No API request repeated.'
    }
    $html = Get-Content -LiteralPath (Join-Path $folder 'screen.html') -Raw
    if ($html -notmatch '(?i)<html|<!doctype' -or $html -match 'accounts.google.com/v3/signin|<title>Sign in - Google Accounts') {
        throw 'Local HTML is not a design export.'
    }
    if (-not $existing.sha256.'screen.html') {
        $existing.sha256 | Add-Member -NotePropertyName 'screen.html' -NotePropertyValue ((Get-FileHash -LiteralPath (Join-Path $folder 'screen.html') -Algorithm SHA256).Hash.ToLowerInvariant())
        $existing | Add-Member -NotePropertyName htmlStatus -NotePropertyValue 'IMPORTED_REQUIRES_VISUAL_REVIEW' -Force
        $existing | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $metadataPath -Encoding utf8
    }
    Write-Output "Verified local cache: $ScreenId"
    exit 0
}
$stitchCredential = $env:STITCH_API_KEY
if (-not $stitchCredential) { $stitchCredential = $env:STITCH_VAR }
if (-not $stitchCredential) { $stitchCredential = [Environment]::GetEnvironmentVariable('STITCH_VAR','User') }
if (-not $stitchCredential) { throw 'STITCH_API_KEY or STITCH_VAR unavailable.' }
$body = @{
    jsonrpc='2.0'; id=1; method='tools/call'
    params=@{name='get_screen';arguments=@{name="projects/$projectId/screens/$ScreenId"}}
} | ConvertTo-Json -Depth 5
$result = Invoke-RestMethod -Uri 'https://stitch.googleapis.com/mcp' -Method Post `
    -Headers @{'X-Goog-Api-Key'=$stitchCredential;Accept='application/json, text/event-stream'} `
    -ContentType 'application/json' -Body $body -TimeoutSec 35
if ($result.error -or $result.result.isError) { throw 'Stitch rejected get_screen; no assets saved.' }
$data = $result.result.structuredContent
if (-not $data) { $data = ($result.result.content | Where-Object type -EQ 'text' | Select-Object -First 1).text | ConvertFrom-Json }
if (-not $data.screenshot.downloadUrl -or -not $data.htmlCode.downloadUrl) {
    throw 'Screen has no HTML/screenshot pair. Do not fabricate missing assets.'
}
$privateMetadata = Join-Path $repoRoot "tmp/stitch-$ScreenId.json"
$data | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $privateMetadata -Encoding utf8
New-Item -ItemType Directory -Force -Path $folder | Out-Null
Invoke-WebRequest -Uri $data.screenshot.downloadUrl -OutFile (Join-Path $folder 'screen.png') -TimeoutSec 35
curl.exe --silent --show-error --fail --location --max-time 35 $data.htmlCode.downloadUrl --output (Join-Path $folder 'screen.html')
if ($LASTEXITCODE -ne 0) { throw 'HTML download failed.' }
$bytes = [IO.File]::ReadAllBytes((Join-Path $folder 'screen.png'))
if ([Convert]::ToHexString($bytes[0..7]) -ne '89504E470D0A1A0A') {
    python -c 'from PIL import Image; import sys; p=sys.argv[1]; im=Image.open(p); im.load(); im.save(p,format="PNG")' (Join-Path $folder 'screen.png')
    if ($LASTEXITCODE -ne 0) { throw 'Image conversion failed.' }
}
$html = Get-Content -LiteralPath (Join-Path $folder 'screen.html') -Raw
if ($html -notmatch '(?i)<html|<!doctype' -or $html -match 'accounts.google.com/v3/signin|<title>Sign in - Google Accounts') {
    Move-Item -LiteralPath (Join-Path $folder 'screen.html') -Destination (Join-Path $repoRoot "tmp/stitch-$ScreenId-rejected.html") -Force
    throw 'HTML requires Google browser authentication; screenshot retained, cache incomplete.'
}
$hashes = @{}
foreach ($file in @('screen.png','screen.html')) {
    $hashes[$file] = (Get-FileHash -LiteralPath (Join-Path $folder $file) -Algorithm SHA256).Hash.ToLowerInvariant()
}
@{
    projectId=$projectId; screenId=$ScreenId; title=$data.title; name=$data.name
    retrievedAt=[DateTime]::UtcNow.ToString('o'); sha256=$hashes
    width=$data.width; height=$data.height; deviceType=$data.deviceType
    transport='MCP get_screen with name only; schema inspected 2026-09-23'
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $metadataPath -Encoding utf8
Write-Output "Cached $ScreenId : $($data.title)"
