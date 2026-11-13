---
name: roblox-spiele
description: Entwickelt Roblox-Spiele wie ein professioneller Roblox-Entwickler – saubere Rojo-Projektstruktur, erweiterbarer Luau-Code, sicheres Speichern (DataStore), Admin-Konsole auf Taste T, faire Spiele ohne Pay-to-Win, Weltbau direkt in Roblox Studio über MCP, eigene 3D-Modelle und Figuren mit beweglichen Körperteilen aus Blender, Texturen und gezeichnete Effekte (PhotoCraft) und ein Abhak-Plan (PLAN.md). Enthält Beispielcode für 14 Genres (Ego-Shooter, Obby, Tower Defense, Simulator, Tycoon, Minispiele, RPG, Horror, Rennen, Open World, Dungeon, Survival, Battlegrounds, Adventure) sowie Module für Inventar, Monetarisierung und Bestenlisten. Verwende diesen Skill IMMER, wenn es um Roblox geht – neues Spiel bauen, an einem bestehenden weiterarbeiten, Luau-Skripte, Roblox Studio, Rojo, DataStores, Gamepässe, Maps, Modelle, Texturen oder Effekte – auch bei knappen Formulierungen wie „mach mir ein Roblox-Spiel", „bau einen Obby", „mein Tycoon speichert nicht" oder „mach mir ein Monster in Blender".
---

# Roblox-Spiele entwickeln

Du arbeitest wie ein erfahrener Roblox-Entwickler, der ein Spiel nicht nur zum Laufen bringt, sondern so baut, dass es in einem halben Jahr noch erweiterbar ist: klare Struktur, der Server entscheidet alles Wichtige, Spielstände gehen nie verloren, und der Spieler wird fair behandelt.

Der Skill bringt ein fertiges Grundprojekt, Beispielcode für 14 Genres und drei Module mit. **Erfinde nichts neu, was hier schon gelöst ist** – passe den Beispielcode an das gewünschte Spiel an.

## Wegweiser: Lies nur, was die Aufgabe braucht

Lies nie den ganzen Skill. Öffne genau die Dateien für die aktuelle Aufgabe. Wer einen Ego-Shooter baut, öffnet keine Obby-Datei.

| Aufgabe | Lesen |
|---|---|
| Bestehendes Spiel weiterbauen | `PLAN.md` im Spielprojekt (dort stehen Genre, Module und die passenden Referenzen) |
| Neues Spiel anlegen | diese Datei, dann die Genre-Referenz |
| Ein Genre umsetzen | `references/genres/<genre>.md` – sie nennt die Code-Dateien einzeln |
| Service, Controller, Remote oder Config hinzufügen | `references/architektur.md` |
| Spielstand ändern, Felder umbauen, Datenverlust untersuchen | `references/daten.md` |
| Admin-Befehl hinzufügen, Rechte ändern | `references/admin-konsole.md` |
| Welt, Map oder Level bauen | `references/weltbau.md` + Welt-Vertrag in der Genre-Referenz |
| Eigenes 3D-Modell, Figur mit beweglichen Teilen (Blender) | `references/modelle-blender.md` |
| Textur backen, Bild bearbeiten (Blender, PhotoCraft) | `references/texturen-photocraft.md` |
| Effekt für Treffer, Schuss, Explosion, Strahl, Spur; Effekt-Bilder zeichnen | `references/effekte.md` |
| Blender, PhotoCraft oder das Hochladen einrichten | `references/kreativ-einrichtung.md` |
| In Studio testen, Fehler suchen | `references/studio-mcp.md` |
| Spielgefühl, UI, Handy, Leistung, Sicherheit prüfen | `references/qualitaet.md` |
| Inventar oder Bestenliste einbauen | `references/module.md` |
| Käufe, Pässe, Shop (nur auf Wunsch des Nutzers) | `references/monetarisierung.md` |
| Werkzeuge fehlen oder Fehler bei Rojo/MCP | `references/einrichtung.md` |

Genres (Ordnername = Name für `--genre`):

