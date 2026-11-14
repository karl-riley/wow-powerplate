$ErrorActionPreference = "Stop"

$candidates = @(
	"${env:ProgramFiles(x86)}\World of Warcraft\_forever_\Interface\AddOns",
	"$env:ProgramFiles\World of Warcraft\_forever_\Interface\AddOns",
	"C:\World of Warcraft\_forever_\Interface\AddOns"
)

$destRoot = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $destRoot) {
	throw "WoW Forever AddOns folder not found. Looked in:`n$($candidates -join "`n")"
}

$src = Join-Path $PSScriptRoot "PowerPlate"
if (-not (Test-Path -LiteralPath (Join-Path $src "PowerPlate.toc"))) {
	throw "PowerPlate addon not found next to this script: $src"
}

$dest = Join-Path $destRoot "PowerPlate"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Copy-Item -LiteralPath (Join-Path $src "PowerPlate.toc") -Destination (Join-Path $dest "PowerPlate.toc") -Force
Copy-Item -LiteralPath (Join-Path $src "PowerPlate.lua") -Destination (Join-Path $dest "PowerPlate.lua") -Force

Write-Output "Installed PowerPlate to $dest"
Write-Output "Enable Power Plate in the addons list, turn on friendly nameplates, then /reload."
