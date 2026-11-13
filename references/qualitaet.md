# Qualität: Was ein gutes Roblox-Spiel ausmacht

Checklisten für „fühlt sich gut an", „läuft überall" und „ist sicher". Vor dem Abhaken einer Phase in `PLAN.md` den passenden Abschnitt durchgehen.

## 1. Kernschleife

Die Kernschleife ist das, was der Spieler immer wieder tut (schießen → Punkte → bessere Waffe; springen → Checkpoint → nächste Stufe).

- In **30 Sekunden** nach dem Beitritt tut der Spieler bereits das, worum es geht. Kein Menü, keine Textwand davor.
- Nach **5 Minuten** hat er etwas erreicht und sieht das nächste Ziel.
- Es gibt immer ein kurzes Ziel (nächste Minute), ein mittleres (diese Sitzung) und ein langes (diese Woche).
- Erst wenn die Kernschleife ohne alles Drumherum Spaß macht, kommen Shop, Pets, Tagesbelohnung, Ranglisten.

## 2. Spielgefühl („Juice")

Jede Aktion des Spielers bekommt sofort eine Antwort – am besten auf mehreren Kanälen:

| Kanal | Beispiele | Mittel im Projekt |
|---|---|---|
| Bild | Aufploppen, Aufblitzen, Zahl steigt hoch | `Kit.Pop`, `Kit.Tween`, Schadenszahlen |
| Ton | Klick, Treffer, Münze, Fehler | `SoundController:Play("Coin")`, in der Welt `:PlayAt(name, position)`, vom Server `Net.Fire("Sound.Play", player, "Coin")`. Töne stehen in `Config/Sounds.luau` (Ids über `search_asset` suchen; leere Id = still). Knöpfe und Meldungen klingen von selbst. |
| Bewegung | Rückstoß, Kamerawackeln, Federn | `Spring` |
| Text | „+25", „Checkpoint 4", „Nicht genug Münzen" | `NotificationController:Notify` |

