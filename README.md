# roblox-spiele

Ein Skill für Claude Code: Claude entwickelt Roblox-Spiele wie ein professioneller Roblox-Entwickler.

- saubere, erweiterbare Projektstruktur (Rojo, Luau im strict-Modus)
- sicheres Speichern der Spielstände (DataStore über ProfileStore, Migrationen)
- Admin-Konsole auf Taste **T** wie in Minecraft (`fly`, `god`, `invisible`, `noclip`, `tp` …)
- Weltbau und Spieltests direkt in Roblox Studio über das eingebaute MCP
- Ton und Musik über eine Tabelle, Lautstärke im Einstellungs-Fenster des Spielers
- faire Spiele: keine Käufe, solange du sie nicht ausdrücklich willst
- ein Abhak-Plan (`PLAN.md`) in jedem Spiel, der nach jedem Arbeitsschritt aktualisiert wird
- fertiger Beispielcode für 14 Genres und 3 Module

| Genres | Module |
|---|---|
| Ego-Shooter (gerade Block-Arme), Obby, Tower Defense, Simulator, Tycoon, Runden/Minispiele, RPG/Nahkampf, Horror/Story, Rennen/Fahrzeuge, Open World, Dungeon, Survival/Crafting, Battlegrounds, Adventure | Inventar, Monetarisierung, Bestenliste |

## Installation

Den Ordner in den Skill-Ordner von Claude Code legen.

**Windows (PowerShell):**
```
git clone <adresse-dieses-repositories> "$env:USERPROFILE\.claude\skills\roblox-spiele"
```

**macOS / Linux:**
```
git clone <adresse-dieses-repositories> ~/.claude/skills/roblox-spiele
```

Ohne git: Ordner als ZIP herunterladen und nach `.claude\skills\roblox-spiele` im Benutzerordner entpacken (die Datei `SKILL.md` muss direkt in diesem Ordner liegen). Danach Claude Code neu starten.

## Benutzen

In Claude Code einfach sagen, was du willst:

> Bau mir einen Ego-Shooter in Roblox mit zwei Teams.

> Mach an meinem Tycoon weiter.

> Füg meinem Obby eine Bestenliste hinzu.

Beim ersten Mal hilft Claude bei der Einrichtung von Roblox Studio, Rojo und der Studio-Verbindung (`references/einrichtung.md`). Prüfen, was fehlt:

```
python scripts/einrichtung_pruefen.py
```

## Aufbau

```
SKILL.md              Anleitung für Claude (Ablauf, Regeln, Wegweiser)
TESTSTATUS.md         was geprüft ist und was beim ersten Einsatz in Studio zu testen ist
references/           Nachschlagetexte (Architektur, Daten, Admin-Konsole, Weltbau, Qualität, …)
references/genres/    je Genre: Dateien, Welt-Vertrag, Entwurfsregeln, Stolperfallen
assets/basis/         Grundprojekt, das jedes neue Spiel bekommt
assets/genres/        Beispielcode je Genre
assets/module/        Inventar, Monetarisierung, Bestenliste
assets/weltbau/       Helfer zum Bauen der Welt in Studio
assets/referenz/      Vorbilder für die Block-Arme
scripts/              neues Spiel anlegen, Projekt prüfen, Einrichtung prüfen
```

## Stand

Der gesamte Code ist automatisch geprüft (baut mit Rojo, Typprüfung, Stilprüfung, Tests der reinen Logik). In Roblox Studio gespielt wurde er bei der Erstellung noch nicht; `TESTSTATUS.md` führt, was beim ersten Einsatz zu prüfen ist.

## Fremde Bestandteile

`assets/basis/src/server/Packages/ProfileStore.luau` stammt von MAD STUDIO (loleris), Apache-Lizenz 2.0; der Lizenztext liegt daneben. Quelle: <https://github.com/MadStudioRoblox/ProfileStore>
