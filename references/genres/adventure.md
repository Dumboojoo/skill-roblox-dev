# Adventure

Ein Hub und mehrere Level, die nacheinander freigeschaltet werden. In jedem Level: Weg zum Ziel finden, Rätsel mit Schaltern lösen, versteckte Edelsteine sammeln, mit Figuren sprechen. Allein oder zusammen spielbar.

## Dateien (`assets/genres/adventure/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/Adventure.luau` | Level-Liste (Reihenfolge = Freischaltung), Dialoge, Belohnungen, **Welt-Vertrag** inkl. Rätsel-Baukasten |
| `server/Services/AdventureService.luau` | Level betreten/abschließen, Freischaltung, Checkpoints, tödliche Flächen, Edelsteine, Dialoge mit Figuren |
| `server/Services/PuzzleService.luau` | **Rätsel-Baukasten:** Schalter und Empfänger über Kanäle |
| `client/Controllers/AdventureController.luau` | Level-Auswahl im Hub, Level-Leiste, Dialogfenster, Edelsteine lokal ausblenden, Abschluss-Banner |
| `server/Admin/Commands/Adventure.luau` | `level <id>`, `hub`, `puzzlereset <kanal>` |

## Welt-Vertrag

| Tag | Klasse | Attribute |
|---|---|---|
| `HubSpawn` | BasePart | – |
| `LevelStart`, `LevelGoal` | BasePart | `Level` (Id aus der Level-Liste) |
| `AdventureCheckpoint` | BasePart | – |
| `Hazard` | BasePart | – (tödlich) |
| `Gem` | BasePart | `Level`, `GemId` (im Level eindeutig) |
| `Npc` | BasePart/Model | `Dialog` (Schlüssel aus `Dialogs`), `DisplayName` |

### Rätsel-Baukasten (ohne Code, nur Tags und Attribute)

| Tag | Attribute | Verhalten |
|---|---|---|
| `Activator` | `Channel` (Text), `Kind` | `Lever`: per Interaktion an/aus · `Plate`: an, solange jemand darauf steht · `Button`: bleibt an |
| `Receiver` | `Channel`, `Action`, optional `Needs` | `Open`: fährt nach oben weg · `Appear`: wird sichtbar und fest · `Disappear`: verschwindet |

Ein Empfänger reagiert, wenn genug Schalter seines Kanals an sind (`Needs`, sonst alle). Beispiele:
- Hebel + Tor (`Open`) auf Kanal „Tor1".
- Zwei Druckplatten + Brücke (`Appear`) = Koop-Rätsel.
- Drei Knöpfe im Level verteilt + Tor mit `Needs = 3` = Suchaufgabe.
- Platte + Barriere (`Disappear`) mit knapper Laufstrecke = Zeit-Rätsel.

## Was ein gutes Adventure ausmacht

- **Jedes Level führt eine Idee ein**, übt sie und dreht sie am Ende einmal um. Nicht fünf Ideen auf einmal.
- **Der Weg ist erkennbar, die Lösung nicht.** Der Spieler sieht das Tor, bevor er den Hebel findet.
- **Rätsel sind gerecht:** Alles Nötige ist im Level sichtbar; keine Lösung verlangt Raten.
- **Sammelobjekte belohnen Neugier:** einer am Weg, einer abseits, einer wirklich versteckt.
- **Die Welt erzählt:** Figuren mit zwei, drei Sätzen statt Textwänden; die Umgebung zeigt, was passiert ist.
- **Checkpoints vor jeder schweren Stelle.**
- **Koop:** Rätsel, die zwei brauchen, klar als solche erkennbar machen oder eine Lösung für Einzelspieler vorsehen.

## Erweitern

- **Level:** Eintrag in `Levels`, Welt mit `LevelStart`/`LevelGoal` bauen.
- **Neuer Schalter** (Zeitschalter, Schlüssel einsetzen, Reihenfolge): Fall in `observeActivator`, ruft `setActive` auf.
- **Neue Reaktion** (Plattform fährt, Licht geht an, Gegner erscheint): Fall in `applyReceiver`, oder von außen an `PuzzleService.ChannelChanged` hängen.
- **Gegner und Boss:** Kampf aus `rpg-nahkampf`; `EnemyService.Killed` kann einen Kanal schalten (Tor öffnet nach dem Sieg).
- **Sterne/Bestzeit je Level:** Felder im Spielstand, Auswertung in `completeLevel`.
- **Kamerafahrt zum Level-Start:** Client setzt `CameraType = Scriptable` und fährt von einem Teil „IntroCamera" zum Spieler.
- **Verzweigte Dialoge:** Zeilen als Tabellen mit Antworten; Auswahl an den Server melden, der die Folge prüft.

## Stolperfallen

- Level-Fortschritt und Checkpoint gelten pro Sitzung; gespeichert werden nur abgeschlossene Level und Edelsteine.
- Der Rätsel-Zustand ist für alle gemeinsam. Für Solo-Level, in denen jeder seinen eigenen Zustand braucht, je Spieler eigene Instanzen nötig (größerer Umbau).
- Druckplatten werden per regelmäßiger Bereichsprüfung erkannt, nicht per `Touched` (das flackert bei stehenden Figuren).
- `GemId` je Level eindeutig; Edelsteine sind `CanCollide = false`, `CanTouch = true`.
- Ein Level ohne `LevelStart` meldet „noch nicht gebaut".

## Erstprüfung in Studio

1. Welt: Hub mit `HubSpawn` und einer Figur (`Npc`, `Dialog = "Guide"`); Level `Forest` mit Start, Ziel, einem Checkpoint, einer `Hazard`-Fläche, drei `Gem`, Hebel + Tor, Platte + Brücke.
2. Spieltest: Knopf „Level", Liste zeigt Level 1 offen, die anderen gesperrt. Mit der Figur sprechen (Dialog blättert).
3. Level betreten; Hebel umlegen → Tor fährt hoch; auf die Platte → Brücke erscheint (Bildschirmfotos).
4. Edelstein einsammeln: verschwindet, Zähler in der Leiste. In die `Hazard`: zurück am Checkpoint.
5. Ziel: Banner, zurück im Hub, Level 2 offen. `level Cave`, `hub`, `puzzlereset Tor1` funktionieren.
