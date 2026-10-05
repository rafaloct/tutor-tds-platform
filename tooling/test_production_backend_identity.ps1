$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Test-ProductionBackendIdentity.ps1')
$expectedSchema = Get-CanonicalAlembicHead
$script:checked = 0
function New-VersionPayload {
    param([hashtable]$Overrides = @{})
    $payload = [ordered]@{ api_version='0.1.0'; schema_version=$expectedSchema; minimum_supported_app_version='1.4.0+13'; environment='production'; compatibility_verified=$true }
    foreach ($key in $Overrides.Keys) { $payload[$key] = $Overrides[$key] }
    return [pscustomobject]$payload
}
function Check {
    param([string]$Name, [bool]$Expected, [object]$Payload, [string]$Candidate='1.4.0', [long]$Code=13)
    $passed=$false
    try { Assert-ProductionBackendIdentity $Payload $expectedSchema $Candidate $Code | Out-Null; $passed=$true } catch { if ($Expected) { throw "$Name failed unexpectedly: $($_.Exception.Message)" } }
    if ($passed -ne $Expected) { throw "$Name should have been rejected." }
    $script:checked++
    Write-Output "PASS $Name"
}
Check 'equal semantic version and build' $true (New-VersionPayload)
Check 'higher patch' $true (New-VersionPayload) '1.4.1' 14
Check 'numeric comparison 1.10 above 1.9' $true (New-VersionPayload @{minimum_supported_app_version='1.9.0'}) '1.10.0'
Check 'minimum without optional build' $true (New-VersionPayload @{minimum_supported_app_version='1.4.0'})
Check 'consistent embedded candidate build' $true (New-VersionPayload) '1.4.0+13'
Check 'lower semantic version' $false (New-VersionPayload) '1.3.9' 20
Check 'lower major version despite high minor' $false (New-VersionPayload @{minimum_supported_app_version='2.0.0'}) '1.99.99' 20
Check 'lower candidate build' $false (New-VersionPayload) '1.4.0' 12
Check 'higher semantic version cannot bypass Android build floor' $false (New-VersionPayload @{minimum_supported_app_version='1.2.0+15'}) '1.4.0' 13
Check 'conflicting embedded candidate build' $false (New-VersionPayload) '1.4.0+12' 13
Check 'staging environment' $false (New-VersionPayload @{environment='staging'})
Check 'case-sensitive environment' $false (New-VersionPayload @{environment='Production'})
Check 'empty schema' $false (New-VersionPayload @{schema_version=''})
Check 'malformed schema' $false (New-VersionPayload @{schema_version='20261001 0020'})
Check 'different migration' $false (New-VersionPayload @{schema_version='20260923_0019'})
Check 'array schema rejected' $false (New-VersionPayload @{schema_version=@($expectedSchema)})
Check 'false compatibility' $false (New-VersionPayload @{compatibility_verified=$false})
Check 'string true rejected' $false (New-VersionPayload @{compatibility_verified='true'})
Check 'string false rejected' $false (New-VersionPayload @{compatibility_verified='false'})
Check 'integer compatibility rejected' $false (New-VersionPayload @{compatibility_verified=1})
Check 'malformed minimum' $false (New-VersionPayload @{minimum_supported_app_version='1.4'})
Check 'empty minimum' $false (New-VersionPayload @{minimum_supported_app_version=''})
Check 'numeric minimum rejected' $false (New-VersionPayload @{minimum_supported_app_version=14})
Check 'malformed api version' $false (New-VersionPayload @{api_version='local-server'})
Check 'malformed candidate' $false (New-VersionPayload) '1.4'
Check 'zero build rejected' $false (New-VersionPayload) '1.4.0' 0
foreach($field in @('api_version','schema_version','minimum_supported_app_version','environment','compatibility_verified')) {
    $payload=New-VersionPayload
    $payload.PSObject.Properties.Remove($field)
    Check "missing $field" $false $payload
}
Write-Output "OFFLINE_BACKEND_IDENTITY=PASS; cases=$script:checked; network=false; production_acceptance=false"

$future = Get-CanonicalAlembicHead -MigrationDefinitions @(
    "revision = 'base_1'`ndown_revision = None",
    "revision = 'future_9999'`ndown_revision = 'base_1'"
)
if ($future -cne 'future_9999') { throw 'future HEAD should resolve without literal edits.' }
$script:checked++; Write-Output 'PASS future HEAD is dynamic'
try {
    Get-CanonicalAlembicHead -MigrationDefinitions @(
        "revision = 'base_1'`ndown_revision = None",
        "revision = 'branch_a'`ndown_revision = 'base_1'",
        "revision = 'branch_b'`ndown_revision = 'base_1'"
    ) | Out-Null
    throw 'multiple heads should fail.'
} catch { if ($_.Exception.Message -eq 'multiple heads should fail.') { throw } }
$script:checked++; Write-Output 'PASS multiple HEADs fail closed'
Write-Output "OFFLINE_BACKEND_IDENTITY_DYNAMIC_HEAD=PASS; cases=$script:checked; network=false; production_acceptance=false"
