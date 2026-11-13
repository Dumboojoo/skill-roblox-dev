#!/usr/bin/env python3
"""Prueft, ob auf diesem Rechner alles fuer die Roblox-Entwicklung eingerichtet ist.

    python einrichtung_pruefen.py

Geprueft wird:
  - Rokit und die Werkzeuge Rojo, selene, StyLua, luau-lsp, lune
  - Roblox Studio und das Rojo-Plugin
  - der in Studio eingebaute MCP-Server und seine Verbindung zu Claude Code

Zu jedem fehlenden Punkt steht direkt dabei, was zu tun ist. Die ausfuehrliche
Anleitung ist references/einrichtung.md. Rueckgabewert 1, wenn etwas Noetiges fehlt.
"""

from __future__ import annotations

import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

IS_WINDOWS = platform.system() == "Windows"
HOME = Path.home()
ROKIT_BIN = HOME / ".rokit" / "bin"

missing_required = 0
missing_optional = 0


def out(text: str = "") -> None:
    print(text)


def report(ok: bool, name: str, detail: str = "", fix: str = "", required: bool = True) -> None:
    global missing_required, missing_optional
    if ok:
        out(f"  [OK]     {name}{'  (' + detail + ')' if detail else ''}")
        return
    if required:
        missing_required += 1
        out(f"  [FEHLT]  {name}")
    else:
        missing_optional += 1
        out(f"  [OFFEN]  {name}")
    for line in fix.splitlines():
        out(f"           -> {line}")


def find(name: str) -> str | None:
    found = shutil.which(name)
    if found:
        return found
    for suffix in ("", ".exe"):
        candidate = ROKIT_BIN / (name + suffix)
        if candidate.exists():
            return str(candidate)
    return None


def version(path: str, cwd: Path | None = None) -> str:
    try:
        result = subprocess.run(
            [path, "--version"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=20,
            cwd=str(cwd) if cwd else None,
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    text = (result.stdout or result.stderr).strip().splitlines()
    return text[0] if text and result.returncode == 0 else ""


def studio_paths() -> tuple[Path | None, Path | None, Path]:
    """Gibt (Studio-Programm, MCP-Starter, Plugin-Ordner) zurueck."""
    if IS_WINDOWS:
        local = Path(os.environ.get("LOCALAPPDATA", HOME / "AppData" / "Local"))
        versions = local / "Roblox" / "Versions"
        studio = None
        if versions.is_dir():
            for folder in versions.iterdir():
                candidate = folder / "RobloxStudioBeta.exe"
                if candidate.exists():
                    studio = candidate
                    break
        mcp = local / "Roblox" / "mcp.bat"
        return studio, mcp if mcp.exists() else None, local / "Roblox" / "Plugins"
    app = Path("/Applications/RobloxStudio.app")
    mcp = app / "Contents" / "MacOS" / "StudioMCP"
    return (app if app.exists() else None), (mcp if mcp.exists() else None), HOME / "Documents" / "Roblox" / "Plugins"


def mcp_connected() -> bool | None:
    """True/False, wenn sich die Verbindung pruefen laesst, sonst None."""
    claude = shutil.which("claude")
    if not claude:
        return None
    try:
        result = subprocess.run(
            [claude, "mcp", "list"], capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=60
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    listing = (result.stdout + result.stderr).lower()
    return "roblox" in listing


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    out(f"Einrichtung pruefen ({platform.system()} {platform.machine()})")
    out()
    out("Werkzeuge")
    rokit = find("rokit")
    rokit_fix = (
        "Rokit installieren: https://github.com/rojo-rbx/rokit/releases (Datei entpacken, 'rokit self-install' ausfuehren)\n"
        "Danach ein neues Terminal oeffnen."
    )
    report(rokit is not None, "Rokit (Werkzeug-Verwaltung)", version(rokit) if rokit else "", rokit_fix)

    # Die Werkzeuge laufen ueber Rokit nur in einem Ordner mit rokit.toml (jedes Spielprojekt hat eine).
    basis = Path(__file__).resolve().parent.parent / "assets" / "basis"
    tool_fix = "Im Spielprojekt ausfuehren: rokit install   (liest rokit.toml und laedt die passenden Versionen)"
    for tool, label, required in (
        ("rojo", "Rojo (Code nach Studio uebertragen)", True),
        ("luau-lsp", "luau-lsp (Typpruefung)", True),
        ("stylua", "StyLua (Formatierung)", False),
        ("selene", "selene (Stilpruefung)", False),
        ("lune", "lune (Tests)", False),
    ):
        path = find(tool)
        tool_version = version(path, basis) if path else ""
        report(bool(tool_version), label, tool_version, tool_fix, required)

    out()
    out("Roblox Studio")
    studio, mcp, plugins = studio_paths()
    report(studio is not None, "Roblox Studio installiert", "", "Installieren: https://create.roblox.com (Start Creating)")

    rojo_plugin = plugins.is_dir() and any("rojo" in entry.name.lower() for entry in plugins.iterdir())
    report(
        rojo_plugin,
        "Rojo-Plugin in Studio",
        "",
        "Im Spielprojekt ausfuehren: rojo plugin install   (Studio danach neu starten)",
    )

    out()
    out("Studio-MCP (Claude steuert Studio)")
    report(
        mcp is not None,
        "MCP-Server von Studio vorhanden",
        "",
        "Roblox Studio aktualisieren und einmal starten.\n"
        "In Studio: Assistant oeffnen -> ... -> Manage MCP Servers -> 'Enable Studio as MCP server' einschalten.",
        required=False,
    )
    connected = mcp_connected()
    if connected is None:
        report(False, "Verbindung zu Claude Code", "", "Nicht pruefbar (Befehl 'claude' nicht gefunden).", required=False)
    else:
        report(
            connected,
            "Verbindung zu Claude Code",
            "",
            "In Studio: Assistant Settings -> MCP Servers -> Quick connect -> 'Claude Code' einschalten.\n"
            "Danach Claude Code neu starten. Details: references/einrichtung.md",
            required=False,
        )

    out()
    if missing_required:
        out(f"Es fehlen {missing_required} noetige Punkte. Ohne sie kann kein Spiel gebaut werden.")
        return 1
    if missing_optional:
        out(f"Grundlage steht. {missing_optional} Punkt(e) sind noch offen (siehe oben).")
    else:
        out("Alles eingerichtet.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
