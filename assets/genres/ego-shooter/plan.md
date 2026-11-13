## Phase 1 – Kern spielbar (Ego-Shooter)

- [ ] Beispielcode läuft: Waffe mit Block-Armen sichtbar, Schießen, Nachladen, Wechsel mit 1/2
- [ ] Trefferprüfung getestet: Trainingspuppe (Model mit Humanoid) nimmt Schaden, durch Wände nicht
- [ ] Waffen in `Config/Weapons.luau` auf das Spiel abgestimmt (Schaden, Feuerrate, Streuung, Rückstoß)
- [ ] Ego-Ansicht abgestimmt: `HipOffset` je Waffe, Arm-Farben und Schulterpunkte in `Weapons.Arms`
- [ ] Spielmodus festgelegt und gebaut (z. B. Team-Deathmatch, Jeder gegen jeden, Runden)
- [ ] Erscheinen: Spawn-Schutz (ForceField) und sinnvolle Spawnpunkte je Team
- [ ] Geräusche eingetragen (`SOUNDS` im WeaponController)

## Phase 2 – Welt (Ego-Shooter)

- [ ] Arena als Block-Welt: Deckung alle 10 bis 15 Studs, mindestens 2 Wege zu jedem Punkt
- [ ] `SpawnLocation`s gesetzt (bei Teams mit TeamColor), keine Sichtlinie von Spawn zu Spawn
- [ ] Kartengrenzen geschlossen, keine Stellen zum Herausfallen
- [ ] 2 Spieler in Studio getestet: Leuchtspuren, Treffer, Kill-Anzeige bei beiden richtig