## Modul: Monetarisierung

- [ ] Gutschrift-Handler angemeldet (`MonetizationService:RegisterGrant("Coins", …)`), tägliche Belohnung funktioniert
- [ ] Katalog in `Config/Products.luau` festgelegt: wenige Angebote, nur Kosmetik, Komfort, Unterstützung (kein Pay-to-Win)
- [ ] Pässe und Produkte im Creator Hub angelegt, Ids eingetragen
- [ ] Pass-Wirkung angeschlossen (`OwnsPass`, Signal `PassOwned`): wirkt sofort nach Kauf und nach Neubeitritt
- [ ] Testkauf in Studio: Produkt wird genau einmal gutgeschrieben; Spielstand danach gespeichert
- [ ] Shop öffnet nur auf Knopfdruck; keine Kauf-Fenster, die sich von selbst öffnen
- [ ] Zufallskäufe (falls vorhanden): Chancen angezeigt und `RandomItemsAllowed` geprüft
- [ ] Preise fair gestaffelt; teuerstes Angebot bringt keinen spielerischen Vorteil gegenüber anderen Spielern