## Phase 1 – Kern spielbar (Dungeon)

- [ ] Beispielcode läuft: Dungeon entsteht, Kampfraum schließt sich, Gegner besiegen öffnet ihn, Truhe gibt Beute, Boss beendet den Durchlauf
- [ ] Mehrere Seeds getestet (`newdungeon <seed>`): immer lösbar, Boss am weitesten weg
- [ ] Gegner, Raumbelegung und Beute in `Config/Dungeon.luau` abgestimmt
- [ ] Kampf vertieft: Waffen, Ausweichen, Fähigkeiten (Code aus `rpg-nahkampf` oder `battlegrounds` übernehmen)
- [ ] Wofür ist die Beute da? (Ausrüstung → Modul `inventar`, dauerhafte Verbesserungen)
- [ ] Schwierigkeitsstufen oder mehr Räume als Anreiz zum Wiederspielen

## Phase 2 – Welt (Dungeon)

- [ ] Eigene Raum-Bausteine je Art unter `ServerStorage.Assets.DungeonRooms` (mind. 2 Varianten für `Combat`)
- [ ] Bausteine geprüft: Boden genau `RoomSize` groß, `DoorN/E/S/W` vorhanden, `MobSpawn` und `Chest` getaggt
- [ ] Stimmung: Fackeln, Nebel, dunkle Lighting-Einstellungen
- [ ] Lobby gebaut; falls gewünscht eigene Server pro Gruppe eingerichtet (siehe Genre-Referenz)