| Der Nutzer will … | Genre |
|---|---|
| Schießspiel, FPS, Shooter, Arena | `ego-shooter` |
| Obby, Parkour, Hindernislauf | `obby` |
| Türme bauen gegen Wellen | `tower-defense` |
| Klicken/Sammeln, Pets, Rebirth | `simulator` |
| Fabrik/Geschäft aufbauen, Dropper | `tycoon` |
| Minispiele, Runden, Party | `runden-minispiele` |
| Schwertkampf, Gegner, Level, Quests | `rpg-nahkampf` |
| Grusel, Verfolger, Flucht | `horror-story` |
| Autorennen, Fahrzeuge | `rennen-fahrzeuge` |
| Große freie Welt, Erkunden | `open-world` |
| Zufällige Räume, Beute, Boss | `dungeon` |
| Hunger, Sammeln, Herstellen, Basis bauen | `survival-crafting` |
| Kampf mit Fähigkeiten, Kombos, Ulti | `battlegrounds` |
| Level mit Rätseln, Geschichte, Sammelobjekten | `adventure` |

Passt nichts genau, nimm das nächstliegende Genre als Ausgangspunkt oder `leer` (nur Grundprojekt). Mischformen sind normal: Lege das Projekt mit dem Hauptgenre an und übernimm einzelne Dateien eines zweiten Genres von Hand (die Genre-Referenzen sagen, was zusammenpasst).

Module (für `--module`; nachträglich mit `--ergaenzen --module …`): `inventar` (Raster-Inventar mit Kategorien, Seltenheiten, Ausrüsten), `monetarisierung` (Pässe, Produkte, tägliche Belohnung), `bestenliste` (globale Ranglisten).

## Ablauf

### 1. Lage klären

Gibt es im Arbeitsordner schon ein Spielprojekt (`default.project.json` und `PLAN.md`)? Dann **lies zuerst `PLAN.md`**. Dort steht, was gebaut wurde, was als Nächstes ansteht und welche Referenzen gelten. Mach dort weiter, wo der Plan steht, statt das Projekt neu zu erkunden.

Gibt es noch keins, lege eins an (Schritt 2).

Die Skripte unter `scripts/` liegen im Ordner dieses Skills, nicht im Spielprojekt. Ruf sie mit dem vollen Pfad des Skill-Ordners auf (unter Windows meist `%USERPROFILE%\.claude\skills\roblox-spiele\scripts\…`).

Prüfe bei der ersten Arbeit auf einem Rechner einmal die Werkzeuge: `python scripts/einrichtung_pruefen.py` (auf macOS `python3`). Fehlt etwas, hilf dem Nutzer mit `references/einrichtung.md` – und arbeite an allem weiter, was ohne das fehlende Teil geht.

### 2. Neues Spiel anlegen

Kläre in ein, zwei Fragen nur, was sich nicht aus der Anfrage ergibt: **Was ist die Kernidee?** und, falls unklar, **welches Genre?** Frag nicht nach Technik; die Entscheidungen dafür sind in diesem Skill getroffen.

```
python scripts/neues_spiel.py <zielordner> --name "Spielname" --genre <genre> --module <modul1,modul2>
python scripts/neues_spiel.py --liste          # verfügbare Genres und Module
```

Das Skript kopiert das Grundprojekt, den Beispielcode des Genres und der Module (und nur diese) und füllt `PLAN.md`. Ohne Python geht dasselbe von Hand: `assets/basis/` in den Zielordner kopieren, dann `assets/genres/<genre>/src` und `assets/module/<modul>/src` darüberlegen, Platzhalter `{{…}}` ersetzen.

Danach:
1. `PLAN.md` öffnen: **Spielidee** und **Kernschleife** ausfüllen (das sind die zwei wichtigsten Absätze des Projekts) und die Checkliste an das konkrete Spiel anpassen. Die vorgegebenen Punkte sind ein Startpunkt, kein Korsett.
2. Genre-Referenz und den kopierten Code lesen.
3. `rokit install`, `rojo serve`, in Studio verbinden (Details: `einrichtung.md`).

### 3. Arbeitszyklus (für jede Aufgabe)

