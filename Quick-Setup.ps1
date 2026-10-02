# MorePlayers Quick-Setup - kein ZIP noetig. Holt alles von GitHub.
# Aufruf: per Einzeiler (siehe unten) oder .\Quick-Setup.ps1 -MaxPlayers 24
param([int]$MaxPlayers = 24)
$ErrorActionPreference = "Stop"
$Base = "https://raw.githubusercontent.com/Teufel2211/supermarket-moreplayers/main"

function Find-SteamDirs {
  $dirs = @()
  foreach ($p in @("HKLM:\SOFTWARE\WOW6432Node\Valve\Steam", "HKLM:\SOFTWARE\Valve\Steam", "HKCU:\SOFTWARE\Valve\Steam")) {
    try {
      $sp = (Get-ItemProperty -Path $p -ErrorAction SilentlyContinue).InstallPath
      if ($sp) { $dirs += $sp }
    } catch {}
  }
  foreach ($d in @("$env:ProgramFilesX86\Steam", "$env:ProgramFiles\Steam")) {
    try { if ($d -and (Test-Path -LiteralPath $d)) { $dirs += $d } } catch {}
  }
  return ($dirs | Select-Object -Unique)
}

function Find-Game {
  $cands = @()
  foreach ($s in (Find-SteamDirs)) {
    try { $cands += (Join-Path $s "steamapps\common\Supermarket Simulator") } catch {}
    try {
      $vdf = Join-Path $s "steamapps\libraryfolders.vdf"
      if (Test-Path -LiteralPath $vdf) {
        foreach ($m in [regex]::Matches((Get-Content -Raw -LiteralPath $vdf), '"path"\s+"([^"]+)"')) {
          try { $cands += (Join-Path $m.Groups[1].Value "steamapps\common\Supermarket Simulator") } catch {}
        }
      }
    } catch {}
  }
  try {
    foreach ($drv in (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue)) {
      try {
        foreach ($lib in @("SteamLibrary", "Steam")) {
          $cands += ("$($drv.Root)$lib\steamapps\common\Supermarket Simulator")
        }
      } catch {}
    }
  } catch {}
  foreach ($c in ($cands | Select-Object -Unique)) {
    try { if (Test-Path -LiteralPath (Join-Path $c "Supermarket Simulator.exe")) { return $c } }
    catch { continue }
  }
  return $null
}

$game = Find-Game
if (!$game) {
  Write-Host "Spiel wurde nicht automatisch gefunden." -ForegroundColor Yellow
  Write-Host "In Steam: Rechtsklick aufs Spiel -> Verwalten -> Lokale Dateien durchsuchen." -ForegroundColor Yellow
  $man = Read-Host "Spielordner (Enter = Abbruch)"
  try {
    if ($man -and (Test-Path -LiteralPath (Join-Path $man "Supermarket Simulator.exe"))) { $game = $man }
  } catch {}
}
if (!$game) { throw "Spiel nicht gefunden. Steam + Supermarket Simulator installieren, dann nochmal." }
Write-Host "Spiel: $game" -ForegroundColor Cyan

# Spiel ggf. schliessen (Dateien sonst gesperrt)
$proc = Get-Process -Name "Supermarket Simulator" -ErrorAction SilentlyContinue
if ($proc) {
  Write-Host "Spiel laeuft - wird geschlossen ..." -ForegroundColor Yellow
  $proc | Stop-Process -Force
  $deadline = (Get-Date).AddSeconds(30)
  while ((Get-Process -Name "Supermarket Simulator" -ErrorAction SilentlyContinue) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 2 }
}

# BepInEx nachinstallieren falls fehlt
if (!(Test-Path -LiteralPath (Join-Path $game "BepInEx\core\BepInEx.Core.dll"))) {
  $zip = "$env:TEMP\BepInEx-IL2CPP-788.zip"
  Write-Host "Lade BepInEx ..." -ForegroundColor Cyan
  Invoke-WebRequest -Uri "https://builds.bepinex.dev/projects/bepinex_be/788/BepInEx-Unity.IL2CPP-win-x64-6.0.0-be.788%2B5b766a3.zip" -OutFile $zip -UseBasicParsing
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::ExtractToDirectory($zip, $game)
  Write-Host "BepInEx installiert." -ForegroundColor Green
}

# Interop: ggf. 1x Spielstart
$interop = Join-Path $game "BepInEx\interop\UnityEngine.CoreModule.dll"
if (!(Test-Path -LiteralPath $interop)) {
  Write-Host "Starte Spiel 1x zur Einrichtung ..." -ForegroundColor Yellow
  Write-Host "Bitte bis zum HAUPTMENUE gehen, dann Spiel SCHLIESSEN." -ForegroundColor Yellow
  Start-Process "steam://run/2670630"
  $deadline = (Get-Date).AddMinutes(15)
  while (!(Test-Path -LiteralPath $interop) -and (Get-Date) -lt $deadline) { Start-Sleep -Seconds 5 }
  if (!(Test-Path -LiteralPath $interop)) { throw "Interop fehlt weiter. Spiel manuell starten/schliessen, dann nochmal." }
  while (Get-Process -Name "Supermarket Simulator" -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 3 }
}

