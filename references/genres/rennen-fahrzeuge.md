# Rennen / Fahrzeuge

Arcade-Autos ohne echte Räder (vier Raycast-Federn), Rennablauf mit Startaufstellung, Countdown, Checkpoints, Runden, Platzierung und Bestzeiten.

## Dateien (`assets/genres/rennen-fahrzeuge/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/Racing.luau` | Fahrverhalten (Tempo, Beschleunigung, Lenkung, Grip, Federung), Rennregeln, **Welt-Vertrag** |
| `server/Services/RaceService.luau` | Autos bauen und zuteilen, Rennphasen, Checkpoint-Auswertung mit Plausibilitätsprüfung, Platzierung, Ergebnis |
| `client/Controllers/RacingController.luau` | **Fahrphysik** des eigenen Autos, Tacho, Runde/Platz, Countdown, Ergebnisliste |
| `server/Admin/Commands/Racing.luau` | `raceskip`, `resetcar` |

## So fährt das Auto

Der Wagen ist ein Quader (`Chassis`) mit `VehicleSeat`. Der Client des Fahrers rechnet jeden Physikschritt:
1. **Federung:** vier Strahlen nach unten; je stärker eingedrückt, desto mehr Schub nach oben an dieser Ecke.
2. **Antrieb:** Geschwindigkeit entlang der Nase Richtung Wunschtempo ändern.
3. **Haftung:** seitliches Rutschen abbauen (`Grip`; wenig = Driften).
4. **Lenkung:** Drehgeschwindigkeit direkt setzen, abhängig vom Tempo.

Gas und Lenkung kommen vom `VehicleSeat` (`ThrottleFloat`, `SteerFloat`) – funktioniert dadurch mit Tastatur, Touch und Controller ohne eigenen Eingabe-Code.

Der Server gibt dem Fahrer den Netzwerk-Besitz am Wagen (nur so lenkt es ohne Verzögerung) und prüft dafür das Rennen: Checkpoints in Reihenfolge, Mindestzeit zwischen zwei Checkpoints.

## Welt-Vertrag

| Tag | Klasse | Attribute |
|---|---|---|
| `StartGrid` | BasePart | – (Vorderseite in Fahrtrichtung; so viele wie Spieler) |
| `RaceCheckpoint` | BasePart | `Order` (1 bis N; höchste = Ziellinie) |
| `LobbySpawn` | BasePart | – (optional) |

Checkpoints sind unsichtbare Kästen quer über die ganze Fahrbahn, hoch und tief genug, dass man sie nicht verfehlt. Eigenes Auto: `ServerStorage.Assets.Car` (PrimaryPart `Chassis`, enthält einen `VehicleSeat`; Zierteile masselos und ohne Kollision).

## Was ein gutes Rennspiel ausmacht

- **Fahrgefühl vor allem anderen.** Erst wenn das Auto auf einer leeren Fläche Spaß macht, eine Strecke bauen. Abstimmen über die Config: schaukelt → `Damping` hoch; liegt zu tief → `Stiffness` hoch; rutscht → `Grip` hoch.
- **Tempo spüren:** Sichtfeld weitet sich mit der Geschwindigkeit, Motor-Ton steigt in der Tonhöhe, Streifen/Staub am Rand.
- **Breite Strecken** (mind. 3 Autobreiten) mit Stellen zum Überholen; Banden ohne Kanten.
- **Runde 30 bis 60 Sekunden**, 2 bis 3 Runden.
- **Zurücksetzen** jederzeit möglich (eingebaut), damit ein Unfall nicht das Rennen beendet.
- Bestzeiten als Rangliste (Modul `bestenliste`, `Racing.BestTime`, aufsteigend, Scale 1000).

## Erweitern

- **Mehrere Fahrzeuge:** `Config.Car` zu einer Tabelle von Fahrzeugen machen; Wahl in der Lobby; Werte je Fahrzeug an den Client (Attribute am Auto).
- **Boost-Felder, Sprungschanzen:** getaggte Teile, die der Fahrer-Client auswertet (Geschwindigkeit setzen) und der Server über die Checkpoint-Zeiten begrenzt.
- **Freies Fahren** außerhalb der Rennen: Autos an Spawn-Punkten per ProximityPrompt.
- **Effekte:** Kamera, Ton, Partikel im `RacingController`.

## Stolperfallen

- Der Netzwerk-Besitz lässt sich erst setzen, wenn das Chassis **nicht** verankert ist (Reihenfolge im Start beachten).
- Die Fahrphysik läuft vor der Simulation (`RunService.PreSimulation`).
- Raycasts der Federung müssen das eigene Auto und den Charakter ausschließen.
- Reibung des Chassis sehr niedrig (`CustomPhysicalProperties`), sonst bleibt es an Banden hängen.
- Checkpoints nicht per `Touched`, sondern per Positionsprüfung auf dem Server (macht `RaceService`).
- Die Sprungtaste wirft einen Spieler normalerweise aus dem Sitz. Der Controller sperrt das Springen, solange man im eigenen Rennwagen sitzt.
- Abstimmung nur im echten Spieltest; die Startwerte in der Config sind ein Ausgangspunkt.

## Erstprüfung in Studio

1. Welt: große Fläche, Rundkurs aus vier Kästen `RaceCheckpoint` (`Order` 1 bis 4), zwei `StartGrid`.
2. Spieltest, `raceskip`: Auto erscheint, Charakter sitzt, Countdown, „LOS!".
3. Fahren (Tastatur über `user_keyboard_input`): Auto schwebt ruhig, beschleunigt, lenkt. Bildschirmfoto; Werte nachstellen, bis es ruhig liegt.
4. Checkpoints der Reihe nach: Rundenzähler steigt; einen auslassen: zählt nicht. `resetcar` stellt richtig hin.
5. Ziel nach drei Runden: Ergebnisliste, zurück in die Lobby, Bestzeit im Spielstand (`data show me Racing`).
