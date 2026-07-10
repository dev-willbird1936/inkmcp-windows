#Requires -Version 5.1
<#
.SYNOPSIS
    One-command installer for the Inkscape MCP server on Windows.

.DESCRIPTION
    Runs the full Windows setup in one step:
      1. Discovers your Inkscape install (registry, PATH, common locations)
      2. Copies the extension into Inkscape's user extensions directory
      3. Disables Inkscape's first-run "boot screen" (it blocks the D-Bus
         mechanism entirely until a document/canvas exists - see README)
      4. Creates the Python virtual environment and installs dependencies
      5. Prints a ready-to-paste MCP client config snippet

    Safe to re-run any time (e.g. after `git pull`) - every step checks
    current state first and skips work that's already done.

    New in the Windows fork of Shriinivas/inkmcp, 2026-07. AGPL-3.0, same as upstream.
#>

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Step($msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg) { Write-Host "    OK: $msg" -ForegroundColor Green }
function Write-Warn2($msg) { Write-Host "    WARNING: $msg" -ForegroundColor Yellow }
function Write-Err2($msg) { Write-Host "    ERROR: $msg" -ForegroundColor Red }

# --- Step 1: Find Inkscape -------------------------------------------------
Write-Step "Locating Inkscape"

function Find-InkscapeExe {
    $envOverride = $env:INKSCAPE_COMMAND
    if ($envOverride -and (Test-Path $envOverride)) { return $envOverride }

    $onPath = Get-Command inkscape.exe -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    foreach ($hive in @("HKLM:", "HKCU:")) {
        $key = "$hive\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\inkscape.exe"
        if (Test-Path $key) {
            $val = (Get-ItemProperty -Path $key -ErrorAction SilentlyContinue).'(default)'
            if ($val -and (Test-Path $val)) { return $val }
        }
    }

    foreach ($candidate in @(
        "C:\Program Files\Inkscape\bin\inkscape.exe",
        "C:\Program Files (x86)\Inkscape\bin\inkscape.exe"
    )) {
        if (Test-Path $candidate) { return $candidate }
    }

    return $null
}

$inkscapeExe = Find-InkscapeExe
if (-not $inkscapeExe) {
    Write-Err2 "Could not find Inkscape."
    Write-Host "    Install it from https://inkscape.org/release/ first, or set the" -ForegroundColor Red
    Write-Host "    INKSCAPE_COMMAND environment variable to the full path of inkscape.exe" -ForegroundColor Red
    Write-Host "    and re-run this script." -ForegroundColor Red
    exit 1
}
$inkscapeBin = Split-Path -Parent $inkscapeExe
$inkscapeCom = Join-Path $inkscapeBin "inkscape.com"
Write-Ok "Found Inkscape at $inkscapeExe"

# --- Step 2: Extensions directory ------------------------------------------
Write-Step "Locating Inkscape's user extensions directory"

$userDataDir = ((& $inkscapeCom --user-data-directory 2>$null) | Select-Object -Last 1)
if ($userDataDir) { $userDataDir = $userDataDir.Trim() }
if (-not $userDataDir) {
    Write-Err2 "Could not determine Inkscape's user data directory. Is Inkscape installed correctly?"
    exit 1
}
$extensionsDir = Join-Path $userDataDir "extensions"
New-Item -ItemType Directory -Force -Path $extensionsDir | Out-Null
Write-Ok "Extensions directory: $extensionsDir"

# --- Step 3: Install the extension -----------------------------------------
Write-Step "Installing the extension"

Copy-Item -Path (Join-Path $repoRoot "inkscape_mcp.py") -Destination $extensionsDir -Force
Copy-Item -Path (Join-Path $repoRoot "inkscape_mcp.inx") -Destination $extensionsDir -Force

$extInkmcpDir = Join-Path $extensionsDir "inkmcp"
if (Test-Path $extInkmcpDir) { Remove-Item -Recurse -Force $extInkmcpDir }
Copy-Item -Path (Join-Path $repoRoot "inkmcp") -Destination $extensionsDir -Recurse -Force

# Copy-Item's directory exclude filtering is inconsistent across PowerShell
# versions - explicitly strip anything that shouldn't have been copied.
Get-ChildItem -Path $extInkmcpDir -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
$strayVenv = Join-Path $extInkmcpDir "venv"
if (Test-Path $strayVenv) { Remove-Item -Recurse -Force $strayVenv }

Write-Ok "Extension installed to $extensionsDir"

