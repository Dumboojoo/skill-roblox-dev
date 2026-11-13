## Phase 1 – Kern spielbar (Simulator)

- [ ] Beispielcode läuft: Klicken gibt Münzen, Upgrade kaufen, Ei öffnen, Pet ausrüsten, Rebirth
- [ ] Thema festgelegt: Was „sammelt" der Spieler eigentlich (statt neutraler Münzen)?
- [ ] Zahlen abgestimmt (`Config/Simulator.luau`, `Simulator/Formulas.luau`): erstes Upgrade nach 30 Sek., erstes Ei nach 2 bis 3 Min., erster Rebirth nach 30 bis 60 Min.
- [ ] Mindestens ein zweites Upgrade und ein Ei pro Zone
- [ ] Neues Ziel alle paar Minuten sichtbar (nächste Zone, nächstes Ei, Rebirth-Fortschritt)

## Phase 2 – Welt (Simulator)

- [ ] Startzone mit `Collectible`-Teilen (Attribut `Value`)
- [ ] Weitere Zonen hinter `ZoneGate`-Sperren (Attribut `Zone`), Sammelobjekte dort mit Attribut `Zone` und höherem `Value`
- [ ] `EggStand` je Zone (Attribut `Egg`)
- [ ] Jede Zone sieht deutlich anders aus (Farbe, Licht, Formen)