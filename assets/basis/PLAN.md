# Plan: {{NAME}}

> Diese Datei ist das Gedächtnis des Projekts. Claude liest sie zu Beginn jeder Sitzung
> und aktualisiert sie nach jedem Arbeitsschritt: Erledigtes abhaken, „Zuletzt gemacht"
> ergänzen, „Als Nächstes" neu ordnen. Neue Aufgaben kommen als neue Zeilen dazu.

| | |
|---|---|
| Genre | {{GENRE}} |
| Module | {{MODULE}} |
| Angelegt | {{DATUM}} |
| Skill-Referenzen | {{REFERENZEN}} |

## Spielidee

_Noch offen: 3 bis 5 Sätze. Was tut der Spieler, warum macht das Spaß, was ist das Ziel?_

## Kernschleife

_Noch offen: Was macht der Spieler in den ersten 30 Sekunden, nach 5 Minuten, nach einer Stunde?_

## Als Nächstes

1. Spielidee und Kernschleife oben ausfüllen
2. Phase 0 abschließen

## Zuletzt gemacht

- {{DATUM}}: Projekt aus dem Grundgerüst angelegt ({{GENRE}})

## Phase 0 – Einrichtung

- [x] Projekt angelegt
- [ ] `rokit install` im Projektordner ausgeführt
- [ ] `rojo serve` läuft und Studio ist über das Rojo-Plugin verbunden
- [ ] Studio-MCP verbunden (Claude kann Studio steuern und testen)
- [ ] Erster Spieltest: keine Fehler in der Ausgabe, Konsole öffnet mit T, `fly` funktioniert
- [ ] `src/shared/Config/GameConfig.luau`: Admins eingetragen

{{GENRE_PLAN}}

{{MODUL_PLAN}}

## Phase 3 – Spielgefühl und Oberfläche

- [ ] Jede Spieleraktion hat eine Rückmeldung (Ton, Effekt oder Meldung)
- [ ] Oberfläche auf Handy-Größe geprüft (Geräte-Emulator in Studio)
- [ ] Steuerung mit Touch und Controller geprüft
- [ ] Einstieg: Ein neuer Spieler versteht ohne Text-Wand, was zu tun ist
- [ ] Töne ausgesucht und in `src/shared/Config/Sounds.luau` eingetragen (Klick, Erfolg, Fehler und die Töne des Genres)
- [ ] Musik eingetragen; Lautstärke im Einstellungs-Fenster (Taste P) geprüft

## Eigene Assets

_Nur nötig, wenn das Spiel eigene Modelle, Texturen oder Effekt-Bilder bekommt (Blender, PhotoCraft).
Jeder Upload kommt als Zeile hierher. Vor jedem Hochladen wird gefragt: Es bleibt dauerhaft im Roblox-Konto._

| Name | Art | Quelle (`quellen/`) | Datei (`export/`) | Asset-Nummer | Eingebaut in | Stand |
|---|---|---|---|---|---|---|

- [ ] Blender-Verbindung geprüft (Würfel bauen, Bild der 3D-Ansicht)
- [ ] `export/` in Studio für das Hochladen freigegeben, Asset-Rechte eingeschaltet
- [ ] Effekt-Bilder erzeugt, hochgeladen und in `src/shared/Config/AssetIds.luau` eingetragen

## Phase 4 – Vor Veröffentlichung

- [ ] Test mit 2 oder mehr Spielern (Studio: Test → Server und Clients)
- [ ] Spielstand: speichern, verlassen, neu beitreten, alles noch da
- [ ] `GameConfig.Data.SaveInStudio` steht auf `false`
- [ ] Sicherheit: Jedes Remote prüft seine Eingaben, der Server entscheidet über Geld, Schaden und Fortschritt
- [ ] Leistung: Server-Herzschlag stabil, keine Fehlermeldungen in der Ausgabe
- [ ] Spielseite: Symbol, Vorschaubilder, Beschreibung
- [ ] In Spieleinstellungen: API-Dienste für DataStores eingeschaltet

## Entscheidungen

_Wichtige Festlegungen mit kurzer Begründung, damit sie später nicht versehentlich umgeworfen werden._

## Bekannte Probleme

_Fehler und offene Fragen, die noch nicht gelöst sind._
