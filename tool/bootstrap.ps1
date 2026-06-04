param(
  [switch]$SkipCreate,
  [string]$FlutterRoot = ".tooling\flutter"
)

$ErrorActionPreference = "Stop"

$flutter = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutter -and (Test-Path (Join-Path $FlutterRoot "bin\flutter.bat"))) {
  $flutter = Get-Item (Join-Path $FlutterRoot "bin\flutter.bat")
}

if (-not $flutter) {
  throw "Flutter is not available. Install Flutter or run the local SDK bootstrap documented in README.md."
}

if (-not $SkipCreate) {
  & $flutter.Source create --platforms=windows,android .
}

& $flutter.Source pub get
& $flutter.Source analyze
