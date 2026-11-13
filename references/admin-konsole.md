# Admin-Konsole (Taste T)

Befehlszeile wie in Minecraft: **T** öffnet, **Enter** führt aus, **Tab** vervollständigt, Pfeiltasten blättern im Verlauf. Auf dem Handy erscheint für Admins ein Knopf `>_`.

## Sicherheit

Der Client schickt nur den Text. `AdminService` prüft bei **jedem** Befehl die Berechtigung und führt ihn auf dem Server aus. Nicht-Admins bekommen weder die Befehlsliste noch eine Oberfläche. Jeder Befehl wird in der Server-Ausgabe protokolliert.

Wer Admin ist (`shared/Config/GameConfig.luau`, Abschnitt `Admin`):

| Feld | Bedeutung |
|---|---|
| `OwnerIsAdmin` | Besitzer des Spiels bzw. der Gruppe |
| `StudioIsAdmin` | beim Testen in Studio jeder |
| `UserIds` | weitere Admins als Liste von UserIds |
| `GroupId`, `GroupMinRank` | alle ab diesem Rang einer Gruppe |
| `ConsoleKey` | Taste zum Öffnen |

## Eingebaute Befehle

| Befehl | Wirkung |
|---|---|
| `fly [an/aus] [spieler]` | Fliegen (WASD in Blickrichtung, Leertaste hoch, Shift runter); `flyspeed <wert>` |
| `noclip [an/aus] [spieler]` | durch Wände |
| `god [an/aus] [spieler]` | unsterblich |
| `invisible [an/aus] [spieler]` | unsichtbar |
| `speed <wert> [spieler]`, `jump <wert> [spieler]` | Lauf- und Sprungkraft |
| `tp <ziel>`, `bring <spieler/all/others>`, `tppos <x> <y> <z>` | Teleport |
| `heal`, `kill`, `respawn` `[spieler]` | Leben |
| `kick <spieler> [grund]` | vom Server entfernen |
| `time <stunde>` | Tageszeit |
| `announce <text>` | Nachricht an alle (läuft durch den Roblox-Textfilter) |
| `data show/set/add/reset …` | Spielstand ansehen und ändern |
| `help [befehl]`, `clear` | Hilfe, Anzeige leeren |

Schalter ohne Angabe wechseln den Zustand. Spieler: Name, Namensanfang oder `me`. Zustände überleben den Tod.

Jedes Genre und Modul bringt eigene Befehle mit (z. B. `stage`, `cash`, `nextwave`, `giveitem`); `help` zeigt alle.

## Eigene Befehle

Neue Datei in `src/server/Admin/Commands/`, die eine Liste zurückgibt. Sie wird automatisch geladen.

```lua
--!strict
local ShopService = require(script.Parent.Parent.Parent.Services.ShopService)
local Types = require(script.Parent.Parent.Types)

local commands: { Types.Command } = {
	{
		Name = "coins",
		Aliases = { "muenzen" },
		Description = "Gibt Münzen",
		Args = { "betrag:integer", "spieler:player?" },
		Run = function(context: Types.Context, amount: number, target: Player?): string?
			local player = target or context.Player
			ShopService:AddCoins(player, amount)
			return `{player.Name} hat {amount} Münzen bekommen.`
		end,
	},
}
return commands
```

**Args** sind Texte `name:typ`, mit `?` am Ende optional:

| Typ | Eingabe | `Run` bekommt |
|---|---|---|
| `player` | Name, Namensanfang, `me` | `Player` |
| `players` | wie oben oder `all`, `others` | `{ Player }` |
| `number`, `integer` | Zahl | `number` |
| `boolean` | an/aus, on/off, true/false | `boolean` |
| `string` | ein Wort oder `"mehrere Wörter"` | `string` |
| `choice` | einer aus `Choices[name]` | `string` |
| `rest` | alles bis zum Zeilenende (nur als letztes) | `string` |

- Auswahlwerte: `Choices = { typ = { "A", "B" } }` oder als Funktion, die eine Liste liefert (dann stimmt auch die Tab-Vervollständigung mit der Config überein).
- Optionale Argumente, die nicht passen, werden übersprungen. Darum bei Schaltern `an/aus:boolean?` **vor** `spieler:player?`.
- Rückgabe von `Run` = Text in der Konsole. Eine Fehlermeldung an den Admin: `error("Text", 0)`.
- Tippfehler in `Args` meldet der Server beim Start in der Ausgabe.

**Regel:** Jedes Feature bringt die Befehle mit, die man zum Testen braucht (Geld geben, Stufe setzen, Phase überspringen, Gegner erscheinen lassen). Das spart bei jedem Spieltest Minuten und macht Tests über das Studio-MCP erst praktikabel.

## Zustände in eigenen Systemen beachten

- Schaden über `Humanoid:TakeDamage()` austeilen: Dann schützt `god` automatisch (unsichtbares Kraftfeld). Wer `Health` direkt setzt, fragt vorher `AdminService:IsGod(player)`.
- Neuer dauerhafter Zustand (z. B. „unendlich Ausdauer"): Attribut am Player setzen und im zuständigen Service/Controller auswerten; Muster in `server/Admin/Effects.luau`.

## Im Spieltest über MCP

Konsole öffnen und bedienen: `user_keyboard_input` mit `T`, dann den Befehlstext, dann `Enter`. Danach `screen_capture` bzw. `get_console_output` (jeder Befehl erscheint als `[Admin] Name: befehl`).
