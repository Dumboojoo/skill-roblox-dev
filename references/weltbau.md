# Welt bauen

Die Welt entsteht **direkt in Roblox Studio** über das MCP, nicht durch Bau-Skripte im Spielcode. Sie liegt in der Place-Datei, und der Nutzer kann jederzeit von Hand weiterbauen.

(Ausnahme: Dinge, die das Spiel zur Laufzeit erzeugen **muss** – Dungeon-Räume, Tropfen im Tycoon, Gegner, gebaute Basis-Teile. Das ist Spiellogik, nicht Weltbau.)

## Vorgehen

1. **Welt-Vertrag lesen** (Genre-Referenz bzw. Kopf der Config-Datei): Welche Tags und Attribute erwartet der Code?
2. **Erst Blockout, dann Schönheit.** Zuerst eine spielbare Welt aus schlichten Blöcken, in der die Mechanik funktioniert und die Maße stimmen. Erst wenn sich das Spiel darin gut anfühlt, Aussehen verbessern.
3. **In kleinen Schritten bauen** und nach jedem Schritt ein Bildschirmfoto ansehen. Ein Skript, das 300 Teile auf einmal setzt, ist schwer zu korrigieren.
4. **Vertrag prüfen** (`assets/weltbau/vertrag_pruefen.luau`), Spieltest, `save_place`.

## Werkzeuge

| Zweck | Mittel |
|---|---|
| Blöcke, Räume, Wände, Treppen, Spawns, Tags, Attribute | `execute_luau` im Bearbeitungsmodus mit den Helfern aus `assets/weltbau/blockout.luau` |
| Licht-Stimmung | `assets/weltbau/licht.luau` (Stilisiert, Tag, Abend, Nacht, Horror) |
| Einzelne Objekte mit Form (Baum, Fass, Kiste, Auto) | `generate_procedural_model` (aus Grundformen) oder `generate_mesh` (aus Beschreibung) |
| Fertige Modelle, Töne, Bilder | `search_asset` → `insert_asset` (vor dem Einfügen prüfen, ob es zum Stil passt; eingefügte Modelle auf mitgebrachte Skripte untersuchen und diese entfernen) |
| Oberflächen | `generate_material` oder eingebaute Materialien |
| Kontrolle | `screen_capture` (auch mit eigener Kamera-Position), `inspect_instance`, `search_game_tree` |

`blockout.luau` so benutzen: Helfer kopieren, darunter die Bau-Aufrufe in `Blockout.Run("Titel", function() … end)` setzen, als ein Skript ausführen. Jeder Lauf ist in Studio ein Rückgängig-Schritt.

## Ordnung in der Welt

```
Workspace
└── Welt
    ├── Lobby
    ├── Arena            (ein Ordner je Bereich)
    │   ├── Boden
    │   ├── Deckung
    │   └── Spawns
    └── …
```

- Sprechende Namen. Zusammengehöriges in Models/Folders.
- Alles, was der Code findet, über **Tags und Attribute**, nie über Namen oder Pfade.
- **Neu bauen:** `Blockout.Clear("Welt/Arena")` und neu erzeugen. Was das Attribut `Handarbeit = true` trägt, bleibt stehen. Setze dieses Attribut auf alles, was der Nutzer oder du von Hand verfeinert hast, und überschreibe solche Bereiche nie ungefragt.
- Feste Teile `Anchored = true`. Unsichtbare Helfer (Zonen, Wegpunkte, Checkpoints-Auslöser) `CanCollide = false`, `Transparency = 1`, in einem eigenen Ordner.

## Maße

| Was | Studs |
|---|---|
| Charakter | ca. 5 hoch, 2 breit |
| Sprung | ca. 7 hoch, 10 bis 12 weit (bei Standardwerten) |
| Laufen | 16 pro Sekunde |
| Tür | mind. 5 breit, 8 hoch |
| Gang | mind. 8 breit (mit Kampf oder mehreren Spielern 12+) |
| Stufe | höchstens 1 hoch (läuft man hoch), Rampe bis ca. 45° |
| Deckung (Shooter) | 4 hoch = geduckt, 6+ = volle Deckung |
| Auto-Fahrbahn | mind. 3 Autobreiten |

Sprungweiten immer im Spieltest prüfen, nie schätzen.

## Stil

- **Wenige Farben, bewusst gewählt.** Eine Palette aus 4 bis 6 Farben je Gebiet. Wichtiges (Ziel, Gefahr, Sammelbares) bekommt die auffälligste Farbe und sieht überall gleich aus: Gefahr immer rot/neon, Checkpoint immer grün usw.
- **Material sparsam:** `SmoothPlastic` als Grundlage, wenige Akzente. Kein Mix aus vielen Texturen.
- **Lesbarkeit vor Detail:** Der Spieler muss auf einen Blick sehen, wo er langgehen kann und wohin er soll. Wege heller als Umgebung, Ziele beleuchtet, Landmarken zur Orientierung.
- **Höhen und Blickachsen:** Flache, gleichförmige Flächen wirken tot. Ebenen, Rampen, ein hoher Punkt, von dem man das Gebiet sieht.
- **Licht macht den halben Eindruck.** Nach dem Blockout eine Stimmung aus `licht.luau` setzen und im Bildschirmfoto prüfen. `Lighting.Technology` stellt der Nutzer im Eigenschaften-Fenster ein.

## Leistung

- Teile zählen: einige Tausend Blöcke sind unkritisch; Zehntausende einzelne Kleinteile nicht. Große Flächen als ein großes Teil statt vieler kleiner.
- Wiederholtes als Model einmal bauen und duplizieren.
- `CastShadow = false` für Kleinkram und Unsichtbares.
- **Streaming bewusst entscheiden.** Mit `Workspace.StreamingEnabled` lädt jeder Client nur die Umgebung des Spielers. Bei neuen Places ist das meist schon eingeschaltet, also zuerst nachsehen (`inspect_instance` auf `Workspace`). Große Welten: an lassen und einstellen (siehe Genre `open-world`). Kleine Karten, auf denen jeder alles sehen muss (Arena, Tower Defense, Obby-Turm, Rennstrecke): ausschalten oder die wichtigen Models auf `ModelStreamingMode = Persistent` stellen, sonst fehlen dem Client entfernte Teile. Der Beispielcode sucht Welt-Teile auf dem Client über `World.Observe` und kommt mit beidem zurecht; eigener Client-Code darf nie voraussetzen, dass ein entferntes Teil schon da ist.
- Nach einem weiten Teleport bei eingeschaltetem Streaming vorher `player:RequestStreamAroundAsync(position)` aufrufen, sonst fällt der Spieler kurz ins Leere.
- Keine Skripte in Welt-Objekten. Verhalten kommt über Tags aus den Services.

## Übergabe an den Nutzer

Nach dem Bauen kurz sagen: was gebaut wurde und wo (Ordner), welche Tags gesetzt sind, was er gefahrlos umgestalten kann (alles, solange Tags und Attribute bleiben) und was er für Feinschliff auf `Handarbeit` setzen sollte.
