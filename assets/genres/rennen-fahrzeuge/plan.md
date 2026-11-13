## Phase 1 – Kern spielbar (Rennen / Fahrzeuge)

- [ ] Beispielcode läuft: Auto erscheint am Start, Countdown, fahren, Runden zählen, Ergebnisliste
- [ ] Fahrgefühl abgestimmt (`Config/Racing.luau`): liegt ruhig, lenkt direkt, driftet nur so viel wie gewollt
- [ ] Abkürzen getestet: ausgelassener Checkpoint zählt nicht; „Zurücksetzen" stellt den Wagen richtig hin
- [ ] Mit Touch und Controller gefahren
- [ ] Zwischen den Rennen gibt es etwas zu tun (Lobby, Bestzeiten, Auto-Farben)
- [ ] Motor- und Reifengeräusche (Tonhöhe an die Geschwindigkeit koppeln)

## Phase 2 – Welt (Rennen / Fahrzeuge)

- [ ] Strecke als Block-Welt: breite Fahrbahn (mind. 3 Autobreiten), Banden außen, keine Kanten zum Hängenbleiben
- [ ] `StartGrid`-Teile (Vorderseite in Fahrtrichtung), so viele wie Spieler pro Server
- [ ] `RaceCheckpoint`-Kästen in Reihenfolge (`Order`), höchste Order = Ziellinie; alle 150 bis 250 Studs einer
- [ ] Eine Runde dauert 30 bis 60 Sekunden; mindestens eine Stelle zum Überholen
- [ ] Mit 2 Spielern gefahren: Positionen stimmen, Zusammenstöße fühlen sich fair an