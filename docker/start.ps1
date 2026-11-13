param([switch]$Build)

$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
$projectDir = Split-Path -Parent $scriptDir
$composeFile = Join-Path $scriptDir 'docker-compose.yml'

function Get-DockerReady {
    param([int]$Timeout = 240)

    $deadline = (Get-Date).AddSeconds($Timeout)
    $launchAttempted = $false

    while ((Get-Date) -lt $deadline) {
        docker info 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { return $true }

        if (-not $launchAttempted) {
            $candidates = @(
                'C:\Program Files\Docker\Docker\Docker Desktop.exe',
                (Join-Path $env:LOCALAPPDATA 'Programs\Docker\Docker\Docker Desktop.exe')
            )
            $exe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
            if ($exe) {
                Write-Host '[*] Starting Docker Desktop...'
                Start-Process $exe | Out-Null
                $launchAttempted = $true
            }
        }

        Write-Host '[*] Waiting for Docker engine...'
        Start-Sleep -Seconds 5
    }

    Write-Host '[!] Docker engine is not available. Start Docker Desktop manually and retry.'
    return $false
}

if (-not (Get-DockerReady)) { exit 1 }

Push-Location $projectDir
try {
    Write-Host '[*] Starting dsh container...'
    if ($Build) {
        docker compose -f $composeFile up -d --build
    } else {
        docker compose -f $composeFile up -d
    }
    if ($LASTEXITCODE -ne 0) {
        Write-Host '[!] docker compose up failed.'
        exit 1
    }

    Write-Host '[*] Waiting for the web token...'
    $token = $null
    for ($i = 0; $i -lt 90; $i++) {
        $lines = docker compose -f $composeFile logs dsh 2>$null
        $match = $lines | Select-String -Pattern 'token=([A-Za-z0-9_\-]+)' | Select-Object -Last 1
        if ($match) {
            $token = $match.Matches[0].Groups[1].Value
            break
        }
        Start-Sleep -Seconds 2
    }

    if (-not $token) {
        Write-Host '[!] Token not printed yet. Check logs with:'
        Write-Host "    docker compose -f `"$composeFile`" logs dsh"
        exit 1
    }

    $port = '3080'
    $published = docker compose -f $composeFile port dsh 3081 2>$null
    $portMatch = [regex]::Match(($published -join ' '), ':(\d+)\s*$')
    if ($portMatch.Success) { $port = $portMatch.Groups[1].Value }

    $url = "http://localhost:$port/?token=$token"
    Write-Host ''
    Write-Host '  dsh web is ready:' -ForegroundColor Green
    Write-Host "  $url"
    Write-Host ''
    Write-Host '  Stop : docker compose -f docker\docker-compose.yml down'
    Write-Host '  Restart with rebuild : start.cmd -Build'
    Write-Host ''

    Start-Process $url
}
finally {
    Pop-Location
}
