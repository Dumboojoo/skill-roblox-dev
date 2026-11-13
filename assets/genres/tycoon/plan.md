## Phase 1 – Kern spielbar (Tycoon)

- [ ] Beispielcode läuft: Grundstück übernehmen, Knopf kaufen, Tropfen fallen, Sammler füllt sich, Abholen zahlt aus
- [ ] Thema festgelegt (Was wird hergestellt? Fabrik, Restaurant, Mine …)
- [ ] Kauf-Reihenfolge in `Config/Tycoon.luau` geplant: 15 bis 30 Gegenstände, Preise steigen, alle paar Käufe etwas sichtbar Neues
- [ ] Neu beitreten baut das Gekaufte wieder auf; Verdienst während der Abwesenheit kommt an
- [ ] Ziel am Ende (letzter großer Kauf, Rebirth oder zweites Stockwerk)

## Phase 2 – Welt (Tycoon)

- [ ] Ein Grundstück KOMPLETT ausgebaut in Studio (Model mit Tag `TycoonPlot`, `Claim`, `CollectPad`)
- [ ] Alle kaufbaren Teile mit Tag `TycoonItem` und Attribut `Item`; Dropper haben ein Teil `Spout`
- [ ] Kaufknöpfe (`TycoonButton`, Attribut `Item`) dort, wo der Gegenstand entsteht
- [ ] Förderbänder (`Conveyor`), Sammler (`TycoonCollector`), Veredler (`TycoonUpgrader`) getaggt
- [ ] Grundstück dupliziert (so viele wie Spieler pro Server), Lobby in der Mitte