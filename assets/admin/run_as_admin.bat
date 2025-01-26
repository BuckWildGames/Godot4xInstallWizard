@echo off
:: Get the path to the installer (running Godot executable) from the argument
set INSTALLER_PATH=%1

:: Check if the process is already running as admin (we’ll skip relaunch if true)
:: Using PowerShell to check for admin
powershell -Command "if (([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {exit 0} else {Start-Process '%INSTALLER_PATH%' -Verb runAs}"
