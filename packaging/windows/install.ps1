<#
    Puts the built Tempo somewhere it can live, and starts it in the tray.

    A build folder is not a home. "flutter clean" deletes it, the next build
    replaces the executable underneath a running copy, and a project kept in
    OneDrive can have its files taken offline without warning. The system's
    sign-in entry holds a path, so any of those quietly ends the tracking:
    nothing starts at the next sign-in, and nothing says why.

    This copies the built app to %LOCALAPPDATA%\Programs\Tempo and runs it from
    there. Nothing here touches the registry — Tempo registers itself to open
    at sign-in on its first launch, from wherever it is actually running, so
    there is only ever one place that decides what the system is told.

    From the project root:

        powershell -ExecutionPolicy Bypass -File packaging\windows\install.ps1
#>

[CmdletBinding()]
param(
    [string] $Source,
    [string] $Destination = (Join-Path $env:LOCALAPPDATA 'Programs\Tempo')
)

$ErrorActionPreference = 'Stop'

# Windows PowerShell leaves $PSScriptRoot empty while parameter defaults are
# being evaluated, so the build folder is worked out here instead.
if (-not $Source) {
    $here = Split-Path -Parent $MyInvocation.MyCommand.Path
    $projectRoot = Split-Path -Parent (Split-Path -Parent $here)
    $Source = Join-Path $projectRoot 'build/windows/x64/runner/Release'
}

if (-not (Test-Path $Source)) {
    throw "No build at $Source. Run: flutter build windows --release"
}
$Source = (Resolve-Path $Source).Path
if (-not (Test-Path (Join-Path $Source 'Tempo.exe'))) {
    throw "No Tempo.exe in $Source. Run: flutter build windows --release"
}

# One Tempo at a time. The running copy holds its own executable open, and two
# of them would count the same minutes twice.
$running = @(Get-Process -Name Tempo -ErrorAction SilentlyContinue)
foreach ($process in $running) {
    Write-Host "Stopping the running Tempo (PID $($process.Id))"
    Stop-Process -Id $process.Id -Force
}
if ($running.Count -gt 0) {
    Start-Sleep -Milliseconds 800
}

New-Item -ItemType Directory -Force -Path $Destination | Out-Null
Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Recurse -Force

# The Store bundle is a build artefact, not part of the app.
Get-ChildItem -Path $Destination -Filter '*.msix' -ErrorAction SilentlyContinue |
    Remove-Item -Force
Write-Host "Installed to $Destination"

# So Tempo can be opened by name, and not only from its tray icon.
$shortcutPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Tempo.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = Join-Path $Destination 'Tempo.exe'
$shortcut.WorkingDirectory = $Destination
$shortcut.Description = 'Screen time, measured beautifully'
$shortcut.Save()
Write-Host "Start menu shortcut written to $shortcutPath"

# Started the way the system will start it from now on: no window, straight
# into the tray, measuring.
Start-Process -FilePath (Join-Path $Destination 'Tempo.exe') -ArgumentList '--hidden'
Write-Host 'Tempo is measuring from the tray, and will open itself at the next sign-in.'
