<#
 .SYNOPSIS
  Build (or rebuild) the image and start the ATM10 server detached.

 .DESCRIPTION
  Executes `docker compose up -d` which will rebuild the image if the Dockerfile
  or build context changed. Use this ONLY when updating the server pack or image.

 .IMPORTANT
  This script is intended for updates. For normal usage, run `./run-server.ps1`.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Error 'docker is required but not found in PATH.'
}

try { docker compose version | Out-Host } catch { Write-Host 'docker compose version unavailable' }

Write-Warning 'CRITICAL: This will rebuild the image. Use only for server UPDATE.'
Write-Host 'Building and starting ATM10 server (detached): docker compose up -d'
docker compose up -d
Write-Host 'Follow logs with: docker compose logs -f'

