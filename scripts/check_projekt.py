#!/usr/bin/env python3
"""Prueft ein Roblox-Spielprojekt (Rojo) auf Fehler, bevor es in Studio getestet wird.

    python check_projekt.py <projektordner> [--fix] [--schnell]

Schritte:
  1. Aufbau       default.project.json, PLAN.md, src/
  2. Bauen        rojo build (laesst sich das Projekt zu einer .rbxl bauen?)
  3. Typen        luau-lsp analyze (Tippfehler, falsche API-Namen, Typfehler)
  4. Stil         selene (typische Fehlerquellen) und stylua (Formatierung)
  5. Hausregeln   eigene Regeln des Skills (veraltete Funktionen, Datenzugriff ...)
  6. Tests        lune run tests/run.luau (falls vorhanden)
  7. Plan         ist PLAN.md aktueller als der Code?

--fix      formatiert den Code mit stylua, statt nur zu pruefen
--schnell  ueberspringt Bauen und Tests

Fehlende Werkzeuge werden gemeldet und uebersprungen (Installation: `rokit install`
im Projektordner, siehe references/einrichtung.md). Rueckgabewert 1 bei Fehlern.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

DEFS_URL = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
CACHE_DIR = Path.home() / ".roblox-spiele"
DEFS_FILE = CACHE_DIR / "globalTypes.d.luau"
EXCLUDED_PARTS = ("Packages",)

errors: list[str] = []
warnings: list[str] = []


def out(text: str = "") -> None:
    print(text)


def ok(text: str) -> None:
    out(f"  [OK]      {text}")


def error(text: str) -> None:
    errors.append(text)
    out(f"  [FEHLER]  {text}")


def warn(text: str) -> None:
    warnings.append(text)
    out(f"  [HINWEIS] {text}")


def section(title: str) -> None:
    out()
    out(f"== {title} ==")


def find_tool(name: str) -> str | None:
    """Sucht ein Werkzeug im PATH und im Rokit-Ordner."""
    found = shutil.which(name)
    if found:
        return found
    for suffix in ("", ".exe"):
        candidate = Path.home() / ".rokit" / "bin" / (name + suffix)
        if candidate.exists():
            return str(candidate)
    return None


def run(command: list[str], cwd: Path, timeout: int = 300) -> tuple[int, str]:
    try:
        result = subprocess.run(
            command,
            cwd=str(cwd),
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return 1, f"Zeitueberschreitung nach {timeout}s: {' '.join(command)}"
    except OSError as problem:
        # z. B. Werkzeug fuer eine andere Prozessor-Architektur
        return 126, f"Werkzeug laesst sich nicht starten: {problem}"
    return result.returncode, (result.stdout + result.stderr).strip()


def show(output: str, limit: int = 60) -> None:
    lines = [line for line in output.splitlines() if line.strip()]
    for line in lines[:limit]:
        out(f"      {line}")
    if len(lines) > limit:
        out(f"      ... ({len(lines) - limit} weitere Zeilen)")


def luau_files(project: Path) -> list[Path]:
    files = []
    for path in sorted((project / "src").rglob("*.luau")):
        if not any(part in EXCLUDED_PARTS for part in path.parts):
            files.append(path)
    return files


# ---------------------------------------------------------------------------
# 1. Aufbau
# ---------------------------------------------------------------------------


def check_structure(project: Path) -> bool:
    section("1. Aufbau")
    project_file = project / "default.project.json"
    if not project_file.exists():
        error("default.project.json fehlt. Ist das der richtige Ordner?")
        return False
    try:
        data = json.loads(project_file.read_text(encoding="utf-8"))
    except json.JSONDecodeError as problem:
        error(f"default.project.json ist kein gueltiges JSON: {problem}")
        return False
    if "{{" in json.dumps(data):
        warn("default.project.json enthaelt noch Platzhalter ({{...}}).")
    for folder in ("src/server", "src/client", "src/shared"):
        if not (project / folder).is_dir():
            error(f"Ordner {folder} fehlt.")
    if (project / "PLAN.md").exists():
        ok("PLAN.md vorhanden")
    else:
        error("PLAN.md fehlt. Jedes Spiel braucht den Abhak-Plan (Vorlage: assets/basis/PLAN.md).")
    if "Workspace" in data.get("tree", {}):
        warn("default.project.json verwaltet Workspace: Die in Studio gebaute Welt koennte ueberschrieben werden.")
    if not errors:
        ok("Projektdateien in Ordnung")
    return True


# ---------------------------------------------------------------------------
# 2. Bauen
# ---------------------------------------------------------------------------


def check_build(project: Path) -> None:
    section("2. Bauen (rojo build)")
    rojo = find_tool("rojo")
    if not rojo:
        warn("rojo nicht gefunden: uebersprungen.")
        return
    with tempfile.TemporaryDirectory() as temp:
        target = Path(temp) / "build.rbxl"
        code, output = run([rojo, "build", "default.project.json", "-o", str(target)], project)
        if code != 0 or not target.exists():
            error("rojo build ist fehlgeschlagen:")
            show(output)
        else:
            ok(f"Projekt laesst sich bauen ({target.stat().st_size // 1024} KB)")


# ---------------------------------------------------------------------------
# 3. Typen
# ---------------------------------------------------------------------------


def ensure_definitions() -> Path | None:
    if DEFS_FILE.exists() and DEFS_FILE.stat().st_size > 100_000:
        return DEFS_FILE
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(DEFS_URL, headers={"User-Agent": "roblox-spiele-check"})
        with urllib.request.urlopen(request, timeout=60) as response:
            DEFS_FILE.write_bytes(response.read())
        return DEFS_FILE
    except Exception as problem:  # noqa: BLE001 - jede Netzwerkstoerung soll nur ein Hinweis sein
        warn(f"Roblox-Typdefinitionen konnten nicht geladen werden ({problem}).")
        return None


def check_types(project: Path) -> None:
    section("3. Typen (luau-lsp analyze)")
    luau_lsp = find_tool("luau-lsp")
    rojo = find_tool("rojo")
    if not luau_lsp or not rojo:
        warn("luau-lsp oder rojo nicht gefunden: uebersprungen.")
        return
    definitions = ensure_definitions()
    if not definitions:
        warn("Ohne Typdefinitionen keine Typpruefung: uebersprungen.")
        return
    code, output = run([rojo, "sourcemap", "default.project.json", "-o", "sourcemap.json"], project)
    if code != 0:
        error("rojo sourcemap ist fehlgeschlagen:")
        show(output)
        return
    command = [
        luau_lsp,
        "analyze",
        "--sourcemap=sourcemap.json",
        f"--definitions=@roblox={definitions}",
        "--ignore=**/Packages/**",
    ]
    if (project / ".luaurc").exists():
        command.append("--base-luaurc=.luaurc")
    command.append("src")
    code, output = run(command, project, timeout=600)
    # Ausgabe lesbar machen: Pfade relativ zum Projekt, Roblox-Pfad und Statuszeilen weg.
    cleaned = []
    for line in output.splitlines():
        if line.startswith(("[INFO]", "[WARN]")):
            continue
        line = line.replace(str(project) + os.sep, "").replace(str(project) + "/", "")
        line = re.sub(r" \[game/[^\]]*\]", "", line)
        cleaned.append(line)
    problems = [line for line in cleaned if re.search(r"\(\d+,\d+\): ", line)]
    if code != 0 or problems:
        error(f"luau-lsp meldet {len(problems) or 'mehrere'} Problem(e):")
        show("\n".join(cleaned), 80)
    else:
        ok("keine Typfehler")


# ---------------------------------------------------------------------------
# 4. Stil
# ---------------------------------------------------------------------------


def check_style(project: Path, fix: bool) -> None:
    section("4. Stil (selene, stylua)")
    selene = find_tool("selene")
    if not selene:
        warn("selene nicht gefunden: uebersprungen.")
    else:
        code, output = run([selene, "src"], project)
        if code == 126:
            warn(f"selene uebersprungen. {output}")
        else:
            summary = re.search(r"Results:\s*(\d+) errors\s*(\d+) warnings", output, re.S)
            error_count = int(summary.group(1)) if summary else (1 if code != 0 else 0)
            warning_count = int(summary.group(2)) if summary else 0
            if error_count:
                error(f"selene meldet {error_count} Fehler:")
                show(output)
            elif warning_count:
                warn(f"selene meldet {warning_count} Warnung(en):")
                show(output, 30)
            else:
                ok("selene ohne Befund")

    stylua = find_tool("stylua")
    if not stylua:
        warn("stylua nicht gefunden: uebersprungen.")
        return
    if fix:
        code, output = run([stylua, "src"], project)
        if code == 0:
            ok("Code formatiert (stylua)")
        else:
            error("stylua konnte nicht formatieren:")
            show(output)
        return
    code, output = run([stylua, "--check", "src"], project)
    if code == 0:
        ok("Formatierung sauber")
    else:
        files = sorted(set(re.findall(r"Diff in (.+?)(?: at line|:)", output)))
        warn(f"{len(files) or 'Einige'} Datei(en) sind nicht formatiert. Beheben mit --fix.")
        for name in files[:15]:
            out(f"      {name}")


# ---------------------------------------------------------------------------
# 5. Hausregeln
# ---------------------------------------------------------------------------

# (Muster, Meldung, Art, Dateien-Ausnahme als Regex auf den Pfad mit '/')
RULES: list[tuple[re.Pattern[str], str, str, str | None]] = [
    (
        re.compile(r"(?<![\w.:])wait\s*\("),
        "wait() ist veraltet: task.wait() benutzen",
        "error",
        None,
    ),
    (
        re.compile(r"(?<![\w.:])spawn\s*\("),
        "spawn() ist veraltet: task.spawn() benutzen",
        "error",
        None,
    ),
    (
        re.compile(r"(?<![\w.:])delay\s*\("),
        "delay() ist veraltet: task.delay() benutzen",
        "error",
        None,
    ),
    (
        re.compile(r":connect\s*\("),
        ":connect() ist veraltet: :Connect() benutzen",
        "error",
        None,
    ),
    (
        re.compile(r'GetService\(\s*"DataStoreService"\s*\)'),
        "DataStoreService nur im DataService bzw. LeaderboardService benutzen (sonst droht Datenverlust)",
        "error",
        r"/(DataService|LeaderboardService)\.luau$",
    ),
    (
        re.compile(r'Instance\.new\(\s*"(RemoteEvent|RemoteFunction|UnreliableRemoteEvent)"'),
        "Remotes nicht von Hand anlegen: shared/Net benutzen (Pruefung und Aufrufgrenze eingebaut)",
        "error",
        r"/shared/Net\.luau$",
    ),
    (
        re.compile(r"\.ProcessReceipt\s*="),
        "ProcessReceipt darf es nur einmal geben: im MonetizationService",
        "error",
        r"/MonetizationService\.luau$",
    ),
    (
        re.compile(r"\bLocalPlayer\b"),
        "LocalPlayer gibt es auf dem Server nicht",
        "error",
        r"^(?!.*src/server/).*$",
    ),
    (
        re.compile(r"[Hh]umanoid\w*\.Health\s*-="),
        "Schaden ueber Humanoid:TakeDamage() austeilen (beachtet Gott-Modus und Kraftfelder)",
        "warn",
        None,
    ),
    (
        re.compile(r"\bInvokeClient\s*\("),
        "InvokeClient vermeiden: Ein Client kann den Server damit ewig warten lassen",
        "error",
        None,
    ),
    (
        re.compile(r"\bloadstring\s*\("),
        "loadstring ist ein Sicherheitsrisiko",
        "error",
        None,
    ),
]


def strip_comments(source: str) -> list[str]:
    """Entfernt Kommentare grob, damit Regeln nicht auf Erklaertexte anspringen."""
    source = re.sub(r"--\[(=*)\[.*?\]\1\]", lambda match: "\n" * match.group(0).count("\n"), source, flags=re.S)
    lines = []
    for line in source.splitlines():
        index = line.find("--")
        lines.append(line if index < 0 else line[:index])
    return lines


def check_rules(project: Path) -> None:
    section("5. Hausregeln")
    count_before = len(errors) + len(warnings)
    for path in luau_files(project):
        relative = path.relative_to(project).as_posix()
        source = path.read_text(encoding="utf-8")
        first_line = source.lstrip("﻿").splitlines()[0] if source.strip() else ""
        if not first_line.startswith("--!strict"):
            warn(f"{relative}: erste Zeile sollte --!strict sein")
        for number, line in enumerate(strip_comments(source), start=1):
            for pattern, message, kind, exception in RULES:
                if exception and re.search(exception, "/" + relative):
                    continue
                if pattern.search(line):
                    text = f"{relative}:{number}: {message}"
                    if kind == "error":
                        error(text)
                    else:
                        warn(text)
    if len(errors) + len(warnings) == count_before:
        ok(f"{len(luau_files(project))} Dateien geprueft, keine Regelverstoesse")


# ---------------------------------------------------------------------------
# 6. Tests
# ---------------------------------------------------------------------------


def check_tests(project: Path) -> None:
    section("6. Tests (lune)")
    runner = project / "tests" / "run.luau"
    if not runner.exists():
        ok("keine Tests vorhanden")
        return
    lune = find_tool("lune")
    if not lune:
        warn("lune nicht gefunden: Tests uebersprungen.")
        return
    code, output = run([lune, "run", "tests/run.luau"], project)
    if code != 0:
        error("Tests fehlgeschlagen:")
        show(output)
    else:
        last = output.splitlines()[-1] if output else ""
        ok(f"Tests bestanden ({last.strip()})")


# ---------------------------------------------------------------------------
# 7. Plan
# ---------------------------------------------------------------------------


def check_plan(project: Path) -> None:
    section("7. Plan")
    plan = project / "PLAN.md"
    if not plan.exists():
        return
    text = plan.read_text(encoding="utf-8")
    done = len(re.findall(r"^\s*[-*] \[[xX]\]", text, re.M))
    todo = len(re.findall(r"^\s*[-*] \[ \]", text, re.M))
    files = luau_files(project)
    newest = max((path.stat().st_mtime for path in files), default=0)
    if newest > plan.stat().st_mtime + 120:
        warn("PLAN.md ist aelter als der Code. Erledigtes abhaken und 'Als Naechstes' aktualisieren.")
    else:
        ok("PLAN.md ist aktuell")
    out(f"      Stand: {done} erledigt, {todo} offen")


# ---------------------------------------------------------------------------


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Prueft ein Roblox-Spielprojekt.")
    parser.add_argument("projekt", nargs="?", default=".", help="Projektordner (Standard: aktueller Ordner)")
    parser.add_argument("--fix", action="store_true", help="Code mit stylua formatieren")
    parser.add_argument("--schnell", action="store_true", help="Bauen und Tests ueberspringen")
    args = parser.parse_args()

    project = Path(args.projekt).resolve()
    out(f"Pruefe {project}")

    # Rokit-Werkzeuge auch dann finden, wenn der PATH sie nicht enthaelt.
    os.environ["PATH"] = os.environ.get("PATH", "") + os.pathsep + str(Path.home() / ".rokit" / "bin")

    if check_structure(project):
        if not args.schnell:
            check_build(project)
        check_types(project)
        check_style(project, args.fix)
        check_rules(project)
        if not args.schnell:
            check_tests(project)
        check_plan(project)

    out()
    out("== Ergebnis ==")
    if errors:
        out(f"  {len(errors)} Fehler, {len(warnings)} Hinweis(e). Fehler zuerst beheben.")
        return 1
    if warnings:
        out(f"  Keine Fehler, {len(warnings)} Hinweis(e).")
    else:
        out("  Alles in Ordnung.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
