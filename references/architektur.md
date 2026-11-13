# Architektur

Wie ein Spielprojekt aufgebaut ist und wie man es erweitert, ohne Bestehendes anzufassen.

**Inhalt:** Ordner · Service und Controller · Reihenfolge beim Start · Net · Check · Config · World · UI-Kit · Ton und Einstellungen · Hilfsmodule · Tests · Stilregeln · Rezepte

## Ordner

```
src/
├── server/                  → ServerScriptService.Server   (nur der Server sieht das)
│   ├── Main.server.luau     Einstieg: lädt alle Services
│   ├── Services/            ein Modul pro Feature
│   ├── Admin/Commands/      Befehlsdateien für die Konsole (automatisch geladen)
│   ├── Admin/Effects.luau   fly/god/invisible-Zustände
│   ├── Data/Migrate.luau    Spielstand-Migration
│   └── Packages/            Fremdmodule (ProfileStore) – nicht ändern
├── client/                  → StarterPlayerScripts.Client
│   ├── Main.client.luau     Einstieg: lädt alle Controller
│   ├── Controllers/         ein Modul pro Feature
│   └── UI/Kit.luau          UI-Baukasten
└── shared/                  → ReplicatedStorage.Shared    (Server und Client)
    ├── Config/              Einstellungen und Inhalte als Tabellen
    │   └── DataSections/    Spielstand-Abschnitte je Feature
    ├── Util/                Signal, Trove, Spring, Format, TablePath, Check, World, CommandParser
    ├── Net.luau             Kommunikation
    └── Loader.luau          lädt Services/Controller
tests/                       Tests für reine Logik (lune) und für Namen von Remotes und Spielstand-Pfaden
```

Faustregel für den Ort: Geheimes und Entscheidendes → `server`. Anzeige und Eingabe → `client`. Was beide brauchen (Tabellen, Formeln, Typen) → `shared`. In `shared` steht nie etwas, das ein Spieler nicht sehen darf.

Größere Features bekommen Unterordner, z. B. `shared/Shooter/`, `server/Minigames/`. Dateien, die keine Services sind, liegen **nicht** in `Services/` (dort wird alles als Service geladen).

## Service und Controller

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Check = require(Shared.Util.Check)
local DataService = require(script.Parent.DataService)   -- andere Services direkt einbinden

local ShopService = {}

function ShopService:Init()      -- Phase 1: Remotes anlegen, Tabellen füllen. Nicht warten.
	Net.On("Shop.Buy", { Check.keyOf(Config.Items) }, onBuy, { Rate = 5 })
end

function ShopService:Start()     -- Phase 2: alle Init sind fertig. Hier darf alles benutzt werden.
	DataService:OnPlayerLoaded(function(player, data) ... end)
end

return ShopService
```

Ein Controller sieht genauso aus (`client/Controllers/`). Datei anlegen genügt, sie wird geladen.

- `Priority` (Zahl, Standard 100): kleiner = früher. `DataService` und `DataController` haben 10.
- Öffentliche Funktionen mit `:` (`ShopService:Give(player, …)`), interne als `local function`.
- Services reden miteinander über direkte Aufrufe und über `Signal`s (`WeaponService.Killed:Connect(...)`). Signale benutzen, wenn der Auslöser den Empfänger nicht kennen soll (Kampf weiß nichts von Quests).
- Kreisbezüge vermeiden: Wenn A B braucht und B A, gehört das Gemeinsame in ein Signal oder ein drittes Modul.

## Reihenfolge beim Start

1. Server: `Main.server` lädt `Net`, dann alle Services: alle `Init` (der Reihe nach), dann alle `Start` (jeweils eigener Thread).
2. Client: `Main.client` lädt alle Controller genauso.
3. Spieler tritt bei → `DataService` lädt den Spielstand → `PlayerLoaded` → Client bekommt `Data.Sync`.

Folge: In `Init` existiert der Spielstand noch nicht. Alles, was Spielerdaten braucht, hängt sich an `DataService:OnPlayerLoaded` (Server) bzw. `DataController:Observe` (Client).

## Net

```lua
-- Server
Net.On("Shop.Buy", { Check.string, Check.integerRange(1, 99) }, function(player, itemId, amount) ... end, { Rate = 5 })
Net.OnInvoke("Shop.GetOffers", {}, function(player) return offers end)
Net.Declare("Round.Started")                          -- Server → Client ankündigen (in Init)
Net.Declare("Enemy.Positions", { Unreliable = true }) -- häufig, Verlust egal
Net.Fire("Round.Started", player, mapName)  /  Net.FireAll(...)  /  Net.FireExcept(...)  /  Net.FireNear(name, position, radius, ...)