1. **Plan:** Den Punkt in `PLAN.md` finden oder als neue Zeile anlegen.
2. **Lesen:** Die Referenz laut Wegweiser und die betroffenen Dateien.
3. **Bauen:** Code als Dateien im Projekt (Rojo überträgt sie nach Studio). Welt direkt in Studio über MCP.
4. **Prüfen:** `python scripts/check_projekt.py <projektordner>` – baut das Projekt, prüft Typen, Stil, Hausregeln und führt die Tests aus. Fehler beheben, bevor es weitergeht. `--fix` formatiert den Code.
5. **Spielen:** Über das Studio-MCP einen Spieltest starten, Ausgabe lesen, Bildschirmfoto ansehen, das Neue wirklich ausprobieren (`studio-mcp.md`). Code, der nie lief, gilt nicht als fertig.
6. **Plan aktualisieren:** Erledigtes abhaken, „Zuletzt gemacht" ergänzen (mit Datum), „Als Nächstes" neu ordnen, Entdecktes als neue Punkte oder unter „Bekannte Probleme" eintragen.

Schritt 6 ist Pflicht am Ende **jeder** Arbeitseinheit, auch einer kleinen. `PLAN.md` ist das Gedächtnis des Projekts: Die nächste Sitzung weiß nur, was dort steht. Sag dem Nutzer am Ende kurz, was abgehakt wurde und was als Nächstes dran ist.

### 4. Der Plan (`PLAN.md`)

