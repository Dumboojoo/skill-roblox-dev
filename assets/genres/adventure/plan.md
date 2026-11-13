## Phase 1 – Kern spielbar (Adventure)

- [ ] Beispielcode läuft: Level im Hub wählen, Ziel erreichen, zurück im Hub ist das nächste Level offen
- [ ] Rätsel-Baukasten getestet: Hebel, Druckplatte, Knopf mit Tor (`Open`), Brücke (`Appear`), Barriere (`Disappear`)
- [ ] Checkpoints und tödliche Flächen (`Hazard`) funktionieren; Neuerscheinen am letzten Checkpoint
- [ ] Edelsteine: einsammeln, bleiben nach Neubeitritt gesammelt, Zähler stimmt
- [ ] Geschichte in 3 bis 5 Sätzen und Level-Liste in `Config/Adventure.luau` festgelegt
- [ ] Jedes Level führt EINE neue Idee ein (neuer Schalter-Typ, neue Gefahr, neue Figur)

## Phase 2 – Welt (Adventure)

- [ ] Hub mit `HubSpawn` und einer Figur (`Npc`), die das Spiel erklärt
- [ ] Level 1 als Block-Welt: `LevelStart`, `LevelGoal`, 2 bis 3 `AdventureCheckpoint`s, ein einfaches Rätsel
- [ ] 3 Edelsteine je Level (`Gem`, Attribute `Level` und `GemId`): einer am Weg, einer abseits, einer versteckt
- [ ] Weitere Level gebaut; jedes mit eigenem Aussehen und eigener Stimmung
- [ ] Jedes Level allein UND zu zweit durchgespielt (Koop-Rätsel müssen auch allein lösbar sein oder klar als Koop erkennbar)