-- Client
Net.Send("Shop.Buy", "Sword", 1)
local offers = Net.Call("Shop.GetOffers")
Net.Listen("Round.Started", function(mapName) ... end)
```

- Namen als `Feature.Aktion`.
- Die Prüfer-Liste hat genau so viele Einträge wie Argumente. Mehr oder falsch getypte Argumente → Aufruf wird verworfen (in Studio mit Warnung).
- `Rate` = erlaubte Aufrufe pro Sekunde und Spieler (Standard 20). Niedrig ansetzen: Kaufen 5, Klicken 12, Schießen 25.
- Der Handler prüft danach die **Spiellogik**: genug Geld? nah genug? Abklingzeit? gehört ihm das Objekt? Das kann `Check` nicht wissen.
- `Net.Call` nur, wenn der Client wirklich eine Antwort braucht. Für Zustand lieber Attribute oder den Spielstand.
- Kein `InvokeClient` (ein Client kann den Server damit hängen lassen).

**Zustand zum Client bringen, in dieser Reihenfolge erwägen:**
1. Spielstand (`DataService:Set`) – kommt automatisch beim eigenen Client an (`DataController:Observe`).
2. Attribute an `Player`, `Workspace` oder einem Objekt – für kleinen, öffentlichen Zustand (Phase, Runde, Leben der Basis). Jeder Client liest sie, auch nach späterem Beitritt.
3. `Net.Fire` – für Ereignisse (Treffer, Effekt, Meldung) und größere Daten.

## Check

`Check.string`, `.boolean`, `.number` (ohne NaN/unendlich), `.integer`, `.Vector3`, `.CFrame`, `.table`, `.any`, und als Fabriken: `Check.stringMax(n)`, `Check.numberRange(a, b)`, `Check.integerRange(a, b)`, `Check.instance("BasePart")`, `Check.oneOf({...})`, `Check.keyOf(Tabelle)`, `Check.optional(prüfer)`, `Check.arrayOf(prüfer, maxLänge)`.

`Check.keyOf(Config.Items)` ist der Normalfall für Ids aus Tabellen: Der Handler kann sich dann darauf verlassen, dass `Config.Items[id]` existiert.

## Config

Eine Datei je Feature in `shared/Config/`, die eine Tabelle zurückgibt. Mit Typen (`export type`), damit Tippfehler in Feldnamen auffallen. Der Kopfkommentar jeder Genre-Config dokumentiert den **Welt-Vertrag**.

`GameConfig.luau`: Name, Admins, DataStore-Name. Sonst nichts Genre-Spezifisches hineinlegen.

## World (Tags und Attribute)

```lua
World.Observe("KillPart", function(part)        -- für jedes vorhandene und künftige Teil mit dem Tag
	local connection = part.Touched:Connect(...)
	return function() connection:Disconnect() end  -- Aufräumen, wenn das Teil verschwindet
end)
World.Tagged("PathPoint")                        -- aktuelle Liste
World.Attribute(part, "Speed", 16)               -- Attribut mit Standardwert und Typprüfung
World.Expect("Obby", { { Tag = "Checkpoint", Min = 2, Class = "BasePart", Attributes = { Stage = "number" }, Hint = "…" } })
```

`World.Observe` funktioniert auch mit Streaming (Teile, die erst später laden). `World.Expect` im `Start` jedes Services aufrufen, der etwas von der Welt braucht.

## UI-Kit

```lua
local gui = Kit.ScreenGui("Shop", 20)            -- skaliert automatisch auf jede Bildschirmgröße
local panel = Kit.Panel({ Size = UDim2.fromOffset(420, 300), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = gui })
Kit.Label({ Text = "Hallo", Parent = panel })
Kit.Button({ Text = "Kaufen", Size = UDim2.fromOffset(160, 44), Parent = panel }, function() Net.Send("Shop.Buy", id, 1) end)
Kit.Create("Frame", { ... }, Kit.Corner(6), Kit.Padding(8), Kit.List())   -- Kinder als weitere Argumente
Kit.Tween(obj, 0.2, { BackgroundTransparency = 1 });  Kit.Pop(label)
```

Farben und Schrift nur aus `Kit.Theme`. Größen in Pixeln (Offset); Knöpfe mindestens 44 hoch. Fenster bauen sich bei Datenänderung am einfachsten komplett neu auf (`DataController:Observe` → Inhalt leeren → neu füllen).

## Ton und Einstellungen

Töne und Musik stehen als Tabelle in `shared/Config/Sounds.luau` (Name → Id, Lautstärke, Tonhöhen-Streuung). Eine leere Id bleibt still, bis ein Ton ausgesucht ist.

```lua
SoundController:Play("Coin")                        -- Client, überall gleich laut
SoundController:PlayAt("Explosion", position)       -- Client, in der Welt (wird mit Entfernung leiser)
Net.Fire("Sound.Play", player, "Purchase")          -- Server → ein Spieler
Net.FireNear("Sound.Play", position, 120, "Explosion", position)   -- Server → alle in der Nähe, mit Ort
SoundController:PlayMusic("rbxassetid://…")         -- einzelnes Stück; ohne Angabe läuft die Liste Sounds.Music
```

Von selbst klingen: jeder `Kit.Button` (`Click`) und jede Meldung (`Notify`, `Success`, `Error`, `Announcement`). Genre-eigene Töne entweder in `Sounds.Effects` eintragen oder die Id direkt übergeben. Töne nicht mehr von Hand mit `Instance.new("Sound")` abspielen, sonst greift die Lautstärke-Einstellung nicht.

Das Einstellungs-Fenster (`SettingsController`, Knopf „Menü" am linken Rand oder Taste P) zeigt, was in `GameConfig.Settings.Entries` steht. Zahlen erscheinen als Regler von 0 bis 100 %, Wahrheitswerte als Schalter. Neue Einstellung: Feld in `DataSections/Core.luau` unter `Settings` anlegen, in `Entries` eintragen, im eigenen Controller mit `DataController:Observe("Settings.<Feld>", …)` anwenden. Der `SettingsService` nimmt nur eingetragene Felder an. Bekommt das Spiel ein eigenes Hauptmenü: `ShowButton = false` und `SettingsController:Open()` von dort aufrufen.

## Hilfsmodule (`shared/Util`)

| Modul | Wofür |
|---|---|
| `Signal` | eigene Ereignisse: `Signal.new()`, `:Connect`, `:Once`, `:Fire`, `:Wait` |
| `Trove` | alles Aufzuräumende sammeln: `trove:Connect(signal, fn)`, `trove:Add(instanz/funktion/thread)`, `trove:Clean()` |
| `Spring` | gedämpfte Feder auf Vector3 (Rückstoß, Schwanken, Wackeln) |
| `Format` | `Number(1234) → "1.23K"`, `Commas`, `Time`, `TimeMs`, `Percent` |
| `TablePath` | verschachtelte Tabellen über Pfade lesen/schreiben, `DeepCopy`, `Reconcile` |
| `CommandParser` | Eingabezeilen der Konsole zerlegen |

## Tests

Logik ohne `game`/`script` (Formeln, Parser, Zufallstabellen, Inventar-Buchhaltung) in eigene Module legen und in `tests/<Name>.spec.luau` absichern; `check_projekt.py` führt sie mit lune aus. Vorlage: `tests/Daten.spec.luau`. In Tests gibt es kein Vector3 und keine Instanzen, deshalb solchen Modulen Zahlen statt Vektoren geben.

Drei Tests bringt jedes Projekt mit, sie prüfen den ganzen Code unter `src/` auf Namen, die nur als Text dastehen und die deshalb keine Typprüfung findet: `Netz.spec.luau` (jedes `Net.Send/Call/Listen` hat sein Gegenstück auf dem Server, gleiche Anzahl Werte), `Spielstand.spec.luau` (jeder benutzte Spielstand-Pfad steht in `Config/DataSections`) und `Ton.spec.luau` (jeder abgespielte Ton steht in `Config/Sounds`). Schlagen sie an, ist fast immer ein Name vertippt.

## Stilregeln

- Erste Zeile `--!strict`. Typen an Funktionsgrenzen angeben.
- `task.wait/spawn/delay/defer`; nie `wait`, `spawn`, `delay`.
- `:Connect` (groß). Verbindungen pro Spieler/Runde/Objekt in einen `Trove`.
- `game:GetService("X")` oben, alphabetisch; danach `require`s.
- Schaden über `Humanoid:TakeDamage()` (beachtet Gott-Modus und Spawn-Schutz), nie `Health -= x`.
- Eine Schleife für viele Objekte (alle Gegner, alle Projektile), nicht ein Thread pro Objekt.
- Schleifen über `x or {}` vermeiden; erst einer getypten Variablen zuweisen (`local list: { T } = x or {}`).
- Gemischte Tabellen-Listen brauchen `:: { any }`; Tabellenschlüssel mit Umlauten als `["Glück"]`.
- `pcall` um alles, was ins Netz geht (DataStore, MarketplaceService, Filter, Teleport).
- Text, den andere Spieler sehen und ein Spieler eingegeben hat, durch `TextService:FilterStringAsync`.

## Rezepte

**Neues Feature „Shop":** `shared/Config/Shop.luau` (Angebote) → `shared/Config/DataSections/Shop.luau` (falls es etwas speichert) → `server/Services/ShopService.luau` → `client/Controllers/ShopController.luau` → `server/Admin/Commands/Shop.luau` → Punkt in `PLAN.md`.

**Neuer Inhalt (Waffe, Gegner, Item):** Eintrag in der Config-Tabelle. Braucht es dafür neuen Code, ist die Tabelle zu schwach – dann ein Feld ergänzen, das der Code allgemein auswertet.

**Zweites Genre dazunehmen:** Dateien aus `assets/genres/<genre>/src` gezielt kopieren. Doppelte Namen prüfen (Remotes, Tags, DataSections) und Überschneidungen auflösen (z. B. nur ein Schadenssystem).