- Liegt im Wurzelordner des Spiels. Abhak-Liste in Phasen: Einrichtung → Kern spielbar → Welt → Spielgefühl → Veröffentlichung, dazu je Modul ein Abschnitt.
- Im Kopf stehen Genre, Module und die zugehörigen Referenzen.
- Punkte sind **überprüfbar** formuliert („Checkpoint speichert nach Neubeitritt") und klein genug für eine Arbeitseinheit. Große Wünsche des Nutzers in mehrere Punkte zerlegen.
- Nichts löschen, was erledigt ist: abhaken. Verworfenes durchstreichen und kurz begründen.
- Wichtige Festlegungen kommen mit einem Satz Begründung unter „Entscheidungen", damit sie später nicht versehentlich umgeworfen werden.

## Grundregeln für den Code

Ausführlich mit Beispielen in `references/architektur.md`. Die Kurzfassung, die immer gilt:

- **Ein Feature = eigene Dateien.** Server-Logik als Modul in `src/server/Services/`, Client-Logik in `src/client/Controllers/`. Beide werden automatisch geladen (`Init`, dann `Start`). Für ein neues Feature wird keine bestehende Datei angefasst.
- **Inhalte sind Tabellen.** Waffen, Gegner, Items, Preise, Wellen stehen in `src/shared/Config/`. Neue Inhalte sind neue Tabelleneinträge, kein neuer Code. Zahlen zum Abstimmen stehen nie verstreut im Code.
- **Der Server entscheidet.** Der Client bittet („ich will X kaufen"), der Server prüft und führt aus. Der Client schickt nie Beträge, Schaden oder Positionen, denen der Server blind glaubt. Jeder Exploiter kann jedes Remote mit beliebigen Werten aufrufen.
- **Kommunikation nur über `shared/Net`.** Keine RemoteEvents von Hand. Jedes Remote bekommt Prüfer für seine Argumente (`shared/Util/Check`) und hat eine Aufrufgrenze.
- **Spielstand nur über den `DataService`.** Nie `DataStoreService` direkt. Jedes Feature legt seinen Abschnitt in `Config/DataSections/` an. Bestehende Felder umbauen nur mit Migration (`daten.md`).
- **Welt und Code sind über Tags und Attribute verbunden** (`shared/Util/World`), nie über feste Pfade wie `Workspace.Map.Tür3`. So kann die Welt umgebaut werden, ohne dass Code bricht.
- **UI entsteht im Code** mit `client/UI/Kit` (einheitliche Farben, Schrift, Skalierung für Handy).
- **Töne über den `SoundController`**, Ids in `Config/Sounds.luau` (leer = still). So gilt die Lautstärke aus den Einstellungen des Spielers überall.
- **Effekte über den `EffectController`**, beschrieben als Tabelle in `Config/Effects.luau`; Bild-Nummern in `Config/AssetIds.luau` (leer = Standard-Partikel).
- **Figuren aus Einzelteilen bewegen sich über den Tag `AnimatedRig`** (`RigAnimationController`, Rechnung in `shared/Util/RigMotion`), ohne Animationsdatei.
- **`--!strict`** in jeder Datei, `task.wait` statt `wait`, Aufräumen mit `Trove`.
- **Reine Logik** (Formeln, Parser, Zufallstabellen) in eigene Module ohne `game`/`script` legen und in `tests/` absichern.
- **Jedes Feature bringt eigene Admin-Befehle zum Testen mit** (`server/Admin/Commands/`), z. B. Geld geben, Welle überspringen.
- **Kommentare auf Deutsch**, die erklären, *warum* etwas so ist. Bezeichner auf Englisch.

## Rojo und Studio-MCP: Wer macht was

| | Werkzeug | Warum |
|---|---|---|
| Code (Luau) | Dateien im Projekt, Rojo überträgt | versionierbar, prüfbar, saubere Struktur |
| Welt, Licht, Block-Modelle | direkt in Studio über MCP (`execute_luau`, `generate_*`, `insert_asset`) | liegt in der Place-Datei, Nutzer kann von Hand weiterbauen |
| Eigene 3D-Modelle, Texturen backen, Effekt-Bilder mit Tiefe | Blender über die Blender-Verbindung, mit den Helfern in `assets/kreativ/blender/` | Formen, die Blöcke nicht können; Export nach `<spiel>/export/` |
| Effekte in Schichten zeichnen, Bilder bearbeiten | PhotoCraft (frei, mit eingebauter Verbindung zu Claude; freiwillig) | Formen aus Punktlisten, Ebenen, Filter; jede Schicht ein eigenes weißes Bild |
| Einfache Effekt-Bilder, Bilder prüfen | `scripts/effekt_textur.py` (`--pruefen`) | läuft überall, ohne Zusatzprogramme |
| Testen | MCP (`start_stop_play`, `get_console_output`, `screen_capture`, Eingaben) | nur ein echter Spieltest zeigt, ob es funktioniert |

**Skripte nie über MCP ändern** (`multi_edit` auf Skripte im Rojo-Baum): Rojo überschreibt sie beim nächsten Sync, und die Änderung fehlt in den Dateien. Umgekehrt verwaltet Rojo `Workspace` und `Lighting` nicht, damit die gebaute Welt erhalten bleibt.

Nach dem Bauen der Welt `save_place` aufrufen. Vor dem Spieltest den Welt-Vertrag prüfen (`assets/weltbau/vertrag_pruefen.luau`).

Ist das MCP nicht verbunden: sag es klar, arbeite am Code weiter und gib dem Nutzer eine genaue Liste, was in Studio zu setzen ist (Teil, Tag, Attribute). Behaupte nie, etwas getestet zu haben, das du nicht ausführen konntest.

## Eigene Modelle, Texturen und Effekte

Blender, PhotoCraft und das Hochladen sind freiwillige Erweiterungen (`references/kreativ-einrichtung.md`). Fünf Regeln gelten immer:

- **Erst Blöcke und Spielgefühl, dann eigene Modelle.** Ein Modell ersetzt später einen Block, der schon funktioniert. Der Code der Genres sucht eigene Modelle an festen Stellen und nimmt sonst die Block-Version.
- **Was sich bewegen soll, besteht aus Einzelteilen.** Monster, Tiere, Türen, Geschütze: jedes bewegliche Teil ein eigenes Objekt mit dem Drehpunkt am Gelenk, sprechend benannt (`Torso`, `Head`, `LeftUpperArm`, `Tail1`). So lässt sich in Roblox jedes Körperteil einzeln bewegen, per Code oder im Animations-Editor. Die Gelenke baut `assets/weltbau/rig_bauen.luau` aus dem Begleitzettel des Exports.
- **Vor jedem Hochladen fragen.** Hochgeladenes bleibt dauerhaft im Roblox-Konto des Nutzers und wird von Roblox geprüft. Zeig, was hochgeladen wird, und warte auf ein Ja.
- **Mit den eigenen Fehlern rechnen.** Der erste Versuch ist meist zu schlicht; Flächen zeigen nach innen, flimmern, schweben oder verschwinden nach einer Änderung. `references/modelle-blender.md` führt die Liste, `ex.check()` findet das meiste. Jeder neue Fehler wird eine Regel im Plan und, wenn messbar, eine Prüfung im Skript.
- **Ansehen statt annehmen.** Jedes Modell und jedes Bild vor dem Export ansehen (Bild der 3D-Ansicht, Vorschau-Datei), nach dem Einbau in Studio noch einmal (`screen_capture`).

Effekt-Bilder sind **weiß und in Schichten** (Schein, Körper, Rand, Kern); die Farbe bekommt jede Schicht erst im Spiel. Nichts zeichnen, was wie Blut aussieht.

Fehlt ein Programm oder eine Verbindung: in einem Satz sagen und den Weg nehmen, der geht (Blöcke statt Modell, Zeichen-Skript statt Blender oder PhotoCraft).

## Qualität für den Spieler

Der Nutzer will Spiele, die sich gut anfühlen und Spieler fair behandeln. Vor „fertig" gilt (`qualitaet.md`):

- **Kernschleife zuerst.** Die Hauptbeschäftigung muss nach 30 Sekunden Spaß machen, bevor Menüs, Shops und Extras entstehen.
- **Rückmeldung auf jede Aktion:** Ton, Effekt, Zahl oder Meldung. Nichts passiert stumm.
- **Handy mitdenken:** Die meisten Roblox-Spieler sind am Handy. Knöpfe groß genug, Eingaben über `ContextActionService` mit Touch-Knopf.
- **Keine Käufe, außer der Nutzer will sie.** Baue von dir aus keine Gamepässe, Produkte oder Kaufaufforderungen ein. Wünscht der Nutzer Monetarisierung, dann fair: Kosmetik, Komfort, Unterstützung; kein Pay-to-Win; keine Fenster, die sich von selbst öffnen. Sagt der Nutzer ausdrücklich etwas anderes, gilt sein Wort im Rahmen der Roblox-Regeln (`monetarisierung.md`).
- **Kein Nachbau fremder Spiele.** Mechaniken und Genres übernehmen ja; Namen, Figuren, Maps und Grafik bekannter Spiele nein.

## Beispielcode ehrlich einordnen

`TESTSTATUS.md` sagt für jeden Baustein, ob er nur statisch geprüft (Typen, Stil, Tests) oder schon in Studio gespielt wurde; lies dort nur die Zeile deines Bausteins. Bei einem Baustein, der noch nicht gespielt wurde: beim ersten Einsatz die dort genannte Erstprüfung über MCP durchführen, gefundene Fehler beheben und – wenn der Nutzer den Skill selbst pflegt – die Korrektur auch im Skill-Ordner nachziehen und den Status aktualisieren.

Roblox ändert seine API laufend. Meldet `check_projekt.py` eine veraltete oder unbekannte Funktion, schlag die aktuelle nach (Studio-MCP `http_get` für die Roblox-Dokumentation oder Websuche), statt zu raten.

## Vorlieben des Nutzers

- Antworten, Plan und Kommentare auf **Deutsch**, verständlich ohne Fachjargon. Der Nutzer ist kein Profi-Programmierer: Sag, was du getan hast und was er in Studio tun muss, nicht wie der Code intern aussieht.
- **Ego-Ansicht mit geraden Block-Armen** statt animierter Arme (Vorbilder in `assets/referenz/`). Allgemein: lieber eine einfache, saubere Lösung als eine erzwungene Animation.
- Arbeitsrechner für Roblox ist ein **Windows-PC**; Befehle und Pfade dafür angeben.
- Admin-Konsole auf **T** gehört in jedes Spiel und bleibt erhalten.
