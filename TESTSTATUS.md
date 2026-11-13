# Teststatus

Diese Datei sagt ehrlich, wie gut jeder Baustein des Skills geprüft ist. Claude liest hier nur die Zeile des Bausteins, mit dem gerade gearbeitet wird.

## Die zwei Stufen

| Stufe | Bedeutung |
|---|---|
| **statisch geprüft** | Der Code baut mit Rojo, hat keine Typfehler (luau-lsp, strict), keine Stilfehler (selene, StyLua), hält die Hausregeln ein, und die Tests der reinen Logik bestehen. Er ist aber **noch nie in Roblox Studio gelaufen**. |
| **in Studio gespielt** | Zusätzlich wurde die Erstprüfung in einem echten Spieltest durchgeführt und bestanden. |

Statisch geprüft heißt: Tippfehler, falsche Typen und kaputte Logik in den Formeln sind ausgeschlossen. **Nicht** ausgeschlossen ist alles, was erst im laufenden Spiel sichtbar wird: Physik (Auto, Fliegen, Rückstoß), Aussehen und Platzierung der Oberfläche, Zeitabläufe, das Zusammenspiel mit der gebauten Welt und Eigenheiten der Roblox-Dienste. Rechne beim ersten Einsatz eines Bausteins mit Nacharbeit.

## So gehst du mit einem ungespielten Baustein um

1. Welt nach dem Welt-Vertrag der Genre-Referenz bauen und `assets/weltbau/vertrag_pruefen.luau` ausführen.
2. Die **Erstprüfung** des Bausteins (Spalte rechts) Schritt für Schritt über das Studio-MCP durchführen: Spieltest starten, Ausgabe lesen, Bildschirmfoto ansehen, Befehle in der Konsole (Taste T) ausführen.
3. Fehler im Spielprojekt beheben und als erledigt oder unter „Bekannte Probleme" in dessen `PLAN.md` eintragen.
4. Pflegt der Nutzer den Skill selbst: dieselbe Korrektur im Skill-Ordner nachziehen und hier die Stufe auf „in Studio gespielt" setzen, mit Datum.

Sag dem Nutzer offen, wenn ein Baustein zum ersten Mal läuft. Behaupte nie, etwas sei getestet, das nur statisch geprüft ist.

## Grundprojekt (`assets/basis/`)

| Baustein | Stufe | Tests | Erstprüfung |
|---|---|---|---|
| Laden der Services und Controller, `Net` | statisch geprüft | – | Spieltest starten: Ausgabe ohne rote Fehler; nach **T** steht in der Konsole „Admin-Konsole bereit" |
| Admin-Konsole (Taste T) | statisch geprüft | 14 (Befehls-Parser) | **T** öffnet die Zeile; `help` listet Befehle; Tab vervollständigt; Pfeil hoch holt den letzten Befehl; `fly` (WASD, Leertaste, Shift), `noclip`, `god` (danach `kill` wirkungslos), `invisible` (Bildschirmfoto: Figur weg), `speed 50`, `time 0`; ein Klick neben die Zeile schließt sie. Rechte: `GameConfig.Admin.StudioIsAdmin` kurz auf `false` stellen und mit zwei Testspielern prüfen, dass der Server Befehle von Spielern ohne Rechte ablehnt |
| Spielstand (`DataService`, Migrationen) | statisch geprüft | 11 (Pfade, Migrationen) | `data show me` zeigt die Vorlage; `data set me <pfad> <wert>` ändert einen Wert und der Client sieht ihn sofort. Dann in `GameConfig.Data.SaveInStudio = true` und API-Dienste in den Spieleinstellungen an: Wert ändern, Spieltest beenden, neu starten → Wert ist noch da. Danach wieder auf `false` |
| UI-Baukasten (`Kit`), Meldungen | statisch geprüft | – | `announce Hallo` zeigt die Meldung; Bildschirmfoto: Schrift lesbar, nichts unter der Roblox-Leiste oben |
| Ton (`SoundController`, `Config/Sounds`) | statisch geprüft; alle Ids sind leer | – | Über `search_asset` Töne für `Click`, `Success`, `Error` suchen und eintragen. Spieltest: Knopf klickt hörbar, `announce Hallo` hat einen Ton, ein Musikstück in `Sounds.Music` läuft und blendet weich ein. In der Ausgabe keine Meldung über fehlgeschlagenes Laden eines Tons |
| Einstellungen (`SettingsController`, `SettingsService`) | statisch geprüft | – | Knopf „Menü" am linken Rand und Taste P öffnen das Fenster; `-`/`+` ändern die Prozentzahl und die Lautstärke hörbar; `data show me Settings` zeigt den neuen Wert. Im Ego-Shooter: Mit offenem Fenster ist die Maus frei. Bildschirmfoto: Knopf verdeckt keine Anzeige des Genres |
| Effekte (`EffectController`, `Config/Effects`, `Config/AssetIds`) | statisch geprüft; alle Bild-Nummern sind leer | 3 (Namen, Schichten, Nummern) | Spieltest in einem Kampf-Genre: Treffer zeigt Partikel (zuerst das Standard-Partikel von Roblox). In der Ausgabe von Studio keine Warnung „[Effekt]". Dann ein Bild hochladen, in `AssetIds` eintragen und mit `assets/weltbau/effekt_vorschau.luau` ansehen: Bildfolge läuft einmal durch, keine viereckige Kante |
| Figuren-Bewegung (`RigAnimationController`, `shared/Util/RigMotion`) | Rechnung getestet; Controller nur statisch geprüft, **noch nie mit einer echten Figur gelaufen** | 9 (Gangarten, Gelenk-Richtungen) | Eine Figur mit `rig_bauen.luau` bauen (siehe unten), Tag `AnimatedRig`. Spieltest: Im Stand atmet sie und wedelt, beim Laufen schwingen Beine und Arme gegengleich **in Laufrichtung** (nicht seitlich, nicht rückwärts), Knie beugen nach hinten; `JawOpen = 1` öffnet das Maul nach unten. Stimmt eine Richtung nicht, liegt es an den Gelenk-Achsen (Kopf von `RigMotion.luau`) |
| Namens-Tests (`tests/Netz.spec.luau`, `tests/Spielstand.spec.luau`, `tests/Ton.spec.luau`, `tests/Effekt.spec.luau`) | mit absichtlichen Tippfehlern erprobt | 12 | laufen mit `check_projekt.py`; keine Prüfung in Studio nötig |

