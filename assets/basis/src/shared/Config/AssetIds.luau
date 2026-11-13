--!strict
--[[
	AssetIds – die Nummern aller selbst hochgeladenen Bilder an einer Stelle.

	Ein leerer Eintrag ("") heißt „noch nicht hochgeladen": Der Code läuft trotzdem,
	Effekte benutzen dann das Standard-Partikel von Roblox.

	So kommt eine Nummer hierher:
	  1. Bild erzeugen (scripts/effekt_textur.py, Blender oder PhotoCraft) und in den
	     Ordner export/ des Spiels legen.
	  2. In Studio hochladen (Studio-MCP: store_image, dann upload_image) – vorher den
	     Nutzer fragen, denn Hochgeladenes bleibt dauerhaft in seinem Konto.
	  3. Die Nummer als "rbxassetid://123456" hier eintragen und in PLAN.md unter
	     „Eigene Assets" vermerken.

	Modelle stehen nicht hier: Sie liegen nach dem Einfügen in der Place-Datei
	(z. B. unter ReplicatedStorage.Assets).
]]

local AssetIds = {
	-- Bilder für Effekte (Config/Effects verweist über diese Schlüssel darauf).
	-- In Klammern: die Form aus scripts/effekt_textur.py, die als Grundlage passt.
	Effects = {
		Glow = "", -- leuchtpunkt
		Ring = "", -- ring
		Spark = "", -- funke
		Star = "", -- stern
		Smoke = "", -- rauch
		Line = "", -- linie
		Slash = "", -- schlag_wischt (Bildfolge 4x4)
		RingGrow = "", -- ring_waechst (Bildfolge 4x4)
		Burst = "", -- funkenstoss (Bildfolge 4x4)
		Puff = "", -- verpuffen (Bildfolge 4x4)
		Explosion = "", -- explosion (Bildfolge 4x4)
	} :: { [string]: string },

	-- Texturen für Oberflächen (SurfaceAppearance, Decal, Texture).
	Textures = {} :: { [string]: string },

	-- Bilder für die Oberfläche (Symbole, Hintergründe).
	Images = {} :: { [string]: string },
}

return AssetIds
