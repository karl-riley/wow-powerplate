param(
	[switch]$Elevated
)

$ErrorActionPreference = "Stop"

function Test-IsAdmin {
	$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object Security.Principal.WindowsPrincipal($identity)
	return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Wait-IfElevated {
	if ($Elevated) {
		Write-Output ""
		Read-Host "Press Enter to close" | Out-Null
	}
}

function Test-SamePath([string]$Left, [string]$Right) {
	$a = [IO.Path]::GetFullPath($Left).TrimEnd('\')
	$b = [IO.Path]::GetFullPath($Right).TrimEnd('\')
	return [string]::Equals($a, $b, [StringComparison]::OrdinalIgnoreCase)
}

function Get-LinkTarget([string]$Path) {
	$item = Get-Item -LiteralPath $Path -Force
	$target = @($item.Target) | Where-Object { $_ } | Select-Object -First 1
	if (-not $target) {
		return $null
	}
	$target = [string]$target
	if (-not [IO.Path]::IsPathRooted($target)) {
		$target = Join-Path (Split-Path -LiteralPath $Path) $target
	}
	return $target
}

try {
	$candidates = @(
		"${env:ProgramFiles(x86)}\World of Warcraft\_forever_\Interface\AddOns",
		"$env:ProgramFiles\World of Warcraft\_forever_\Interface\AddOns",
		"C:\World of Warcraft\_forever_\Interface\AddOns"
	)

	$destRoot = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
	if (-not $destRoot) {
		throw "WoW Forever AddOns folder not found. Looked in:`n$($candidates -join "`n")"
	}

	# This script lives inside the PowerPlate folder, so that folder is the link target.
	$src = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
	if (-not (Test-Path -LiteralPath (Join-Path $src "PowerPlate.toc"))) {
		throw "PowerPlate.toc not found next to this script: $src"
	}

	$dest = [IO.Path]::GetFullPath((Join-Path $destRoot "PowerPlate")).TrimEnd('\')
	if (Test-SamePath $src $dest) {
		Write-Output "This script is running from the WoW AddOns folder, which is already the installed copy."
		Write-Output "Run install-onedrive.cmd from the PowerPlate folder in OneDrive instead."
		Wait-IfElevated
		return
	}
	$existing = Get-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
	if ($existing -and ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
		$current = Get-LinkTarget $dest
		if ($current -and (Test-SamePath $current $src)) {
			Write-Output "PowerPlate already links to $src"
			Write-Output "Enable Power Plate in the addons list, turn on friendly nameplates, then /reload."
			Wait-IfElevated
			return
		}
	}

	if (-not (Test-IsAdmin)) {
		Write-Output "Requesting administrator approval to link PowerPlate into the WoW AddOns folder."
		try {
			$proc = Start-Process -FilePath "powershell.exe" -Verb RunAs -Wait -PassThru -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Elevated"
		} catch {
			throw "Administrator approval was cancelled. The AddOns link was not created."
		}
		$code = 0
		if ($null -ne $proc -and $null -ne $proc.ExitCode) {
			$code = $proc.ExitCode
		}
		if ($code -ne 0) {
			throw "Elevated install failed with exit code $code."
		}
		return
	}

	if ($existing) {
		if ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) {
			& cmd.exe /c "rmdir `"$dest`""
			if ($LASTEXITCODE -ne 0) {
				throw "Could not remove the existing link at $dest"
			}
			Write-Output "Removed the existing link at $dest"
		} else {
			Remove-Item -LiteralPath $dest -Recurse -Force
			Write-Output "Removed the copied PowerPlate folder at $dest"
		}
	}

	& cmd.exe /c "mklink /J `"$dest`" `"$src`""
	if ($LASTEXITCODE -ne 0) {
		throw "Could not create the PowerPlate link (mklink exit $LASTEXITCODE)."
	}

	Write-Output "Linked $dest"
	Write-Output "-> $src"
	Write-Output "In OneDrive, right-click PowerPlate and choose Always keep on this device."
	Write-Output "Enable Power Plate in the addons list, turn on friendly nameplates, then /reload."
	Wait-IfElevated
} catch {
	Write-Output $_.Exception.Message
	Wait-IfElevated
	$launchedWithFile = @([Environment]::GetCommandLineArgs()) -contains "-File"
	if ($Elevated -or $launchedWithFile) {
		exit 1
	}
	$global:LASTEXITCODE = 1
}