## Genres (`assets/genres/`)

Die Erstprüfung steht jeweils am Ende der Genre-Referenz im Abschnitt „Erstprüfung in Studio".

| Genre | Stufe | Tests der Logik | Erstprüfung |
|---|---|---|---|
| `ego-shooter` | statisch geprüft | – | `references/genres/ego-shooter.md` |
| `obby` | statisch geprüft | – | `references/genres/obby.md` |
| `tower-defense` | statisch geprüft | – | `references/genres/tower-defense.md` |
| `simulator` | statisch geprüft | 6 (Formeln) | `references/genres/simulator.md` |
| `tycoon` | statisch geprüft | – | `references/genres/tycoon.md` |
| `runden-minispiele` | statisch geprüft | – | `references/genres/runden-minispiele.md` |
| `rpg-nahkampf` | statisch geprüft | 5 (Formeln) | `references/genres/rpg-nahkampf.md` |
| `horror-story` | statisch geprüft | – | `references/genres/horror-story.md` |
| `rennen-fahrzeuge` | statisch geprüft | – | `references/genres/rennen-fahrzeuge.md` |
| `open-world` | statisch geprüft | – | `references/genres/open-world.md` |
| `dungeon` | statisch geprüft | 7 (Raum-Erzeugung, Beute) | `references/genres/dungeon.md` |
| `survival-crafting` | statisch geprüft | 5 (Rezepte) | `references/genres/survival-crafting.md` |
| `battlegrounds` | statisch geprüft | 3 (Kampf-Rechnung) | `references/genres/battlegrounds.md` |
| `adventure` | statisch geprüft | – | `references/genres/adventure.md` |

Am ehesten Nacharbeit brauchen die Teile, die stark von Physik und Gefühl leben: das Auto in `rennen-fahrzeuge` (Federung, Lenkung), die Block-Arme und der Rückstoß in `ego-shooter` (Position vor der Kamera), das Fliegen der Admin-Konsole und die Wegfindung des Verfolgers in `horror-story`. Die Zahlen dafür stehen in den Config-Tabellen und lassen sich ohne Umbau abstimmen.

## Module (`assets/module/`)

| Modul | Stufe | Tests der Logik | Erstprüfung |
|---|---|---|---|
| `inventar` | statisch geprüft | 7 (stapeln, Plätze, entfernen) | `references/module.md`, Abschnitt Inventar |
| `bestenliste` | statisch geprüft | – | `references/module.md`, Abschnitt Bestenliste |
| `monetarisierung` | statisch geprüft | 7 (tägliche Belohnung) | Pass und Produkt im Creator Hub anlegen, Ids in `Config/Products.luau` eintragen. Spieltest: Shop öffnen, Testkauf eines Produkts → genau eine Gutschrift (`data show me`); Kauffenster abbrechen → nichts gutgeschrieben; mit `SaveInStudio = true` neu beitreten → Gutschrift und Pass bleiben; tägliche Belohnung lässt sich nur einmal abholen. Checkliste: `references/monetarisierung.md`, Abschnitt 8 |

## Weltbau-Helfer (`assets/weltbau/`)

