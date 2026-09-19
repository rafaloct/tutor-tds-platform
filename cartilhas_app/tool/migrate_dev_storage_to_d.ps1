[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'

$devRoot = [IO.Path]::GetFullPath('D:\DevTools')
$backupRoot = [IO.Path]::GetFullPath('D:\DevTools\migration-backup\2026-08-11-caches')
$flutterRoot = [IO.Path]::GetFullPath('D:\flutter-3.44.9')
$flutterMain = [IO.Path]::GetFullPath('D:\DevTools\flutter-main')
$androidSdk = [IO.Path]::GetFullPath('D:\DevTools\AndroidSDK')
$gradleHome = [IO.Path]::GetFullPath('D:\DevTools\gradle')
$pubCache = [IO.Path]::GetFullPath('D:\DevTools\pub-cache')
$androidUserHome = [IO.Path]::GetFullPath('D:\DevTools\android-user')
$tempRoot = [IO.Path]::GetFullPath('D:\DevTools\temp')
$studioCacheRoot = [IO.Path]::GetFullPath('D:\DevTools\android-studio-cache')

function Assert-UnderDevRoot {
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [IO.Path]::GetFullPath($Path)
    if (-not $fullPath.StartsWith($devRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Destino fora de D:\DevTools: $fullPath"
    }
    return $fullPath
}

function Get-LinkTarget {
    param([Parameter(Mandatory)][System.IO.FileSystemInfo]$Item)

    return ($Item.Target -join ';')
}

function Move-AndCreateJunction {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$StoredAt,
        [Parameter(Mandatory)][string]$JunctionTarget
    )

    $sourceFull = [IO.Path]::GetFullPath($Source)
    $storedFull = Assert-UnderDevRoot $StoredAt
    $junctionFull = [IO.Path]::GetFullPath($JunctionTarget)

    if (-not ($junctionFull.StartsWith($devRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
              $junctionFull.Equals($flutterRoot, [StringComparison]::OrdinalIgnoreCase))) {
        throw "Alvo de juncao inesperado: $junctionFull"
    }

    if (Test-Path -LiteralPath $sourceFull) {
        $sourceItem = Get-Item -LiteralPath $sourceFull -Force
        if ($sourceItem.LinkType) {
            [pscustomobject]@{
                Status = 'ja configurado'
                Source = $sourceFull
                StoredAt = '-'
                JunctionTarget = Get-LinkTarget $sourceItem
            }
            return
        }
    }

    if ($Execute) {
        if (Test-Path -LiteralPath $sourceFull) {
            $robocopy = Join-Path $env:SystemRoot 'System32\robocopy.exe'
            & $robocopy `
                $sourceFull `
                $storedFull `
                /E /MOVE /COPY:DAT /DCOPY:DAT /R:2 /W:1 /XJ `
                /NFL /NDL /NP /NJH /NJS
            $robocopyCode = $LASTEXITCODE
            if ($robocopyCode -ge 8) {
                throw "Falha ao mover $sourceFull (Robocopy $robocopyCode)."
            }
            if (Test-Path -LiteralPath $sourceFull) {
                $remaining = @(Get-ChildItem -LiteralPath $sourceFull -Force)
                if ($remaining.Count -gt 0) {
                    throw "Itens permaneceram na origem: $($remaining.FullName -join ', ')"
                }
                Remove-Item -LiteralPath $sourceFull
            }
        }
        if (-not (Test-Path -LiteralPath $junctionFull)) {
            throw "Alvo da juncao ausente apos a migracao: $junctionFull"
        }
        if (-not (Test-Path -LiteralPath $sourceFull)) {
            New-Item -ItemType Junction -Path $sourceFull -Target $junctionFull | Out-Null
        }
    }

    [pscustomobject]@{
        Status = if ($Execute) { 'migrado' } else { 'planejado' }
        Source = $sourceFull
        StoredAt = $storedFull
        JunctionTarget = $junctionFull
    }
}

function Set-UserEnvironment {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string]$Value)

    if ($Execute) {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
        Set-Item -Path "Env:$Name" -Value $Value
    }
    [pscustomobject]@{ Variable = $Name; Value = $Value }
}

if (-not (Test-Path -LiteralPath $flutterRoot)) {
    throw "Flutter no D: nao encontrado: $flutterRoot"
}
if (-not (Test-Path -LiteralPath $androidSdk)) {
    throw "Android SDK no D: nao encontrado: $androidSdk"
}
if (-not (Test-Path -LiteralPath $gradleHome)) {
    throw "Gradle no D: nao encontrado: $gradleHome"
}

