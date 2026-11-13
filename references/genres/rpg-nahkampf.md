# RPG / Nahkampf

Schlagen mit Kombo, Ausweichrolle, Gegner mit einfacher KI, Erfahrung und Stufen, Quests aus Tabellen.

## Dateien (`assets/genres/rpg-nahkampf/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/Rpg.luau` | Kampfwerte, Ausweichrolle, Stufenkurve, Gegner, Quests, **Welt-Vertrag** |
| `shared/Rpg/Formulas.luau` | XP je Stufe, Stufe aus Gesamt-XP, Leben, Schaden – getestet |
| `server/Services/CombatService.luau` | Schlag (Trefferzone aus Serversicht, Kombo), Ausweichrolle (Unverwundbarkeit) |
| `server/Services/EnemyService.luau` | Gegner erscheinen lassen, KI-Schleife, Schaden verbuchen, Signal `Killed` |
| `server/Services/ProgressService.luau` | XP, Stufenaufstieg, Leben je Stufe, Quests annehmen/zählen/abholen |
| `client/Controllers/RpgController.luau` | Eingaben, Armschwung ohne Animations-Datei, Schadenszahlen, XP-Balken, Quest-Fenster |
| `server/Admin/Commands/Rpg.luau` | `xp`, `spawnenemy <typ> [anzahl]` |
| `tests/Rpg.spec.luau` | Tests der Formeln |

## Aufteilung, die man kennen muss

- **Nahkampf prüft der Server selbst:** Der Client meldet nur „Schlag". Der Server legt einen Kasten vor den Charakter (seine eigene Position) und trifft, was darin steht. Anders als beim Shooter meldet der Client keine Treffer.
- **Gegner:** eine Schleife für alle (5-mal pro Sekunde), Server besitzt ihre Physik.
- **Belohnung** bekommt, wer am meisten Schaden gemacht hat (`EnemyService.Killed`). Quests und XP hängen an diesem Signal, der Kampf weiß nichts von ihnen.
- **Gespeichert wird Gesamt-XP;** die Stufe wird berechnet.

## Welt-Vertrag

| Tag | Klasse | Attribute |
|---|---|---|
| `EnemySpawn` | BasePart | `Enemy` (Schlüssel aus `Enemies`) |

Eigenes Gegnermodell (optional): `ServerStorage.Assets.Enemies.<Schlüssel>` (Model mit Humanoid, PrimaryPart = HumanoidRootPart). Aus Blender: Figur in Einzelteilen bauen, mit `assets/weltbau/rig_bauen.luau` einbauen (`Humanoid = true`, `Parent = "ServerStorage.Assets.Enemies"`, `Name` = Schlüssel); mit dem Tag `AnimatedRig` läuft sie von selbst (`references/modelle-blender.md`).

## Was ein gutes RPG ausmacht

- **Kampf mit Gewicht:** Ausholen, Treffer-Ton, Schadenszahl, Gegner zuckt zurück. Jeder Schlag muss spürbar sein.
- **Gegner sind lesbar:** Angriff kündigt sich an (kurze Pause, Aufleuchten), damit Ausweichen eine Fähigkeit ist und kein Glück.
- **Stufenkurve:** die erste Stufe nach 1 bis 2 Minuten, dann langsamer. Jede Stufe gibt etwas Spürbares.
- **Gebiete nach Stärke gestaffelt**, mit sichtbaren Grenzen (Brücke, Tor), damit niemand versehentlich in zu starke Gegner läuft.
- **Quests führen** durch die Welt und erklären nebenbei die Mechaniken.
- Ausrüstung macht den Fortschritt sichtbar → Modul `inventar` (`InventoryService.Equipped` → Schaden der Waffe anwenden).

## Erweitern

- **Gegner/Quest:** Tabelleneintrag.
- **Neue Quest-Art** (sammle, sprich mit, erreiche): Feld `Type` in der Quest und ein Aufruf von `advance` beim passenden Ereignis.
- **Fernkampf-Gegner, Boss-Phasen, Flucht:** Zustände in `think` (EnemyService), über Felder am Gegnertyp schaltbar.
- **Fähigkeiten mit Abklingzeit:** Muster aus `battlegrounds` übernehmen.
- **Waffe in der Hand:** Modell an `RightHand` schweißen (Vorgehen wie `showHeldWeapon` im Ego-Shooter).
- **Beute:** in `Killed` würfeln und `InventoryService:Give` aufrufen.

## Stolperfallen

- Block-Gegner brauchen `RigType = R15`, `HipHeight`, `RequiresNeck = false` (steht in `blockModel`), sonst schweben oder sterben sie.
- `root:SetNetworkOwner(nil)` für Gegner, sonst ruckeln sie oder lassen sich wegschieben.
- Schaden an Spielern über `TakeDamage`; die Ausweichrolle prüft das Attribut `DodgeUntil` (Serverzeit).
- PvP ist aus (`Config.PvP`); einschalten nur mit sicheren Zonen.
- Quest als erledigt vermerken, **bevor** die Belohnung gutgeschrieben wird.

## Erstprüfung in Studio

1. Welt: Fläche mit drei `EnemySpawn` (`Slime`).
2. Spieltest: Gegner stehen da, schlendern, verfolgen bei Annäherung, machen Schaden.
3. Schlagen (Mausklick): Arm schwingt, Schadenszahl, Lebensbalken sinkt; Kombo bis zum dritten Schlag.
4. Besiegen: XP-Balken steigt; `xp 500` → Stufenaufstieg mit Meldung, Leben erhöht.
5. Quest-Fenster (`J`): annehmen, 5 Schleime (`spawnenemy Slime 5`), abholen. Ausgabe ohne Fehler.
