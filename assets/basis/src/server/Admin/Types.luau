--!strict
-- Typen für Admin-Befehle (eigene Datei, damit Befehlsdateien nicht den AdminService laden müssen).

export type Context = {
	Player: Player, -- wer den Befehl ausführt
	Raw: string, -- die ganze Eingabe
}

--[[
	Args ist eine Liste kurzer Texte der Form "name:typ" bzw. "name:typ?" (optional):

	    Args = { "wert:number", "spieler:player?" }

	Typen:
	    player    ein Spieler (Name, Namensanfang oder "me")           -> Player
	    players   einer oder mehrere ("all", "others", Name)           -> { Player }
	    number    Zahl                                                 -> number
	    integer   ganze Zahl                                           -> number
	    boolean   an/aus, on/off, true/false                           -> boolean
	    string    ein Wort (oder "mehrere Wörter in Anführungszeichen") -> string
	    choice    einer der Werte aus Choices[name]                    -> string
	    rest      alles bis zum Zeilenende (nur als letztes Argument)  -> string

	Optionale Argumente, die nicht passen, werden übersprungen. Darum bei Schaltern
	"an/aus:boolean?" VOR "spieler:player?" schreiben.
]]
export type Command = {
	Name: string,
	Aliases: { string }?,
	Description: string,
	Args: { string }?,
	-- Auswahlwerte für choice-Argumente: Name -> Liste oder Funktion, die eine Liste liefert.
	Choices: { [string]: any }?,
	-- Bekommt die aufgelösten Argumente in der Reihenfolge von Args (fehlende optionale = nil).
	-- Rückgabe: Text für die Konsole (oder nil für "OK"). error("Text", 0) zeigt eine Fehlermeldung.
	Run: (context: Context, ...any) -> string?,
}

return {}