$blockingProcesses = Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(studio64|idea64|dart|flutter)$' }
if ($Execute -and $blockingProcesses) {
    $names = ($blockingProcesses.Name | Sort-Object -Unique) -join ', '
    throw "Feche os processos antes da migracao: $names"
}

if ($Execute) {
    $adb = Join-Path $androidSdk 'platform-tools\adb.exe'
    if (Test-Path -LiteralPath $adb) {
        try {
            & $adb kill-server 2>$null
        } catch {
            # O estado desejado ja foi atingido quando nao existe daemon ativo.
        }
    }
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.Name -eq 'java.exe' -and
            $_.CommandLine -like '*org.gradle.launcher.daemon.bootstrap.GradleDaemon*'
        } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

    New-Item -ItemType Directory -Path $devRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $studioCacheRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
}

$moves = @()
$moves += Move-AndCreateJunction `
    -Source 'C:\Users\Rafael\.gradle' `
    -StoredAt (Join-Path $backupRoot 'gradle-c') `
    -JunctionTarget $gradleHome
$moves += Move-AndCreateJunction `
    -Source 'C:\Users\Rafael\AppData\Local\Pub\Cache' `
    -StoredAt $pubCache `
    -JunctionTarget $pubCache
$moves += Move-AndCreateJunction `
    -Source 'C:\Users\Rafael\.android' `
    -StoredAt $androidUserHome `
    -JunctionTarget $androidUserHome
$moves += Move-AndCreateJunction `
    -Source 'C:\Users\Rafael\AppData\Local\Android\Sdk' `
    -StoredAt (Join-Path $backupRoot 'android-sdk-c') `
    -JunctionTarget $androidSdk
$moves += Move-AndCreateJunction `
    -Source 'C:\flutter' `
    -StoredAt $flutterMain `
    -JunctionTarget $flutterRoot

if ($Execute -and (Test-Path -LiteralPath (Join-Path $flutterMain '.git'))) {
    & git -C $flutterMain worktree repair $flutterRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'Falha ao reparar o worktree do Flutter no D:.'
    }
}

$studioRoot = [IO.Path]::GetFullPath('C:\Users\Rafael\AppData\Local\Google')
if (Test-Path -LiteralPath $studioRoot) {
    $studioDirs = Get-ChildItem -LiteralPath $studioRoot -Directory -Force |
        Where-Object { $_.Name -like 'AndroidStudio*' }
    foreach ($studioDir in $studioDirs) {
        $expectedPrefix = $studioRoot + '\AndroidStudio'
        if (-not $studioDir.FullName.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Origem inesperada: $($studioDir.FullName)"
        }
        $studioTarget = Join-Path $studioCacheRoot $studioDir.Name
        $moves += Move-AndCreateJunction `
            -Source $studioDir.FullName `
            -StoredAt $studioTarget `
            -JunctionTarget $studioTarget
    }
}

$environment = @()
$environment += Set-UserEnvironment 'GRADLE_USER_HOME' $gradleHome
$environment += Set-UserEnvironment 'PUB_CACHE' $pubCache
$environment += Set-UserEnvironment 'ANDROID_USER_HOME' $androidUserHome
$environment += Set-UserEnvironment 'ANDROID_HOME' $androidSdk
$environment += Set-UserEnvironment 'ANDROID_SDK_ROOT' $androidSdk
$environment += Set-UserEnvironment 'FLUTTER_ROOT' $flutterRoot
$environment += Set-UserEnvironment 'TEMP' $tempRoot
$environment += Set-UserEnvironment 'TMP' $tempRoot

$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pathParts = @($userPath -split ';' | Where-Object {
    $_ -and -not $_.Trim().Equals('C:\flutter\bin', [StringComparison]::OrdinalIgnoreCase) -and
    -not $_.Trim().Equals((Join-Path $flutterRoot 'bin'), [StringComparison]::OrdinalIgnoreCase)
})
$newUserPath = (@((Join-Path $flutterRoot 'bin')) + $pathParts) -join ';'
if ($Execute) {
    [Environment]::SetEnvironmentVariable('Path', $newUserPath, 'User')
    $env:Path = (Join-Path $flutterRoot 'bin') + ';' + $env:Path
}
$environment += [pscustomobject]@{ Variable = 'Path (primeiro item)'; Value = Join-Path $flutterRoot 'bin' }

$moves | Format-Table Status, Source, StoredAt, JunctionTarget -AutoSize
$environment | Format-Table Variable, Value -AutoSize

if (-not $Execute) {
    Write-Host 'Simulacao concluida. Execute novamente com -Execute para aplicar.'
} else {
    Write-Host 'Migracao concluida. Abra um novo terminal para herdar todas as variaveis.'
}
