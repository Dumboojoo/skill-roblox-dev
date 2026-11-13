## Modul: Bestenliste

- [ ] Ranglisten in `Config/Leaderboards.luau` festgelegt (Pfad im Spielstand, Richtung, Format)
- [ ] In Studio: Spieleinstellungen → Sicherheit → API-Dienste eingeschaltet; `leaderboard <name> refresh` zeigt Einträge
- [ ] Tafeln in der Welt: Teile mit Tag `LeaderboardBoard` und Attribut `Board` (Vorderseite zeigt die Liste)
- [ ] Bestzeiten: `Ascending = true`, `Scale = 1000`; Einträge ohne Zeit erscheinen nicht
- [ ] Geprüft, dass die Werte nicht manipulierbar sind (alles, was hineinfließt, entscheidet der Server)