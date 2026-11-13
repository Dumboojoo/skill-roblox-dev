# Battlegrounds (Fähigkeiten-Kampf)

Arena-Kampf mit wählbaren Kämpfern: Grundschlag-Kombo, drei Fähigkeiten mit Abklingzeit, Blocken, Betäubung, Rückstoß und eine Ulti, die sich durch Schaden auflädt.

## Dateien (`assets/genres/battlegrounds/src/`)

| Datei | Inhalt |
|---|---|
| `shared/Config/Battlegrounds.luau` | Kämpfer und ihre Angriffe (Schaden, Abklingzeit, Ausholzeit, Trefferzone, Betäubung, Rückstoß, Vorwärtssprung), Tasten, Block, Ulti |
| `shared/Battlegrounds/CombatMath.luau` | Block-Regel, Kombo-Zähler, Ulti-Aufladung – getestet |
| `server/Services/AbilityService.luau` | Prüfung und Ausführung aller Angriffe, Trefferzonen aus Serversicht, Betäubung, Block, Ulti, Kills, Kämpferwechsel |
| `client/Controllers/AbilityController.luau` | Eingaben, Abklingzeit-Leiste, Ulti-Balken, Kämpferwahl, sichtbare Trefferzonen, Schadenszahlen, Rückstoß umsetzen |
| `server/Admin/Commands/Battlegrounds.luau` | `ult`, `fighter <name>` |
| `tests/Battlegrounds.spec.luau` | Tests der Kampfregeln |

## Das Prinzip eines Angriffs

Jeder Angriff ist dieselbe kleine Tabelle: nach der **Ausholzeit** (`Windup`) entsteht vor dem Kämpfer eine **Trefferzone** (Kasten mit `Size`, Mitte `Reach` Studs voraus). Wer darin steht, bekommt Schaden, Betäubung, Rückstoß. Optional schnellt der Angreifer nach vorn (`Dash`). Aus diesen Werten entstehen völlig verschiedene Angriffe.

- Der Client meldet nur die Taste. Der Server prüft, wartet die Ausholzeit ab und trifft aus seiner Sicht.
- Während der Ausholzeit zeigen alle Clients die Zone als durchscheinenden Kasten. Das macht Angriffe **lesbar** und Ausweichen möglich.
- **Rückstoß und Sprung** setzt der Client des Betroffenen um (`Battle.Push`), weil jeder Client seinen eigenen Charakter bewegt.
- **Block** wirkt nur von vorn und nimmt Betäubung und Rückstoß weg.

## Welt-Vertrag

Nur eine Arena mit `SpawnLocation`s. Trainingspuppen: Model mit `Humanoid` und `HumanoidRootPart` (nehmen Schaden und Rückstoß).

## Was gute Battlegrounds ausmacht

- **Lesbarkeit:** Jede starke Fähigkeit hat eine sichtbare Ausholzeit. Nichts trifft sicher und sofort.
- **Konter für alles:** Block gegen Frontalangriffe, Ausweichen gegen langsame, Betäubung unterbricht Ausholende.
- **Kämpfer mit Rolle und Schwäche** (schnell und zerbrechlich, langsam und stark, Reichweite). Kein Kämpfer kann alles.
- **Kombos mit Ende:** Betäubungen kurz halten; nach einem Rückstoß ist der Getroffene frei. Endlos-Kombos vertreiben Spieler.
- **Treffer fühlen sich schwer an:** Ton, Kamerawackeln, kurzes Einfrieren, Effekte.
- **Fair:** Kämpfer durch Spielen freischalten; Verkauf höchstens kosmetisch.

## Erweitern

- **Neuer Kämpfer:** Eintrag in `Characters` (genau drei Fähigkeiten + Ulti).
- **Neue Wirkung** (Heilen, Ziehen, Projektil, Flächeneffekt über Zeit): Feld im Typ `Attack`, Auswertung in `resolveHit`/`perform`; Regel in `CombatMath` + Test.
- **Ausweich-Sprint:** eigener Slot ohne Schaden mit `Dash` und kurzer Unverwundbarkeit (Attribut wie `DodgeUntil` im RPG).
- **Effekte je Fähigkeit:** in `showTelegraph`/`Battle.Cast` nach Fähigkeit unterscheiden.
- **Runden und Ranglisten:** `AbilityService.Killed` an `runden-minispiele` bzw. Modul `bestenliste`.

## Stolperfallen

- Wird der Angreifer während der Ausholzeit betäubt, verpufft sein Angriff (so gewollt; macht Unterbrechen möglich).
- Betäubung über ein Attribut mit **Serverzeit** (`StunnedUntil`), nicht über Warten in einer Schleife.
- Laufgeschwindigkeit immer über `applyWalkSpeed` setzen (berücksichtigt Betäubung, Block, Kämpfer).
- Nach dem Tod Block, Betäubung und Abklingzeiten zurücksetzen.
- Schaden über `TakeDamage` (Spawn-Schutz).
- Die Armbewegung nutzt den R15-Schultermotor; mit R6 fehlt sie.

## Erstprüfung in Studio

1. Welt: Fläche, zwei Trainingspuppen (Model, Humanoid, HumanoidRootPart, unverankert).
2. Spieltest: Leiste mit vier Feldern und Ulti-Balken sichtbar.
3. Grundschlag viermal: Zone erscheint, Schadenszahlen, vierter Schlag stößt die Puppe weg.
4. `E`, `R`, `T`: Zonen unterschiedlich groß, Felder laufen ab; Fähigkeit 1 schnellt nach vorn.
5. `ult`, dann `G`: große Zone, Balken leer. `fighter Blade`: Leiste zeigt andere Namen. Block mit zwei Spielern (Nutzer).
