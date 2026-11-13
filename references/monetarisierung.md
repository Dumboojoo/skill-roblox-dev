# Monetarisierung

**Nur lesen und anwenden, wenn der Nutzer Käufe im Spiel haben will.** Von sich aus baut Claude keine Pässe, Produkte oder Kaufaufforderungen ein. Wünscht der Nutzer etwas anderes als die Leitlinien hier, gilt sein Wort – innerhalb der Roblox-Regeln (Abschnitt 5), denn Verstöße gefährden sein Spiel und sein Konto.

Technik: Modul `monetarisierung` (`python scripts/neues_spiel.py <projekt> --ergaenzen --module monetarisierung`).

## 1. Grundhaltung: fair verdient besser

Spiele, die Spieler respektieren, halten sie länger – und nur Spieler, die bleiben, geben Geld aus. Aggressive Kauf-Fenster bringen kurzfristig etwas und kosten Bewertungen, Empfehlungen und Wiederkehrer.

Die Reihenfolge ist immer: **erst ein Spiel, das Spaß macht, dann Angebote für Leute, die es schon mögen.**

## 2. Was man verkaufen kann

| Art | Beispiele | Einschätzung |
|---|---|---|
| **Kosmetik** | Skins, Farben, Spuren, Effekte, Titel, Emotes, Haus-Deko | ideal: schadet niemandem, wird gern gezeigt |
| **Unterstützung** | „Unterstützer"-Pass mit Abzeichen und goldenem Namen | ehrlich und beliebt, niedriger Preis |
| **Komfort** | mehr Inventarplätze, zweiter Speicherplatz, schnelleres Laufen in der Lobby, Auto-Sammeln | gut, solange das Spiel ohne nicht nervt |
| **Inhalt** | zusätzliche Kämpfer, Level, Spielmodi | gut, wenn das Grundspiel vollständig ist und nichts Gekauftes überlegen macht |
| **Zeitersparnis** | Währungspakete, doppelte Erfahrung | vorsichtig: nur, wenn dasselbe in vertretbarer Zeit erspielbar ist und es keinen direkten Wettbewerb entscheidet |
| **Stärke** | stärkste Waffe nur gegen Robux, Leben kaufen im PvP | **nein** (Pay-to-Win): vergrault alle Nichtzahler |
| **Zufall gegen Robux** | Kisten, Eier, Glücksrad | nur mit angezeigten Chancen und Länderprüfung (Abschnitt 5); besser als Spielwährung anbieten |

Faustregel für Vorteile: *Würde sich ein Spieler, der nichts kauft, im Vergleich betrogen fühlen?* Wenn ja, anders lösen.

## 3. Die Werkzeuge von Roblox

| Werkzeug | Eigenschaft | Typische Verwendung |
|---|---|---|
| **Game-Pass** | einmaliger Kauf, dauerhaft | Unterstützer, Komfort, zusätzliche Inhalte |
| **Entwicklerprodukt** | beliebig oft kaufbar | Währungspakete, Verbrauchsgüter |
| **Abonnement** | monatlich, in echter Währung | nur für Spiele mit laufend neuen Inhalten; aufwendig, spät erwägen |
| **Premium-Auszahlung** | Roblox zahlt nach Spielzeit von Premium-Mitgliedern | passiv; kleiner Bonus für Premium-Spieler (`MonetizationService:IsPremium`) ist erlaubt und üblich |
| **Private Server** | Spieler mieten einen eigenen Server | in den Spieleinstellungen einschalten; ohne Code |

## 4. Angebot gestalten

- **Wenige Angebote.** 2 bis 4 Pässe, 2 bis 3 Produktgrößen. Jedes in einem Satz erklärt.
- **Preisstaffel:** ein günstiger Einstieg (25 bis 99 Robux), ein Hauptangebot (150 bis 400), höchstens ein großes. Größere Pakete geben spürbar mehr pro Robux – ehrlich ausgerechnet und so beschriftet.
- **Der Shop öffnet nur auf Wunsch des Spielers.** Kein Fenster beim Beitritt, nach dem Tod oder nach jeder Runde. Erlaubt und sinnvoll: ein ruhiger „Shop"-Knopf, ein Schloss-Symbol an einem gesperrten Kosmetik-Gegenstand, das den Shop an der richtigen Stelle öffnet.
- **Kein künstlicher Druck:** keine erfundenen Countdowns, kein „nur noch 2 Minuten!", keine absichtlich nervigen Wartezeiten, die man wegkaufen soll.
- **Gratis zuerst:** Die tägliche Belohnung steht im Shop oben. Wer regelmäßig etwas geschenkt bekommt, sieht den Shop gern.
- **Sofort wirksam:** Ein gekaufter Pass gilt im selben Moment, ohne Neubeitritt (`PassOwned`-Signal).
- **Erstkauf würdigen:** kurzes Danke, sichtbarer Effekt.

