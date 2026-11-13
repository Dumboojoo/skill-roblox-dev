#!/usr/bin/env python3
"""Legt ein neues Roblox-Spielprojekt an oder ergaenzt ein bestehendes um Module.

    python neues_spiel.py --liste
    python neues_spiel.py <zielordner> --name "Mein Spiel" --genre ego-shooter --module inventar,bestenliste
    python neues_spiel.py <zielordner> --ergaenzen --module monetarisierung

Neues Spiel: kopiert assets/basis, legt den Beispielcode des gewaehlten Genres und der
gewaehlten Module darueber und fuellt PLAN.md aus. Es landet nur der Code im Projekt,
der gebraucht wird.

--ergaenzen: kopiert nur die Module in ein bestehendes Projekt und haengt ihre
Plan-Abschnitte an PLAN.md an. Vorhandene Dateien werden nie ueberschrieben.
"""

from __future__ import annotations

import argparse
import datetime
import re
import shutil
import sys
from pathlib import Path

SKILL = Path(__file__).resolve().parent.parent
BASIS = SKILL / "assets" / "basis"
GENRES = SKILL / "assets" / "genres"
MODULE = SKILL / "assets" / "module"

# Welche Referenz zu welchem Modul gehoert (wird in den Kopf von PLAN.md eingetragen).
MODULE_REFERENCES = {
    "inventar": "module.md",
    "bestenliste": "module.md",
    "monetarisierung": "monetarisierung.md",
}

# Dateien, in denen Platzhalter ersetzt werden.
TEXT_FILES = ("default.project.json", "README.md", "PLAN.md", "src/shared/Config/GameConfig.luau")

LEER_PLAN = """## Phase 1 – Kern spielbar

- [ ] Kernmechanik als eigener Service (Server) und Controller (Client) umgesetzt
- [ ] Inhalte als Tabellen in `src/shared/Config/`
- [ ] Spielstand-Abschnitt in `src/shared/Config/DataSections/`
- [ ] Eigene Admin-Befehle zum Testen in `src/server/Admin/Commands/`

## Phase 2 – Welt

- [ ] Welt-Vertrag festgelegt (welche Tags und Attribute der Code erwartet)
- [ ] Spielbare Block-Welt in Studio gebaut
- [ ] `World.Expect` meldet beim Start keine fehlenden Teile"""


def available(folder: Path) -> list[str]:
    if not folder.is_dir():
        return []
    return sorted(entry.name for entry in folder.iterdir() if entry.is_dir() and not entry.name.startswith("."))


def fail(message: str) -> None:
    print(f"FEHLER: {message}")
    sys.exit(1)


def overlay(source: Path, target: Path) -> list[str]:
    """Kopiert source nach target, ohne vorhandene Dateien zu ueberschreiben. Gibt Konflikte zurueck."""
    conflicts: list[str] = []
    if not source.is_dir():
        return conflicts
    for path in sorted(source.rglob("*")):
        if path.is_dir() or path.name == ".DS_Store":
            continue
        relative = path.relative_to(source)
        destination = target / relative
        if destination.exists():
            if destination.read_bytes() != path.read_bytes():
                conflicts.append(relative.as_posix())
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
    return conflicts


def read_fragment(folder: Path) -> str:
    fragment = folder / "plan.md"
    return fragment.read_text(encoding="utf-8").strip() if fragment.exists() else ""


def copy_kit(kit: Path, target: Path) -> None:
    """Kopiert src/ und tests/ eines Genres oder Moduls ins Projekt."""
    for part in ("src", "tests"):
        conflicts = overlay(kit / part, target / part)
        for conflict in conflicts:
            print(f"  HINWEIS: {part}/{conflict} gibt es schon mit anderem Inhalt und wurde nicht ueberschrieben.")


def create(args: argparse.Namespace, genres: list[str], modules: list[str]) -> None:
    target = Path(args.ziel).resolve()
    if target.exists() and any(target.iterdir()):
        fail(f"{target} ist nicht leer. Fuer ein bestehendes Projekt --ergaenzen benutzen.")
    if args.genre != "leer" and args.genre not in genres:
        fail(f'Genre "{args.genre}" gibt es nicht. Verfuegbar: leer, {", ".join(genres)}')
    chosen = [name.strip() for name in args.module.split(",") if name.strip()]
    for module in chosen:
        if module not in modules:
            fail(f'Modul "{module}" gibt es nicht. Verfuegbar: {", ".join(modules)}')

    name = args.name or target.name
    shutil.copytree(BASIS, target, ignore=shutil.ignore_patterns(".DS_Store", "sourcemap.json", "build"))

    genre_plan = LEER_PLAN
    references = ["architektur.md"]
    if args.genre != "leer":
        copy_kit(GENRES / args.genre, target)
        genre_plan = read_fragment(GENRES / args.genre) or LEER_PLAN
        references.append(f"genres/{args.genre}.md")

    module_plans = []
    for module in chosen:
        copy_kit(MODULE / module, target)
        fragment = read_fragment(MODULE / module)
        if fragment:
            module_plans.append(fragment)
        reference = MODULE_REFERENCES.get(module)
        if reference and reference not in references:
            references.append(reference)

    replacements = {
        "{{NAME}}": name,
        "{{GENRE}}": args.genre,
        "{{MODULE}}": ", ".join(chosen) if chosen else "keine",
        "{{DATUM}}": datetime.date.today().isoformat(),
        "{{REFERENZEN}}": ", ".join(f"`references/{reference}`" for reference in references),
        "{{GENRE_PLAN}}": genre_plan,
        "{{MODUL_PLAN}}": "\n\n".join(module_plans),
    }
    for relative in TEXT_FILES:
        path = target / relative
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        for placeholder, value in replacements.items():
            if relative != "PLAN.md" and placeholder == "{{NAME}}":
                # In JSON und Luau duerfen keine Anfuehrungszeichen aus dem Namen landen.
                value = value.replace('"', "'").replace("\\", "/")
            text = text.replace(placeholder, value)
        while "\n\n\n" in text:
            text = text.replace("\n\n\n", "\n\n")
        path.write_text(text, encoding="utf-8", newline="\n")

    print(f"Projekt angelegt: {target}")
    print(f"  Genre:  {args.genre}")
    print(f"  Module: {', '.join(chosen) if chosen else 'keine'}")
    print()
    print("Naechste Schritte:")
    print(f"  1. cd {target}")
    print("  2. rokit install        (Werkzeuge in der richtigen Version)")
    print("  3. rojo serve           (und in Studio ueber das Rojo-Plugin verbinden)")
    print("  4. PLAN.md: Spielidee und Kernschleife ausfuellen")


