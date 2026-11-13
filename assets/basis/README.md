# {{NAME}}

Roblox-Spiel, entwickelt mit Rojo (Code als Dateien) und Roblox Studio (Welt).

## Starten

```
rokit install          # einmalig: Rojo und Prüfwerkzeuge in der richtigen Version
rojo serve             # Code live nach Studio übertragen
```

In Studio: Plugins → Rojo → Connect. Danach Play drücken.

## Aufbau

```
src/
├── server/            → ServerScriptService.Server
│   ├── Main.server.luau     Einstieg, lädt alle Services
│   ├── Services/            ein Modul pro Feature (wird automatisch geladen)
│   ├── Admin/               Befehle und Zustände der Konsole (Taste T)
│   ├── Data/                Migration von Spielständen
│   └── Packages/            Fremdmodule (ProfileStore)
├── client/            → StarterPlayerScripts.Client
│   ├── Main.client.luau     Einstieg, lädt alle Controller
│   ├── Controllers/         ein Modul pro Feature (wird automatisch geladen)
│   └── UI/                  UI-Baukasten
└── shared/            → ReplicatedStorage.Shared
    ├── Config/              alle Einstellungen und Inhalte als Tabellen
    ├── Util/                Hilfsmodule
    ├── Net.luau             Kommunikation Server ↔ Client
    └── Loader.luau          lädt Services und Controller
```

Die Welt (Workspace, Beleuchtung) liegt in der Place-Datei in Studio und wird von Rojo
nicht angefasst. Code und Welt sind über Tags und Attribute verbunden.

`PLAN.md` enthält den Stand des Projekts und die nächsten Schritte.
