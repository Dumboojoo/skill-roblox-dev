# Horror / Story

Ein Verfolger, der sieht, hört, jagt und sucht; ein Kapitel aus Zielen (Gegenstand finden, Tür öffnen, Ort erreichen); Taschenlampe mit Batterie und Sprint mit Ausdauer.

## Dateien (`assets/genres/horror-story/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/Horror.luau` | Ziel-Liste des Kapitels, Werte des Verfolgers, Taschenlampe, Sprint, **Welt-Vertrag** |
| `server/Services/ChaserService.luau` | Verfolger: Zustände Patrol/Chase/Search, Sicht (Kegel + Sichtlinie), Gehör, Wegfindung, Fangen |
| `server/Services/StoryService.luau` | Ziele der Reihe nach, Gegenstände, Türen mit Schlüssel, Notizen, Zonen; gemeinsamer Stand für alle |
| `client/Controllers/HorrorController.luau` | Taschenlampe, Sprint, Ziel-Anzeige, Notiz-Fenster, pulsierender Bildrand bei Gefahr |
| `server/Admin/Commands/Horror.luau` | `storyskip`, `storyrestart`, `chaser` |

## Welt-Vertrag

| Tag | Klasse | Attribute |
|---|---|---|
| `ChaserSpawn` | BasePart | – (genau einer) |
| `PatrolPoint` | BasePart | `Order` (Zahl): Streifenroute |
| `HideSpot` | BasePart | – (unsichtbarer Kasten; wer darin steht, wird nicht gesehen) |
| `Pickup` | BasePart | `Item` (Text), `DisplayName` (optional) |
| `Door` | BasePart | `DoorId` (Text), `Key` (optional: Item, das sie öffnet) |
| `StoryZone` | BasePart | `Zone` (Text) |
| `Note` | BasePart | `Text` |

Die Tags müssen zur Ziel-Liste in der Config passen (`Item`, `Door`, `Zone`). Eigenes Monster: `ServerStorage.Assets.Chaser`.

## Was guten Horror ausmacht

- **Ton trägt 80 %:** Schritte des Verfolgers (lauter, je näher), Herzschlag, Knarren, Stille davor. Ohne Ton kein Horror.
- **Der Verfolger ist fair und lesbar.** Der Spieler muss verstehen, warum er entdeckt wurde (gesehen, gerannt, Tür geöffnet). Klare Regeln statt Zufall; die Regeln stehen im `ChaserService`.
- **Anspannung und Entspannung wechseln.** Ruhige Abschnitte mit Rätseln, dann Druck. Dauerstress stumpft ab.
- **Wenig zeigen:** Dunkelheit, Nebel, das Monster selten voll im Licht.
- **Rundwege statt Sackgassen**, damit Flucht möglich ist; Verstecke an sinnvollen Stellen.
- **Knappheit:** Batterie und Ausdauer reichen gerade so.
- Rücksicht: `FlashOnCaught` abschaltbar; keine echten Schock-Bilder, altersgerecht bleiben.

## Erweitern

- **Ziel-Arten:** in `complete` (StoryService) einen weiteren Typ behandeln, z. B. „Schalter umlegen" (Rätsel-Kanäle aus `adventure` übernehmen).
- **Lärmquellen:** `ChaserService:MakeNoise(position)` aus beliebigen Ereignissen (umgeworfene Dinge, Alarm).
- **Mehrere Kapitel:** je Kapitel eine Ziel-Liste, Wechsel per Teleport im selben Place oder in einen weiteren Place.
- **Jeder für sich statt gemeinsam:** Stand pro Spieler statt am Workspace führen.
- **Verfolger-Varianten:** blind aber hellhörig, nur im Dunkeln aktiv (Taschenlampe als Schutz).

## Stolperfallen

- Türen und Gänge breit genug für den Verfolger (`AgentRadius` aus seiner Größe); sonst findet er keinen Weg und läuft gegen Wände.
- Wegfindung in `pcall` und nur alle 0,5 s neu berechnen.
- Wer verfolgt wird, kann sich nicht vor den Augen des Verfolgers verstecken (so gewollt).
- Der Sprint läuft auf dem Client (Laufgeschwindigkeit); Lärm misst der Server an der tatsächlichen Geschwindigkeit, nicht an einer Client-Meldung.
- Stimmung kommt aus Studio: Lighting dunkel stellen (`licht.luau`, Stimmung „Horror") und Lichtinseln setzen.

## Erstprüfung in Studio

1. Welt: drei Räume mit Rundweg, `ChaserSpawn`, vier `PatrolPoint`, ein `HideSpot`, `Pickup` (`CellarKey`), `Door` (`Cellar`, Key `CellarKey`), `Pickup` (`Fuse`), `StoryZone` (`Exit`).
2. Spieltest: `chaser` zeigt `Patrol`; Verfolger läuft die Punkte ab (Bildschirmfoto).
3. In Sicht laufen: `Chase`; hinter eine Wand und stehen bleiben: `Search`, dann `Patrol`.
4. Im `HideSpot` warten, bevor er kommt: läuft vorbei.
5. Kapitel durchspielen: Schlüssel, Tür fährt hoch, Sicherung, Ausgang → Abschluss-Meldung. Taschenlampe (`F`) und Sprint-Balken prüfen.
