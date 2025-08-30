<#
 .SYNOPSIS
  Start the ATM10 server using the existing image (no rebuild).

 .DESCRIPTION
  Executes `docker compose up` to run the server and attach to logs.
  Use this for normal day-to-day operation.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Error 'docker is required but not found in PATH.'
}

try { docker compose version | Out-Host } catch { Write-Host 'docker compose version unavailable' }

Write-Host 'Starting ATM10 server (no rebuild): docker compose up'
docker compose up

