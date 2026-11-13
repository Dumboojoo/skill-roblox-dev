# Runden / Minispiele

Lobby → Abstimmung → Minispiel → Ergebnis, in Dauerschleife. Minispiele sind einzelne Dateien, die automatisch gefunden werden.

## Dateien (`assets/genres/runden-minispiele/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/Rounds.luau` | Zeiten, Mindestspieler, Belohnungen, **Welt-Vertrag** |
| `server/RoundTypes.luau` | die Schnittstelle eines Minispiels (`Context`, `Minigame`) |
| `server/Services/RoundService.luau` | Ablauf, Abstimmung, Teilnehmer, Ausscheiden, Sieger, Belohnung |
| `server/Minigames/HotPotato.luau` | Beispiel: Kartoffel weitergeben, Träger scheidet aus |
| `server/Minigames/RisingLava.luau` | Beispiel: Lava steigt, wer sie berührt, scheidet aus |
| `client/Controllers/RoundController.luau` | Statusleiste, Abstimmungsfenster, Sieger-Banner, Zuschauen |
| `server/Admin/Commands/Rounds.luau` | `skipround`, `forcegame <name>` |

## Ein Minispiel schreiben

Datei in `server/Minigames/`, Dateiname = Id:

```lua
local RoundTypes = require(script.Parent.Parent.RoundTypes)
local minigame: RoundTypes.Minigame = {
	DisplayName = "Name",
	Description = "Ein Satz, was zu tun ist.",
	Duration = 60,
	Start = function(context)
		-- einrichten; alles Angelegte in context.Trove (wird am Rundenende aufgeräumt)
		-- context.Alive(), context.IsAlive(p), context.Eliminate(p), context.Finish(sieger), context.TimeLeft(), context.Map
	end,
}
return minigame
```

Die Runde endet von selbst bei Zeitablauf (Überlebende gewinnen) oder wenn nur noch einer übrig ist. Spiele mit eigenem Ziel rufen `context.Finish` auf.

## Welt-Vertrag

| Tag | Klasse | Attribute |
|---|---|---|
| `LobbySpawn` | BasePart | – |
| `MinigameMap` | Model | `Minigame` (Dateiname, z. B. `HotPotato`) |
| `MinigameSpawn` | BasePart | – (innerhalb des Map-Models) |

`RisingLava` braucht in seiner Map ein Teil namens `Lava` (optional mit Attribut `Speed`, Studs pro Sekunde). Ein Minispiel steht nur zur Wahl, wenn es eine Map hat.

## Was gute Rundenspiele ausmacht

- **In fünf Sekunden verstanden:** Name und ein Satz reichen. Sonst ist das Minispiel zu kompliziert.
- **Kurz:** 45 bis 120 Sekunden. Niemand wartet länger als eine Runde.
- **Ausgeschiedene sind beschäftigt:** Zuschauen (eingebaut), später Mitmischen aus der Lobby.
- **Abwechslung:** verschiedene Arten (Überleben, Wettlauf, Sammeln, Einer-gegen-alle), nicht fünfmal dasselbe.
- **Die Lobby ist Teil des Spiels:** etwas zum Tun in den 12 Sekunden Pause.
- Belohnung fürs Mitspielen und extra fürs Gewinnen; Münzen für Kosmetik.

## Erweitern

- **Teams:** im `Start` Spieler aufteilen (`Player.Team`), `Finish` mit dem Sieger-Team aufrufen.
- **Maps pro Runde frisch:** Map in ServerStorage halten und je Runde klonen (`context.Trove:Add(klon)`), wenn ein Minispiel die Map verändert.
- **Schießen/Kämpfen als Minispiel:** Code aus `ego-shooter` bzw. `battlegrounds` einbinden; deren `Killed`-Signale zählen Punkte.

## Stolperfallen

- Alles, was ein Minispiel anlegt (Verbindungen, Teile, Schleifen), in `context.Trove`. Sonst läuft es in die nächste Runde weiter.
- `context.Alive()` nicht verändern.
- `MinPlayers = 1` nur zum Testen; veröffentlicht mindestens 2 (mit einem Spieler endet „Letzter gewinnt" nie von selbst vor Zeitablauf).
- Maps weit auseinander oder abgeschirmt, damit niemand in die falsche läuft.

## Erstprüfung in Studio

1. Welt: Lobby mit `LobbySpawn`, zwei Maps (`HotPotato`, `RisingLava` mit Teil `Lava` und Kletterblöcken), je 4 `MinigameSpawn`.
2. Spieltest: Statusleiste zählt herunter, Abstimmung erscheint, Wahl wird markiert.
3. `forcegame RisingLava`, `skipround`: Teleport in die Map, Lava steigt, Berühren wirft raus (Zuschauen-Knopf erscheint).
4. Rundenende: Banner, zurück in die Lobby, Lava wieder unten.
5. `forcegame HotPotato`: Träger leuchtet, nach 12 s ausgeschieden.