- **Der Client reagiert sofort**, der Server bestätigt. Auf die Antwort des Servers zu warten, bevor etwas sichtbar passiert, fühlt sich zäh an.
- Fehlschläge erklären sich selbst („Zu weit weg", „Lädt noch 3 s"), statt dass einfach nichts passiert.
- Ohne Ton wirkt alles halb fertig. Die Lautstärke regelt der Spieler im Einstellungs-Fenster (Knopf „Menü" oder Taste P; `SettingsController`, Einträge in `GameConfig.Settings`). Musik: Liste `Music` in `Config/Sounds.luau`.
- Lieber einfache, saubere Bewegung aus Mathematik (Feder, Sinus, Tween) als eine halbgare Animation.

## 3. Oberfläche

- Aufbau mit `Kit`: einheitliche Farben, Schrift, Abstände.
- Wichtiges groß und nah an der Mitte, Dauer-Anzeigen klein am Rand.
- Nicht in die Ecke oben links (Roblox-Menü) und nicht unter die Sprungtaste rechts unten (Handy).
- Höchstens ein Fenster gleichzeitig offen; jedes hat ein großes **X**.
- Texte kurz. Zahlen mit `Format.Number` (1.2K) bzw. `Format.Commas`.
- Im Geräte-Emulator von Studio auf einem kleinen Handy und einem großen Monitor ansehen.

## 4. Jedes Gerät

Der größte Teil der Roblox-Spieler ist am Handy.

- Eingaben über `ContextActionService:BindAction(name, fn, true, Taste, ControllerTaste)`: Das `true` erzeugt automatisch einen Touch-Knopf. `SetTitle` und `SetPosition` setzen.
- Bewegung nie selbst abfragen (WASD); `Humanoid.MoveDirection` gilt für Tastatur, Stick und Touch gleichermaßen.
- Interaktionen in der Welt über `ProximityPrompt` (funktioniert überall ohne eigenen Code).
- Knöpfe mindestens 44 Pixel hoch.
- Kein Feature darf nur per Tastatur erreichbar sein.

## 5. Sicherheit

Annahme: Ein Schummler kann jedes Remote jederzeit mit beliebigen Werten aufrufen, seinen Charakter überallhin setzen und alles lesen, was der Client sieht.

- Geld, Schaden, Fortschritt, Beute, Zufall: **entscheidet nur der Server**.
- Der Client schickt Absichten (Ids, Tastendrücke), keine Ergebnisse (Beträge, Schaden, „ich habe gewonnen").
- Jedes Remote: Typprüfung (`Check`) + Aufrufgrenze (`Rate`) + Logikprüfung im Handler (Besitz, Abstand, Abklingzeit, Zustand).
- Abstände prüft der Server mit **seinen** Positionen.
- Nichts Geheimes in `shared` oder `ReplicatedStorage` (Lösungen, Gewinnchancen sind dagegen ruhig öffentlich).
- Eingegebener Text, den andere sehen: durch den Roblox-Filter.
- Fremde Modelle aus dem Creator Store: enthaltene Skripte löschen.
- `check_projekt.py` findet einen Teil davon (Hausregeln), ersetzt aber nicht das Nachdenken pro Remote.

Pro Remote eine Frage stellen: *„Was passiert, wenn ein Spieler das 100-mal pro Sekunde mit den schlimmsten denkbaren Werten aufruft?"*

## 6. Leistung

- Eine Schleife für viele Objekte statt ein Thread/Skript pro Objekt.
- Nichts jeden Frame tun, was auch 5-mal pro Sekunde reicht (KI, Bereichsprüfung, Anzeige-Texte).
- Viele gleichartige Dinge (Gegner in Tower Defense, Projektile) als **Daten** auf dem Server, Darstellung auf dem Client.
- Häufige, verlustfreundliche Daten über unzuverlässige Remotes (`Unreliable = true`), gebündelt.
- Effekte nur an Spieler in der Nähe (`Net.FireNear`).
- Alles pro Spieler/Runde/Objekt in einem `Trove` und beim Ende aufräumen (sonst Speicherleck).
- Obergrenzen für alles, was Spieler erzeugen können (Bauteile, Tropfen, Türme).
- Im Spieltest: Fenster „Leistung" bzw. Shift+F5 (Bildrate); Server-Ausgabe frei von Warnungen.

## 7. Einstieg neuer Spieler

- Kein Tutorial-Text, der gelesen werden muss. Die Welt zeigt, was zu tun ist: Pfeil, Leuchten, ein erstes Ziel in Sichtweite.
- Der erste Erfolg kommt in der ersten Minute.
- Eine Mechanik nach der anderen einführen.
- Sterben oder Scheitern kostet am Anfang fast nichts.

## 8. Fairness

- Nichts, was Zeit kostet, wird künstlich gestreckt, um zum Kauf zu drängen.
- Zufall mit angezeigten Chancen.
- Belohnungen fürs Spielen (Tagesbelohnung, Spielzeit, Quests) statt Bestrafung fürs Wegbleiben.
- Kein Feature, das nur zahlende Spieler haben und das andere im Wettbewerb schlägt.
- Details und Käufe: `monetarisierung.md` (nur wenn der Nutzer Käufe wünscht).

## 9. Vor der Veröffentlichung

- Zwei-Spieler-Test in Studio.
- Speichern → verlassen → wiederkommen geprüft.
- `GameConfig.Data.SaveInStudio = false`, Admins eingetragen, `MinPlayers` der Runden auf echte Werte.
- Ausgabe von Server und Client ohne Fehler.
- Spielseite: Symbol, Vorschaubilder, ehrliche Beschreibung, passende Altersfreigabe (Fragebogen im Creator Hub).
- Nach dem Start: Rückmeldungen lesen, in `PLAN.md` als Punkte aufnehmen.
