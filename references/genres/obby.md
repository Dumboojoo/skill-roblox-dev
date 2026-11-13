# Obby

Hindernislauf über Stufen mit Checkpoints. Der Beispielcode liefert Checkpoints mit Speichern, sechs Hindernis-Arten und eine Zeitmessung.

## Dateien (`assets/genres/obby/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/Obby.luau` | Einstellungen, Standardwerte der Hindernisse, **Welt-Vertrag** |
| `server/Services/ObbyService.luau` | Checkpoints, Neuerscheinen, tödliche Teile, Förderbänder, Zeitlauf |
| `client/Controllers/ObbyController.luau` | bewegte Hindernisse (flüssig, an der Serverzeit ausgerichtet), Anzeige Stufe/Zeit, Neustart-Knopf |
| `server/Admin/Commands/Obby.luau` | `stage <n> [spieler]` |
| `shared/Config/DataSections/Obby.luau` | Stufe, Abschlüsse, Bestzeit |

## Welt-Vertrag

| Tag | Klasse | Attribute |
|---|---|---|
| `Checkpoint` | BasePart | `Stage` (Zahl ab 0; 0 = Start, höchste = Ziel) |
| `KillPart` | BasePart | – |
| `Spinner` | BasePart | `Speed` (Grad/s), `Axis` ("X"/"Y"/"Z") |
| `MovingPlatform` | BasePart | `Offset` (Vector3), `Time` (s je Strecke) |
| `FadingPlatform` | BasePart | `Delay`, `Respawn` |
| `JumpPad` | BasePart | `Power` |
| `Conveyor` | BasePart | `Speed` (Richtung = Vorderseite) |

Mindestens zwei Checkpoints. Unter der ganzen Strecke ein großes, unsichtbares `KillPart`.

## Was einen guten Obby ausmacht

- **Schwierigkeit steigt in Stufen:** Jede neue Hindernis-Art erst allein und leicht, dann schwerer, dann kombiniert.
- **Checkpoints großzügig:** nach jeder Stufe. Frust entsteht durch verlorene Zeit, nicht durch schwere Sprünge.
- **Lesbar:** Tödliches hat immer dieselbe Farbe (rot/neon), Checkpoints immer dieselbe (grün), der Weg ist erkennbar.
- **Abwechslung alle 5 bis 10 Stufen:** neues Thema (Farbe, Licht) oder neue Mechanik.
- Sprungweiten im Spieltest prüfen: bequem bis 9 Studs, schwer ab 11.
- Ein Ziel mit Belohnungsmoment; Wiederspielwert über Bestzeit und Rangliste (Modul `bestenliste`, `Obby.BestTime`, aufsteigend, Scale 1000).

## Erweitern

- **Neues Hindernis:** Tag ausdenken, `World.Observe`-Block im `ObbyController` (bewegt/lokal) oder `ObbyService` (Regeln), Tag in `Config/Obby.luau` dokumentieren.
- **Stufen überspringen** gegen Spielwährung statt Robux, oder gar nicht (Fairness).
- **Verschiedene Welten:** Attribut `World` an den Checkpoints und je Welt eigene Stufenzählung.

## Stolperfallen

- Bewegte Plattformen tragen den Spieler nur, wenn sie zusätzlich zur CFrame-Änderung die passende Geschwindigkeit (`AssemblyLinearVelocity`/`AssemblyAngularVelocity`) bekommen. Das macht der Controller.
- Nach dem Erscheinen kurz warten, bevor der Charakter zum Checkpoint versetzt wird.
- `Stage`-Nummern lückenlos und eindeutig (prüft `vertrag_pruefen.luau`).
- Checkpoint-Teile groß genug und `CanTouch` an.
- Der Spawn-Schutz von Roblox (Kraftfeld nach dem Erscheinen) würde tödliche Teile kurz wirkungslos machen. Der `ObbyService` entfernt ihn deshalb nach jedem Erscheinen; der Gott-Modus der Konsole bleibt.

## Erstprüfung in Studio

1. Welt: 4 Checkpoints (`Stage` 0 bis 3), je ein Hindernis jeder Art, `KillPart` darunter.
2. Spieltest: über die Checkpoints laufen (`character_navigation`), Anzeige zählt hoch.
3. In ein `KillPart` laufen: Neuerscheinen am letzten Checkpoint. Sofort wieder hineinlaufen: stirbt erneut (kein Spawn-Schutz).
4. Bildschirmfoto mit Spinner und Plattform in Bewegung; kein Ruckeln in der Ausgabe.
5. `stage 3`, dann Ziel berühren: Abschluss-Meldung. Neustart-Knopf: Zeit läuft.
