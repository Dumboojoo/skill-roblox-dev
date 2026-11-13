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
| Namens-Tests (`tests/Netz.spec.luau`, `tests/Spielstand.spec.luau`, `tests/Ton.spec.luau`) | mit absichtlichen Tippfehlern erprobt | 9 | laufen mit `check_projekt.py`; keine Prüfung in Studio nötig |

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

## Skripte (`scripts/`)

| Skript | Stand |
|---|---|
| `neues_spiel.py` | auf macOS ausgeführt: jedes Genre einzeln, mehrere Genre-Modul-Kombinationen und `--ergaenzen`; alle erzeugten Projekte bestehen `check_projekt.py`. Unter Windows noch nicht ausgeführt (nur Standardbibliothek, Pfade über `pathlib`) |
| `check_projekt.py` | auf macOS ausgeführt. Unter Windows noch nicht ausgeführt |
| `einrichtung_pruefen.py` | auf macOS ausgeführt (ohne installiertes Roblox Studio). Die Windows-Pfade für Studio, Rojo-Plugin und MCP sind nach der Roblox-Dokumentation eingetragen, aber nicht auf einem Windows-Rechner erprobt |

## Verlauf

| Datum | Was |
|---|---|
| 2026-11-13 | Skill erstellt. Alles statisch geprüft (Rojo 7.7.1, luau-lsp 1.70.1, selene, StyLua 2.6.0, lune 0.11.1). Kein Roblox Studio auf dem Erstellungsrechner, daher nichts gespielt. |
| 2026-11-14 | Durchsicht: Fehler in Admin-Effekten, Spielstand-Reset, Konsole, Ego-Shooter, Obby (Spawn-Schutz), Tower Defense (Wellen-Neustart), Runden (Sieg bei kaputtem Minispiel) und Rennen (Sprungtaste im Auto) behoben; Pass-Abfrage mit Wiederholung; Ton, Einstellungs-Fenster und Namens-Tests ergänzt. Weiterhin nichts in Studio gespielt. |
