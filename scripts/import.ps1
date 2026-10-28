# Importiert Fotos von einer externen Festplatte, einem Ordner oder einem Google-Takeout
# auf den Server. Windows-Variante von import.sh.
#
# Voraussetzung: immich-go.exe  →  https://github.com/simulot/immich-go/releases
#                (Windows-ZIP herunterladen, immich-go.exe in diesen scripts-Ordner legen)
#
# Verwendung (PowerShell):
#   .\scripts\import.ps1 ordner E:\Fotos                     # Ordnernamen werden zu Alben
#   .\scripts\import.ps1 google C:\Downloads\takeout-001.zip # Google-Fotos-Export
#   .\scripts\import.ps1 icloud C:\Downloads\iCloud-Fotos     # iCloud-Export (privacy.apple.com)
#   .\scripts\import.ps1 ordner E:\Fotos --dry-run           # nur testen
param(
  [Parameter(Mandatory = $true, Position = 0)][ValidateSet('ordner', 'google', 'icloud')][string]$Modus,
  [Parameter(Mandatory = $true, Position = 1, ValueFromRemainingArguments = $true)][string[]]$Argumente
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent

$exe = Join-Path $PSScriptRoot 'immich-go.exe'
if (-not (Test-Path $exe)) {
  $cmd = Get-Command immich-go -ErrorAction SilentlyContinue
  if (-not $cmd) { throw 'immich-go.exe nicht gefunden. Download: https://github.com/simulot/immich-go/releases' }
  $exe = $cmd.Source
}

$envFile = Join-Path $root 'import.env'
if (-not (Test-Path $envFile)) { throw 'import.env fehlt – import.env.example kopieren und ausfüllen.' }
$cfg = @{}
Get-Content $envFile | Where-Object { $_ -match '^\s*([A-Z_]+)\s*=\s*(.*)$' } | ForEach-Object { $cfg[$Matches[1]] = $Matches[2].Trim() }
if (-not $cfg['IMMICH_API_KEY']) { throw 'IMMICH_API_KEY in import.env ist leer.' }

$common = @("--server=$($cfg['IMMICH_SERVER'])", "--api-key=$($cfg['IMMICH_API_KEY'])",
            '--manage-raw-jpeg=StackCoverJPG', '--manage-burst=Stack', '--on-errors=continue')

if ($Modus -eq 'ordner') {
  & $exe upload from-folder @common --folder-as-album=FOLDER @Argumente
} elseif ($Modus -eq 'google') {
  & $exe upload from-google-photos @common @Argumente
} else {
  & $exe upload from-icloud @common @Argumente
}
exit $LASTEXITCODE
