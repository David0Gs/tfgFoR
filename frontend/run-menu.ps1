param(
  [string]$FlutterEntrypoint = "lib/main.dart"
)

$ErrorActionPreference = "Stop"

# Always run Flutter commands from the project root (where this script lives).
Set-Location -Path $PSScriptRoot

function Get-Devices {
  $raw = flutter devices --machine 2>$null
  if (-not $raw) {
    return @()
  }

  try {
    return ($raw | ConvertFrom-Json)
  } catch {
    return @()
  }
}

function Find-AndroidDeviceId($devices) {
  if (-not $devices) {
    return $null
  }

  # Prefer running emulators, then any Android device.
  $emulator = $devices | Where-Object {
    $_.targetPlatform -like "android*" -and $_.emulator -eq $true
  } | Select-Object -First 1

  if ($emulator) {
    return $emulator.id
  }

  $android = $devices | Where-Object {
    $_.targetPlatform -like "android*"
  } | Select-Object -First 1

  if ($android) {
    return $android.id
  }

  return $null
}

$devices = Get-Devices
$androidId = Find-AndroidDeviceId -devices $devices

$windowsAvailable = [bool]($devices | Where-Object { $_.id -eq "windows" })
$chromeAvailable = [bool]($devices | Where-Object { $_.id -eq "chrome" })
$edgeAvailable = [bool]($devices | Where-Object { $_.id -eq "edge" })
$androidAvailable = -not [string]::IsNullOrWhiteSpace($androidId)

Write-Host ""
Write-Host "Selecciona destino para flutter run:" -ForegroundColor Cyan
Write-Host "  1) Windows" -NoNewline
Write-Host ($(if ($windowsAvailable) { "" } else { " (no disponible)" })) -ForegroundColor DarkGray
Write-Host "  2) Chrome" -NoNewline
Write-Host ($(if ($chromeAvailable) { "" } else { " (no disponible)" })) -ForegroundColor DarkGray
Write-Host "  3) Edge" -NoNewline
Write-Host ($(if ($edgeAvailable) { "" } else { " (no disponible)" })) -ForegroundColor DarkGray
Write-Host "  4) Android" -NoNewline
Write-Host ($(if ($androidAvailable) { " [$androidId]" } else { " (no disponible)" })) -ForegroundColor DarkGray
Write-Host ""

$choice = Read-Host "Elige opcion [1-4]"

switch ($choice) {
  "1" {
    if (-not $windowsAvailable) {
      Write-Host "Windows no esta disponible." -ForegroundColor Red
      exit 1
    }
    $deviceId = "windows"
  }
  "2" {
    if (-not $chromeAvailable) {
      Write-Host "Chrome no esta disponible." -ForegroundColor Red
      exit 1
    }
    $deviceId = "chrome"
  }
  "3" {
    if (-not $edgeAvailable) {
      Write-Host "Edge no esta disponible." -ForegroundColor Red
      exit 1
    }
    $deviceId = "edge"
  }
  "4" {
    if (-not $androidAvailable) {
      Write-Host "No hay dispositivo Android disponible." -ForegroundColor Red
      exit 1
    }
    $deviceId = $androidId
  }
  default {
    Write-Host "Opcion no valida." -ForegroundColor Red
    exit 1
  }
}

Write-Host ""
Write-Host "Ejecutando: flutter run -d $deviceId -t $FlutterEntrypoint" -ForegroundColor Green
flutter run -d $deviceId -t $FlutterEntrypoint
