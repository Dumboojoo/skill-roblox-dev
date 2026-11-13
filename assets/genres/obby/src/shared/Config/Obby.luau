--!strict
--[[
	Obby – Einstellungen und der Welt-Vertrag.

	Der Code findet alles über TAGS. Stufen und Hindernisse werden in Studio gebaut
	und getaggt; Reihenfolge und Verhalten kommen aus ATTRIBUTEN am jeweiligen Teil.

	Tag               Klasse     Attribute
	Checkpoint        BasePart   Stage (number, ab 0; Stage 0 = Start)
	KillPart          BasePart   –
	Spinner           BasePart   Speed (Grad/Sek., Standard 90), Axis ("X"/"Y"/"Z", Standard "Y")
	MovingPlatform    BasePart   Offset (Vector3, wohin sie fährt), Time (Sek. für eine Strecke, Standard 3)
	FadingPlatform    BasePart   Delay (Sek. bis sie verschwindet, Standard 0.6), Respawn (Standard 3)
	JumpPad           BasePart   Power (Standard 90)
	Conveyor          BasePart   Speed (Studs/Sek., Standard 16; Richtung = Vorderseite des Teils)

	Die höchste Stage ist das Ziel.
]]

return {
	-- Darf man Checkpoints überspringen, indem man einen späteren berührt?
	AllowCheckpointSkipping = false,

	RespawnHeight = 4, -- Studs über dem Checkpoint

	Defaults = {
		SpinnerSpeed = 90,
		MovingTime = 3,
		FadeDelay = 0.6,
		FadeRespawn = 3,
		JumpPower = 90,
		ConveyorSpeed = 16,
	},
}
