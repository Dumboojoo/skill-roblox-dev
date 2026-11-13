--!strict
--[[
	GameConfig – die zentralen Schalter des Spiels.

	Alles, was man beim Balancen oder Veröffentlichen ändert, steht in shared/Config
	und nicht verstreut im Code. Inhalte einzelner Features (Waffen, Türme, Items …)
	haben jeweils ihre eigene Datei in diesem Ordner.
]]

local GameConfig = {
	Name = "{{NAME}}",

	Admin = {
		-- Wer die Konsole (Taste T) benutzen darf.
		OwnerIsAdmin = true, -- Besitzer des Spiels bzw. der Gruppe
		StudioIsAdmin = true, -- beim Testen in Studio jeder
		UserIds = {} :: { number }, -- weitere Admins, z. B. { 123456789 }
		GroupId = 0, -- 0 = keine Gruppe; sonst zählt GroupMinRank
		GroupMinRank = 255,
		ConsoleKey = Enum.KeyCode.T,
	},

	Data = {
		-- Name des DataStores. Ändern = alle fangen neu an. Für Datenumbauten gibt es Migrationen.
		StoreName = "PlayerData_v1",
		-- false: In Studio werden Testdaten benutzt, die echten Spielstände bleiben unberührt.
		SaveInStudio = false,
		LoadFailedMessage = "Dein Spielstand konnte nicht geladen werden. Bitte tritt neu bei. Es ist nichts verloren gegangen.",
		SessionEndedMessage = "Dein Spielstand wurde auf einem anderen Server geöffnet.",
	},

	-- Einstellungs-Fenster des Spielers (SettingsController).
	Settings = {
		ShowButton = true, -- false: kein eigener Knopf; dann von einem eigenen Menü aus SettingsController:Open() aufrufen
		ButtonText = "Menü",
		Key = Enum.KeyCode.P, -- öffnet und schließt das Fenster
		-- Linker Rand, halbe Höhe: dort liegt in keinem der Beispiel-Genres eine Anzeige.
		ButtonPosition = UDim2.new(0, 12, 0.5, 0),
		-- Was der Spieler ändern darf. Key = Feld unter "Settings" im Spielstand (Config/DataSections/Core).
		-- Zahlen gelten als Regler von 0 bis 1, Wahrheitswerte als An/Aus-Schalter.
		Entries = {
			{ Key = "MusicVolume", Label = "Musik" },
			{ Key = "SfxVolume", Label = "Effekte" },
		},
	},
}

return GameConfig