# Aktuelle Version + DLLs von GitHub holen
Write-Host "Frage Version an ..." -ForegroundColor Cyan
$verTxt = (Invoke-WebRequest -Uri ($Base + "/version.txt") -UseBasicParsing -TimeoutSec 30).Content
$lines = @($verTxt -split "`r?`n" | ForEach-Object { $_.Trim().Trim([char]0xFEFF) } | Where-Object { $_ -ne "" })
if ($lines.Count -lt 2) { throw "version.txt ungueltig." }
$ver = $lines[0]
$dllUrl = $lines[1]
Write-Host "Installiere MorePlayers v$ver ..." -ForegroundColor Cyan
$plugDir = Join-Path $game "BepInEx\plugins"
New-Item -ItemType Directory -Path $plugDir -Force | Out-Null
Invoke-WebRequest -Uri $dllUrl -OutFile (Join-Path $plugDir "MorePlayers.dll") -UseBasicParsing -TimeoutSec 60
$patchDir = Join-Path $game "BepInEx\patchers"
New-Item -ItemType Directory -Path $patchDir -Force | Out-Null
try {
  Invoke-WebRequest -Uri ($Base + "/patcher/MorePlayers.Updater.dll") -OutFile (Join-Path $patchDir "MorePlayers.Updater.dll") -UseBasicParsing -TimeoutSec 60
  Write-Host "Swap-Patcher installiert." -ForegroundColor Green
} catch { Write-Host "Swap-Patcher uebersprungen (kommt per Updater nach)." -ForegroundColor Yellow }

# Altes .new aufraeumen / uebernehmen
$newFile = Join-Path $plugDir "MorePlayers.dll.new"
if (Test-Path -LiteralPath $newFile) {
  try {
    $vT = [Reflection.AssemblyName]::GetAssemblyName((Join-Path $plugDir "MorePlayers.dll")).Version
    $vN = [Reflection.AssemblyName]::GetAssemblyName($newFile).Version
    if ($vN -ge $vT) { Copy-Item -LiteralPath $newFile -Destination (Join-Path $plugDir "MorePlayers.dll") -Force }
  } catch {}
  Remove-Item -LiteralPath $newFile -Force -ErrorAction SilentlyContinue
}

# Bestehenden MaxPlayers-Wert behalten, sonst Parameter
$keep = $null
$cfg = Join-Path $game "BepInEx\config\de.steven.supermarket.moreplayers.cfg"
if (Test-Path -LiteralPath $cfg) {
  $m = Select-String -LiteralPath $cfg -Pattern '^\s*MaxPlayers\s*=\s*(\d+)' | Select-Object -First 1
  if ($m -and $m.Matches[0].Groups[1].Value) { $keep = [int]$m.Matches[0].Groups[1].Value }
}
if ($keep) { $MaxPlayers = $keep }
if ($MaxPlayers -lt 5) { $MaxPlayers = 5 }
if ($MaxPlayers -gt 32) { $MaxPlayers = 32 }
$body = @"
## MorePlayers - Lobby-Groesse (Host + ALLE Clients GLEICH!)
[Lobby]

## Gewuenschte maximale Spielerzahl (Standard Spiel: 4)
# Setting type: Int32
# Default value: 24
MaxPlayers = $MaxPlayers

## Pruefintervall in Sekunden
# Setting type: Single
# Default value: 5
EnforceIntervalSeconds = 5

## Diagnose-Logging (beim Testen AN lassen)
# Setting type: Boolean
# Default value: true
DebugLog = true

## HOST-Schalter: duerfen Mitspieler (keine Hoster) den Tag beenden?
# Setting type: Boolean
# Default value: true
AllowClientsEndDay = true

## --- Auto-Updater (haelt alle Clients auf derselben Version) ---
[Update]

## Beim Spielstart im Hintergrund auf neue Version pruefen
# Setting type: Boolean
# Default value: true
AutoUpdate = true

## URL zu version.txt (Zeile1=Version, Zeile2=DLL-URL, Zeile3=SHA256 optional). Leer = aus.
# Setting type: String
# Default value: https://raw.githubusercontent.com/Teufel2211/supermarket-moreplayers/main/version.txt
VersionUrl = https://raw.githubusercontent.com/Teufel2211/supermarket-moreplayers/main/version.txt

## Timeout in Sekunden (5-60)
# Setting type: Int32
# Default value: 10
TimeoutSeconds = 10

## Auch WAehrend dem Spiel alle X Minuten pruefen (5-60)
# Setting type: Int32
# Default value: 10
CheckEveryMinutes = 10

## Version des Hosts automatisch uebernehmen
# Setting type: Boolean
# Default value: true
FollowHostVersion = true
"@
New-Item -ItemType Directory -Path (Split-Path -Parent $cfg) -Force | Out-Null
Set-Content -LiteralPath $cfg -Value $body -Encoding UTF8
Write-Host ""
Write-Host "FERTIG! MorePlayers v$ver, MaxPlayers=$MaxPlayers. Spiel normal ueber Steam starten." -ForegroundColor Green
