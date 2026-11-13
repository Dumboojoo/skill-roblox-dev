## Phase 1 – Kern spielbar (RPG / Nahkampf)

- [ ] Beispielcode läuft: Schlagen mit Kombo, Ausweichrolle, Gegner verfolgen und greifen an, XP und Stufenaufstieg
- [ ] Quests: annehmen, Fortschritt zählt, Belohnung abholen
- [ ] Gegner, Quests und Kampfwerte in `Config/Rpg.luau` auf das Spiel abgestimmt
- [ ] Stufenkurve geprüft (`Rpg/Formulas.luau`): erste Stufe nach 2 Minuten, danach langsamer
- [ ] Wofür sind Münzen da? (Ausrüstung, Tränke → Modul `inventar` einplanen)
- [ ] Waffe sichtbar in der Hand (Modell an die rechte Hand schweißen)

## Phase 2 – Welt (RPG / Nahkampf)

- [ ] Startgebiet mit sicherem Bereich und den ersten `EnemySpawn`-Teilen (Attribut `Enemy`)
- [ ] Gebiete nach Schwierigkeit gestaffelt; stärkere Gegner weiter weg vom Start
- [ ] Wege und Landmarken, damit man sich ohne Karte zurechtfindet
- [ ] Kampf mit 2 Spielern getestet: Beide sehen Schläge und Schadenszahlen