--!strict
-- Einstiegspunkt des Servers. Hier steht absichtlich keine Spiellogik:
-- Jedes Feature ist ein eigenes Modul in Services/ und wird automatisch geladen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)

-- Net zuerst laden, damit der Remotes-Ordner existiert, bevor Clients danach suchen.
local Net = require(ReplicatedStorage.Shared.Net)

-- Allgemeine Meldungen an Spieler: Net.Fire("Notify", player, text, art) – siehe NotificationController.
Net.Declare("Notify")
-- Töne vom Server aus: Net.Fire("Sound.Play", player, "Coin") – siehe SoundController.
Net.Declare("Sound.Play")

local started = os.clock()
local services = Loader.Load(script.Parent.Services, "Server")

local count = 0
for _ in services do
	count += 1
end
print(string.format("[Server] %d Services geladen (%.0f ms)", count, (os.clock() - started) * 1000))
