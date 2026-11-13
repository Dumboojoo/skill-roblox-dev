# roblox-spiele

Ein Skill für Claude Code: Claude entwickelt Roblox-Spiele wie ein professioneller Roblox-Entwickler.

- saubere, erweiterbare Projektstruktur (Rojo, Luau im strict-Modus)
- sicheres Speichern der Spielstände (DataStore über ProfileStore, Migrationen)
- Admin-Konsole auf Taste **T** wie in Minecraft (`fly`, `god`, `invisible`, `noclip`, `tp` …)
- Weltbau und Spieltests direkt in Roblox Studio über das eingebaute MCP
- Ton und Musik über eine Tabelle, Lautstärke im Einstellungs-Fenster des Spielers
- Effekte (Treffer, Schuss, Explosion) über eine Tabelle, dazu ein Zeichen-Skript für die Effekt-Bilder
- eigene 3D-Modelle aus Blender: Figuren aus Einzelteilen, deren Körperteile sich einzeln bewegen lassen und im Spiel von selbst laufen, wedeln und atmen
- Effekte in weißen Schichten zeichnen mit dem freien Bildprogramm PhotoCraft, Texturen backen in Blender (beides freiwillig; alles geht auch ohne)
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

> Mach mir in Blender ein Monster für mein RPG, das laufen und beißen kann.

> Der Treffer braucht einen schöneren Effekt.

Beim ersten Mal hilft Claude bei der Einrichtung von Roblox Studio, Rojo und der Studio-Verbindung (`references/einrichtung.md`). Blender und PhotoCraft sind freiwillige Erweiterungen (`references/kreativ-einrichtung.md`). Prüfen, was fehlt:

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
assets/weltbau/       Helfer für Studio: Welt bauen, Blender-Modelle einbauen, Gelenke bauen, Effekte ansehen
assets/kreativ/       Helfer für Blender: Modelle, Figuren aus Einzelteilen, Texturen, Effekt-Bilder
assets/referenz/      Vorbilder für die Block-Arme
scripts/              neues Spiel anlegen, Projekt prüfen, Einrichtung prüfen, Effekt-Bilder zeichnen
```

## Stand

Der gesamte Code ist automatisch geprüft (baut mit Rojo, Typprüfung, Stilprüfung, Tests der reinen Logik). In Roblox Studio gespielt wurde er bei der Erstellung noch nicht; `TESTSTATUS.md` führt, was beim ersten Einsatz zu prüfen ist. Die Blender-Helfer liefen in Blender 4.5 ohne Fenster; die Verbindungen zu Blender und PhotoCraft, das Hochladen und der Einbau in Studio sind noch nicht erprobt.

## Fremde Bestandteile

`assets/basis/src/server/Packages/ProfileStore.luau` stammt von MAD STUDIO (loleris), Apache-Lizenz 2.0; der Lizenztext liegt daneben. Quelle: <https://github.com/MadStudioRoblox/ProfileStore>
