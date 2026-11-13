# Survival / Crafting

Hunger und Durst, Rohstoffe sammeln, Gegenstände herstellen, mit Raster und Vorschau bauen. Die Basis wird pro Spieler gespeichert und beim nächsten Beitritt wieder aufgestellt.

## Dateien (`assets/genres/survival-crafting/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/Survival.luau` | Gegenstände, Rezepte, Bauteile, Bedürfnisse, Raster, **Welt-Vertrag** |
| `shared/Survival/Crafting.luau` | Rechenregeln: bezahlbar?, abziehen, hinzufügen, Rückerstattung, Raster – getestet |
| `server/Services/SurvivalService.luau` | Bedürfnisse, Essen, Trinken, Sammeln, Herstellen (mit Station), Bauen/Abbauen, Basis speichern |
| `client/Controllers/SurvivalController.luau` | Balken, Rucksack-Fenster (Gegenstände, Rezepte, Bauteile), Baumodus mit Vorschau |
| `server/Admin/Commands/Survival.luau` | `give <gegenstand> [anzahl]`, `feed` |
| `tests/Survival.spec.luau` | Tests der Rechenregeln |

## Welt-Vertrag

| Tag | Klasse | Attribute |
|---|---|---|
| `Harvestable` | BasePart/Model | `Item` (Schlüssel aus `Items`), `Amount`, `Respawn` |
| `WaterSource` | BasePart | – |

Arbeitsstationen (Werkbank, Lagerfeuer) sind Bauteile mit dem Feld `Station`; Rezepte mit `Station` brauchen eine in der Nähe.

## Was gutes Survival ausmacht

- **Die ersten zehn Minuten sind geplant:** Was sammelt man zuerst, was baut man zuerst, wovor muss man sich schützen? Der Spieler hat immer einen nächsten Schritt.
- **Eine Kette von Freischaltungen:** Hände → Werkzeug → Werkbank → bessere Werkzeuge → neue Rohstoffe. Jede Stufe öffnet etwas Neues.
- **Bedürfnisse erzeugen Rhythmus, nicht Nerv:** Hunger soll Entscheidungen auslösen (Vorrat anlegen), nicht alle zwei Minuten stören.
- **Eine Bedrohung gibt dem Bauen Sinn:** Nacht, Kälte, Gegner. Ohne sie ist die Basis nur Deko.
- **Bauen ist befriedigend:** Raster, Vorschau in Grün/Rot, sofortiges Einrasten, Abbauen gibt einen Teil zurück.
- Sterben kostet etwas, aber nicht alles.

## Erweitern

- **Gegenstand/Rezept/Bauteil:** Tabelleneintrag.
- **Werkzeuge:** Gegenstand mit Feld (z. B. `HarvestBonus`), das der Service beim Sammeln auswertet; oder Attribut `Tool` am `Harvestable`, das ein bestimmtes Werkzeug verlangt.
- **Gegner und Kampf:** `rpg-nahkampf`; Gebiete, Tag/Nacht: `open-world` (dessen `NightChanged` für nächtliche Gefahr).
- **Richtiges Inventar** mit Plätzen und Stapeln: Modul `inventar` statt der einfachen Zähler (`Survival.Items`) – dann die Aufrufe im Service auf `InventoryService` umstellen.
- **Lagerkisten, Türen, Betten** (Respawn-Punkt): Bauteile mit eigener Wirkung über ein Feld in `Buildable`.
- **Gemeinsame Basen:** Besitz über Gruppen/Freunde statt pro Spieler.

## Stolperfallen

- Der Client schickt Rezept- bzw. Bauteil-**Id** und Position; Kosten und Ergebnis bestimmt der Server.
- Der Server rastet die Position selbst ein und prüft Reichweite, Material, Höchstzahl und Überschneidung mit anderen Bauteilen.
- Die Vorschau benutzt dieselbe Einrast-Regel wie der Server (`Crafting.Snap`), sonst springt das Teil beim Bauen.
- Positionen als Zahlen speichern; Basis-Liste deckeln (`MaxPieces`).
- Beim Wiederaufbau überspringt der Service Teile, die sich mit fremden überschneiden.
- Nach dem Tod Bedürfnisse auf mindestens die Hälfte setzen, sonst stirbt man sofort wieder.

## Erstprüfung in Studio

1. Welt: je zwei `Harvestable` für `Wood`, `Stone`, `Fiber`, `Berry`; ein `WaterSource`; ebene Fläche.
2. Spieltest: Balken sichtbar; sammeln (Meldung, Knoten verschwindet), Rucksack (`Tab`) zeigt Mengen.
3. `give Wood 20`, Brett herstellen; Boden wählen → Vorschau rastet ein, grün; bauen. Wand mit `R` drehen.
4. Werkbank bauen; Rezept mit Station geht nur in ihrer Nähe.
5. Bauteil abbauen (halten): halbe Kosten zurück. Mit `SaveInStudio = true` neu starten: Basis steht wieder.
