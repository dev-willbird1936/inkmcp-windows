"""Resolution of the gdbus executable and waiting for extension response files.

On Windows, gdbus is not on a stock PATH, and a bare "gdbus" resolved via PATH could
belong to an unrelated GLib install (MSYS2, GIMP, ...) that autolaunches its own empty
session bus instead of finding Inkscape's. The only copy that reliably shares Inkscape's
D-Bus session is the one bundled next to inkscape.exe itself, so it must be resolved as
a sibling of the actual Inkscape executable rather than looked up by bare name.

New in the Windows fork of Shriinivas/inkmcp, 2026-07. AGPL-3.0, same as upstream.
"""

import os
import platform
import shutil
import time
from pathlib import Path
from typing import Optional


def find_inkscape_exe() -> Optional[str]:
    """Locate the Inkscape executable via env override, PATH, registry, or common install dirs."""
    env_override = os.environ.get("INKSCAPE_COMMAND")
    if env_override and os.path.isfile(env_override):
        return env_override

    which_result = shutil.which("inkscape") or shutil.which("inkscape.exe")
    if which_result:
        return which_result

    if platform.system() == "Windows":
        for candidate in _windows_registry_inkscape_paths():
            if candidate and os.path.isfile(candidate):
                return candidate
        for candidate in (
            r"C:\Program Files\Inkscape\bin\inkscape.exe",
            r"C:\Program Files (x86)\Inkscape\bin\inkscape.exe",
        ):
            if os.path.isfile(candidate):
                return candidate

    return None


def _windows_registry_inkscape_paths():
    import winreg

    for hive in (winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER):
        try:
            key_path = r"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\inkscape.exe"
            with winreg.OpenKey(hive, key_path) as key:
                value, _ = winreg.QueryValueEx(key, None)
                yield value
        except OSError:
            continue


def find_gdbus() -> str:
    """Return the path to invoke for gdbus calls against Inkscape's D-Bus session."""
    env_override = os.environ.get("INKMCP_GDBUS_PATH")
    if env_override and os.path.isfile(env_override):
        return env_override

    if platform.system() != "Windows":
        return "gdbus"

    inkscape_exe = find_inkscape_exe()
    if inkscape_exe:
        sibling = Path(inkscape_exe).parent / "gdbus.exe"
        if sibling.is_file():
            return str(sibling)

    raise FileNotFoundError(
        "Could not locate gdbus.exe. On Windows this must be the copy bundled with "
        "Inkscape - install Inkscape or set INKMCP_GDBUS_PATH to the full path of "
        "gdbus.exe (e.g. C:\\Program Files\\Inkscape\\bin\\gdbus.exe)."
    )


def wait_for_response_file(response_file: str, timeout: float = 5.0, interval: float = 0.05) -> bool:
    """Poll for the extension's response file to appear, rather than assuming it is
    already present the instant the gdbus call returns. Returns True once found."""
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if os.path.exists(response_file):
            return True
        time.sleep(interval)
    return os.path.exists(response_file)
