function Get-RecoveryEvidenceProperty {
    param(
        [Parameter(Mandatory = $true)][object]$Proof,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $property = $Proof.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "prova de recuperação sem campo obrigatório '$Name'." }
    return ,$property.Value
}

function Assert-ProductionRecoveryEvidence {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][object]$Proof)

    Set-StrictMode -Version Latest
    if ($null -eq $Proof -or $Proof -is [string] -or $Proof -is [System.Array] -or
        $Proof -is [System.ValueType]) {
        throw 'prova de recuperação deve ser um objeto JSON.'
    }

    $status = Get-RecoveryEvidenceProperty $Proof 'status'
    if ($status -isnot [string] -or $status -cne 'passed') {
        throw 'status da prova de recuperação deve ser a string passed.'
    }

    foreach ($field in @(
        'offsite_backup',
        'postgres_restore',
        'critical_volumes_restore',
        'upgrade_compatibility',
        'backend_schema_compatibility'
    )) {
        $value = Get-RecoveryEvidenceProperty $Proof $field
        if ($value -isnot [bool] -or $value -ne $true) {
            throw "campo obrigatório da prova de recuperação inválido: $field."
        }
    }
    return $true
}