| Datei | Stufe | Erstprüfung |
|---|---|---|
| `blockout.luau`, `licht.luau`, `vertrag_pruefen.luau` | statisch geprüft (Typen) | Im Bearbeitungsmodus über `execute_luau` einen Boden und einen Raum bauen, ein Licht-Preset setzen, Bildschirmfoto ansehen; `vertrag_pruefen.luau` meldet fehlende Tags verständlich |
| `rig_bauen.luau`, `modell_einbauen.luau`, `effekt_vorschau.luau` | statisch geprüft (Typen); **noch nie in Studio gelaufen** | siehe nächster Abschnitt |

## Eigene Modelle, Texturen, Effekte

Hier gibt es eine dritte Stufe: **in Blender gelaufen** heißt, das Skript lief in Blender 4.5.16 ohne Fenster auf einem Mac, und die erzeugten Bilder und Dateien wurden angesehen. Die Kette dahinter (Verbindung zu Claude, Hochladen, Einbau in Studio) ist damit **nicht** geprüft.

| Baustein | Stufe | Erstprüfung |
|---|---|---|
| `scripts/effekt_textur.py` | ausgeführt (macOS), alle 18 Formen angesehen | unter Windows einmal `--liste` und eine Form mit `--vorschau` erzeugen und ansehen |
| `assets/kreativ/blender/rbx_base.py`, `rbx_rig.py`, `rbx_export.py`, `beispiel_monster.py` | in Blender gelaufen: Monster aus 17 Teilen gebaut, Vorschau und Gelenk-Probe angesehen, Prüfung mit absichtlichen Fehlern erprobt, `.glb`, `.fbx` und Begleitzettel geschrieben | Über die Blender-Verbindung `beispiel_monster.build()` ausführen, Bild der 3D-Ansicht ansehen, exportieren |
| `rbx_texture.py` | in Blender gelaufen: gemeinsames Abwickeln, Farbe mit Schattierung, Normal-, Rauheits- und Schatten-Karte; Ergebnis am Monster angesehen | am ersten echten Modell: Bild ansehen, in Studio prüfen, ob die Textur richtig sitzt |
| `rbx_vfx.py`, `beispiel_effekt.py` | in Blender gelaufen: Einzelbild, Bildfolge 4×4 und Blitz gerendert und angesehen | ein Bild hochladen und mit `effekt_vorschau.luau` in Studio ansehen |
| Blender-Verbindung (Community `blender-mcp`, ersatzweise die offizielle) | **nicht erprobt**; Einrichtung nach den Projektbeschreibungen | `references/kreativ-einrichtung.md`, Abschnitt 1: Würfel bauen, Bild der Ansicht holen. Prüfen, wie die Werkzeuge wirklich heißen und ob `import rbx_base` nach dem Setzen des Pfads klappt |
| PhotoCraft (`storytold/photocraft`, eingebaute Verbindung) | **nicht erprobt**; Einrichtung, Werkzeuge und die genannten Befehle stammen aus der Dokumentation des Projekts (Version 0.23.1), nichts davon ist gelaufen. Wie man ein Vieleck aus Punkten füllt, ist dort nicht beschrieben | `kreativ-einrichtung.md`, Abschnitt 2, „Erster Test". Dann mit `command_list` die Befehle für Vieleck/Lasso und Füllen suchen und in `effekte.md` (Weg 3) und `kreativ-einrichtung.md` nachtragen |
| Effekte in Schichten (Ablauf aus dem Video von YorusDevs, Feld `Front`) | Ablauf nur beschrieben; `Front` statisch geprüft | Einen Hieb in vier Schichten zeichnen, hochladen, als Effekt eintragen; mit `effekt_vorschau.luau` prüfen, dass die Schichten deckungsgleich liegen und die Reihenfolge stimmt (Kern vorn) |
| `scripts/effekt_textur.py --pruefen` | ausgeführt (macOS) an eigenen Bildern: findet Rand-Berührung, fehlende Durchsicht, farbige Bilder; alle 18 Formen des Skripts und die Blender-Beispiele bestehen | an den ersten PhotoCraft-Bildern ausprobieren |
| Hochladen (`store_image`/`upload_image`, Modell über `rbx-import-asset`) | **nicht erprobt** | `kreativ-einrichtung.md`, Abschnitt 3. Erst ein Effekt-Bild, dann `Monster.glb` |
| Einbau: `rig_bauen.luau` | statisch geprüft; **nie gelaufen** | Monster importieren, Zettel einfügen, ausführen. Der Bericht muss 17 Teile, 17 Gelenke, 3 Andockpunkte und 0 Hinweise nennen. Bildschirmfoto: aufrecht, richtige Größe (7,4 Studs), Farben stimmen. `Mode = "probe"`: jedes Glied dreht um sein Gelenk. Dann als `ServerStorage.Assets.Enemies.<Schlüssel>` im RPG spawnen: steht auf dem Boden, läuft, nimmt Schaden |
| Einbau: `modell_einbauen.luau` | statisch geprüft; **nie gelaufen** | Eine Waffe (ein Teil mit `Grip` und `Muzzle`) einbauen: Größe stimmt, Andockpunkte sitzen an Griff und Mündung, Vorderseite zeigt nach −Z (sonst `MeshTurn = 180`) |
| `effekt_vorschau.luau` | statisch geprüft; **nie gelaufen** | ausführen, Bildschirmfoto: Partikel laufen vor dunkler Wand neben der Vergleichsfigur |

