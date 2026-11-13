## Phase 1 – Kern spielbar (Horror / Story)

- [ ] Beispielcode läuft: Verfolger läuft Streife, entdeckt, jagt, verliert die Spur und sucht
- [ ] Verstecken in einem `HideSpot` funktioniert (und nicht, wenn er einen hineinlaufen sieht)
- [ ] Kapitel durchspielbar: Gegenstand aufheben, Tür mit Schlüssel öffnen, Zone erreichen
- [ ] Taschenlampe (Batterie) und Sprint (Ausdauer) fühlen sich knapp, aber fair an
- [ ] Eigene Ziel-Liste in `Config/Horror.luau` (Geschichte in 5 bis 10 Schritten)
- [ ] Geräusche eingetragen: Schritte des Verfolgers, Herzschlag, Türen (macht 80 % der Wirkung)

## Phase 2 – Welt (Horror / Story)

- [ ] Grundriss als Block-Welt: Rundwege statt Sackgassen, damit Flucht möglich ist
- [ ] `ChaserSpawn`, `PatrolPoint`s (Attribut `Order`), `HideSpot`s gesetzt
- [ ] `Pickup`, `Door`, `StoryZone`, `Note` passend zur Ziel-Liste gesetzt und getaggt
- [ ] Lighting dunkel gestellt (Ambient niedrig, Nebel, wenige warme Lichtinseln)
- [ ] Wegfindung geprüft: Der Verfolger kommt überall hin, wo Spieler hinkommen (Türbreiten!)