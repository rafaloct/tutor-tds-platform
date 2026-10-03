param([string]$Php = 'php')
$ErrorActionPreference = 'Stop'
$plugin = Join-Path $PSScriptRoot '../../tds-portal-core'
Get-ChildItem $plugin, $PSScriptRoot -Recurse -Filter *.php | ForEach-Object {
    & $Php -n -l $_.FullName
    if ($LASTEXITCODE -ne 0) { throw 'PHP lint failed' }
}
& $Php -n (Join-Path $PSScriptRoot 'test-wp2-foundation.php')
if ($LASTEXITCODE -ne 0) { throw 'PHP behavior tests failed' }