**Offene Fragen, die erst der erste Lauf in Studio beantwortet** (Ergebnis hier und in den Helfern nachtragen):

1. Wie benennt der Roblox-Import die Teile eines `.glb` mit mehreren Objekten? `rig_bauen.luau` sucht jedes Teil am Objektnamen aus Blender und listet bei einem Fehlschlag die vorhandenen Namen auf.
2. In welcher Größe und Drehung kommt das Modell an? Die Helfer messen das selbst aus (Abstände der Teile, 24 mögliche Drehungen) und sollten damit zurechtkommen.
3. Liegt die Mitte eines importierten Teils in der Mitte seines Umrisses? Darauf beruht das Ausmessen. Wenn nicht, meldet der Bericht Teile „neben dem erwarteten Platz".
4. Bewegt eine Änderung von `Motor6D.C0` im Bearbeitungsmodus die Teile sichtbar (Gelenk-Probe)? Wenn nicht: Probe im Spieltest über das Attribut `Strength` beurteilen.
5. Kommt eine im `.glb` eingebettete Textur beim Import mit, oder muss das PNG einzeln hochgeladen werden?
6. Lässt sich `CollisionFidelity` über `execute_luau` setzen (`modell_einbauen`, `Collision = "Teile"`)? Sonst meldet der Bericht es je Teil.

## Skripte (`scripts/`)

| Skript | Stand |
|---|---|
| `neues_spiel.py` | auf macOS ausgeführt: jedes Genre einzeln, mehrere Genre-Modul-Kombinationen und `--ergaenzen`; alle erzeugten Projekte bestehen `check_projekt.py`. Unter Windows noch nicht ausgeführt (nur Standardbibliothek, Pfade über `pathlib`) |
| `check_projekt.py` | auf macOS ausgeführt. Unter Windows noch nicht ausgeführt |
| `einrichtung_pruefen.py` | auf macOS ausgeführt (ohne installiertes Roblox Studio). Die Windows-Pfade für Studio, Rojo-Plugin, MCP und Blender sind nach den Dokumentationen eingetragen, aber nicht auf einem Windows-Rechner erprobt |
| `effekt_textur.py` | auf macOS ausgeführt, alle Formen und Bildfolgen angesehen. Unter Windows noch nicht ausgeführt (nur Standardbibliothek) |

## Verlauf

| Datum | Was |
|---|---|
| 2026-11-13 | Skill erstellt. Alles statisch geprüft (Rojo 7.7.1, luau-lsp 1.70.1, selene, StyLua 2.6.0, lune 0.11.1). Kein Roblox Studio auf dem Erstellungsrechner, daher nichts gespielt. |
| 2026-11-13 | Durchsicht: Fehler in Admin-Effekten, Spielstand-Reset, Konsole, Ego-Shooter, Obby (Spawn-Schutz), Tower Defense (Wellen-Neustart), Runden (Sieg bei kaputtem Minispiel) und Rennen (Sprungtaste im Auto) behoben; Pass-Abfrage mit Wiederholung; Ton, Einstellungs-Fenster und Namens-Tests ergänzt. Weiterhin nichts in Studio gespielt. |
| 2026-11-13 | Erweiterung um Blender, PhotoCraft und Effekte: Zeichen-Skript für Effekt-Bilder, Effekt-Baustein, Blender-Helfer (Modelle, Figuren aus Einzelteilen, Texturen, Effekt-Bilder), Bewegungs-Baustein für Figuren, Studio-Helfer für Einbau und Gelenke. Blender-Helfer liefen in Blender 4.5.16 ohne Fenster; Verbindungen, Hochladen und alles in Studio sind nicht erprobt. |
| 2026-11-13 | PhotoCraft berichtigt: Es ist das freie Programm `storytold/photocraft` mit eingebauter Verbindung (Windows, Mac, Linux), das Formen zeichnen kann; die frühere Beschreibung (nur Windows, Zusatzprojekt, kein Zeichnen) war falsch. Arbeitsablauf für Effekte in weißen Schichten und Bildfolgen ergänzt, Bild-Prüfer (`--pruefen`), Reihenfolge der Schichten (`Front`). Der Prüfer fand eine Rand-Berührung im Blender-Beispiel; behoben. |
