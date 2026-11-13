# Dungeon

Bei jedem Durchlauf neu zusammengesetzter Dungeon: Räume auf einem Raster, Kampfräume verriegeln sich, Schatzräume mit Truhen, Boss am Ende, Beute nach Seltenheit.

## Dateien (`assets/genres/dungeon/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/Dungeon.luau` | Raumgröße, Gegner, Raumbelegung, Beute-Tabelle, Angriff, Aufbau eigener Raum-Bausteine |
| `shared/Dungeon/Layout.luau` | **Grundriss-Generator** mit Seed (reines Luau, getestet) und gewichtete Auswahl |
| `server/Services/DungeonService.luau` | Räume aufstellen (eigene Bausteine oder Block-Räume), Gitter, Gegner-KI, Angriff, Beute, Durchlauf |
| `client/Controllers/DungeonController.luau` | Minikarte (deckt sich beim Erkunden auf), Angriff, Meldungen |
| `server/Admin/Commands/Dungeon.luau` | `newdungeon [seed]`, `loot [anzahl]` |
| `tests/Dungeon.spec.luau` | Tests: gleiche Seeds, Raumzahl, Türen passen, alles erreichbar, Boss am weitesten weg |

## So entsteht der Dungeon

1. `Layout.Generate(seed, anzahl)` liefert Zellen mit Rasterposition, Art (`Start`, `Combat`, `Treasure`, `Boss`) und Türen nach N/E/S/W. Jeder Raum ist garantiert erreichbar; der fernste wird Boss, jede zweite Sackgasse Schatzraum.
2. Der Service stellt für jede Zelle einen Raum auf: einen **eigenen Baustein**, falls vorhanden, sonst einen schlichten Block-Raum. Dadurch läuft das Spiel sofort und wird schöner, sobald Bausteine gebaut sind.
3. Betritt ein Spieler einen Kampfraum, schließen die Gitter und die Gegner erscheinen; nach dem Sieg öffnen sie.

Der Dungeon ist die eine Stelle, an der der Spielcode Welt erzeugt – weil sie bei jedem Durchlauf anders sein soll.

## Eigene Raum-Bausteine (Welt-Vertrag)

Unter `ServerStorage.Assets.DungeonRooms.<Art>` ein Model oder ein Folder mit mehreren Varianten:

| Teil | Bedingung |
|---|---|
| PrimaryPart | der Boden, genau `RoomSize` × `RoomSize`, mittig |
| `DoorN`, `DoorE`, `DoorS`, `DoorW` | Wandstück in der Türöffnung; wird zum Gitter, wo der Grundriss eine Tür vorsieht, sonst bleibt es Wand |
| Tag `MobSpawn` (BasePart) | Erscheinungspunkte (optional) |
| Tag `Chest` (BasePart) | Truhe im Schatzraum (optional) |

N zeigt nach -Z, E nach +X. Bausteine über MCP in Studio bauen und nach ServerStorage legen.

## Was einen guten Dungeon ausmacht

- **Jeder Durchlauf fühlt sich anders an:** mehrere Varianten je Raumart, wechselnde Gegnergruppen.
- **Kurze Durchläufe** (5 bis 15 Minuten) mit klarem Höhepunkt (Boss).
- **Beute, die man will:** Seltenheiten mit sichtbarem Unterschied; die Chance steht fest in der Config.
- **Der Boss ist ein Ereignis:** eigener Raum, eigene Angriffe mit Ansage, mehr als nur viel Leben.
- **Zusammenspiel:** Gegnermenge und Leben mit der Spielerzahl skalieren.
- **Dauerhafter Fortschritt zwischen Durchläufen** (Ausrüstung, Freischaltungen), sonst fehlt der Grund für den nächsten.

## Erweitern

- **Tieferer Kampf:** `CombatService`/`ProgressService` aus `rpg-nahkampf` oder das Fähigkeiten-System aus `battlegrounds` statt des einfachen Angriffs hier.
- **Beute als Gegenstände:** in `GiveLoot` `InventoryService:Give` aufrufen (Modul `inventar`).
- **Schwierigkeitsstufen:** Faktor auf Leben/Schaden und `RoomCount`.
- **Neue Raumarten** (Falle, Händler, Rätsel): in `Layout.Generate` vergeben und im Service behandeln; Test ergänzen.
- **Eigene Server pro Gruppe:** In einem Lobby-Place Gruppen bilden, dann `TeleportService:ReserveServer(placeId)` und `TeleportService:TeleportAsync(placeId, spieler, optionen)` mit `TeleportOptions.ReservedServerAccessCode`. Der Dungeon-Place ist ein zweiter Place derselben Erfahrung und enthält diesen Service unverändert. Teleports immer in `pcall`; Daten für den Zielserver über `TeleportOptions:SetTeleportData`.

## Stolperfallen

- Derselbe Seed muss denselben Dungeon ergeben: im Generator nur den eigenen Zufallsgenerator benutzen, nie `math.random`.
- Gitter erst schließen, wenn der Spieler ein Stück im Raum steht (`ENTER_MARGIN`), sonst wird er in der Tür eingeklemmt.
- Der Dungeon entsteht weit weg von der Lobby (`Config.Origin`).
- Beim Neuaufbau laufende Verzögerungen ungültig machen (`runToken`).
- Gegner gehören dem Server (`SetNetworkOwner(nil)`).

## Erstprüfung in Studio

1. Spieltest ohne jede Welt: Dungeon entsteht, Spieler steht im Startraum, Minikarte zeigt ein Feld.
2. In den nächsten Raum: Gitter schließen (Banner), Gegner erscheinen und greifen an (Bildschirmfoto).
3. Zuschlagen (Mausklick): Gegner verlieren Leben; mit `god an` alle besiegen → Gitter öffnen, Feld wird grün.
4. `newdungeon 1234` zweimal: beide Male derselbe Grundriss.
5. Schatzraum: Truhe gibt einmal Beute. Boss besiegen: Abschluss, Beute, nach 15 s neuer Dungeon.
