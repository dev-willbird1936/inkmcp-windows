# Inkscape MCP Server (Windows-enabled fork)

A Model Context Protocol (MCP) server that enables live control of Inkscape through natural language instructions. This allows AI assistants like Claude to directly manipulate vector graphics in real-time.

> **This is a fork of [Shriinivas/inkmcp](https://github.com/Shriinivas/inkmcp)**, which adds support for
> native Windows Inkscape installs (the upstream project is Linux-only). See
> [Changes from upstream](#changes-from-upstream) for exactly what changed and why. All credit for the
> original design, the D-Bus/GAction mechanism, and the full `inkmcpops` element-creation system goes to
> the upstream author - this fork only adds the Windows-specific plumbing needed to reach the same
> mechanism from a different OS.

## Features

- 🎯 **Live Instance Control** - Direct manipulation of running Inkscape documents
- ⚡ **D-Bus Integration** - Real-time communication
- 🚀 **Universal Element Creation** - Create any SVG element with unified syntax
- 🏗️ **Hierarchical Scene Management** - Semantic organization with automatic ID collision handling
- 📐 **Python Code Execution** - Run arbitrary inkex code in live context
- 🖼️ **Screenshot Support** - Visual feedback with viewport capture

## Platform Support

- **✅ Linux** - Native D-Bus session bus
- **✅ Windows** - Works via Inkscape's bundled GDBus (GLib's Windows D-Bus implementation autolaunches its own session bus - no separate D-Bus daemon install required). See [Windows setup](#windows-setup) below.
- **🔮 macOS**: Untested; likely works the same way as Windows if Inkscape's GTK build includes GDBus, but not verified.

## Quick Start

### 1. Installation (Linux)

1. Go to the [Releases page](https://github.com/Shriinivas/inkmcp/releases)
2. Download `inkmcp-extension.zip` from the latest release
3. Extract it to your Inkscape extensions directory:
   ```bash
   cd ~/.config/inkscape/extensions/
   unzip ~/Downloads/inkmcp-extension.zip
   ```


### 2. Make Scripts Executable

```bash
cd ~/.config/inkscape/extensions/inkmcp
chmod +x run_inkscape_mcp.sh inkmcpcli.py inkscape_mcp_server.py main.py
```

### 3. Start Inkscape
Launch Inkscape normally - the extension is hidden from the menu and only accessible via D-Bus.

### 1b. Installation (Windows) {#windows-setup}

**Easiest way:** clone or download this repo, then double-click **`install_windows.bat`**
(or run `install_windows.ps1` from PowerShell). It finds your Inkscape install, installs the
extension, disables the first-run boot screen (see why below), creates the Python venv, and
prints a ready-to-paste MCP config snippet - all in one step. Safe to re-run any time (e.g.
after `git pull`); every step checks the current state first and skips whatever's already done.

```powershell
# From PowerShell, if you'd rather not double-click the .bat:
powershell -ExecutionPolicy Bypass -File install_windows.ps1
```

Then skip to [Connect with AI Tools](#4-connect-with-ai-tools) - the snippet the script prints
is ready to paste in as-is.

<details>
<summary>Manual steps (what the installer does under the hood - for reference, or if you need to customize something)</summary>

1. Find Inkscape's user extensions directory - run `inkscape.com --user-data-directory` (ships in Inkscape's `bin\` folder) and append `\extensions`. This is typically `%APPDATA%\inkscape\extensions`, but always confirm rather than assume.
2. Copy `inkscape_mcp.py`, `inkscape_mcp.inx`, and the whole `inkmcp\` folder from this repo into that extensions directory, so the layout matches:
   ```
   %APPDATA%\inkscape\extensions\
     inkscape_mcp.py
     inkscape_mcp.inx
     inkmcp\
       gdbus_util.py
       inkmcpcli.py
       inkscape_mcp_server.py
       inkmcpops\
       ...
   ```
3. **Disable Inkscape's first-run "boot screen"** - it blocks the D-Bus extension dispatch entirely (no document/canvas context exists while it's showing). With Inkscape fully closed, edit `%APPDATA%\inkscape\preferences.xml` and set `enabled="0"` on the `boot` group:
   ```xml
   <group id="boot" theme="colorful" enabled="0" />
   ```
   (If Inkscape is running while you edit this, it will overwrite your change on exit - close it first.)
4. From this repo's `inkmcp\` folder, run the one-time setup script to create a venv and install dependencies:
   ```powershell
   powershell -ExecutionPolicy Bypass -File setup_windows.ps1
   ```
5. Launch Inkscape with a document open (`inkscape.exe some.svg`, or just create a new document) before triggering any operation - the extension needs a live document/canvas to act on.

</details>

### 4. Connect with AI Tools

**Auto-Setup (Linux)**: The first time an AI client connects, `run_inkscape_mcp.sh` will automatically create the venv, install dependencies, and start the server - no manual setup required.

**Windows**: run `install_windows.ps1` (see [Windows setup](#windows-setup) above) - it prints this exact snippet with your repo's real paths already filled in, ready to paste. Either way, the config points directly at the venv's `python.exe` with an absolute path to `main.py` as the argument - not a wrapper script, so nothing can print to stdout and corrupt the JSON-RPC stream:
```json
{
  "mcpServers": {
    "inkscape": {
      "command": "C:\\path\\to\\inkmcp\\venv\\Scripts\\python.exe",
      "args": ["C:\\path\\to\\inkmcp\\main.py"]
    }
  }
}
```
The same substitution (venv `python.exe` + absolute `main.py` path, instead of a shell script) applies to every AI tool config shown below.

#### Claude Code
Edit your Claude configuration file:
```bash
# ~/.claude/claude-config.json
```
```json
{
  "mcpServers": {
    "inkscape": {
      "command": "/home/USERNAME/.config/inkscape/extensions/inkmcp/run_inkscape_mcp.sh"
    }
  }
}
```

#### Anthropic Claude Desktop
Update Claude desktop app settings:
```json
{
  "mcpServers": {
    "inkscape": {
      "command": "/home/USERNAME/.config/inkscape/extensions/inkmcp/run_inkscape_mcp.sh"
    }
  }
}
```

#### Google Gemini/Codex
For Gemini, edit settings file:
```bash
# ~/.gemini/settings.json
```
```json
{
  "mcpServers": {
    "inkscape-mcp": {
      "command": "/home/USERNAME/.config/inkscape/extensions/inkmcp/run_inkscape_mcp.sh"
    }
  }
}
```

For Codex, edit configuration:
```bash
# ~/.codex/config.toml
```
```toml
[mcp_servers.inkscape-mcp]
command = "/home/USERNAME/.config/inkscape/extensions/inkmcp/run_inkscape_mcp.sh"
```


## Usage Examples

### With AI Assistant (Claude Code/Gemini/etc) - Requires Running Inkscape
```
"In Inkscape, draw a smooth sine wave starting at the left edge in the middle of the document and apply power stroke path effect to it"
"In Inkscape, create a beautiful logo with a radial gradient circle and elegant typography"
"In Inkscape, draw a mathematical spiral using varying circle sizes with golden ratio"
"In Inkscape, create a house illustration with gable roof, wooden door, and flower garden"
"In Inkscape, design a data visualization chart with bars with hatch fill and labels using current document size"
"In Inkscape, export the current document as high-resolution PNG for presentation"
```

## Available MCP Tools

**inkscape_operation** - Universal tool for all Inkscape operations:
- Create any SVG element (circle, rect, text, path, gradient, etc.)
- Execute Python/inkex code in live context
- Get document/selection information
- Export viewport screenshots
- Hierarchical element creation with groups
- Automatic ID collision handling

## Hybrid Execution

Execute code seamlessly across multiple Python contexts with automatic variable sharing!

### execute-hybrid CLI Command

Interleave local Python execution with Inkscape operations using magic comments:

```python
# @local
import random
points = [(random.randint(10, 200), random.randint(10, 200)) for _ in range(5)]

# @inkscape
for x, y in points:
    circle = Circle()
    circle.set("cx", str(x))
    circle.set("cy", str(y))
    svg.append(circle)
```

**Features:**
- 🔄 Full bidirectional variable flow (Local ↔ Inkscape)
- 🎯 `get_element_by_id()` helper function for reliable element lookup
- ⚠️ Full error tracebacks with fail-fast behavior

**Usage:**
```bash
python inkmcpcli.py execute-hybrid -f script.py
```

### Blender-Inkscape Addon

Transfer curves and data from Blender to Inkscape in real-time!

**Installation:**
1. Blender > Edit > Preferences > Add-ons > Install
2. Select `blender_addon_inkscape_hybrid.py`
3. Enable "Scripting: Inkscape Hybrid Execution"
4. Set INKMCP_CLI_PATH to `/path/to/inkmcp/inkmcpcli.py`

**Usage:**
```python
# @local - Runs in Blender
import bpy
curve = bpy.context.object
segs = [list(pt.co[:2]) for spline in curve.data.splines 
        for pt in spline.bezier_points]

# @inkscape - Runs in Inkscape via D-Bus
for x, y in segs:
    circle = Circle()
    circle.set("cx", str(x * 100))
    svg.append(circle)
```

Run with: **Text > Run Hybrid Code** (or Ctrl+Shift+H)

**Features:**
- ✨ One-click execution from Blender text editor
- 🔄 Automatic variable serialization
- ⚠️ Helpful warnings for non-serializable Blender objects
- 🎨 Real-time bezier curve transfer to Inkscape

**Example:** `blender_paste_example.py` - Complete bezier curve visualization

**Note:** Blender objects (Vectors, etc.) must be converted to lists for JSON serialization.

See `BLENDER_HYBRID_README.md` for detailed documentation.

## Technical Details

### Architecture
- **Extension**: `inkscape_mcp.py` - Inkscape extension triggered via D-Bus
- **MCP Server**: `inkscape_mcp_server.py` - FastMCP server handling AI requests
- **CLI Client**: `inkmcpcli.py` - Direct command-line interface for testing
- **Operations**: `inkmcpops/` - Modular operation handlers
- **gdbus resolution**: `gdbus_util.py` - Locates the correct `gdbus` (bare name on Linux; Inkscape's bundled `gdbus.exe` on Windows) and polls for the extension's response file

### Communication Flow
```
AI Assistant → MCP Server → CLI Client → D-Bus → Inkscape Extension → Live Document
```

## Advanced Usage

### Direct CLI Usage (For Testing/Development)
```bash
# In the inkmcp directory - bypasses AI assistant for direct control

# Basic shapes
python inkmcpcli.py circle "cx=100 cy=100 r=50 fill=red"
python inkmcpcli.py rect "x=0 y=0 width=200 height=100 stroke=blue"

# Gradients
python inkmcpcli.py linearGradient "x1=0 y1=0 x2=200 y2=200 stops='[[\"0%\",\"green\"],[\"50%\",\"yellow\"],[\"100%\",\"red\"]]'"

# Code execution
python inkmcpcli.py execute-code "code='circle = inkex.Circle(); circle.set(\"cx\", \"150\"); circle.set(\"cy\", \"100\"); circle.set(\"r\", \"25\"); svg.append(circle)'"

# Document info
python inkmcpcli.py get-info

# Selection info
python inkmcpcli.py get-selection

# Export screenshot
python inkmcpcli.py export-document-image "format=png max_size=800"
```

### Arbitrary Code Execution
Execute any Python/inkex code in the live Inkscape context:
```python
# Create complex shapes programmatically
code = '''
rect = Rectangle()
rect.set('x', '10')
rect.set('y', '20')
rect.set('width', '100')
rect.set('height', '50')
rect.set('style', 'fill:blue;stroke:red;stroke-width:2')
svg.append(rect)
'''
```


## Troubleshooting

### Common Issues

1. **D-Bus not found**: Ensure you're on Linux with D-Bus session running, or on Windows using Inkscape's bundled `gdbus.exe` (see Windows issues below)
2. **Extension not triggered**: Check Inkscape is running and extension is installed
3. **Python environment**: Ensure virtual environment is activated with dependencies
4. **Permissions**: Make sure scripts are executable (`chmod +x *.sh *.py`)

### Windows-Specific Issues

1. **`gdbus` call hangs/times out with no response**: Almost always means Inkscape's first-run "boot screen" is still showing - the extension can't run without a live document/canvas. Disable it via `preferences.xml` as described in [Windows setup](#windows-setup), and make sure Inkscape was launched with a document open.
2. **`org.gtk.Actions.List` works but `Activate` never completes**: Confirm you're not accidentally targeting a *different* running Inkscape instance - Inkscape's GApplication forwards new invocations to whichever instance already owns the D-Bus name, so a stuck/blocked instance will silently absorb every subsequent call.
3. **"gdbus not recognized" / wrong D-Bus session found**: Never rely on a bare `gdbus` resolved via PATH - a copy from an unrelated GLib install (MSYS2, GIMP, etc.) will autolaunch its *own* empty session bus instead of finding Inkscape's. Always resolve `gdbus.exe` as the sibling of the actual `inkscape.exe` (this is what `gdbus_util.find_gdbus()` does); override with the `INKMCP_GDBUS_PATH` env var if needed.
4. **`python -m venv` fails with "No module named venv"**: Your shell's `python` on PATH may be shadowed by an unrelated project's virtual environment. `setup_windows.ps1` uses the `py` launcher (`py -3`) instead of bare `python` to avoid this; if invoking manually, prefer `py -3 -m venv venv` over `python -m venv venv`.

### Debug Mode
```bash
# Check D-Bus connection
gdbus introspect --session --dest org.inkscape.Inkscape --object-path /org/inkscape/Inkscape

# Structured JSON output
python inkmcpcli.py get-info --parse-out --pretty
```

## Development

### Adding New Operations
1. Create new file in `inkmcpops/`
2. Implement `execute(svg, params)` function
3. Add corresponding MCP tool in `inkscape_mcp_server.py`


## Changes from upstream

Modified 2026-07 from [Shriinivas/inkmcp](https://github.com/Shriinivas/inkmcp) to add native Windows
support, per AGPL-3.0 §5(a). No operation-handling logic changed - `inkmcpops/`, `main.py`, and
`inkscape_mcp.inx` are byte-identical to upstream.

- **`inkmcp/gdbus_util.py`** (new) - resolves `gdbus.exe` as the sibling of the discovered
  `inkscape.exe` instead of a bare `gdbus` on PATH (which could resolve to an unrelated GLib install's
  D-Bus session), and polls for the extension's response file instead of assuming it's instantly present.
- **`inkmcp/inkmcpcli.py`**, **`inkmcp/inkscape_mcp_server.py`** - use the above instead of hardcoded
  `"gdbus"`.
- **`inkscape_mcp.py`** - fixed a hardcoded `/tmp/error_response.json` fallback path (now uses
  `tempfile.gettempdir()`).
- **`inkmcp/setup_windows.ps1`** (new) - one-time Windows venv bootstrap, replacing the bash
  `run_inkscape_mcp.sh` wrapper (see [Windows setup](#windows-setup)).
- **`install_windows.ps1`**, **`install_windows.bat`** (new) - one-command installer that runs every
  manual Windows setup step (find Inkscape, install the extension, disable the boot screen, bootstrap
  the venv via `setup_windows.ps1`) and prints a ready-to-paste MCP config snippet. Idempotent - safe
  to re-run after `git pull`.
- **README** - Windows install/troubleshooting sections, this section, and the license label fix below
  (was incorrectly showing GPL-3.0; the project is AGPL-3.0, matching `LICENSE`).

## License

[AGPL-3.0](https://github.com/Shriinivas/inkmcp/blob/main/LICENSE) (same as upstream)

