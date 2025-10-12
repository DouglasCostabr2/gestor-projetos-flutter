# PowerShell helper to run the Flutter Windows app
# Usage: Right-click > Run with PowerShell (preferably as Administrator if winget needs elevation)

$ErrorActionPreference = 'Stop'

function Test-Cmd($name) {
  $path = (Get-Command $name -ErrorAction SilentlyContinue).Path
  return -not [string]::IsNullOrEmpty($path)
}

Write-Host "==> Checking Flutter CLI..."
$hasFlutter = Test-Cmd 'flutter'
if (-not $hasFlutter) {
  Write-Host "Flutter not found. Trying to install via winget..."
  $hasWinget = Test-Cmd 'winget'
  if ($hasWinget) {
    winget install -e --id Flutter.Flutter --source winget --accept-package-agreements --accept-source-agreements
  } else {
    Write-Warning "winget is not available. Please install Flutter manually from https://docs.flutter.dev/get-started/install/windows"
    Write-Warning "After installing, re-run this script."
    exit 1
  }
}

Write-Host "==> Enabling Windows desktop target"
flutter config --enable-windows-desktop

Write-Host "==> Fetching packages"
flutter pub get

Write-Host "==> Doctor"
flutter doctor -v

Write-Host "==> Running app (Windows)"
flutter run -d windows

