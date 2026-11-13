## Phase 1 – Kern spielbar (Runden / Minispiele)

- [ ] Beispielcode läuft: Pause, Abstimmung, Runde, Ergebnis, zurück in die Lobby
- [ ] Beide Beispiel-Minispiele gespielt (HotPotato, RisingLava)
- [ ] 3 bis 5 eigene Minispiele als Dateien in `server/Minigames` (jeweils unter 2 Minuten, in 5 Sekunden verstanden)
- [ ] Ausgeschiedene können zuschauen; niemand wartet länger als eine Runde
- [ ] `Config/Rounds.luau`: `MinPlayers` für die Veröffentlichung auf 2 gestellt
- [ ] Wofür gibt man die Münzen aus? (Kosmetik in der Lobby, Spuren, Titel)

## Phase 2 – Welt (Runden / Minispiele)

- [ ] Lobby mit `LobbySpawn`-Teilen und etwas zu tun während der Wartezeit
- [ ] Je Minispiel eine Map (`MinigameMap`, Attribut `Minigame`) mit `MinigameSpawn`-Teilen
- [ ] Maps liegen weit genug auseinander oder sind voneinander abgeschirmt
- [ ] Jede Map einzeln mit `forcegame <name>` getestet