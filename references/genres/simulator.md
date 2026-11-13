# Simulator

Klicken und Sammeln für Währung, Upgrades, Pets mit Multiplikatoren, Zonen und Rebirth. Läuft schon ohne Welt (Klick-Knopf und Menüs).

## Dateien (`assets/genres/simulator/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/Simulator.luau` | Upgrades, Pets, Eier mit Gewichten, Zonen, Rebirth, **Welt-Vertrag** |
| `shared/Simulator/Formulas.luau` | alle Rechenregeln (Preise, Klickwert, Pet-Bonus, Rebirth, gewichtete Auswahl, Chancen) – getestet |
| `server/Services/SimulatorService.luau` | Klick, Sammeln, Kaufen, Schlüpfen, Ausrüsten, Zonen, Rebirth |
| `client/Controllers/SimulatorController.luau` | Münzanzeige, Klick-Knopf, Fenster mit Reitern (Upgrades, Pets, Eier, Rebirth) |
| `server/Admin/Commands/Simulator.luau` | `coins` |
| `tests/Simulator.spec.luau` | Tests der Formeln |

## Welt-Vertrag (alles optional)

| Tag | Klasse | Attribute |
|---|---|---|
| `Collectible` | BasePart | `Value` (Zahl), `Zone` (Text, optional), `Respawn` (s) |
| `ZoneGate` | BasePart | `Zone` (Schlüssel aus `Zones`): Sperre, die für Besitzer verschwindet |
| `EggStand` | BasePart | `Egg` (Schlüssel aus `Eggs`) |

## Was einen guten Simulator ausmacht

- **Ein Thema** statt neutraler Münzen: Was sammelt man, warum wird man dabei größer/stärker/reicher?
- **Immer ein Ziel in Reichweite:** nächstes Upgrade in Sekunden, nächstes Ei in Minuten, nächste Zone in einer Sitzung, Rebirth als Fernziel.
- **Zahlen wachsen sichtbar**, aber kontrolliert: Pet-Boni additiv (steht in `Formulas`), Preise wachsen schneller als Einkommen pro Stufe.
- Richtwerte: erstes Upgrade nach 30 s, erstes Ei nach 2 bis 3 min, erster Rebirth nach 30 bis 60 min.
- **Zonen sehen deutlich anders aus** und geben spürbar mehr.
- **Chancen der Eier offen zeigen** (macht das Menü aus den Gewichten).
- Eier kosten Spielwährung. Robux-Eier nur mit `monetarisierung.md` (Chancen, Länderprüfung).

## Erweitern

- **Upgrade/Pet/Ei/Zone:** Tabelleneintrag.
- **Zweites Upgrade mit anderer Wirkung** (z. B. Laufgeschwindigkeit, Sammelradius): Eintrag + Auswertung im Service; Formel in `Formulas` + Test.
- **Pets sichtbar folgen lassen:** Client-Controller, der für ausgerüstete Pets Blöcke hinter dem Charakter herführt (rein kosmetisch, Daten sind schon da).
- **Automatisches Klicken** als erspielbares Upgrade.
- **Handel zwischen Spielern** nur mit großer Sorgfalt (Betrug, Duplikate); nicht nebenbei einbauen.

## Stolperfallen

- Der Client schickt nur „Klick", nie einen Betrag. Die Aufrufgrenze (`MaxClicksPerSecond`) stoppt Autoklicker.
- Münzen immer über `SimulatorService:AddCoins` (hält `Coins` und `TotalCoins` zusammen).
- Sehr große Zahlen: Anzeige über `Format.Number`; `leaderstats` sind ganze Zahlen.
- Balancing in `Formulas.luau` und Config ändern, danach Tests anpassen.

## Erstprüfung in Studio

1. Spieltest ohne Welt: Klick-Knopf erhöht Münzen, Zahl ploppt.
2. Menü: Upgrade kaufen (Preis steigt), `coins 10000`, Ei öffnen (Meldung, Pet im Reiter), ausrüsten (Klickwert steigt).
3. Reiter Eier: Chancen stehen dabei. Bildschirmfoto je Reiter.
4. `coins 200000`, Rebirth: Münzen und Upgrades zurück, Pets bleiben, Klickwert höher.
5. Mit Welt: `Collectible` berühren, `ZoneGate` kaufen und durchgehen.
