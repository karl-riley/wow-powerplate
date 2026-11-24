@echo off
net session >nul 2>&1
if %errorLevel% neq 0 (
	powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -Verb RunAs -FilePath '%~f0'"
	if errorlevel 1 (
		echo.
		echo Administrator approval was cancelled.
		pause
	)
	exit /b
)

cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-onedrive.ps1" -Elevated
