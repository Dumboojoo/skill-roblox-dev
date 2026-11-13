# Spielstände (DataStore)

Datenverlust ist der schlimmste Fehler, den ein Roblox-Spiel machen kann. Deshalb läuft alles über **einen** Weg: den `DataService`, der auf ProfileStore aufbaut.

## Was ProfileStore abnimmt

- **Sitzungssperre:** Ein Spielstand ist immer nur auf einem Server offen. Wechselt ein Spieler schnell den Server, wartet der neue, bis der alte gespeichert hat. Das verhindert Duplikate und überschriebene Stände.
- **Automatisches Speichern** alle paar Minuten und beim Verlassen.
- **Herunterfahren:** Beim Server-Ende werden alle offenen Stände gespeichert.
- **Fehler und Grenzen:** Wiederholungen, Anfragegrenzen der DataStores.

`server/Packages/ProfileStore.luau` nie ändern. Neue Version: Datei aus dem offiziellen Repository (MadStudioRoblox/ProfileStore) ersetzen.

## Benutzen (Server)

```lua
DataService:Get(player, "Currency.Coins")                 -- nil, solange nicht geladen
DataService:Set(player, "Settings.MusicVolume", 0.3)
DataService:Increment(player, "Currency.Coins", 25)      -- gibt den neuen Wert zurück
DataService:Update(player, "Inventory.Slots", function(slots) table.insert(slots, x) return slots end)
DataService:Observe(player, "Currency.Coins", function(new, old) ... end)
DataService:OnPlayerLoaded(function(player, data) ... end) -- für alle jetzigen und künftigen Spieler
DataService:WaitForData(player)                           -- wartet; nil, wenn der Spieler vorher geht
DataService.PlayerRemoving:Connect(function(player, data) ... end)  -- letzte Chance, etwas hineinzuschreiben
```

- Pfad als Text mit Punkten oder als Liste (`{ "Gems", levelId, gemId }`). Die Liste ist nötig, wenn ein Schlüssel aus einer Variablen kommt oder einen Punkt enthält.
- **Immer über Set/Increment/Update ändern.** Nur dann erfährt der Client davon. Eine Tabelle aus `Get` direkt zu verändern, ohne danach `Set`/`Update` für denselben Pfad aufzurufen, ist ein Fehler.
- Möglichst schmale Pfade ändern: `Set(player, { "Owned", itemId }, true)` schickt nur diesen einen Wert, `Set(player, "Owned", ganzeTabelle)` die ganze Tabelle.
- Einen Schlüssel löschen: `Set(player, pfad, nil)`.

Client: `DataController:Get(pfad)`, `DataController:Observe(pfad, fn)` (ruft sofort und bei jeder Änderung auf), `DataController:WaitForData()`. Der Client ändert nie selbst.

## Neuer Abschnitt im Spielstand

Datei in `shared/Config/DataSections/`:

```lua
return {
	Template = {
		Currency = { Coins = 0, Gems = 0 },   -- ein Oberschlüssel pro Feature
	},
	Leaderstats = { { Name = "Münzen", Path = "Currency.Coins" } },   -- optional: Spielerliste
}
```

Neue Felder in einem bestehenden Abschnitt: einfach in die Vorlage schreiben. Bestehende Spieler bekommen sie beim nächsten Laden automatisch (Reconcile).

## Was gespeichert werden darf

- Zahlen, Texte, Wahrheitswerte und Tabellen daraus.
- **Nicht:** Instanzen, Funktionen, `Vector3`/`Color3`/`CFrame` (vorher in Zahlen zerlegen: `X`, `Y`, `Z`).
- Listen ohne Lücken. Tabellen nie mit Zahlen- **und** Text-Schlüsseln mischen.
- Wörterbuch-Schlüssel sind Texte. `UserId` als Schlüssel mit `tostring` umwandeln.
- Schlüssel mit Unterstrich am Anfang (`_Receipts`) gehen nicht an den Client.
- Grenze: 4 MB pro Spielstand. Praktisch erreicht man die nur mit unbegrenzt wachsenden Listen (Verlauf, Logbuch) – solche Listen immer deckeln.
- Speichere **Fakten**, keine Ableitungen: Gesamt-XP speichern, Stufe daraus berechnen. Gekaufte Item-Ids speichern, Modelle daraus bauen.

## Felder umbauen: Migration

Sobald ein Feld umbenannt, verschoben oder sein Aufbau geändert wird, in `shared/Config/DataMigrations.luau`:

```lua
return {
	Version = 2,                       -- um 1 erhöht
	Steps = {
		[2] = function(data)           -- bringt Version 1 auf Version 2
			data.Currency = data.Currency or {}
			data.Currency.Coins = data.Coins or 0
			data.Coins = nil
		end,
	},
}
```

- Alte Schritte nie löschen oder ändern. Ein Spieler, der lange weg war, durchläuft alle der Reihe nach.
- Ein Schritt darf nicht warten und muss mit fehlenden Feldern zurechtkommen.
- Schlägt ein Schritt fehl, wird der Spieler gekickt und sein Stand bleibt unverändert.
- Für jede Migration einen Test in `tests/` schreiben (Vorlage `Daten.spec.luau`): alter Stand rein, erwarteter Stand raus.
- Den DataStore-Namen (`GameConfig.Data.StoreName`) nur ändern, wenn wirklich alle neu anfangen sollen.

## In Studio

`GameConfig.Data.SaveInStudio = false` (Standard): Studio benutzt Testdaten im Speicher, die echten Stände bleiben unberührt. Jeder Spieltest beginnt mit einem frischen Stand. Zum Testen von „speichern → verlassen → wiederkommen" kurz auf `true` stellen (API-Dienste müssen in den Spieleinstellungen an sein) und danach zurück.

Admin-Befehle zum Testen: `data show <spieler> [pfad]`, `data set <spieler> <pfad> <wert>`, `data add <spieler> <pfad> <zahl>`, `data reset <spieler> JA`.

## Käufe mit Robux

Nie von Hand. `DataService:GrantOnce(player, kaufId, funktion)` schreibt gut **und** wartet, bis gespeichert ist; das Modul `monetarisierung` benutzt es in `ProcessReceipt`. Siehe `monetarisierung.md`.

## Ranglisten

Der Spielstand lässt sich nicht sortiert abfragen. Globale Ranglisten: Modul `bestenliste` (eigener OrderedDataStore).

## Daten anderer oder abwesender Spieler

`DataService:ReadOffline(userId)` liest einen Stand, ohne ihn zu öffnen (nur lesen). Geschenke an abwesende Spieler: ProfileStore `MessageAsync` (siehe dessen Dokumentation) – nur bei echtem Bedarf einbauen.

## Wenn Daten „weg" sind – Reihenfolge der Suche

1. Ausgabe lesen: Meldungen mit `[DataService]` oder `[ProfileStore]`?
2. Wurde der Wert über `Set/Increment/Update` geändert oder eine Tabelle direkt verändert?
3. Steht `SaveInStudio` auf `false` und es wurde in Studio getestet? (Dann ist das Verhalten richtig.)
4. Wurde ein Feld umbenannt ohne Migration?
5. Wird etwas Unspeicherbares abgelegt (Instanz, Vector3, Liste mit Lücke)?
