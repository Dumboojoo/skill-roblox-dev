--!strict
--[[
	DataMigrations – Umbauten an bestehenden Spielständen.

	Nötig, sobald ein Feld UMBENANNT, VERSCHOBEN oder sein Aufbau GEÄNDERT wird.
	(Für rein neue Felder reicht ein Eintrag in der Vorlage.)

	Ablauf:
	  1. Version um 1 erhöhen.
	  2. Unter Steps[neueVersion] eine Funktion schreiben, die einen alten Spielstand
	     auf den neuen Aufbau bringt.
	  3. Alte Schritte NIE löschen oder ändern: Ein Spieler, der ein Jahr weg war,
	     läuft beim Laden alle Schritte der Reihe nach durch.

	Beispiel (Coins wandern von der obersten Ebene nach Currency.Coins):

	  Version = 2,
	  Steps = {
	      [2] = function(data)
	          data.Currency = data.Currency or {}
	          data.Currency.Coins = data.Coins or 0
	          data.Coins = nil
	      end,
	  }

	Eine Migration darf nicht warten (kein task.wait) und muss auch mit fehlenden
	Feldern zurechtkommen. Schlägt sie fehl, wird der Spieler gekickt und sein
	Spielstand bleibt unverändert.
]]

export type Step = (data: { [string]: any }) -> ()

return {
	Version = 1,
	Steps = {} :: { [number]: Step },
}
