# Open World

Große, frei begehbare Welt: Gebiete entdecken, Wegpunkte für Schnellreise, Rohstoffe sammeln, Tag und Nacht, gespeicherte Position. Der Beispielcode ist das **Gerüst der Welt**; die Hauptbeschäftigung (Kämpfen, Bauen, Aufgaben) kommt aus einem zweiten Genre dazu.

## Dateien (`assets/genres/open-world/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/OpenWorld.luau` | Tageslänge, Rohstoffe, Belohnungen, **Welt-Vertrag** |
| `server/Services/OpenWorldService.luau` | Gebietserkennung, Entdecken, Wegpunkte, Schnellreise, Rohstoff-Knoten, Tag/Nacht, Position speichern |
| `client/Controllers/OpenWorldController.luau` | Gebiet und Uhr, Entdeckt-Banner, Rohstoff-Anzeige, Schnellreise-Menü (`M`) |
| `server/Admin/Commands/OpenWorld.luau` | `waypoints`, `region` |

## Welt-Vertrag

| Tag | Klasse | Attribute |
|---|---|---|
| `WorldSpawn` | BasePart | – |
| `Region` | BasePart | `RegionId`, `DisplayName` (unsichtbarer Kasten, `CanCollide` aus) |
| `Waypoint` | BasePart | `WaypointId`, `DisplayName` |
| `ResourceNode` | BasePart/Model | `Resource` (Schlüssel aus `Resources`) |

Gebiete dürfen ineinander liegen (Stadt im Königreich): das kleinste zählt. Der Server erkennt Gebiete per Positionsprüfung, nicht per `Touched`.

## Passende Ergänzungen

| Wunsch | Übernehmen aus |
|---|---|
| Gegner, Stufen, Quests | `rpg-nahkampf` (alle Services; `EnemySpawn`-Tags in der Welt) |
| Hunger, Herstellen, Bauen | `survival-crafting` (ersetzt die Rohstoff-Knoten hier durch `Harvestable`) |
| Figuren mit Dialog | Block `Npc` aus `adventure` (AdventureService) |
| Fahrzeuge | Fahrphysik aus `rennen-fahrzeuge` |
| Gegenstände | Modul `inventar` |

`OpenWorldService.RegionEntered` und `NightChanged` sind die Anknüpfpunkte (z. B. nachts stärkere Gegner, Musik je Gebiet).

## Streaming (bei großen Welten Pflicht)

Ohne Streaming lädt jedes Gerät die ganze Karte; Handys geben dann auf. Einstellen an `Workspace` in Studio:

- `StreamingEnabled = true`
- `StreamingMinRadius` (immer geladen, z. B. 128) und `StreamingTargetRadius` (wird nachgeladen, z. B. 512 bis 1024)
- Je Model `ModelStreamingMode`: **Atomic** für alles, was als Ganzes da sein muss (Häuser, Maschinen); **Persistent** nur für wenige Dinge, die jeder Client immer braucht.

Folgen für den Code (im Beispielcode berücksichtigt):
- Der **Server** sieht immer alles. Logik gehört dorthin.
- Auf dem **Client** existieren entfernte Teile nicht. Nie `Workspace.Welt.X` direkt ansprechen; `World.Observe` reagiert, sobald etwas geladen wird.
- Teleport an einen fernen Ort: Der Server versetzt den Charakter; bei Bedarf vorher `Player:RequestStreamAroundAsync(position)`.

## Was eine gute offene Welt ausmacht

- **Landmarken:** aus jedem Gebiet sieht man etwas Hohes und Besonderes, das neugierig macht und Orientierung gibt.
- **Dichte vor Größe:** lieber klein und voll als riesig und leer. Alle 20 bis 30 Sekunden Laufweg etwas Interessantes.
- **Jedes Gebiet hat eine eigene Identität** (Farbe, Form, Licht, Ton) und einen Grund, hinzugehen.
- **Entdecken wird belohnt** (Banner, Münzen, Wegpunkt).
- **Wege leiten**, ohne zu zwingen: Straßen, Lichter, Blickachsen.
- **Schnellreise** erst freischalten lassen: einmal hinlaufen, dann springen.

## Stolperfallen

- Position als drei Zahlen speichern (kein Vector3 im Spielstand).
- Gespeicherte Position nur beim ersten Erscheinen der Sitzung anwenden; nach dem Tod zum Startpunkt.
- Wird die Welt stark umgebaut, können gespeicherte Positionen im Boden liegen: `SavePosition` vorübergehend aus oder Mindesthöhe erzwingen.
- Rohstoff-Knoten sind für alle Spieler gemeinsam erschöpft (einfach). Pro Spieler getrennt = auf dem Client ausblenden und auf dem Server pro Spieler merken.
- `Lighting.ClockTime` setzt nur der Server.

## Erstprüfung in Studio

1. Welt: `WorldSpawn`, zwei `Region`-Kästen nebeneinander, je ein `Waypoint`, drei `ResourceNode`.
2. Spieltest: Gebiet in der Anzeige; ins zweite laufen → Banner „Entdeckt", Münzen.
3. Beide Wegpunkte aktivieren, `M`: Liste erscheint, Reise funktioniert, zweite Reise sofort danach wird abgelehnt (Abklingzeit).
4. Rohstoff sammeln: Zähler steigt, Knoten verschwindet und kommt wieder.
5. `time 20`: Uhr und `IsNight`. Mit `SaveInStudio = true`: verlassen, neu starten, gleiche Position.
