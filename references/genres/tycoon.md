# Tycoon

Grundstück übernehmen, mit Kaufknöpfen ausbauen, Tropfer erzeugen Ware, Förderband bringt sie zum Sammler, Geld abholen. Gekauftes bleibt gespeichert.

## Dateien (`assets/genres/tycoon/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/Tycoon.luau` | kaufbare Gegenstände (Preis, Voraussetzungen, Tropfer-Werte), Grenzen, **Welt-Vertrag** |
| `server/Services/TycoonService.luau` | Grundstücke, Knöpfe, Kauf, Wiederaufbau, Tropfen, Sammler, Veredler, Verdienst bei Abwesenheit |
| `client/Controllers/TycoonController.luau` | Geldanzeige, Stand des Sammlers |
| `server/Admin/Commands/Tycoon.luau` | `money` |

## Bauweise der Welt (wichtig)

Ein Grundstück wird in Studio **komplett ausgebaut** hingestellt. Beim Start räumt der Server alles Kaufbare weg (nach ServerStorage) und stellt Kopien wieder hin, sobald gekauft wurde. So sieht man beim Bauen das fertige Ergebnis.

## Welt-Vertrag

| Was | Klasse | Bedingung |
|---|---|---|
| Tag `TycoonPlot` | Model | das Grundstück; enthält alles Folgende |
| Kind `Claim` | BasePart | Berühren übernimmt das Grundstück |
| Kind `CollectPad` | BasePart | Berühren zahlt den Sammler aus |
| Tag `TycoonButton` | BasePart | Attribut `Item` (Schlüssel aus `Items`) |
| Tag `TycoonItem` | Model/BasePart | Attribut `Item`; Tropfer enthalten ein Teil `Spout` |
| Tag `TycoonCollector` | BasePart | nimmt Tropfen an |
| Tag `TycoonUpgrader` | BasePart | Attribut `Multiplier` |
| Tag `Conveyor` | BasePart | Attribut `Speed`; Richtung = Vorderseite |

Ein Grundstück fertig bauen und testen, dann duplizieren.

## Was einen guten Tycoon ausmacht

- **Jeder Kauf verändert etwas Sichtbares.** Reine Zahlen-Upgrades sparsam.
- **Kauf-Reihenfolge als Kurve:** erste Käufe im 10-Sekunden-Takt, später Minuten; 15 bis 30 Gegenstände, dazwischen Höhepunkte (zweites Stockwerk, neue Maschine).
- **Thema durchziehen** (Fabrik, Restaurant, Mine): Tropfen, Maschinen und Deko passen dazu.
- **Abholen fühlt sich gut an:** Ton, Zahl, Aufploppen.
- Verdienst bei Abwesenheit gedeckelt (Config), damit Spielen sich mehr lohnt als Wegbleiben.
- Ein Ziel am Ende (letzter großer Kauf, Rebirth, Trophäe).

## Erweitern

- **Neuer Gegenstand:** Eintrag in `Items`, Modell mit Tag und Attribut in der Welt, Knopf dazu.
- **Rebirth:** `Owned` leeren, Multiplikator im Spielstand, Tropfenwerte damit malnehmen.
- **Zweite Etage / Freischaltbereiche:** über `Requires`.
- **Waffen/Fahrzeuge kaufen:** Gegenstand, dessen Kauf eine andere Wirkung auslöst (eigenes Feld in `Item`, Auswertung in `buy`).

## Stolperfallen

- Gespeichert wird nur die Liste der gekauften Ids, nie Modelle.
- Tropfen gehören dem Server (`SetNetworkOwner(nil)`), sonst kann ein Client sie in den Sammler teleportieren.
- Obergrenze der Tropfen je Grundstück und Lebensdauer (Config) schützen die Leistung.
- Ein Veredler wertet jeden Tropfen nur einmal auf.
- Jedes `Item`-Attribut muss in `Config/Tycoon.luau` stehen (der Service warnt sonst beim Start).

## Erstprüfung in Studio

1. Welt: ein Grundstück mit `Claim`, `CollectPad`, zwei Tropfern (mit `Spout`), Förderband, Sammler, Knöpfen.
2. Spieltest: `Claim` berühren; Knopf für den ersten Tropfer erscheint, kaufen, Tropfen fallen und fahren zum Sammler.
3. Sammler-Stand in der Anzeige steigt; `CollectPad` zahlt aus.
4. `money 5000`, alles kaufen: Knöpfe erscheinen in der richtigen Reihenfolge.
5. Spieltest neu starten (mit `SaveInStudio = true`): Gekauftes steht nach `Claim` wieder da.
