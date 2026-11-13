--!strict
-- Einstiegspunkt des Clients. Jedes Feature ist ein eigenes Modul in Controllers/
-- und wird automatisch geladen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Loader = require(ReplicatedStorage.Shared.Loader)

Loader.Load(script.Parent.Controllers, "Client")
