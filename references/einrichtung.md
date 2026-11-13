# Einrichtung

Einmal pro Rechner nötig. `python scripts/einrichtung_pruefen.py` zeigt, was fehlt.

## Überblick

| Teil | Wozu | Pflicht |
|---|---|---|
| Roblox Studio | das Spiel läuft und wird dort gebaut | ja |
| Rokit | lädt die Werkzeuge in der Version, die im Projekt steht (`rokit.toml`) | ja |
| Rojo + Studio-Plugin | überträgt die Code-Dateien live nach Studio | ja |
| luau-lsp, selene, StyLua, lune | Typprüfung, Stilprüfung, Formatierung, Tests (`check_projekt.py`) | empfohlen |
| Studio-MCP | Claude baut die Welt und testet selbst in Studio | empfohlen |

## Windows (Arbeitsrechner des Nutzers)

1. **Roblox Studio** von <https://create.roblox.com> installieren und einmal starten.
2. **Rokit:** von <https://github.com/rojo-rbx/rokit/releases> die Datei `rokit-…-windows-x86_64.zip` laden, entpacken, `rokit.exe` doppelklicken oder in einem Terminal `rokit self-install` ausführen. Danach ein **neues** Terminal öffnen.
3. Im Spielprojekt (Ordner mit `rokit.toml`):
   ```
   rokit install
   rojo plugin install
   ```
   `rokit install` fragt beim ersten Mal je Werkzeug, ob ihm vertraut wird (mit `y` bestätigen). Studio danach neu starten.
4. **Studio-MCP einschalten:** in Studio Assistant öffnen → **…** → **Manage MCP Servers** → **Enable Studio as MCP server**.
5. **Mit Claude Code verbinden:** Assistant Settings → MCP Servers → **Quick connect** → **Claude Code** einschalten. Claude Code neu starten. Erscheint Claude Code dort nicht: Claude Code installieren, Studio neu starten.
   Von Hand geht es auch: `claude mcp add Roblox_Studio -- cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`

## macOS

Wie oben, mit diesen Unterschieden: Rokit-Datei `rokit-…-macos-aarch64.zip` (Apple-Chip) bzw. `x86_64` (Intel); manueller MCP-Eintrag: `claude mcp add Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`.
Auf Intel-Macs gibt es von selene keine aktuelle Version; `check_projekt.py` überspringt es dann.

## Täglicher Start

```
cd <spielprojekt>
rojo serve
```
In Studio: Reiter **Plugins** → **Rojo** → **Connect**. Ab jetzt landet jede gespeicherte Datei sofort in Studio. Die Place-Datei in Studio speichern (bzw. in Roblox veröffentlichen), sie enthält die Welt.

Neues Projekt zum ersten Mal: In Studio eine leere Baseplate öffnen, verbinden, als Datei oder in Roblox speichern.

## Einstellungen im Spiel (Studio → Datei → Spieleinstellungen)

- **Sicherheit → API-Dienste für Studio aktivieren:** nötig, damit DataStores in Studio erreichbar sind (für die Bestenliste und für `SaveInStudio = true`).
- **Avatar:** R15 (der Beispielcode geht von R15 aus; R6 funktioniert meist, Armbewegungen und Handpositionen weichen ab).

## Typische Fehler

| Meldung / Verhalten | Ursache und Abhilfe |
|---|---|
| `rojo` oder `rokit` wird nicht gefunden | Terminal nach der Installation nicht neu geöffnet; sonst `%USERPROFILE%\.rokit\bin` in den PATH aufnehmen |
| „has not been marked as trusted" | `rokit trust <werkzeug>` oder `rokit install` interaktiv ausführen |
| Rojo verbindet nicht | läuft `rojo serve`? Plugin und Rojo müssen dieselbe Hauptversion (7) haben |
| Skripte doppelt in Studio | alte, von Hand angelegte Skripte in ServerScriptService/StarterPlayerScripts löschen |
| Welt nach Verbinden weg | `default.project.json` verwaltet Workspace (darf es nicht; siehe `assets/basis`) |
| MCP-Werkzeuge fehlen in Claude Code | Studio offen? MCP-Server in Studio eingeschaltet? Claude Code danach neu gestartet? `claude mcp list` zeigt den Status |
| Typprüfung meldet massenhaft „Unknown global" | Typdefinitionen fehlen: `check_projekt.py` lädt sie beim ersten Lauf (Internet nötig) nach `~/.roblox-dev/` |

## Den Skill selbst auf einen anderen Rechner bringen

Der Skill ist ein normaler Ordner. Auf dem Zielrechner nach `%USERPROFILE%\.claude\skills\roblox-dev` (Windows) bzw. `~/.claude/skills/roblox-dev` (macOS) kopieren oder dorthin klonen. Claude Code neu starten.
