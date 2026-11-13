# Tower Defense

Gegner laufen in Wellen einen Weg entlang, Spieler bauen Türme. Der Beispielcode ist ein vollständiges Koop-Spiel pro Server: Wellen, drei Turmarten mit Stufen, Geld, Sieg und Niederlage.

## Dateien (`assets/genres/tower-defense/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/TowerDefense.luau` | Türme (mit Stufen), Gegner, Wellen, Startgeld, Abstände, **Welt-Vertrag** |
| `shared/TowerDefense/PathMath.luau` | Weg aus Wegpunkten; Position nach Strecke; Abstand zum Weg |
| `server/Services/TowerDefenseService.luau` | Spielablauf, Gegner als Daten, Türme, Zielwahl, Schaden, Geld, Bau-Prüfung |
| `client/Controllers/TowerDefenseController.luau` | Darstellung von Gegnern und Türmen, Bau-Vorschau, Turm-Menü, Anzeige |
| `server/Admin/Commands/TowerDefense.luau` | `cash`, `nextwave`, `tdrestart` |

## Die Kernidee

Gegner sind auf dem Server **keine Modelle**, sondern Einträge `{ Typ, Leben, zurückgelegte Strecke }`. Ein Heartbeat rückt alle vor und lässt Türme schießen. Clients bekommen Ereignisse (erschienen, entfernt) und fünfmal pro Sekunde gebündelt die Strecken; sie stellen die Gegner selbst dar und laufen zwischen den Meldungen flüssig weiter. So bleiben auch 200 Gegner flüssig. Dieses Muster nicht durch Humanoid-Gegner ersetzen.

## Welt-Vertrag

| Tag | Klasse | Attribute |
|---|---|---|
| `PathPoint` | BasePart | `Order` (1, 2, 3 …): Wegpunkte; erster = Eingang, letzter = Basis |
| `TowerGround` | BasePart | – (Flächen, auf denen gebaut werden darf) |

Wegpunkte auf Bodenhöhe, unsichtbar. Den sichtbaren Weg als eigene Teile darunter bauen.

## Was ein gutes Tower Defense ausmacht

- **Entscheidungen statt Klicken:** Jeder Turm hat eine Rolle (Einzelziel, Fläche, Verlangsamen) und Gegner, gegen die er gut oder schlecht ist.
- **Die Karte stellt Fragen:** Kurven, Engstellen, Stellen, die zwei Wegstücke abdecken. Gute und schlechte Bauplätze.
- **Geld ist knapp:** Der Spieler kann sich nie alles leisten; Verbessern gegen Neubauen ist die Kernfrage.
- **Wellen erzählen:** neue Gegnerart einzeln vorstellen, dann mischen, alle paar Wellen ein Brocken oder Boss.
- Die ersten drei Wellen sind kaum zu verlieren; die letzte verlangt eine durchdachte Aufstellung.
- Reichweite beim Bauen und Auswählen anzeigen (macht der Controller).

## Erweitern

- **Turm/Gegner/Welle:** Tabelleneintrag in der Config.
- **Neuer Turm-Effekt** (Gift, Kette, Betäuben): Feld in `TowerLevel`, Auswertung in `shoot`.
- **Fliegende Gegner, zweiter Weg:** Feld am Gegnertyp bzw. mehrere Pfade (`PathMath.new` je Pfad).
- **Dauerhafter Fortschritt** (Türme freischalten): eigener DataSection; im Spiel selbst bleibt das Geld pro Partie.
- **Eigene Modelle:** `createEnemyVisual` / `createTowerVisual` im Controller.

## Stolperfallen

- Bau-Prüfung immer auf dem Server (Fläche, Abstand zum Weg und zu Türmen, Geld, Höchstzahl). Der Controller prüft nur für die Vorschaufarbe.
- Spät Beitretende brauchen den aktuellen Stand (`TD.RequestSync`).
- Bei Niederlage/Neustart laufende Wellen-Threads ungültig machen (`gameToken`).
- `Order` der Wegpunkte lückenlos und eindeutig.

## Erstprüfung in Studio

1. Welt: 5 `PathPoint`s mit Kurve, drei `TowerGround`-Flächen, Kamera mit Überblick.
2. Spieltest: Wartezeit läuft, „Welle starten" bzw. `nextwave`.
3. Turm wählen, Vorschau grün/rot, bauen; Bildschirmfoto: Gegner laufen, Lebensbalken, Schuss-Strahlen.
4. Turm anklicken: Verbessern, Zielwahl wechseln, Verkaufen (Geld stimmt).
5. `cash 5000`, mehrere Wellen: Ausgabe ohne Fehler. Alle Gegner durchlassen: Niederlage und Neustart.
