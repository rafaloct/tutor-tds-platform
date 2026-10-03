$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Test-ProductionRecoveryEvidence.ps1')

$fields = @(
    'offsite_backup',
    'postgres_restore',
    'critical_volumes_restore',
    'upgrade_compatibility',
    'backend_schema_compatibility'
)
$script:checked = 0

function New-Proof {
    param([hashtable]$Overrides = @{})
    $proof = [ordered]@{ status = 'passed' }
    foreach ($field in $fields) { $proof[$field] = $true }
    foreach ($key in $Overrides.Keys) { $proof[$key] = $Overrides[$key] }
    return [pscustomobject]$proof
}

function Check {
    param([string]$Name, [bool]$Expected, [object]$Proof)
    $passed = $false
    try { Assert-ProductionRecoveryEvidence $Proof | Out-Null; $passed = $true } catch {
        if ($Expected) { throw "$Name falhou inesperadamente: $($_.Exception.Message)" }
    }
    if ($passed -ne $Expected) { throw "$Name deveria ter sido rejeitado." }
    $script:checked++
    Write-Output "PASS $Name"
}

Check 'valid proof' $true (New-Proof)
$invalidValues = @($false, 'true', 'false', 0, 1, [pscustomobject]@{ value = $true }, $null)
$invalidValues += ,@($true)
foreach ($field in $fields) {
    foreach ($value in $invalidValues) {
        $typeName = if ($null -eq $value) { 'null' } else { $value.GetType().Name }
        Check "$field rejects $typeName" $false (New-Proof @{ $field = $value })
    }
    $missing = New-Proof
    $missing.PSObject.Properties.Remove($field)
    Check "$field missing" $false $missing
}
Check 'status wrong value' $false (New-Proof @{ status = 'passed ' })
Check 'status wrong case' $false (New-Proof @{ status = 'Passed' })
Check 'status non-string boolean' $false (New-Proof @{ status = $true })
Check 'status non-string number' $false (New-Proof @{ status = 1 })
Check 'status null' $false (New-Proof @{ status = $null })
Check 'proof null' $false $null
Check 'proof string' $false 'proof'
Check 'proof number' $false 1
Check 'proof array' $false @()

Write-Output "OFFLINE_PRODUCTION_RECOVERY_EVIDENCE=PASS; cases=$script:checked; network=false; production_acceptance=false"
