# Studio über MCP steuern und testen

Roblox Studio bringt einen eigenen MCP-Server mit. Darüber kann Claude in das offene Studio schauen, Luau ausführen, die Welt bauen und Spieltests fahren. Einrichtung: `einrichtung.md`.

Die Werkzeuge heißen je nach Verbindung etwa `mcp__Roblox_Studio__<name>`. Die Liste unten gibt den Stand der Roblox-Dokumentation wieder (<https://create.roblox.com/docs/studio/mcp>); zählt die tatsächlich angebotene Werkzeugliste anders, gilt die.

## Werkzeuge

| Bereich | Werkzeug | Wofür |
|---|---|---|
| Sitzung | `list_roblox_studios` | offene Studio-Fenster und ihre `studio_id` (jeder Aufruf braucht sie) |
| | `get_studio_state` | läuft gerade ein Spieltest? welche Seiten (Edit, Server, Client) gibt es? |
| Erkunden | `search_game_tree`, `inspect_instance` | Aufbau des Spiels, Eigenschaften, Attribute |
| | `script_read`, `script_search`, `script_grep` | Skripte in Studio lesen (zum Vergleichen, nicht zum Ändern) |
| Ausführen | `execute_luau` | Luau im Bearbeitungsmodus, auf dem Server oder auf dem Client ausführen |
| Bauen | `generate_procedural_model`, `wait_job_finished` | Modell aus Grundformen erzeugen lassen |
| | `generate_mesh`, `generate_material` | 3D-Objekt bzw. Material aus einer Beschreibung |
| | `search_asset`, `insert_asset` | Modelle, Bilder, Töne im Creator Store suchen und einfügen |
| Testen | `start_stop_play` | Spieltest starten und beenden |
| | `get_console_output` | Ausgabe lesen (Fehler, Warnungen, `print`) |
| | `screen_capture` | Bildschirmfoto der Ansicht |
| | `character_navigation` | Charakter zu einer Position oder Instanz laufen lassen |
| | `user_keyboard_input`, `user_mouse_input` | Tasten und Maus wie ein Spieler bedienen |
| Sichern | `save_place` | Place speichern |
| Nachschlagen | `http_get`, `skill` | Roblox-Dokumentation und Roblox-eigene Anleitungen |

## Arbeitsteilung mit Rojo

- **Code** entsteht als Dateien im Projekt. Rojo überträgt sie nach Studio.
- **Nicht** `multi_edit` auf Skripte anwenden, die Rojo verwaltet (alles unter `ServerScriptService.Server`, `ReplicatedStorage.Shared`, `StarterPlayerScripts.Client`): Rojo überschreibt die Änderung, und in den Dateien fehlt sie.
- **Welt, Licht, Modelle, Töne** entstehen in Studio über MCP und liegen in der Place-Datei.
- Läuft `rojo serve` nicht, sieht Studio alten Code. Bei unerklärlichem Verhalten zuerst mit `script_read` prüfen, ob der Code in Studio dem in der Datei entspricht.

## Die Testschleife

Nach jeder Code-Änderung, die das Verhalten betrifft:

1. `python scripts/check_projekt.py <projekt>` – erst wenn das sauber ist, lohnt ein Spieltest.
2. Welt-Vertrag prüfen: `assets/weltbau/vertrag_pruefen.luau` mit dem Vertrag des Genres über `execute_luau` (Bearbeitungsmodus).
3. `start_stop_play` (starten).
4. `get_console_output`: Steht dort ein Fehler oder eine Warnung mit `[Server]`, `[Client]`, `[Welt]`, `[Net]`, `[DataService]`, `[Admin]`? Zuerst das beheben.
5. Das Neue **wirklich ausprobieren**: hinlaufen (`character_navigation`), Tasten drücken, Admin-Befehle nutzen, um schnell in die richtige Lage zu kommen (`T`, Befehl, `Enter`).
6. `screen_capture`: Sieht es so aus wie gedacht? Ist die Oberfläche lesbar und nichts überlappt?
7. Zustand prüfen statt raten: `execute_luau` auf dem Server, z. B. Spielstand oder Attribute ausgeben.
8. `start_stop_play` (beenden). Fehler beheben, wiederholen.

Erst danach den Punkt in `PLAN.md` abhaken.

### Nützliche Prüf-Schnipsel für `execute_luau`

Auf dem **Server** während eines Spieltests:

```lua
-- Spielstand des ersten Spielers als Text
local Players = game:GetService("Players")
local DataService = require(game.ServerScriptService.Server.Services.DataService)
return game:GetService("HttpService"):JSONEncode(DataService:Get(Players:GetPlayers()[1]))
```

```lua
-- Admin-Befehl ohne Tastatur ausführen
local AdminService = require(game.ServerScriptService.Server.Services.AdminService)
local ok, message = AdminService:Execute(game:GetService("Players"):GetPlayers()[1], "fly an")
return tostring(ok) .. " " .. message
```

```lua
-- Welche Remotes gibt es?
local names = {}
for _, remote in game.ReplicatedStorage.Remotes:GetChildren() do table.insert(names, remote.Name) end
table.sort(names)
return table.concat(names, ", ")
```

Im **Bearbeitungsmodus**:

```lua
-- Alle Tags und wie oft sie vorkommen
local CollectionService = game:GetService("CollectionService")
local lines = {}
for _, tag in CollectionService:GetAllTags() do
	table.insert(lines, tag .. ": " .. #CollectionService:GetTagged(tag))
end
table.sort(lines)
return table.concat(lines, "\n")
```

## Was sich so nicht testen lässt

| Thema | Wie stattdessen |
|---|---|
| Mehrere Spieler gleichzeitig | Der Nutzer startet in Studio „Test → Clients und Server" mit 2 Spielern. Sag ihm genau, was er prüfen soll. |
| Echtes Speichern über Sitzungen | kurz `SaveInStudio = true`, Spieltest, beenden, erneut starten, danach zurückstellen |
| Echte Robux-Käufe | In Studio sind Käufe Testkäufe (kosten nichts); der Ablauf lässt sich so prüfen |
| Handy-Bedienung | Geräte-Emulator in Studio; der Nutzer schaut drauf. Bildschirmfotos zeigen zumindest die Anordnung |
| Gefühl (Tempo, Schwierigkeit, Spaß) | Der Nutzer spielt. Stell ihm gezielte Fragen („Fühlt sich der Rückstoß zu stark an?") |

Sei genau bei dem, was du meldest: „im Spieltest geprüft: X, Y" und „nicht prüfbar, bitte selbst testen: Z" getrennt nennen.

## Ohne MCP

Dann gilt: Code weiterbauen, `check_projekt.py` nutzen, und dem Nutzer eine konkrete Liste geben – welche Teile mit welchen Tags und Attributen er in Studio anlegen muss und was er im Spieltest prüfen soll. Bitte ihn, die Ausgabe (Fenster „Ausgabe" in Studio) hereinzukopieren, wenn etwas nicht klappt.