## 5. Regeln von Roblox (verbindlich)

Vor der Veröffentlichung von Käufen die aktuellen Richtlinien im Creator Hub nachlesen (Monetarisierung, Gemeinschaftsstandards); sie ändern sich. Stand der Kenntnis beim Schreiben dieses Skills:

- **Zufallskäufe:** Wer Zufallsgegenstände direkt oder indirekt für Robux anbietet, muss die Chancen **vor dem Kauf** anzeigen. In einigen Ländern sind sie verboten: `PolicyService:GetPolicyInfoForPlayerAsync(player).ArePaidRandomItemsRestricted` prüfen (`MonetizationService:RandomItemsAllowed(player)`) und das Angebot dort ausblenden.
- **Keine Irreführung:** Der Spieler bekommt genau, was beschrieben ist. Keine gefälschten Rabatte.
- **Kein Verkauf außerhalb von Roblox**, keine Umgehung über externe Seiten, kein Tausch gegen echtes Geld.
- **Käufe nur über die Roblox-Kauffenster** (`MarketplaceService`), nie eigene Zahlungsabfragen.
- **Altersgerecht:** kein Glücksspiel-Aufbau, keine Angebote, die gezielt Kinder unter Druck setzen.

## 6. Technik richtig machen

Das Modul erledigt die heiklen Teile. Was dabei wichtig ist:

- **Katalog** in `shared/Config/Products.luau`. Ids aus dem Creator Hub eintragen; Id `0` bedeutet „noch nicht angelegt" (Shop zeigt „Bald").
- **Gutschrift** anmelden, damit das Modul die Währung des Spiels nicht kennen muss:
  ```lua
  MonetizationService:RegisterGrant("Coins", function(player, amount)
      DataService:Increment(player, "Currency.Coins", amount)
  end)
  ```
  Ein Handler darf nicht warten.
- **Entwicklerprodukte:** `ProcessReceipt` gibt es genau einmal (im `MonetizationService`). Es antwortet erst dann „erledigt", wenn Gutschrift und Kauf-Id im Spielstand **gespeichert** sind (`DataService:GrantOnce`). Stürzt der Server vorher ab, meldet Roblox den Beleg später erneut, und es wird trotzdem nicht doppelt gutgeschrieben.
- **Pässe:** `MonetizationService:OwnsPass(player, "Schlüssel")` für Entscheidungen auf dem Server; Signal `PassOwned` für sofortige Wirkung nach dem Kauf.
- **Der Client löst nur aus** (`Net.Send("Shop.Prompt", "Pass", schlüssel)`). Welche Id gekauft wird, bestimmt der Server aus der Config.
- **Testen in Studio:** Käufe sind dort Testkäufe ohne echte Robux. Prüfen: einmalige Gutschrift, Wirkung nach Neubeitritt, Verhalten bei Abbruch des Kauffensters.

## 7. Auswerten

Roblox zeigt im Creator Hub Einnahmen, Käufe pro Besucher und Abbruchstellen. Im Code lassen sich eigene Ereignisse melden (`AnalyticsService:LogEconomyEvent`, `LogFunnelStepEvent`, `LogOnboardingFunnelStepEvent`) – sinnvoll, sobald das Spiel Spieler hat: Wo steigen neue Spieler aus? Was wird gekauft und was nie? Erst messen, dann ändern.

## 8. Vor dem Einbau abhaken

- [ ] Die Kernschleife macht ohne jeden Kauf Spaß und ist vollständig spielbar.
- [ ] Kein Angebot verschafft einen Vorteil gegen andere Spieler.
- [ ] Jedes Angebot ist in einem Satz erklärt und liefert genau das.
- [ ] Kein Fenster öffnet sich von selbst.
- [ ] Zufall gegen Robux: Chancen sichtbar, Länderprüfung aktiv – oder gar nicht vorhanden.
- [ ] Testkauf: genau eine Gutschrift, bleibt nach Neubeitritt erhalten.
