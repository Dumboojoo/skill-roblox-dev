--!strict
--[[
	MonetizationService – Game-Pässe, Robux-Produkte, tägliche Belohnung.

	Einbinden ins Spiel (in irgendeinem Service, in Init oder Start):

	    MonetizationService:RegisterGrant("Coins", function(player, amount)
	        DataService:Increment(player, "Currency.Coins", amount)
	    end)

	    if MonetizationService:OwnsPass(player, "ExtraStorage") then ... end
	    MonetizationService.PassOwned:Connect(function(player, passKey) ... end)

	ROBUX-PRODUKTE (mehrfach kaufbar) sind die heikelste Stelle im ganzen Spiel:
	Roblox ruft ProcessReceipt auf, und nur wenn wir PurchaseGranted antworten, gilt
	der Kauf als erledigt. Antworten wir zu früh, ist bei einem Absturz das Geld
	weg und die Ware nicht da. Deshalb:
	  1. Gutschrift und Kauf-Id landen zusammen im Spielstand,
	  2. erst wenn dieser Spielstand wirklich GESPEICHERT ist, antworten wir
	     PurchaseGranted (DataService:GrantOnce erledigt beides),
	  3. kommt derselbe Beleg noch einmal, wird nicht doppelt gutgeschrieben.
	Ein Grant-Handler darf deshalb nicht warten (kein task.wait, keine Web-Aufrufe).

	ProcessReceipt darf es im ganzen Spiel nur EINMAL geben, nämlich hier.

	GAME-PÄSSE (einmalig) werden beim Beitritt abgefragt und nach einem Kauf sofort
	freigeschaltet, ohne dass der Spieler neu beitreten muss.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Check = require(Shared.Util.Check)
local Daily = require(Shared.Shop.Daily)
local Net = require(Shared.Net)
local Products = require(Shared.Config.Products)
local Signal = require(Shared.Util.Signal)
local DataService = require(script.Parent.DataService)

type GrantHandler = (player: Player, amount: number) -> ()

local PASS_CHECK_ATTEMPTS = 4
local PASS_CHECK_WAIT = 2 -- Sekunden; wächst mit jedem Versuch

local MonetizationService = {
	PassOwned = Signal.new() :: Signal.Signal<Player, string>, -- beim Beitritt (falls vorhanden) und nach Kauf
	ProductPurchased = Signal.new() :: Signal.Signal<Player, string>,
}

local grants: { [string]: GrantHandler } = {}
local ownedPasses: { [Player]: { [string]: boolean } } = {}

------------------------------------------------------------------------------
-- Öffentlich
------------------------------------------------------------------------------

function MonetizationService:RegisterGrant(name: string, handler: GrantHandler)
	grants[name] = handler
end

function MonetizationService:OwnsPass(player: Player, passKey: string): boolean
	local owned = ownedPasses[player]
	return owned ~= nil and owned[passKey] == true
end

function MonetizationService:IsPremium(player: Player): boolean
	return player.MembershipType == Enum.MembershipType.Premium
end

-- Dürfen diesem Spieler Zufallskäufe gegen Robux angeboten werden? (Länderregeln)
-- Solange die Auskunft fehlt, lautet die Antwort sicherheitshalber nein.
function MonetizationService:RandomItemsAllowed(player: Player): boolean
	return player:GetAttribute("PaidRandomItemsAllowed") == true
end

------------------------------------------------------------------------------
-- Pässe
------------------------------------------------------------------------------

local function markOwned(player: Player, passKey: string)
	local owned = ownedPasses[player]
	if owned and not owned[passKey] then
		owned[passKey] = true
		-- Für die Anzeige im Shop. Entscheidungen trifft immer der Server über OwnsPass.
		player:SetAttribute("Pass_" .. passKey, true)
		MonetizationService.PassOwned:Fire(player, passKey)
	end
end

-- Fragt Roblox, ob der Spieler den Pass besitzt. Die Abfrage kann vorübergehend scheitern;
-- dann wird sie wiederholt, damit ein zahlender Spieler seinen Pass nicht für die ganze
-- Sitzung verliert. nil: auch nach allen Versuchen keine Auskunft.
local function ownsPass(player: Player, passId: number): boolean?
	for attempt = 1, PASS_CHECK_ATTEMPTS do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok then
			return owns == true
		end
		if attempt < PASS_CHECK_ATTEMPTS then
			task.wait(PASS_CHECK_WAIT * attempt)
		end
		if player.Parent ~= Players then
			return nil
		end
	end
	warn(`[Shop] Pass {passId} konnte für {player.Name} nicht geprüft werden (Roblox antwortet nicht).`)
	return nil
end

local function loadPlayer(player: Player)
	ownedPasses[player] = {}
	for passKey, pass in Products.GamePasses do
		if pass.Id ~= 0 then
			-- Jeden Pass für sich prüfen, damit ein langsamer die anderen nicht aufhält.
			task.spawn(function()
				if ownsPass(player, pass.Id) and player.Parent == Players then
					markOwned(player, passKey)
				end
			end)
		end
	end

	local ok, policy = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if ok and type(policy) == "table" and player.Parent == Players then
		player:SetAttribute("PaidRandomItemsAllowed", policy.ArePaidRandomItemsRestricted == false)
	end
end

------------------------------------------------------------------------------
-- Produkte
------------------------------------------------------------------------------

local function findProduct(productId: number): (string?, Products.Product?)
	for key, product in Products.Products do
		if product.Id == productId then
			return key, product
		end
	end
	return nil, nil
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local notYet = Enum.ProductPurchaseDecision.NotProcessedYet
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return notYet -- Spieler ist weg: Roblox meldet den Beleg beim nächsten Beitritt erneut.
	end
	local key, product = findProduct(receipt.ProductId)
	if not key or not product then
		warn(`[Shop] Kauf für unbekannte Produkt-Id {receipt.ProductId}. In Config/Products eintragen.`)
		return notYet
	end
	local handler = grants[product.Grant]
	if not handler then
		warn(`[Shop] Kein Gutschrift-Handler "{product.Grant}" angemeldet (MonetizationService:RegisterGrant).`)
		return notYet
	end
	if not DataService:WaitForData(player) then
		return notYet
	end

	local saved = DataService:GrantOnce(player, receipt.PurchaseId, function()
		handler(player, product.Amount)
		DataService:Increment(player, "Shop.Purchases", 1)
	end)
	if not saved then
		return notYet
	end
	MonetizationService.ProductPurchased:Fire(player, key)
	Net.Fire("Notify", player, `Danke! Erhalten: {product.DisplayName}`, "Success", 4)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------

local function onPrompt(player: Player, kind: string, key: string)
	-- Der Client nennt nur den Schlüssel; die Id kommt aus der Config auf dem Server.
	if kind == "Pass" then
		local pass = Products.GamePasses[key]
		if not pass then
			return
		elseif pass.Id == 0 then
			Net.Fire("Notify", player, "Dieses Angebot ist noch nicht verfügbar.", "Info")
		elseif not MonetizationService:OwnsPass(player, key) then
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		end
	else
		local product = Products.Products[key]
		if not product then
			return
		elseif product.Id == 0 then
			Net.Fire("Notify", player, "Dieses Angebot ist noch nicht verfügbar.", "Info")
		else
			MarketplaceService:PromptProductPurchase(player, product.Id)
		end
	end
end

local function onClaimDaily(player: Player)
	local shop = DataService:Get(player, "Shop")
	if type(shop) ~= "table" then
		return
	end
	local rewards = Products.Daily.Rewards
	local today = Daily.DayNumber(os.time())
	local canClaim, streak = Daily.Status(shop.LastDailyDay, shop.Streak, today, #rewards)
	if not canClaim then
		return
	end
	local handler = grants[Products.Daily.Grant]
	if not handler then
		warn(`[Shop] Kein Gutschrift-Handler "{Products.Daily.Grant}" für die tägliche Belohnung angemeldet.`)
		return
	end
	-- Erst als abgeholt vermerken, dann gutschreiben: So ist doppeltes Abholen ausgeschlossen.
	DataService:Set(player, "Shop.LastDailyDay", today)
	DataService:Set(player, "Shop.Streak", streak)
	handler(player, rewards[streak])
	Net.Fire("Notify", player, `Tägliche Belohnung (Tag {streak}): +{rewards[streak]}`, "Success", 4)
end

------------------------------------------------------------------------------

function MonetizationService:Init()
	Net.On("Shop.Prompt", { Check.oneOf({ "Pass", "Product" }), Check.stringMax(60) }, onPrompt, { Rate = 2 })
	Net.On("Shop.ClaimDaily", {}, onClaimDaily, { Rate = 1 })

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if not purchased then
				return
			end
			for passKey, pass in Products.GamePasses do
				if pass.Id == passId then
					markOwned(player, passKey)
					Net.Fire("Notify", player, `Danke! Freigeschaltet: {pass.DisplayName}`, "Success", 4)
				end
			end
		end
	)
end

function MonetizationService:Start()
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(function(player)
		ownedPasses[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
end

return MonetizationService