def plan_row(text: str, label: str) -> str | None:
    """Liest den Wert einer Zeile '| Label | Wert |' aus dem Kopf von PLAN.md."""
    match = re.search(rf"^\|\s*{re.escape(label)}\s*\|(.*)\|\s*$", text, flags=re.M)
    return match.group(1).strip() if match else None


def set_plan_row(text: str, label: str, value: str) -> str:
    pattern = re.compile(rf"^\|\s*{re.escape(label)}\s*\|.*\|\s*$", flags=re.M)
    if not pattern.search(text):
        return text
    return pattern.sub(lambda _match: f"| {label} | {value} |", text, count=1)


def plan_modules(text: str) -> list[str]:
    value = plan_row(text, "Module") or ""
    return [name.strip() for name in value.split(",") if name.strip() and name.strip() != "keine"]


def plan_references(text: str) -> list[str]:
    value = plan_row(text, "Skill-Referenzen") or ""
    return re.findall(r"`references/([^`]+)`", value)


def extend(args: argparse.Namespace, modules: list[str]) -> None:
    target = Path(args.ziel).resolve()
    if not (target / "default.project.json").exists():
        fail(f"{target} ist kein Spielprojekt (default.project.json fehlt).")
    chosen = [name.strip() for name in args.module.split(",") if name.strip()]
    if not chosen:
        fail("Mit --ergaenzen muss --module angegeben werden.")
    for module in chosen:
        if module not in modules:
            fail(f'Modul "{module}" gibt es nicht. Verfuegbar: {", ".join(modules)}')

    plan = target / "PLAN.md"
    text = plan.read_text(encoding="utf-8") if plan.exists() else ""
    present = plan_modules(text)
    additions = []
    for module in chosen:
        copy_kit(MODULE / module, target)
        if module in present:
            print(f"Modul {module}: steht schon im Plan, fehlende Dateien wurden ergaenzt.")
            continue
        fragment = read_fragment(MODULE / module)
        if fragment:
            additions.append(fragment)
        present.append(module)
        print(f"Modul ergaenzt: {module}")

    if not plan.exists():
        print("Hinweis: PLAN.md fehlt, die Aufgaben der Module wurden nirgends eingetragen.")
        return

    text = set_plan_row(text, "Module", ", ".join(present) if present else "keine")
    references = plan_references(text)
    for module in present:
        reference = MODULE_REFERENCES.get(module)
        if reference and reference not in references:
            references.append(reference)
    if references:
        text = set_plan_row(text, "Skill-Referenzen", ", ".join(f"`references/{reference}`" for reference in references))
    if additions:
        text = text.rstrip() + "\n\n" + "\n\n".join(additions) + "\n"
    plan.write_text(text, encoding="utf-8", newline="\n")
    print("PLAN.md aktualisiert (Kopf und Aufgaben der Module).")


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description="Legt ein Roblox-Spielprojekt an.")
    parser.add_argument("ziel", nargs="?", help="Zielordner des Projekts")
    parser.add_argument("--name", help="Anzeigename des Spiels (Standard: Ordnername)")
    parser.add_argument("--genre", default="leer", help="Genre aus assets/genres oder 'leer'")
    parser.add_argument("--module", default="", help="Module aus assets/module, mit Komma getrennt")
    parser.add_argument("--ergaenzen", action="store_true", help="Module in ein bestehendes Projekt kopieren")
    parser.add_argument("--liste", action="store_true", help="verfuegbare Genres und Module anzeigen")
    args = parser.parse_args()

    genres = available(GENRES)
    modules = available(MODULE)

    if args.liste:
        print("Genres: leer, " + ", ".join(genres))
        print("Module: " + (", ".join(modules) if modules else "keine"))
        return
    if not args.ziel:
        parser.error("Zielordner fehlt")
    if args.ergaenzen:
        extend(args, modules)
    else:
        create(args, genres, modules)


if __name__ == "__main__":
    main()
