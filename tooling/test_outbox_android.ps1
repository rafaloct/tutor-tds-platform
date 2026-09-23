param(
    [ValidatePattern('^emulator-[0-9]+$')][string]$Device = 'emulator-5556',
    [string]$Flutter = 'C:/Users/Usuario/flutter-3.44.9/bin/flutter.bat',
    [string]$Adb = 'C:/Users/Usuario/AppData/Local/Android/sdk/platform-tools/adb.exe'
)
$ErrorActionPreference = 'Stop'
$appRoot = Join-Path (Split-Path $PSScriptRoot -Parent) 'cartilhas_app'
$arguments = @(
    'test', 'integration_test/outbox_persistence_test.dart', '-d', $Device,
    '--no-pub', '--no-uninstall', '--reporter', 'expanded',
    '--dart-define=TUTOR_ENVIRONMENT=staging',
    '--dart-define=TUTOR_API_URL=https://ead.ipexdesenvolvimento.cloud/tutor-staging-api',
    '--dart-define=TUTOR_STAGING_API_URL=https://ead.ipexdesenvolvimento.cloud/tutor-staging-api',
    '--dart-define=DURABLE_LEARNING_OUTBOX_ENABLED=true'
)
Push-Location -LiteralPath $appRoot
try {
    & $Flutter @arguments '--dart-define=OUTBOX_QA_PHASE=seed'
    if ($LASTEXITCODE -ne 0) { throw 'Outbox seed failed; do not run verify.' }
    & $Adb -s $Device shell am force-stop com.tutortds_cartilhas.dev
    if ($LASTEXITCODE -ne 0) { throw 'Could not stop QA app.' }
    & $Flutter @arguments '--dart-define=OUTBOX_QA_PHASE=verify'
    if ($LASTEXITCODE -ne 0) { throw 'Outbox verification failed.' }
} finally {
    Pop-Location
}