# --- Step 4: Disable the first-run boot screen ------------------------------
Write-Step "Disabling Inkscape's first-run boot screen"
Write-Host "    (blocks the D-Bus mechanism entirely until disabled - see README)"

$inkscapeRunning = Get-Process -Name inkscape -ErrorAction SilentlyContinue
if ($inkscapeRunning) {
    Write-Warn2 "Inkscape is currently running - it will overwrite preferences.xml on exit,"
    Write-Warn2 "so this step can't be applied safely right now."
    Write-Warn2 "Close Inkscape, then re-run this script to apply the boot-screen fix."
} else {
    $prefsPath = Join-Path $userDataDir "preferences.xml"
    if (-not (Test-Path $prefsPath)) {
        Write-Warn2 "preferences.xml doesn't exist yet - launching Inkscape once to create it..."
        Start-Process -FilePath $inkscapeExe | Out-Null
        $deadline = (Get-Date).AddSeconds(20)
        while (-not (Test-Path $prefsPath) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 500 }
        Start-Sleep -Seconds 1
        Get-Process -Name inkscape -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 1
    }

    if (Test-Path $prefsPath) {
        [xml]$prefs = Get-Content -Path $prefsPath -Raw
        $bootNode = $prefs.SelectSingleNode("//group[@id='boot']")
        if (-not $bootNode) {
            $optionsNode = $prefs.SelectSingleNode("//group[@id='options']")
            if (-not $optionsNode) {
                $optionsNode = $prefs.CreateElement("group")
                $optionsNode.SetAttribute("id", "options") | Out-Null
                $prefs.DocumentElement.AppendChild($optionsNode) | Out-Null
            }
            $bootNode = $prefs.CreateElement("group")
            $bootNode.SetAttribute("id", "boot") | Out-Null
            $optionsNode.AppendChild($bootNode) | Out-Null
        }
        if ($bootNode.GetAttribute("enabled") -ne "0") {
            $stamp = Get-Date -Format yyyyMMdd-HHmmss
            Copy-Item -Path $prefsPath -Destination "$prefsPath.bak-install-$stamp" -Force
            $bootNode.SetAttribute("enabled", "0") | Out-Null
            $prefs.Save($prefsPath)
            Write-Ok "Boot screen disabled (backup saved as preferences.xml.bak-install-$stamp)"
        } else {
            Write-Ok "Boot screen already disabled"
        }
    } else {
        Write-Warn2 "Could not create preferences.xml automatically."
        Write-Warn2 "Launch Inkscape once manually, close it, then re-run this script."
    }
}

# --- Step 5: Python virtual environment -------------------------------------
Write-Step "Setting up the Python virtual environment"
& (Join-Path $repoRoot "inkmcp\setup_windows.ps1")

# --- Step 6: Print MCP config snippet ---------------------------------------
Write-Step "MCP client configuration"

$venvPython = (Join-Path $repoRoot "inkmcp\venv\Scripts\python.exe") -replace '\\', '\\'
$mainPy = (Join-Path $repoRoot "inkmcp\main.py") -replace '\\', '\\'
$snippet = @"
{
  "mcpServers": {
    "inkscape": {
      "command": "$venvPython",
      "args": ["$mainPy"]
    }
  }
}
"@
Write-Host ""
Write-Host $snippet -ForegroundColor White
Write-Host ""
Write-Host "    Paste the above into your AI tool's MCP config (Claude Desktop, Claude Code," -ForegroundColor Cyan
Write-Host "    Codex, etc. - see README for exact config file locations per tool)." -ForegroundColor Cyan

# --- Step 7: Verify -----------------------------------------------------------
Write-Step "Verifying the extension is reachable"

$inkscapeNowRunning = Get-Process -Name inkscape -ErrorAction SilentlyContinue
if ($inkscapeNowRunning) {
    $gdbusExe = Join-Path $inkscapeBin "gdbus.exe"
    $listOutput = & $gdbusExe call --session --dest org.inkscape.Inkscape --object-path /org/inkscape/Inkscape --method org.gtk.Actions.List 2>$null
    if ($listOutput -match "org\.khema\.inkscape\.mcp") {
        Write-Ok "Extension detected on the running Inkscape instance - ready to use."
    } else {
        Write-Warn2 "Extension not detected on the currently running Inkscape instance."
        Write-Warn2 "Restart Inkscape to pick up the newly installed extension."
    }
} else {
    Write-Host "    Launch Inkscape with a document open, then you're ready to go." -ForegroundColor White
}

Write-Host ""
Write-Host "Setup complete." -ForegroundColor Green
