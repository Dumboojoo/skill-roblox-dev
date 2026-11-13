# Module: Inventar und Bestenliste

Module passen zu jedem Genre und lassen sich jederzeit nachrüsten:

```
python scripts/neues_spiel.py <projektordner> --ergaenzen --module inventar,bestenliste
```

Das kopiert die Dateien (ohne Vorhandenes zu überschreiben) und hängt die Checkliste an `PLAN.md` an. Das dritte Modul, `monetarisierung`, hat eine eigene Referenz (`monetarisierung.md`).

## Inventar

Raster-Inventar, wie man es aus großen Roblox-Rollenspielen kennt: Kategorie-Reiter, Suche, Kacheln mit Seltenheitsfarbe und Stapelzahl, Detailfeld mit Ausrüsten/Benutzen/Wegwerfen. Übernommen ist der Aufbau, nicht Gegenstände oder Grafik eines bestimmten Spiels.

| Datei (`assets/module/inventar/src/`) | Inhalt |
|---|---|
| `shared/Config/Items.luau` | Gegenstände, Seltenheiten, Kategorien, Ausrüstungsplätze, Kapazität, Taste |
| `shared/Inventory/Logic.luau` | Buchhaltung: stapeln, Plätze, entfernen, Ausrüstung lösen – getestet |
| `server/Services/InventoryService.luau` | `Give`, `Take`, `Count`, `HasSpace`, `GetEquipped`; Signale `Equipped`, `Used` |
| `client/Controllers/InventoryController.luau` | das Fenster (Taste B oder Knopf) |
| `server/Admin/Commands/Inventory.luau` | `giveitem <gegenstand> [anzahl]`, `clearinv <spieler> JA` |

**Aufbau im Spielstand:** `Inventory.Slots` ist eine Liste von `{ Uid, Id, Count }`. Die `Uid` macht jeden Platz eindeutig ansprechbar; damit lassen sich später einzelne Stücke aufwerten oder handeln.

**Anschließen:**

```lua
-- Gegenstände geben (Beute, Händler, Quest)
if InventoryService:HasSpace(player, "IronOre", 5) then
	InventoryService:Give(player, "IronOre", 5)
end

-- Bezahlen mit Gegenständen (alles oder nichts)
if InventoryService:Take(player, "IronOre", 10) then ... end

-- Wirkung von Ausrüstung
InventoryService.Equipped:Connect(function(player, equipSlot, itemId)   -- itemId = nil: abgelegt
	if equipSlot == "Weapon" then ... Schaden/Modell der Waffe anwenden ... end
end)

-- Verbrauchsgegenstände
InventoryService.Used:Connect(function(player, itemId)
	if itemId == "HealthPotion" then ... heilen ... end
end)
```

`Equipped` feuert auch beim Laden und nach jedem Erscheinen des Charakters, damit Ausrüstung wieder angewendet wird.

**Erweitern:** Symbole (Feld `Icon` + ImageLabel in `createTile`), Sortier-Knopf, Schnellleiste (ausgerüstete Verbrauchsgegenstände auf Zifferntasten), Handel (nur serverseitig, beide Seiten bestätigen, Tausch in einem Schritt), Verkaufen an Händler (`Take` + Währung gutschreiben).

**Stolperfallen:** Der Client schickt nur `Uid`s; der Server schaut selbst nach, was dort liegt. Tabellenschlüssel mit Umlauten (`Stats`) als `["Glück"]` schreiben. Kapazitäts-Erweiterungen (z. B. per Pass) über einen Wert im Spielstand statt der festen `Items.Capacity`.

**Erstprüfung in Studio:** `giveitem StormBlade`, `giveitem IronOre 150`, `giveitem HealthPotion 5` → Fenster (`B`): Kacheln mit Farben und Stapelzahlen (zwei Erz-Stapel), Reiter und Suche filtern, Ausrüsten markiert die Kachel, Benutzen verringert den Stapel, Wegwerfen fragt nach. `data show me Inventory` zeigt denselben Stand.

## Bestenliste

Globale Ranglisten über alle Server, optional als Tafel in der Welt.

| Datei (`assets/module/bestenliste/src/`) | Inhalt |
|---|---|
| `shared/Config/Leaderboards.luau` | Ranglisten (Pfad im Spielstand, Richtung, Skalierung, Format), Anzahl, Takt |
| `server/Services/LeaderboardService.luau` | schreibt und liest OrderedDataStores mit Rücksicht auf die Anfragegrenzen; Tafeln |
| `server/Admin/Commands/Leaderboard.luau` | `leaderboard <name> [refresh]` |

**Rangliste anlegen:** Eintrag in `Boards`:

```lua
Kills = { DisplayName = "Meiste Kills", Path = "Shooter.Kills", Ascending = false, Scale = 1, Format = "Number" },
ObbyTime = { DisplayName = "Schnellster Lauf", Path = "Obby.BestTime", Ascending = true, Scale = 1000, Format = "Time" },
```

Bestzeiten: `Ascending = true` und `Scale = 1000` (gespeichert werden ganze Zahlen, also Millisekunden); Einträge mit 0 werden ausgelassen.

**Tafel in der Welt:** Teil mit Tag `LeaderboardBoard` und Attribut `Board` (Schlüssel). Die Liste erscheint auf der Vorderseite.

**Im Client anzeigen:** `Net.Call("Leaderboard.Get", "Kills")` liefert `{ Rank, UserId, Name, Value }`.

**Wissen muss man:** Ranglisten sind bis zu `RefreshSeconds` alt (gewollt, wegen der Anfragegrenzen; nicht unter 60 stellen). In Studio brauchen sie eingeschaltete API-Dienste. Alles, was in eine Rangliste fließt, muss der Server entscheiden – sonst führt sie der beste Schummler an. Zurücksetzen: `StoreVersion` erhöhen.

**Erstprüfung in Studio:** API-Dienste an; Tafel mit `Board = "PlayTime"`; Spieltest, `leaderboard PlayTime refresh` → eigener Eintrag erscheint in der Konsole und auf der Tafel.
