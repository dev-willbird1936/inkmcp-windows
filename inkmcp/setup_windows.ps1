#Requires -Version 5.1
<#
.SYNOPSIS
    One-time setup for the Inkscape MCP server on Windows.

.DESCRIPTION
    Creates a Python virtual environment next to this script and installs the
    server's requirements into it. Run this once (and again after pulling
    updates that change requirements.txt). It does not run the server itself -
    MCP registration should invoke venv\Scripts\python.exe with an absolute
    path to main.py directly, so no wrapper script's output can pollute the
    server's stdio JSON-RPC stream at runtime.

    New in the Windows fork of Shriinivas/inkmcp, 2026-07. AGPL-3.0, same as upstream.
#>

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$venvDir = Join-Path $scriptDir "venv"
$venvPython = Join-Path $venvDir "Scripts\python.exe"

# Prefer the Windows Python Launcher over a bare "python" on PATH - PATH order can
# resolve "python" to an unrelated project's virtual environment (which may lack the
# venv module entirely), while "py" reliably finds a real base interpreter.
$pythonLauncher = Get-Command py -ErrorAction SilentlyContinue
if ($pythonLauncher) {
    $baseCmd = "py"
    $baseArgs = @("-3")
} else {
    $baseCmd = "python"
    $baseArgs = @()
}

if (-not (Test-Path $venvPython)) {
    Write-Host "Creating virtual environment at $venvDir ..."
    & $baseCmd @baseArgs -m venv $venvDir
} else {
    Write-Host "Virtual environment already exists at $venvDir"
}

Write-Host "Installing requirements..."
& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install -r (Join-Path $scriptDir "requirements.txt")

Write-Host ""
Write-Host "Setup complete."
Write-Host "MCP server command : $venvPython"
Write-Host "MCP server args     : $(Join-Path $scriptDir 'main.py')"
