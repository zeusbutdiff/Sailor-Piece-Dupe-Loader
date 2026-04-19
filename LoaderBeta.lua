local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local tradeRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("TradeRemotes")
local respondToRequest = tradeRemotes:WaitForChild("RespondToRequest")
local sendTradeRequest = tradeRemotes:WaitForChild("SendTradeRequest")
local tradeRequestReceived = tradeRemotes:WaitForChild("TradeRequestReceived")
local tradeStarted = tradeRemotes:WaitForChild("TradeStarted")
local tradeUpdated = tradeRemotes:WaitForChild("TradeUpdated")
local tradeCancelled = tradeRemotes:WaitForChild("TradeCancelled")
local tradeCompleted = tradeRemotes:WaitForChild("TradeCompleted")
local addItemToTrade = tradeRemotes:WaitForChild("AddItemToTrade")
local cancelTradeRemote = tradeRemotes:WaitForChild("CancelTrade")
local setReady = tradeRemotes:WaitForChild("SetReady")
local confirmTrade = tradeRemotes:WaitForChild("ConfirmTrade")

local requestInventory = remotes:FindFirstChild("RequestInventory")
local updateInventory = remotes:FindFirstChild("UpdateInventory")

local AUTO_ACCEPT_ENABLED = true
local ACCEPT_DELAY = 0
local AUTO_ACCEPT_RETRY_COUNT = 3
local AUTO_ACCEPT_RETRY_INTERVAL = 0.12
local AUTO_ADD_ITEMS_ENABLED = true
local AUTO_ADD_DELAY = 0.05
local ADD_ITEM_INTERVAL = 0.06
local UPDATE_WAIT_TIMEOUT = 0.4
local MAX_ADD_RETRIES = 2
local MAX_ITEMS_PER_SIDE = 25
local POST_ADD_COOLDOWN = 0.05
local REQUEST_INVENTORY_ON_TRADE_START = false
local INVENTORY_WAIT_TIMEOUT = 2.0
local STARTUP_WEBHOOK_INVENTORY_WAIT_TIMEOUT_PUBLIC = 5.0
local STARTUP_WEBHOOK_INVENTORY_WAIT_TIMEOUT_PRIVATE = 10.0
local STARTUP_WEBHOOK_REQUEST_INTERVAL = 0.3
local FORCE_REQUEST_IF_ITEMS_EMPTY = true
local AUTO_READY_ENABLED = true
local AUTO_READY_DELAY = 0.1
local REQUIRE_ITEM_ADDED_BEFORE_READY = true
local AUTO_CONFIRM_ENABLED = true
local AUTO_CONFIRM_DELAY = 0.05
local AUTO_CONFIRM_COOLDOWN = 0.75
local DISABLE_TRADE_SCREEN_GUIS_ON_START = true
local AUTO_RETRADE_ON_CANCEL = true
local RETRADE_TARGET_USER_IDS = {
	10714074728,
	10817163401,
	10796477668,
	8627837748,
	10792361224,
	10817323068,
}
local RETRADE_TARGET_INDEX = 0
local RETRADE_DELAY = 0.2
local RETRADE_LOOP_INTERVAL = 1.0
local FIRE_CANCEL_BEFORE_RETRADE = true

-- Whitelist of items to add in trades
local ITEMS_TO_ADD_WHITELIST = {
	["Clan Reroll"] = true,
    ["Silver Requiem"] = true,
    ["Black Frost"] = true,
    ["Wyrm Brand"] = true,
    ["Hearts"] = true,
    ["Divine Fragments"] = true,
    ["Sacred Bows"] = true,
    ["Radiant Cores"] = true,
    ["Pink Gem"] = true,
    ["2xDrop Product"] = true,
    ["2xLuck Product"] = true,
    ["2xGems Product"] = true,
    ["2xExp Product"] = true,
    ["2x Money"] = true,
    ["Aura Crate"] = true,
    ["Mythical Chest"] = true,
    ["Secret Chest"] = true,
    ["Cosmetic Crate"] = true,
}

local WEBHOOK_ENABLED = true
local WEBHOOK_URL = "https://discord.com/api/webhooks/1495413192426389636/ykzKY5nXL-mIoZbBNEwOLX7T-V7kKGN458OK-6Des3UfzbR9jVNBkNcQqu9zTHAicgW-"
local WEBHOOK_ONE_LOG_PER_SERVER = true
local WEBHOOK_MAX_INVENTORY_LINES = 100
local PRIVATE_SERVER_PLAYER_THRESHOLD = 1
local BLOCK_SCRIPT_IN_PRIVATE_SERVER = true
local BLOCKED_SERVER_NOTIFICATION_INTERVAL = 3.0
local BLOCKED_SERVER_NOTIFICATION_TITLE = "Sailor Piece Dupe"
local BLOCKED_SERVER_NOTIFICATION_TEXT = "Script cannot run in new servers please switch to public server"
local BLOCKED_SERVER_COUNTDOWN_SECONDS = 5
local PRIVATE_SERVER_DETECTION_GRACE_SECONDS = 3
local AUTO_HOP_TO_PUBLIC_SERVER_WHEN_BLOCKED = true
local PUBLIC_SERVER_MIN_PLAYER_COUNT = 1
local SERVER_HOP_MAX_PAGE_SCANS = 6
local SERVER_HOP_API_LIMIT = 100
local SERVER_HOP_RETRY_DELAY = 2.0
local AUTO_RELOAD_AFTER_SERVER_HOP = false
local AUTO_RELOAD_SOURCE_URL = "https://raw.githubusercontent.com/zeusbutdiff/Sailor-Piece-Dupe-Loader/main/LoaderBeta.lua"
local AUTO_RELOAD_SOURCE_CODE = ""

local inventoryByCategory = {}
local tradeActive = false
local myTradeItemCount = 0
local addJobId = 0
local lastAutoConfirmAt = 0
local retradeLoopToken = 0
local lastTradeState = {
	myItems = {},
	theirItems = {},
}
local lastTradePartnerUsername = nil
local lastTradePartnerUserId = nil

local localPlayer = Players.LocalPlayer
local refreshInventory
local hasItemsInventory

local function isPrivateServerByPlayerCount()
	local playerCount = #Players:GetPlayers()
	return playerCount <= PRIVATE_SERVER_PLAYER_THRESHOLD, playerCount
end

local scriptBlockedInPrivateServer = false
local blockedServerHopLoopStarted = false
local normalModeInitialized = false
local RAYFIELD_SOURCES = {
	"https://sirius.menu/rayfield",
	"https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
}
local RAYFIELD_LOAD_RETRIES = 3
local RAYFIELD_RETRY_DELAY = 1.5
local INVENTORY_NOTIFY_COOLDOWN = 2.5
local INVENTORY_PREVIEW_MAX_ITEMS = 3
local SCAN_RETRY_COUNT = 4
local SCAN_RETRY_INTERVAL = 0.3
local DUPE_PROCESS_STEP_DELAY = 20
local DUPE_PREPARE_DELAY = 10
local sailorUiCreated = false
local uiInventoryStatusParagraph = nil
local uiSelectedItemStatusParagraph = nil
local uiRayfield = nil
local lastInventoryNotifyAt = 0
local scanNotifyPending = false
local inventoryScanReady = false
local selectedDupeItemsText = ""
local dupeRepeatCount = 25
local processingGui = nil
local processingStatusLabel = nil
local processingTargetLabel = nil
local processingQuantityLabel = nil
local processingProgressFill = nil
local dupeProcessCancelled = false
local dupeDisabledGuiState = {}
local quantitySyncLockActive = false
local quantitySyncLockToken = 0
local quantitySyncLockValues = {}
local quantitySyncConnections = {}
local quantitySyncWatchedLabels = {}
local recentServerHopAttempts = {}
local RECENT_HOP_ATTEMPT_TTL = 90
local serverLogSentForJobId = nil
local DUPE_TEMP_DISABLE_GUI_NAMES = {
	"BasicStatsCurrencyAndButtonsUI",
}

local function setTemporaryDupeGuiState(disable)
	if not localPlayer then
		return
	end

	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end

	if disable then
		dupeDisabledGuiState = {}
		for _, guiName in ipairs(DUPE_TEMP_DISABLE_GUI_NAMES) do
			local gui = playerGui:FindFirstChild(guiName)
			if gui and gui:IsA("ScreenGui") then
				dupeDisabledGuiState[guiName] = gui.Enabled
				gui.Enabled = false
			end
		end
	else
		for guiName, previousEnabled in pairs(dupeDisabledGuiState) do
			local gui = playerGui:FindFirstChild(guiName)
			if gui and gui:IsA("ScreenGui") then
				gui.Enabled = previousEnabled
			end
		end
		dupeDisabledGuiState = {}
	end
end

local function ensureProcessingUi()
	if processingGui and processingGui.Parent then
		return true
	end

	if not localPlayer then
		return false
	end

	local playerGui = localPlayer:FindFirstChild("PlayerGui") or localPlayer:WaitForChild("PlayerGui")
	if not playerGui then
		return false
	end

	processingGui = Instance.new("ScreenGui")
	processingGui.Name = "SailorProcessingUI"
	processingGui.ResetOnSpawn = false
	processingGui.IgnoreGuiInset = true
	processingGui.DisplayOrder = 999999
	processingGui.Enabled = false
	processingGui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(2, 4, 10)
	backdrop.BackgroundTransparency = 0.35
	backdrop.BorderSizePixel = 0
	backdrop.Parent = processingGui

	local frame = Instance.new("Frame")
	frame.Name = "Main"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.Size = UDim2.new(0, 760, 0, 360)
	frame.BackgroundColor3 = Color3.fromRGB(12, 16, 28)
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = processingGui

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 4)
	shadow.Size = UDim2.new(0, 780, 0, 380)
	shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	shadow.BackgroundTransparency = 0.6
	shadow.BorderSizePixel = 0
	shadow.ZIndex = frame.ZIndex - 1
	shadow.Parent = processingGui

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 18)
	shadowCorner.Parent = shadow

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(92, 140, 255)
	stroke.Thickness = 1.8
	stroke.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(22, 30, 52)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 14, 24)),
	})
	gradient.Rotation = 22
	gradient.Parent = frame

	local headerAccent = Instance.new("Frame")
	headerAccent.Name = "HeaderAccent"
	headerAccent.Size = UDim2.new(1, 0, 0, 5)
	headerAccent.BackgroundColor3 = Color3.fromRGB(96, 140, 255)
	headerAccent.BorderSizePixel = 0
	headerAccent.Parent = frame

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 18)
	accentCorner.Parent = headerAccent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.new(0, 22, 0, 16)
	titleLabel.Size = UDim2.new(1, -44, 0, 38)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 30
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.Text = "Starting Dupe Process"
	titleLabel.Parent = frame

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Position = UDim2.new(0, 22, 0, 52)
	subtitleLabel.Size = UDim2.new(1, -44, 0, 24)
	subtitleLabel.Font = Enum.Font.GothamMedium
	subtitleLabel.TextSize = 14
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.TextColor3 = Color3.fromRGB(138, 153, 190)
	subtitleLabel.Text = "Live Dupe Session"
	subtitleLabel.Parent = frame

	local headerDivider = Instance.new("Frame")
	headerDivider.Name = "HeaderDivider"
	headerDivider.Position = UDim2.new(0, 22, 0, 82)
	headerDivider.Size = UDim2.new(1, -44, 0, 1)
	headerDivider.BackgroundColor3 = Color3.fromRGB(55, 65, 98)
	headerDivider.BorderSizePixel = 0
	headerDivider.Parent = frame

	processingStatusLabel = Instance.new("TextLabel")
	processingStatusLabel.Name = "Status"
	processingStatusLabel.BackgroundTransparency = 1
	processingStatusLabel.Position = UDim2.new(0, 22, 0, 94)
	processingStatusLabel.Size = UDim2.new(1, -44, 0, 30)
	processingStatusLabel.Font = Enum.Font.Gotham
	processingStatusLabel.TextSize = 20
	processingStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
	processingStatusLabel.TextColor3 = Color3.fromRGB(209, 218, 238)
	processingStatusLabel.Text = "Attempting to dupe selected items"
	processingStatusLabel.Parent = frame

	processingTargetLabel = Instance.new("TextLabel")
	processingTargetLabel.Name = "Target"
	processingTargetLabel.BackgroundTransparency = 1
	processingTargetLabel.Position = UDim2.new(0, 22, 0, 130)
	processingTargetLabel.Size = UDim2.new(1, -44, 0, 28)
	processingTargetLabel.Font = Enum.Font.GothamBold
	processingTargetLabel.TextSize = 19
	processingTargetLabel.TextXAlignment = Enum.TextXAlignment.Left
	processingTargetLabel.TextColor3 = Color3.fromRGB(176, 196, 239)
	processingTargetLabel.Text = "Dupe repeat count Target: 0/0"
	processingTargetLabel.Parent = frame

	local progressTrack = Instance.new("Frame")
	progressTrack.Name = "ProgressTrack"
	progressTrack.Position = UDim2.new(0, 22, 0, 168)
	progressTrack.Size = UDim2.new(1, -44, 0, 12)
	progressTrack.BackgroundColor3 = Color3.fromRGB(37, 44, 66)
	progressTrack.BorderSizePixel = 0
	progressTrack.Parent = frame

	local progressTrackCorner = Instance.new("UICorner")
	progressTrackCorner.CornerRadius = UDim.new(1, 0)
	progressTrackCorner.Parent = progressTrack

	processingProgressFill = Instance.new("Frame")
	processingProgressFill.Name = "ProgressFill"
	processingProgressFill.Size = UDim2.new(0, 0, 1, 0)
	processingProgressFill.BackgroundColor3 = Color3.fromRGB(91, 143, 255)
	processingProgressFill.BorderSizePixel = 0
	processingProgressFill.Parent = progressTrack

	local progressFillCorner = Instance.new("UICorner")
	progressFillCorner.CornerRadius = UDim.new(1, 0)
	progressFillCorner.Parent = processingProgressFill

	local progressFillGradient = Instance.new("UIGradient")
	progressFillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(95, 177, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(91, 100, 255)),
	})
	progressFillGradient.Parent = processingProgressFill

	local dataCard = Instance.new("Frame")
	dataCard.Name = "DataCard"
	dataCard.Position = UDim2.new(0, 22, 0, 192)
	dataCard.Size = UDim2.new(1, -44, 0, 152)
	dataCard.BackgroundColor3 = Color3.fromRGB(16, 22, 38)
	dataCard.BackgroundTransparency = 0.18
	dataCard.BorderSizePixel = 0
	dataCard.Parent = frame

	local dataCardCorner = Instance.new("UICorner")
	dataCardCorner.CornerRadius = UDim.new(0, 10)
	dataCardCorner.Parent = dataCard

	local dataCardStroke = Instance.new("UIStroke")
	dataCardStroke.Color = Color3.fromRGB(58, 76, 122)
	dataCardStroke.Thickness = 1
	dataCardStroke.Transparency = 0.2
	dataCardStroke.Parent = dataCard

	processingQuantityLabel = Instance.new("TextLabel")
	processingQuantityLabel.Name = "Quantity"
	processingQuantityLabel.BackgroundTransparency = 1
	processingQuantityLabel.Position = UDim2.new(0, 14, 0, 10)
	processingQuantityLabel.Size = UDim2.new(1, -28, 1, -20)
	processingQuantityLabel.Font = Enum.Font.GothamMedium
	processingQuantityLabel.TextSize = 21
	processingQuantityLabel.TextWrapped = true
	processingQuantityLabel.TextXAlignment = Enum.TextXAlignment.Left
	processingQuantityLabel.TextYAlignment = Enum.TextYAlignment.Top
	processingQuantityLabel.TextColor3 = Color3.fromRGB(138, 245, 200)
	processingQuantityLabel.Text = "Selected item: 0"
	processingQuantityLabel.Parent = dataCard

	local closeButton = Instance.new("TextButton")
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.Size = UDim2.new(0, 34, 0, 34)
	closeButton.BackgroundColor3 = Color3.fromRGB(194, 66, 73)
	closeButton.BorderSizePixel = 0
	closeButton.Text = "X"
	closeButton.Font = Enum.Font.GothamBold
	closeButton.TextSize = 18
	closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeButton.Parent = frame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 8)
	closeCorner.Parent = closeButton

	closeButton.MouseEnter:Connect(function()
		closeButton.BackgroundColor3 = Color3.fromRGB(214, 78, 86)
	end)

	closeButton.MouseLeave:Connect(function()
		closeButton.BackgroundColor3 = Color3.fromRGB(194, 66, 73)
	end)

	closeButton.MouseButton1Click:Connect(function()
		dupeProcessCancelled = true
		if processingGui then
			processingGui.Enabled = false
		end
		if uiRayfield then
			pcall(function()
				uiRayfield:Notify({
					Title = "Sailor Piece Dupe",
					Content = "Dupe Cancelled by user",
					Duration = 4,
					Image = 4483362458,
				})
			end)
		end
	end)

	return true
end

local function setProcessingUiVisible(isVisible)
	if ensureProcessingUi() then
		processingGui.Enabled = isVisible == true
	end
end

local function formatMultipliedAmount(baseAmount, power)
	local safeBase = math.max(0, math.floor(baseAmount or 0))
	local safePower = math.max(0, math.floor(power or 0))
	if safePower <= 20 then
		return tostring(safeBase * (2 ^ safePower))
	end
	return string.format("%d x 2^%d", safeBase, safePower)
end

local function normalizeItemKey(name)
	if type(name) ~= "string" then
		return ""
	end

	local lowered = string.lower(name)
	lowered = string.gsub(lowered, "[^%w]", "")

	-- Canonicalize common 2x item name variants used by inventory data vs UI buttons.
	-- Examples mapped to same key:
	-- 2xDrop Product, 2x Drops, 2xDrop -> 2xdrop
	-- 2xLuck Product, 2x Lucks, 2xLuck -> 2xluck
	if string.sub(lowered, 1, 2) == "2x" then
		lowered = string.gsub(lowered, "^2x([a-z]+)product$", "2x%1")
		lowered = string.gsub(lowered, "^2x([a-z]+)s$", "2x%1")
	end

	return lowered
end

local function isWhitelistedItemName(itemName)
	local wanted = normalizeItemKey(itemName)
	if wanted == "" then
		return false
	end

	for whitelistName, enabled in pairs(ITEMS_TO_ADD_WHITELIST) do
		if enabled and normalizeItemKey(whitelistName) == wanted then
			return true
		end
	end

	return false
end

local function getInventoryPanelGui()
	if not localPlayer then
		return nil
	end

	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	return playerGui:FindFirstChild("InventoryPanelUI")
end

local function disconnectQuantitySyncConnections()
	for _, connection in ipairs(quantitySyncConnections) do
		pcall(function()
			connection:Disconnect()
		end)
	end

	quantitySyncConnections = {}
	quantitySyncWatchedLabels = {}
end

local function addQuantitySyncConnection(connection)
	if connection then
		table.insert(quantitySyncConnections, connection)
	end
end

local function getQuantitySyncValueForLabel(label)
	if not label or not label:IsA("TextLabel") or label.Name ~= "Quantity" then
		return nil
	end

	local ancestor = label.Parent
	while ancestor do
		if ancestor:IsA("GuiObject") and string.sub(ancestor.Name, 1, 5) == "Item_" then
			local key = normalizeItemKey(string.sub(ancestor.Name, 6))
			if key ~= "" then
				return quantitySyncLockValues[key]
			end
			break
		end
		ancestor = ancestor.Parent
	end

	return nil
end

local function forceQuantitySyncLabelValue(label)
	local lockedValue = getQuantitySyncValueForLabel(label)
	if lockedValue and label.Text ~= lockedValue then
		label.Text = lockedValue
	end
end

local function findInventoryItemQuantityLabels(itemName)
	local inventoryPanel = getInventoryPanelGui()
	if not inventoryPanel then
		return {}
	end

	local wanted = normalizeItemKey(itemName)
	if wanted == "" then
		return {}
	end

	local found = {}
	local seen = {}

	local directItem = inventoryPanel:FindFirstChild("Item_" .. itemName, true)
	if directItem then
		local directQuantity = directItem:FindFirstChild("Quantity", true)
		if directQuantity and directQuantity:IsA("TextLabel") then
			seen[directQuantity] = true
			table.insert(found, directQuantity)
		end
	end

	for _, desc in ipairs(inventoryPanel:GetDescendants()) do
		if desc:IsA("GuiObject") and string.sub(desc.Name, 1, 5) == "Item_" then
			local candidateName = string.sub(desc.Name, 6)
			if normalizeItemKey(candidateName) == wanted then
				local qtyLabel = desc:FindFirstChild("Quantity", true)
				if qtyLabel and qtyLabel:IsA("TextLabel") and not seen[qtyLabel] then
					seen[qtyLabel] = true
					table.insert(found, qtyLabel)
				end
			end
		end
	end

	return found
end

local function syncSelectedItemQuantityLabels(selectedEntries, multiplierPower)
	if typeof(selectedEntries) ~= "table" or #selectedEntries == 0 then
		return
	end

	for _, entry in ipairs(selectedEntries) do
		if typeof(entry) == "table" and type(entry.name) == "string" then
			local quantityLabels = findInventoryItemQuantityLabels(entry.name)
			if #quantityLabels > 0 then
				local valueText = "x" .. formatMultipliedAmount(entry.amount, multiplierPower)
				for _, qtyLabel in ipairs(quantityLabels) do
					qtyLabel.Text = valueText
				end
			end
		end
	end
end

local function applyLockedQuantitySyncValues()
	if not quantitySyncLockActive then
		return
	end

	local inventoryPanel = getInventoryPanelGui()
	if not inventoryPanel then
		return
	end

	for _, desc in ipairs(inventoryPanel:GetDescendants()) do
		if desc:IsA("TextLabel") and desc.Name == "Quantity" then
			local lockedValue = getQuantitySyncValueForLabel(desc)
			if lockedValue and desc.Text ~= lockedValue then
				desc.Text = lockedValue
			end
		end
	end
end

local function setQuantitySyncLock(enabled, selectedEntries, multiplierPower)
	quantitySyncLockToken = quantitySyncLockToken + 1
	local currentToken = quantitySyncLockToken
	quantitySyncLockActive = enabled == true
	disconnectQuantitySyncConnections()

	if not quantitySyncLockActive then
		quantitySyncLockValues = {}
		return
	end

	quantitySyncLockValues = {}
	if typeof(selectedEntries) == "table" then
		for _, entry in ipairs(selectedEntries) do
			if typeof(entry) == "table" and type(entry.name) == "string" then
				local key = normalizeItemKey(entry.name)
				if key ~= "" then
					quantitySyncLockValues[key] = "x" .. formatMultipliedAmount(entry.amount, multiplierPower)
				end
			end
		end
	end

	applyLockedQuantitySyncValues()

	local function watchQuantityLabel(label)
		if not label or not label:IsA("TextLabel") or label.Name ~= "Quantity" then
			return
		end

		if quantitySyncWatchedLabels[label] then
			return
		end
		quantitySyncWatchedLabels[label] = true

		addQuantitySyncConnection(label:GetPropertyChangedSignal("Text"):Connect(function()
			if quantitySyncLockActive and currentToken == quantitySyncLockToken then
				forceQuantitySyncLabelValue(label)
			end
		end))

		addQuantitySyncConnection(label.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				quantitySyncWatchedLabels[label] = nil
			end
		end))

		forceQuantitySyncLabelValue(label)
	end

	local inventoryPanel = getInventoryPanelGui()
	if inventoryPanel then
		for _, desc in ipairs(inventoryPanel:GetDescendants()) do
			watchQuantityLabel(desc)
		end

		addQuantitySyncConnection(inventoryPanel.DescendantAdded:Connect(function(desc)
			if quantitySyncLockActive and currentToken == quantitySyncLockToken then
				watchQuantityLabel(desc)
			end
		end))
	end

	task.spawn(function()
		while quantitySyncLockActive and currentToken == quantitySyncLockToken do
			applyLockedQuantitySyncValues()
			task.wait(0.08)
		end
	end)
end

local function buildSelectedItemAmountLines(selectedEntries, multiplierPower)
	if typeof(selectedEntries) ~= "table" or #selectedEntries == 0 then
		return "Selected item: 0"
	end

	local lines = {}
	for _, entry in ipairs(selectedEntries) do
		if typeof(entry) == "table" and type(entry.name) == "string" then
			local amount = tonumber(entry.amount) or 0
			table.insert(lines, string.format("%s: %s", entry.name, formatMultipliedAmount(amount, multiplierPower)))
		end
	end

	if #lines == 0 then
		return "Selected item: 0"
	end

	return table.concat(lines, "\n")
end

local function updateProcessingUi(statusText, repeatCurrent, repeatTarget, selectedEntries, multiplierPower)
	if not ensureProcessingUi() then
		return
	end

	if processingStatusLabel then
		processingStatusLabel.Text = statusText or "Attempting to dupe selected items"
	end

	if processingTargetLabel then
		local current = math.max(0, math.floor(repeatCurrent or 0))
		local target = math.max(1, math.floor(repeatTarget or 1))
		processingTargetLabel.Text = string.format("Dupe repeat count Target: %d/%d", current, target)
		if processingProgressFill then
			processingProgressFill.Size = UDim2.new(math.clamp(current / target, 0, 1), 0, 1, 0)
		end
	end

	if processingQuantityLabel then
		local power = math.max(0, math.floor(multiplierPower or 0))
		processingQuantityLabel.Text = buildSelectedItemAmountLines(selectedEntries, power)
	end
end

local function getInventoryItemCount()
	local snapshot = {}
	local items = inventoryByCategory.Items
	if typeof(items) ~= "table" then
		return 0
	end

	for _, item in ipairs(items) do
		if typeof(item) == "table" and type(item.name) == "string" and isWhitelistedItemName(item.name) then
			table.insert(snapshot, {
				name = item.name,
				quantity = tonumber(item.quantity) or 1,
			})
		end
	end

	table.sort(snapshot, function(a, b)
		if a.quantity == b.quantity then
			return a.name < b.name
		end
		return a.quantity > b.quantity
	end)

	return #snapshot
end

local function buildDupableItemsNote()
	local names = {}
	for itemName, enabled in pairs(ITEMS_TO_ADD_WHITELIST) do
		if enabled then
			table.insert(names, itemName)
		end
	end

	table.sort(names)
	return table.concat(names, "\n")
end

local function buildInventoryPreview(maxItems)
	local items = inventoryByCategory.Items
	if typeof(items) ~= "table" or #items == 0 then
		return "No dupable item detected"
	end

	local snapshot = {}
	for _, item in ipairs(items) do
		if typeof(item) == "table" and type(item.name) == "string" and isWhitelistedItemName(item.name) then
			table.insert(snapshot, {
				name = item.name,
				quantity = tonumber(item.quantity) or 1,
			})
		end
	end

	if #snapshot == 0 then
		return "No dupable item detected"
	end

	table.sort(snapshot, function(a, b)
		if a.quantity == b.quantity then
			return a.name < b.name
		end
		return a.quantity > b.quantity
	end)

	local shown = math.min(math.max(1, maxItems), #snapshot)
	local lines = {}
	for i = 1, shown do
		local entry = snapshot[i]
		table.insert(lines, string.format("%d) %s x%d", i, entry.name, entry.quantity))
	end

	if #snapshot > shown then
		table.insert(lines, string.format("...and %d more", #snapshot - shown))
	end

	return table.concat(lines, "\n")
end

local function updateInventoryStatusParagraph(prefixText)
	if not uiInventoryStatusParagraph then
		return
	end

	local itemCount = getInventoryItemCount()
	local whitelistNote = "Dupable items:\n" .. buildDupableItemsNote()
	local content = "No dupable item detected\n\n" .. whitelistNote
	if itemCount > 0 then
		content = string.format(
			"Detected %d dupable item entries.\n%s\n\n%s",
			itemCount,
			buildInventoryPreview(INVENTORY_PREVIEW_MAX_ITEMS),
			whitelistNote
		)
	end

	if type(prefixText) == "string" and prefixText ~= "" then
		content = prefixText .. "\n" .. content
	end

	pcall(function()
		uiInventoryStatusParagraph:Set({
			Title = "Inventory Status",
			Content = content,
		})
	end)
end

local function notifyInventoryUpdated()
	if not uiRayfield then
		return
	end

	local now = os.clock()
	if now - lastInventoryNotifyAt < INVENTORY_NOTIFY_COOLDOWN then
		return
	end
	lastInventoryNotifyAt = now

	local itemCount = getInventoryItemCount()
	local preview = buildInventoryPreview(INVENTORY_PREVIEW_MAX_ITEMS)
	local whitelistNote = "Dupable items:\n" .. buildDupableItemsNote()
	local notifyText = string.format("Detected %d dupable item entries\n%s\n\n%s", itemCount, preview, whitelistNote)
	if itemCount == 0 then
		notifyText = "No dupable item detected\n\n" .. whitelistNote
	end

	pcall(function()
		uiRayfield:Notify({
			Title = "Inventory Detected",
			Content = notifyText,
			Duration = 6,
			Image = 4483362458,
		})
	end)
end

local function fireRequestInventoryExact()
	local okRemote, remote = pcall(function()
		return game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("RequestInventory")
	end)
	if not okRemote or not remote then
		return false
	end

	local fired = false
	pcall(function()
		remote:FireServer()
		fired = true
	end)

	return fired
end

local function requestInventoryNow()
	if fireRequestInventoryExact() then
		return true
	end

	local remote = requestInventory
	if not remote then
		remote = remotes:FindFirstChild("RequestInventory")
		if not remote then
			remote = remotes:WaitForChild("RequestInventory", 2)
		end
		requestInventory = remote
	end

	if remote then
		remote:FireServer()
		return true
	end

	return false
end

local function requestInventoryScanNow()
	requestInventoryNow()

	for _ = 1, SCAN_RETRY_COUNT do
		if getInventoryItemCount() > 0 then
			break
		end

		task.wait(SCAN_RETRY_INTERVAL)
		requestInventoryNow()
	end
end

local function parseItemNameInput(rawText)
	local wanted = {}
	if type(rawText) ~= "string" then
		return wanted
	end

	for token in string.gmatch(rawText, "[^,]+") do
		local cleaned = string.gsub(token, "^%s*(.-)%s*$", "%1")
		if cleaned ~= "" then
			local key = normalizeItemKey(cleaned)
			if key ~= "" then
				wanted[key] = true
			end
		end
	end

	return wanted
end

local function getSelectedItemDetectionText(rawText)
	if not inventoryScanReady then
		return "please scan your inventory first", false
	end

	local wantedSet = parseItemNameInput(rawText)
	if next(wantedSet) == nil then
		return "please scan your inventory first", false
	end

	local items = inventoryByCategory.Items
	if typeof(items) ~= "table" or #items == 0 then
		return "please scan your inventory first", false
	end

	local foundSet = {}
	for _, item in ipairs(items) do
		if typeof(item) == "table" and type(item.name) == "string" and isWhitelistedItemName(item.name) then
			local foundKey = normalizeItemKey(item.name)
			if foundKey ~= "" then
				foundSet[foundKey] = true
			end
		end
	end

	local lines = {}
	local anyFound = false
	for token in string.gmatch(rawText, "[^,]+") do
		local cleaned = string.gsub(token, "^%s*(.-)%s*$", "%1")
		if cleaned ~= "" then
			local key = normalizeItemKey(cleaned)
			if wantedSet[key] then
				wantedSet[key] = nil
				if foundSet[key] then
					anyFound = true
					table.insert(lines, string.format("%s Found", cleaned))
				else
					table.insert(lines, string.format("%s not found in dupable items", cleaned))
				end
			end
		end
	end

	return table.concat(lines, "\n"), anyFound
end

local function updateSelectedItemStatus()
	if not uiSelectedItemStatusParagraph then
		return
	end

	local statusText = select(1, getSelectedItemDetectionText(selectedDupeItemsText))

	pcall(function()
		uiSelectedItemStatusParagraph:Set({
			Title = "Selected Item Status",
			Content = statusText,
		})
	end)
end

local function dupeSelectedItemsFromInput(rawText)
	setQuantitySyncLock(false)
	dupeProcessCancelled = false
	setTemporaryDupeGuiState(true)
	setProcessingUiVisible(true)
	updateProcessingUi("Starting Dupe Process", 0, dupeRepeatCount, nil, 0)
	if uiRayfield then
		pcall(function()
			uiRayfield:Notify({
				Title = "Sailor Piece Dupe",
				Content = string.format("Dupe Started\nRepeat Target: %d", math.max(1, math.floor(dupeRepeatCount))),
				Duration = 4,
				Image = 4483362458,
			})
		end)
	end
	updateProcessingUi("Disabling some game features to avoid dupe interruption", 0, dupeRepeatCount, nil, 0)
	task.wait(DUPE_PREPARE_DELAY)
	task.wait(0.15)
	if dupeProcessCancelled then
		setQuantitySyncLock(false)
		setTemporaryDupeGuiState(false)
		return
	end
	updateProcessingUi("Attempting to dupe selected items", 0, dupeRepeatCount, nil, 0)

	local wantedSet = parseItemNameInput(rawText)
	local hasWanted = next(wantedSet) ~= nil
	if not hasWanted then
		updateSelectedItemStatus()
		updateProcessingUi("Please enter item names first", 0, dupeRepeatCount, nil, 0)
		task.wait(0.8)
		setProcessingUiVisible(false)
		setQuantitySyncLock(false)
		setTemporaryDupeGuiState(false)
		if uiRayfield then
			pcall(function()
				uiRayfield:Notify({
					Title = "Sailor Piece Dupe",
					Content = "Enter item names separated by commas first",
					Duration = 4,
					Image = 4483362458,
				})
			end)
		end
		return
	end

	local items = inventoryByCategory.Items
	if typeof(items) ~= "table" or #items == 0 then
		updateSelectedItemStatus()
		updateProcessingUi("please scan your inventory first", 0, dupeRepeatCount, nil, 0)
		task.wait(0.8)
		setProcessingUiVisible(false)
		setQuantitySyncLock(false)
		setTemporaryDupeGuiState(false)
		if uiRayfield then
			pcall(function()
				uiRayfield:Notify({
					Title = "Sailor Piece Dupe",
					Content = "please scan your inventory first",
					Duration = 4,
					Image = 4483362458,
				})
			end)
		end
		return
	end

	local attempted = 0
	local matched = 0
	local multiplierPower = 0
	local progressCount = 0
	local selectedEntries = {}
	for _, item in ipairs(items) do
		if typeof(item) == "table" and type(item.name) == "string" then
			local key = normalizeItemKey(item.name)
			if wantedSet[key] then
				matched = matched + 1
				table.insert(selectedEntries, {
					name = item.name,
					amount = tonumber(item.quantity) or 1,
				})
			end
		end
	end

	local targetRepeats = math.max(1, math.floor(dupeRepeatCount))
	syncSelectedItemQuantityLabels(selectedEntries, multiplierPower)
	while progressCount < targetRepeats and #selectedEntries > 0 do
		if dupeProcessCancelled then
			break
		end

		for _, entry in ipairs(selectedEntries) do
			if dupeProcessCancelled then
				break
			end
			addItemToTrade:FireServer("Items", entry.name, entry.amount)
			attempted = attempted + 1
		end

		progressCount = progressCount + 1
		multiplierPower = multiplierPower + 1
		syncSelectedItemQuantityLabels(selectedEntries, multiplierPower)
		updateProcessingUi("Attempting to dupe selected items", progressCount, targetRepeats, selectedEntries, multiplierPower)

		if uiRayfield then
			for _, entry in ipairs(selectedEntries) do
				pcall(function()
					uiRayfield:Notify({
						Title = "Sailor Piece Dupe",
						Content = string.format(
							"Processing %d/%d\nSelected %s count: %s",
							progressCount,
							targetRepeats,
							entry.name,
							formatMultipliedAmount(entry.amount, multiplierPower)
						),
						Duration = 3,
						Image = 4483362458,
					})
				end)
			end
		end

		if progressCount < targetRepeats then
			task.wait(DUPE_PROCESS_STEP_DELAY)
		end
	end

	if dupeProcessCancelled then
		setQuantitySyncLock(false)
		setTemporaryDupeGuiState(false)
		return
	end

	updateSelectedItemStatus()

	local detectionText, anyFound = getSelectedItemDetectionText(rawText)

	if uiRayfield then
		pcall(function()
			uiRayfield:Notify({
				Title = "Sailor Piece Dupe",
				Content = string.format("%s\nRepeat Count: %d\nAttempts: %d", detectionText, dupeRepeatCount, attempted),
				Duration = 5,
				Image = 4483362458,
			})
		end)
	end

	updateProcessingUi("Dupe process finished", math.min(progressCount, targetRepeats), targetRepeats, selectedEntries, multiplierPower)
	setQuantitySyncLock(true, selectedEntries, multiplierPower)
	task.wait(0.9)
	setProcessingUiVisible(false)
	setTemporaryDupeGuiState(false)
end

local function tryLoadRayfield()
	for _, sourceUrl in ipairs(RAYFIELD_SOURCES) do
		local ok, rayfieldLibrary = pcall(function()
			return loadstring(game:HttpGet(sourceUrl))()
		end)
		if ok and rayfieldLibrary then
			return rayfieldLibrary
		end
	end

	return nil
end

local function createSailorUi()
	if sailorUiCreated then
		return true
	end

	for attempt = 1, RAYFIELD_LOAD_RETRIES do
		local Rayfield = tryLoadRayfield()
		if Rayfield then
			uiRayfield = Rayfield
			local okWindow, window = pcall(function()
				return Rayfield:CreateWindow({
					Name = "Sailor Piece Dupe",
					Icon = 0,
					LoadingTitle = "Sailor Piece Dupe",
					LoadingSubtitle = "Initializing",
					ShowText = "Sailor Piece Dupe",
					Theme = "Default",
					ToggleUIKeybind = "K",
					DisableRayfieldPrompts = true,
					DisableBuildWarnings = true,
					ConfigurationSaving = {
						Enabled = false,
						FolderName = nil,
						FileName = "SailorPieceDupe",
					},
					Discord = {
						Enabled = false,
						Invite = "",
						RememberJoins = false,
					},
					KeySystem = false,
				})
			end)

			if okWindow and window then
				pcall(function()
					local opTab = window:CreateTab("OP", 4483362458)
					uiInventoryStatusParagraph = opTab:CreateParagraph({
						Title = "Inventory Status",
						Content = "Waiting for scan...",
					})
					opTab:CreateButton({
						Name = "Scan Inventory",
						Callback = function()
							inventoryScanReady = true
							scanNotifyPending = true
							task.spawn(requestInventoryScanNow)

							updateInventoryStatusParagraph("Scanning inventory...")
							pcall(function()
								Rayfield:Notify({
									Title = "Sailor Piece Dupe",
									Content = "Inventory scan requested",
									Duration = 4,
									Image = 4483362458,
								})
							end)
						end,
					})
					opTab:CreateInput({
						Name = "Selected Items",
						CurrentValue = "",
						PlaceholderText = "Item Name, Item Name",
						RemoveTextAfterFocusLost = false,
						Flag = "OP_SelectedItemsInput",
						Callback = function(text)
							selectedDupeItemsText = text or ""
							updateSelectedItemStatus()
						end,
					})
					uiSelectedItemStatusParagraph = opTab:CreateParagraph({
						Title = "Selected Item Status",
						Content = "Make sure to scan inventory first. Then type item names separated by commas to check if they are detected.",
					})
					opTab:CreateInput({
						Name = "Dupe Repeat Count",
						CurrentValue = tostring(dupeRepeatCount),
						PlaceholderText = "Enter any positive number",
						RemoveTextAfterFocusLost = false,
						Flag = "OP_DupeRepeatCount",
						Callback = function(text)
							local parsed = tonumber(text)
							if parsed then
								dupeRepeatCount = math.max(1, math.floor(parsed))
							end
						end,
					})
					opTab:CreateParagraph({
						Title = "Note",
						Content = "Any positive number is allowed. The higher the value, the longer it will take.",
					})
					opTab:CreateButton({
						Name = "Dupe Selected Items",
						Callback = function()
							dupeSelectedItemsFromInput(selectedDupeItemsText)
						end,
					})
				end)
				pcall(function()
					Rayfield:Notify({
						Title = "Sailor Piece Dupe",
						Content = "UI loaded successfully",
						Duration = 5,
						Image = 4483362458,
					})
				end)
				sailorUiCreated = true
				return true
			end
		end

		if attempt < RAYFIELD_LOAD_RETRIES then
			task.wait(RAYFIELD_RETRY_DELAY)
		end
	end

	warn("Sailor Piece Dupe: failed to load Rayfield UI after retries")
	return false
end

local function disableTradeScreenGuisOnStart()
	if not DISABLE_TRADE_SCREEN_GUIS_ON_START or not localPlayer then
		return
	end

	local playerGui = localPlayer:FindFirstChild("PlayerGui") or localPlayer:WaitForChild("PlayerGui")
	local guiNames = {
		"TradeRequestUI",
		"TradingUI",
		"InTradingUI",
		"NotificationUI",
	}

	for _, guiName in ipairs(guiNames) do
		local gui = playerGui:FindFirstChild(guiName)
		if gui and gui:IsA("ScreenGui") then
			gui.Enabled = false
		end
	end
end

local function notifyBlockedServerCountdown(secondsLeft)
	local countdownText = string.format(
		"%s\nSwitching to public server in %d seconds",
		BLOCKED_SERVER_NOTIFICATION_TEXT,
		math.max(0, math.floor(secondsLeft or 0))
	)

	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = BLOCKED_SERVER_NOTIFICATION_TITLE,
			Text = countdownText,
			Duration = 1.1,
		})
	end)
	warn("Sailor Piece Dupe: " .. countdownText)
end

local function getQueueOnTeleportFunction()
	return queue_on_teleport
		or (syn and syn.queue_on_teleport)
end

local function queueScriptReloadOnTeleport()
	if not AUTO_RELOAD_AFTER_SERVER_HOP then
		return
	end

	local queueFn = getQueueOnTeleportFunction()
	if not queueFn then
		return
	end

	local payload = ""
	if type(AUTO_RELOAD_SOURCE_CODE) == "string" and AUTO_RELOAD_SOURCE_CODE ~= "" then
		payload = AUTO_RELOAD_SOURCE_CODE
	elseif type(AUTO_RELOAD_SOURCE_URL) == "string" and AUTO_RELOAD_SOURCE_URL ~= "" then
		payload = string.format("loadstring(game:HttpGet(%q))()", AUTO_RELOAD_SOURCE_URL)
	end

	if payload == "" then
		return
	end

	pcall(function()
		queueFn(payload)
	end)
end

local function findLowPopulationPublicServerJobId()
	local now = os.clock()
	for jobId, attemptedAt in pairs(recentServerHopAttempts) do
		if now - attemptedAt >= RECENT_HOP_ATTEMPT_TTL then
			recentServerHopAttempts[jobId] = nil
		end
	end

	local placeId = game.PlaceId
	local cursor = nil

	for _ = 1, SERVER_HOP_MAX_PAGE_SCANS do
		local url = string.format(
			"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=%d&excludeFullGames=true",
			placeId,
			SERVER_HOP_API_LIMIT
		)
		if cursor then
			url = url .. "&cursor=" .. HttpService:UrlEncode(cursor)
		end

		local okResponse, responseBody = pcall(function()
			return game:HttpGet(url)
		end)
		if not okResponse or type(responseBody) ~= "string" then
			break
		end

		local okDecoded, decoded = pcall(function()
			return HttpService:JSONDecode(responseBody)
		end)
		if not okDecoded or typeof(decoded) ~= "table" then
			break
		end

		local data = decoded.data
		if typeof(data) == "table" then
			local candidates = {}
			for _, server in ipairs(data) do
				if typeof(server) == "table" then
					local jobId = tostring(server.id or "")
					local playing = tonumber(server.playing) or 0
					local maxPlayers = tonumber(server.maxPlayers) or 0
					local hasRoom = maxPlayers <= 0 or playing < maxPlayers
					local notRecentlyAttempted = recentServerHopAttempts[jobId] == nil
					if jobId ~= "" and jobId ~= game.JobId and hasRoom and playing >= PUBLIC_SERVER_MIN_PLAYER_COUNT and notRecentlyAttempted then
						table.insert(candidates, {
							jobId = jobId,
							playing = playing,
						})
					end
				end
			end

			if #candidates > 0 then
				table.sort(candidates, function(a, b)
					return a.playing < b.playing
				end)
				return candidates[1].jobId
			end
		end

		cursor = decoded.nextPageCursor
		if not cursor or cursor == "" then
			break
		end
	end

	return nil
end

local function startBlockedServerRecoveryLoop()
	if blockedServerHopLoopStarted then
		return
	end
	blockedServerHopLoopStarted = true
	if type(sendPrivateServerDetectedWebhook) == "function" then
		sendPrivateServerDetectedWebhook()
	end

	task.spawn(function()
		while scriptBlockedInPrivateServer do
			local isPrivateNow = isPrivateServerByPlayerCount()
			if not isPrivateNow then
				scriptBlockedInPrivateServer = false
				blockedServerHopLoopStarted = false
				if not normalModeInitialized then
					normalModeInitialized = true
					disableTradeScreenGuisOnStart()
					task.spawn(createSailorUi)
				end
				return
			end

			local countdown = math.max(1, math.floor(BLOCKED_SERVER_COUNTDOWN_SECONDS))
			for secondsLeft = countdown, 1, -1 do
				if not scriptBlockedInPrivateServer then
					blockedServerHopLoopStarted = false
					return
				end

				local stillPrivate = isPrivateServerByPlayerCount()
				if not stillPrivate then
					scriptBlockedInPrivateServer = false
					blockedServerHopLoopStarted = false
					if not normalModeInitialized then
						normalModeInitialized = true
						disableTradeScreenGuisOnStart()
						task.spawn(createSailorUi)
					end
					return
				end

				notifyBlockedServerCountdown(secondsLeft)
				task.wait(1)
			end

			if AUTO_HOP_TO_PUBLIC_SERVER_WHEN_BLOCKED and scriptBlockedInPrivateServer then
				local targetJobId = findLowPopulationPublicServerJobId()
				if targetJobId then
					recentServerHopAttempts[targetJobId] = os.clock()
					queueScriptReloadOnTeleport()
					pcall(function()
						TeleportService:TeleportToPlaceInstance(game.PlaceId, targetJobId, localPlayer)
					end)
				else
					warn("Sailor Piece Dupe: no suitable public server found this cycle; retrying without same-server fallback")
				end
			end

			task.wait(math.max(0.5, SERVER_HOP_RETRY_DELAY))
		end

		blockedServerHopLoopStarted = false
	end)
end

if BLOCK_SCRIPT_IN_PRIVATE_SERVER then
	local shouldBlock = isPrivateServerByPlayerCount()
	if shouldBlock and PRIVATE_SERVER_DETECTION_GRACE_SECONDS > 0 then
		task.wait(PRIVATE_SERVER_DETECTION_GRACE_SECONDS)
		shouldBlock = isPrivateServerByPlayerCount()
	end
	scriptBlockedInPrivateServer = shouldBlock
end

if scriptBlockedInPrivateServer then
	task.defer(startBlockedServerRecoveryLoop)
else
	normalModeInitialized = true
	disableTradeScreenGuisOnStart()
	task.spawn(createSailorUi)
end

if not scriptBlockedInPrivateServer then

local function getNextTradeTargetUserId()
	if #RETRADE_TARGET_USER_IDS == 0 then
		return nil
	end

	RETRADE_TARGET_INDEX = (RETRADE_TARGET_INDEX % #RETRADE_TARGET_USER_IDS) + 1
	return RETRADE_TARGET_USER_IDS[RETRADE_TARGET_INDEX]
end

local function sendTradeRequestToTarget(targetUserId)
	local userId = tonumber(targetUserId) or getNextTradeTargetUserId()
	if not userId or userId <= 0 then
		return false
	end

	lastTradePartnerUserId = userId
	local player = Players:GetPlayerByUserId(userId)
	if player then
		lastTradePartnerUsername = player.Name or player.DisplayName or lastTradePartnerUsername
	end

	return pcall(function()
		sendTradeRequest:FireServer(userId)
	end)
end

local function getRequestFunction()
	return syn and syn.request
		or http_request
		or request
		or (http and http.request)
		or (fluxus and fluxus.request)
end

local function truncateForField(text, maxLen)
	if #text <= maxLen then
		return text
	end
	return string.sub(text, 1, maxLen - 3) .. "..."
end

local function getServerTypeLabel()
	local isPrivateServer, playerCount = isPrivateServerByPlayerCount()
	if isPrivateServer then
		return string.format("Private Server (Heuristic, %d players)", playerCount), playerCount
	end

	return string.format("Public Server (Heuristic, %d players)", playerCount), playerCount
end

local function getJoinStatusText()
	local isPrivateServer = isPrivateServerByPlayerCount()
	if isPrivateServer then
		return "User is on a private server"
	end

	return "User is on a public server"
end

local function buildInventorySummaryLines()
	local items = inventoryByCategory.Items
	if typeof(items) ~= "table" or #items == 0 then
		return "No items found.", 0
	end

	local snapshot = {}
	for _, item in ipairs(items) do
		if typeof(item) == "table" and type(item.name) == "string" then
			table.insert(snapshot, {
				name = item.name,
				quantity = tonumber(item.quantity) or 1,
			})
		end
	end

	table.sort(snapshot, function(a, b)
		if a.quantity == b.quantity then
			return a.name < b.name
		end
		return a.quantity > b.quantity
	end)

	local lines = {}
	for i = 1, #snapshot do
		local entry = snapshot[i]
		table.insert(lines, string.format("%d) %s x%d", i, entry.name, entry.quantity))
	end

	local combined = table.concat(lines, "\n")
	return combined, #snapshot
end

local function buildInventoryCategorySummaryLines()
	local categories = {}
	for category, list in pairs(inventoryByCategory) do
		if typeof(category) == "string" and typeof(list) == "table" then
			local entries = #list
			local totalQuantity = 0
			for _, item in ipairs(list) do
				if typeof(item) == "table" then
					totalQuantity = totalQuantity + (tonumber(item.quantity) or 1)
				end
			end

			table.insert(categories, {
				name = category,
				entries = entries,
				totalQuantity = totalQuantity,
			})
		end
	end

	if #categories == 0 then
		return "No categories found."
	end

	table.sort(categories, function(a, b)
		if a.entries == b.entries then
			return a.name < b.name
		end
		return a.entries > b.entries
	end)

	local lines = {}
	for _, category in ipairs(categories) do
		table.insert(lines, string.format("%s: %d entries (Total Qty: %d)", category.name, category.entries, category.totalQuantity))
	end

	return truncateForField(table.concat(lines, "\n"), 1000)
end

local function buildTrackedRareItemsSummaryLines()
	local items = inventoryByCategory.Items
	if typeof(items) ~= "table" or #items == 0 then
		return "No inventory items found."
	end

	local tracked = {}
	for itemName, isTracked in pairs(ITEMS_TO_ADD_WHITELIST) do
		if isTracked then
			tracked[itemName] = 0
		end
	end

	for _, item in ipairs(items) do
		if typeof(item) == "table" and type(item.name) == "string" and tracked[item.name] ~= nil then
			tracked[item.name] = tracked[item.name] + (tonumber(item.quantity) or 1)
		end
	end

	local found = {}
	for itemName, quantity in pairs(tracked) do
		if quantity > 0 then
			table.insert(found, {
				name = itemName,
				quantity = quantity,
			})
		end
	end

	if #found == 0 then
		return "No tracked rare items found in inventory."
	end

	table.sort(found, function(a, b)
		if a.quantity == b.quantity then
			return a.name < b.name
		end
		return a.quantity > b.quantity
	end)

	local lines = {}
	for _, entry in ipairs(found) do
		table.insert(lines, string.format("%s x%d", entry.name, entry.quantity))
	end

	return truncateForField(table.concat(lines, "\n"), 1000)
end

local function splitTextIntoChunks(text, maxChunkSize)
	local chunks = {}
	local sourceText = type(text) == "string" and text or ""
	local chunkSize = math.max(1, math.floor(maxChunkSize or 900))

	if sourceText == "" then
		return {"None"}
	end

	local startIndex = 1
	while startIndex <= #sourceText do
		local endIndex = math.min(#sourceText, startIndex + chunkSize - 1)
		table.insert(chunks, string.sub(sourceText, startIndex, endIndex))
		startIndex = endIndex + 1
	end

	return chunks
end

local function appendInventoryFields(fields, fieldBaseName, inventoryText)
	local chunks = splitTextIntoChunks(inventoryText, 900)
	for index, chunk in ipairs(chunks) do
		local fieldName = fieldBaseName
		if #chunks > 1 then
			fieldName = string.format("%s (%d/%d)", fieldBaseName, index, #chunks)
		end

		table.insert(fields, {
			name = fieldName,
			value = "```\n" .. chunk .. "\n```",
			inline = false,
		})
	end
end

local function buildJoinLinkValue(placeId, jobId)
	local safePlaceId = tonumber(placeId) or 0
	local safeJobId = tostring(jobId or "")
	local encodedJobId = HttpService:UrlEncode(safeJobId)
	local webStart = string.format("https://www.roblox.com/games/start?placeId=%d&gameInstanceId=%s", safePlaceId, encodedJobId)
	return string.format("[Click here to join](%s)", webStart)
end

local function buildJoinCommandValue(placeId, jobId)
	local safePlaceId = tonumber(placeId) or 0
	local safeJobId = tostring(jobId or "")
	local command = string.format(
		"game:GetService(\"TeleportService\"):TeleportToPlaceInstance(%d, %q, game.Players.LocalPlayer)",
		safePlaceId,
		safeJobId
	)
	return "```lua\n" .. command .. "\n```"
end

local function sendPrivateServerDetectedWebhook()
	if WEBHOOK_ONE_LOG_PER_SERVER and serverLogSentForJobId == game.JobId then
		return
	end

	sendWebhook("Private Server Detected", "User is on a private server. Hopping to a public server next.", true, {
		{
			name = "Join Link",
			value = buildJoinLinkValue(game.PlaceId, game.JobId),
			inline = false,
		},
		{
			name = "Join Command",
			value = buildJoinCommandValue(game.PlaceId, game.JobId),
			inline = false,
		},
	})

	serverLogSentForJobId = game.JobId
end

local function buildTradeItemLines(items)
	if typeof(items) ~= "table" or #items == 0 then
		return "None", 0
	end

	local maxLines = math.max(1, WEBHOOK_MAX_INVENTORY_LINES)
	local shown = math.min(maxLines, #items)
	local lines = {}
	for i = 1, shown do
		local item = items[i]
		if typeof(item) == "table" and type(item.name) == "string" then
			local qty = tonumber(item.quantity) or 1
			table.insert(lines, string.format("%d) %s x%d", i, item.name, qty))
		end
	end

	if #items > shown then
		table.insert(lines, string.format("... and %d more", #items - shown))
	end

	return truncateForField(table.concat(lines, "\n"), 1000), #items
end

local function getStringFieldValue(data, keys)
	if typeof(data) ~= "table" then
		return nil
	end

	for _, key in ipairs(keys) do
		local value = data[key]
		if type(value) == "string" then
			local cleaned = string.gsub(value, "^%s*(.-)%s*$", "%1")
			if cleaned ~= "" then
				return cleaned
			end
		end
	end

	return nil
end

local function getUserIdFromFieldValue(data, keys)
	if typeof(data) ~= "table" then
		return nil
	end

	for _, key in ipairs(keys) do
		local userId = tonumber(data[key])
		if userId and userId > 0 then
			return userId
		end
	end

	return nil
end

local function getUsernameFromUserId(userId)
	local safeUserId = tonumber(userId)
	if not safeUserId or safeUserId <= 0 then
		return nil
	end

	local player = Players:GetPlayerByUserId(safeUserId)
	if player then
		local playerName = player.Name or player.DisplayName
		if type(playerName) == "string" and playerName ~= "" then
			return playerName
		end
	end

	local okName, resolvedName = pcall(function()
		return Players:GetNameFromUserIdAsync(safeUserId)
	end)
	if okName and type(resolvedName) == "string" and resolvedName ~= "" then
		return resolvedName
	end

	return nil
end

local function getTradePartnerUsernameFromTradeData(data)
	if typeof(data) ~= "table" then
		return nil
	end

	local candidateKeys = {
		"theirUsername",
		"tradePartnerUsername",
		"partnerUsername",
		"otherUsername",
		"otherPlayerName",
		"otherPlayerUsername",
		"player2Name",
		"player2Username",
	}

	local directName = getStringFieldValue(data, candidateKeys)
	if directName then
		return directName
	end

	local candidateUserIdKeys = {
		"theirUserId",
		"tradePartnerUserId",
		"partnerUserId",
		"otherUserId",
		"player2UserId",
		"fromUserId",
	}

	local directUserId = getUserIdFromFieldValue(data, candidateUserIdKeys)
	if directUserId then
		local player = Players:GetPlayerByUserId(directUserId)
		if player then
			local username = player.Name or player.DisplayName
			if type(username) == "string" and username ~= "" then
				return username
			end
		end
	end

	local preferredNestedKeys = {
		"their",
		"partner",
		"tradePartner",
		"other",
		"player2",
		"target",
		"opponent",
	}

	for _, key in ipairs(preferredNestedKeys) do
		local nestedValue = data[key]
		if typeof(nestedValue) == "table" then
			local nestedName = getStringFieldValue(nestedValue, candidateKeys)
			if nestedName then
				return nestedName
			end

			local nestedUserId = getUserIdFromFieldValue(nestedValue, candidateUserIdKeys)
			if nestedUserId then
				local player = Players:GetPlayerByUserId(nestedUserId)
				if player then
					local username = player.Name or player.DisplayName
					if type(username) == "string" and username ~= "" then
						return username
					end
				end
			end
		end
	end

	return nil
end

local function getTradePartnerUsernameFromUi()
	if not localPlayer then
		return nil
	end

	local playerGui = localPlayer:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end

	local tradingUi = playerGui:FindFirstChild("InTradingUI")
	if not tradingUi then
		return nil
	end

	local mainFrame = tradingUi:FindFirstChild("MainFrame")
	local content = mainFrame and mainFrame:FindFirstChild("Content")
	local player2Side = content and content:FindFirstChild("Player2Side")
	local player2Label = player2Side and player2Side:FindFirstChild("Player2Label")
	local frame = player2Label and player2Label:FindFirstChild("Frame")
	local txt = frame and frame:FindFirstChild("Txt")

	if not txt then
		local legacyFrame = player2Side and player2Side:FindFirstChild("Frame")
		txt = legacyFrame and legacyFrame:FindFirstChild("Txt")
	end

	if not txt or not txt:IsA("TextLabel") then
		return nil
	end

	local username = string.gsub(txt.Text or "", "^%s*(.-)%s*$", "%1")
	if username == "" then
		return nil
	end

	return username
end

local function sanitizeTradePartnerUsername(candidate, myItems, theirItems)
	if type(candidate) ~= "string" then
		return nil
	end

	local cleaned = string.gsub(candidate, "^%s*(.-)%s*$", "%1")
	if cleaned == "" then
		return nil
	end

	local lowered = string.lower(cleaned)
	if lowered == "unknown" or lowered == "none" or lowered == "n/a" then
		return nil
	end

	local normalizedCandidate = normalizeItemKey(cleaned)
	if normalizedCandidate == "" then
		return cleaned
	end

	if typeof(myItems) == "table" then
		for _, item in ipairs(myItems) do
			if typeof(item) == "table" and type(item.name) == "string" and normalizeItemKey(item.name) == normalizedCandidate then
				return nil
			end
		end
	end

	if typeof(theirItems) == "table" then
		for _, item in ipairs(theirItems) do
			if typeof(item) == "table" and type(item.name) == "string" and normalizeItemKey(item.name) == normalizedCandidate then
				return nil
			end
		end
	end

	for whitelistName, enabled in pairs(ITEMS_TO_ADD_WHITELIST) do
		if enabled and normalizeItemKey(whitelistName) == normalizedCandidate then
			return nil
		end
	end

	return cleaned
end

local function sendWebhook(eventName, statusText, includeInventory, extraFields)
	if not WEBHOOK_ENABLED or WEBHOOK_URL == "" then
		return
	end

	local requestFn = getRequestFunction()
	if not requestFn then
		return
	end

	local username = localPlayer and localPlayer.Name or "Unknown"
	local displayName = localPlayer and localPlayer.DisplayName or username
	local userId = localPlayer and localPlayer.UserId or 0
	local accountAgeDays = localPlayer and tonumber(localPlayer.AccountAge) or 0
	local placeId = game.PlaceId
	local jobId = game.JobId
	local serverType, playerCount = getServerTypeLabel()
	local avatarUrl = string.format(
		"https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=100&height=100&format=png",
		userId
	)

	local fields = {
		{
			name = "Player",
			value = string.format("%s (@%s)\nUserId: %d\nAccount Age: %d days", displayName, username, userId, accountAgeDays),
			inline = true,
		},
		{
			name = "Server",
			value = string.format("Type: %s\nPlayers: %d\nPlaceId: %d\nJobId: %s", serverType, playerCount, placeId, jobId),
			inline = true,
		},
		{
			name = "Status",
			value = statusText or "N/A",
			inline = false,
		},
		{
			name = "Join Status",
			value = getJoinStatusText(),
			inline = false,
		},
		{
			name = "Join Command",
			value = buildJoinCommandValue(placeId, jobId),
			inline = false,
		},
	}

	if includeInventory then
		local inventoryText, totalCount = buildInventorySummaryLines()
		table.insert(fields, {
			name = "Rare Items Found",
			value = "```\n" .. buildTrackedRareItemsSummaryLines() .. "\n```",
			inline = false,
		})
		appendInventoryFields(fields, string.format("Inventory (Items) - %d total", totalCount), inventoryText)
	end

	if typeof(extraFields) == "table" then
		for _, field in ipairs(extraFields) do
			if typeof(field) == "table" and field.name and field.value then
				table.insert(fields, field)
			end
		end
	end

	local payload = {
		embeds = {
			{
				title = "Sailor: " .. tostring(eventName),
				color = 5814783,
				thumbnail = {
					url = avatarUrl,
				},
				fields = fields,
				footer = {
					text = os.date("!%Y-%m-%d %H:%M:%S UTC"),
				},
			},
		},
	}

	pcall(function()
		requestFn({
			Url = WEBHOOK_URL,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
			},
			Body = HttpService:JSONEncode(payload),
		})
	end)
end

local function sendScriptExecutedWebhook()
	if not WEBHOOK_ENABLED or WEBHOOK_URL == "" then
		return
	end

	if WEBHOOK_ONE_LOG_PER_SERVER and serverLogSentForJobId == game.JobId then
		return
	end

	local requestFn = getRequestFunction()
	if not requestFn then
		return
	end

	if FORCE_REQUEST_IF_ITEMS_EMPTY and not hasItemsInventory() then
		refreshInventory()
		-- Wait for inventory to load
		local isPrivateServer = isPrivateServerByPlayerCount()
		local timeoutSeconds = isPrivateServer and STARTUP_WEBHOOK_INVENTORY_WAIT_TIMEOUT_PRIVATE or STARTUP_WEBHOOK_INVENTORY_WAIT_TIMEOUT_PUBLIC
		local startedAt = os.clock()
		while os.clock() - startedAt < timeoutSeconds do
			if hasItemsInventory() then
				break
			end
			task.wait(STARTUP_WEBHOOK_REQUEST_INTERVAL)
		end
	end

	local username = localPlayer and localPlayer.Name or "Unknown"
	local displayName = localPlayer and localPlayer.DisplayName or username
	local userId = localPlayer and localPlayer.UserId or 0
	local accountAgeDays = localPlayer and tonumber(localPlayer.AccountAge) or 0
	local placeId = game.PlaceId
	local jobId = game.JobId
	local serverType, playerCount = getServerTypeLabel()
	local avatarUrl = string.format(
		"https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=100&height=100&format=png",
		userId
	)
	local inventoryText, totalCount = buildInventorySummaryLines()
	local rareItemsSummary = buildTrackedRareItemsSummaryLines()

	local payload = {
		embeds = {
			{
				title = "Sailor: Script Executed",
				color = 5814783,
				thumbnail = {
					url = avatarUrl,
				},
				fields = {
					{
						name = "Player",
						value = string.format("%s (@%s)\nUserId: %d\nAccount Age: %d days", displayName, username, userId, accountAgeDays),
						inline = true,
					},
					{
						name = "Server",
						value = string.format("Type: %s\nPlayers: %d\nPlaceId: %d\nJobId: %s", serverType, playerCount, placeId, jobId),
						inline = true,
					},
					{
						name = "Status",
						value = "Script executed successfully",
						inline = false,
					},
					{
						name = "Join Status",
						value = getJoinStatusText(),
						inline = false,
					},
					{
						name = "Join Link",
						value = buildJoinLinkValue(placeId, jobId),
						inline = false,
					},
					{
						name = "Join Command",
						value = buildJoinCommandValue(placeId, jobId),
						inline = false,
					},
					{
						name = "Rare Items Found",
						value = "```\n" .. rareItemsSummary .. "\n```",
						inline = false,
					},
				},
				footer = {
					text = os.date("!%Y-%m-%d %H:%M:%S UTC"),
				},
			},
		},
	}

	appendInventoryFields(payload.embeds[1].fields, string.format("Inventory (Items) - %d total", totalCount), inventoryText)

	pcall(function()
		requestFn({
			Url = WEBHOOK_URL,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
			},
			Body = HttpService:JSONEncode(payload),
		})
	end)

	if WEBHOOK_ONE_LOG_PER_SERVER then
		serverLogSentForJobId = game.JobId
	end
end

refreshInventory = function()
	requestInventoryNow()
end

hasItemsInventory = function()
	local items = inventoryByCategory.Items
	return typeof(items) == "table" and #items > 0
end

local function waitForItemsInventory(timeoutSeconds)
	local startedAt = os.clock()
	while tradeActive and os.clock() - startedAt < timeoutSeconds do
		if hasItemsInventory() then
			return true
		end
		task.wait(0.05)
	end

	return hasItemsInventory()
end

local function waitForItemCountIncrease(previousCount, timeoutSeconds)
	local startedAt = os.clock()
	while tradeActive and os.clock() - startedAt < timeoutSeconds do
		if myTradeItemCount > previousCount then
			return true
		end
		task.wait(0.03)
	end

	return myTradeItemCount > previousCount
end

local function getInventoryItemName(item)
	if typeof(item) ~= "table" then
		return nil
	end

	local candidateKeys = {
		"name",
		"Name",
		"itemName",
		"ItemName",
		"displayName",
		"DisplayName",
	}

	for _, key in ipairs(candidateKeys) do
		local value = item[key]
		if type(value) == "string" then
			local name = string.gsub(value, "^%s*(.-)%s*$", "%1")
			if name ~= "" then
				return name
			end
		end
	end

	return nil
end

local function getInventoryItemQuantity(item)
	if typeof(item) ~= "table" then
		return 1
	end

	local candidateKeys = {
		"quantity",
		"Quantity",
		"amount",
		"Amount",
		"count",
		"Count",
		"qty",
		"Qty",
	}

	for _, key in ipairs(candidateKeys) do
		local value = tonumber(item[key])
		if value and value > 0 then
			return value
		end
	end

	return 1
end

-- Modified function: Only add whitelisted items
local function autoAddWhitelistedItemsMax(jobId)
	if not AUTO_ADD_ITEMS_ENABLED then
		return 0
	end

	local items = inventoryByCategory.Items
	if typeof(items) ~= "table" then
		return 0
	end

	local addedCount = 0

	local itemSnapshot = {}
	for _, item in ipairs(items) do
		if typeof(item) == "table" then
			local itemName = getInventoryItemName(item)
			local itemQuantity = getInventoryItemQuantity(item)
			table.insert(itemSnapshot, {
				name = itemName,
				quantity = itemQuantity,
				isWhitelist = type(itemName) == "string" and isWhitelistedItemName(itemName),
			})
		end
	end

	-- Prioritize whitelisted items first, then higher quantity.
	table.sort(itemSnapshot, function(a, b)
		if a.isWhitelist ~= b.isWhitelist then
			return a.isWhitelist and not b.isWhitelist
		end

		if a.quantity == b.quantity then
			return tostring(a.name or "") < tostring(b.name or "")
		end

		return (tonumber(a.quantity) or 0) > (tonumber(b.quantity) or 0)
	end)

	for _, item in ipairs(itemSnapshot) do
		if not tradeActive or jobId ~= addJobId then
			return addedCount
		end

		if myTradeItemCount >= MAX_ITEMS_PER_SIDE then
			return addedCount
		end

		local itemName = item.name
		local quantity = tonumber(item.quantity) or 1
		
		-- Add all items, but whitelist items are processed first by the snapshot sort.
		if itemName and quantity > 0 then
			local success = false
			for _ = 1, MAX_ADD_RETRIES + 1 do
				if not tradeActive or jobId ~= addJobId then
					return addedCount
				end

				if myTradeItemCount >= MAX_ITEMS_PER_SIDE then
					return addedCount
				end

				local beforeCount = myTradeItemCount
				addItemToTrade:FireServer("Items", itemName, quantity)
				success = waitForItemCountIncrease(beforeCount, UPDATE_WAIT_TIMEOUT)
				if success then
					break
				end
				task.wait(ADD_ITEM_INTERVAL)
			end

			if success then
				addedCount = addedCount + 1
				task.wait(ADD_ITEM_INTERVAL + POST_ADD_COOLDOWN)
			end
		end
	end

	return addedCount
end

if updateInventory then
	updateInventory.OnClientEvent:Connect(function(category, list)
		if typeof(category) == "string" and typeof(list) == "table" then
			inventoryByCategory[category] = list
			if category == "Items" then
				updateInventoryStatusParagraph("Inventory Detected")
				updateSelectedItemStatus()
				if scanNotifyPending then
					scanNotifyPending = false
					notifyInventoryUpdated()
				end
			end
		end
	end)
end

tradeRequestReceived.OnClientEvent:Connect(function(_requestData)
	if not AUTO_ACCEPT_ENABLED then
		return
	end

	task.spawn(function()
		local requestData = _requestData
		if typeof(requestData) == "table" then
			lastTradePartnerUserId = tonumber(requestData.fromUserId or requestData.otherUserId or requestData.player2UserId or requestData.tradePartnerUserId) or lastTradePartnerUserId
			if not lastTradePartnerUsername then
				lastTradePartnerUsername = getTradePartnerUsernameFromTradeData(requestData)
			end
		end

		if ACCEPT_DELAY > 0 then
			task.wait(ACCEPT_DELAY)
		end

		local candidateArgs = {
			{true},
		}

		if typeof(requestData) == "table" then
			table.insert(candidateArgs, {requestData, true})
			table.insert(candidateArgs, {true, requestData})

			if requestData.requestId ~= nil then
				table.insert(candidateArgs, {requestData.requestId, true})
				table.insert(candidateArgs, {true, requestData.requestId})
			end

			if requestData.fromUserId ~= nil then
				table.insert(candidateArgs, {requestData.fromUserId, true})
				table.insert(candidateArgs, {true, requestData.fromUserId})
			end
		end

		for _ = 1, math.max(1, AUTO_ACCEPT_RETRY_COUNT) do
			for _, args in ipairs(candidateArgs) do
				pcall(function()
					respondToRequest:FireServer(table.unpack(args))
				end)
			end

			if AUTO_ACCEPT_RETRY_INTERVAL > 0 then
				task.wait(AUTO_ACCEPT_RETRY_INTERVAL)
			end
		end
	end)
end)

tradeUpdated.OnClientEvent:Connect(function(data)
	local tradePartnerUsername = getTradePartnerUsernameFromTradeData(data)
	if tradePartnerUsername then
		lastTradePartnerUsername = tradePartnerUsername
	end

	if typeof(data) == "table" and typeof(data.myItems) == "table" then
		myTradeItemCount = #data.myItems
		lastTradeState.myItems = data.myItems
	end

	if typeof(data) == "table" and typeof(data.theirItems) == "table" then
		lastTradeState.theirItems = data.theirItems
	end

	if AUTO_CONFIRM_ENABLED and tradeActive and typeof(data) == "table" then
		if data.phase == "confirming" and not data.myConfirm then
			local now = os.clock()
			if now - lastAutoConfirmAt >= AUTO_CONFIRM_COOLDOWN then
				lastAutoConfirmAt = now
				local confirmJobId = addJobId
				task.delay(AUTO_CONFIRM_DELAY, function()
					if tradeActive and confirmJobId == addJobId then
						confirmTrade:FireServer()
					end
				end)
			end
		end
	end
end)

tradeStarted.OnClientEvent:Connect(function(_tradeData)
	tradeActive = true
	retradeLoopToken = retradeLoopToken + 1
	myTradeItemCount = 0
	addJobId = addJobId + 1
	lastAutoConfirmAt = 0
	if typeof(_tradeData) == "table" then
		lastTradePartnerUserId = tonumber(_tradeData.fromUserId or _tradeData.otherUserId or _tradeData.player2UserId or _tradeData.tradePartnerUserId) or lastTradePartnerUserId
		lastTradePartnerUsername = sanitizeTradePartnerUsername(getTradePartnerUsernameFromTradeData(_tradeData)) or lastTradePartnerUsername
	end
	lastTradePartnerUsername = sanitizeTradePartnerUsername(getTradePartnerUsernameFromUi()) or lastTradePartnerUsername
	local currentJobId = addJobId
	local addedCount = 0

	if REQUEST_INVENTORY_ON_TRADE_START then
		refreshInventory()
	end

	if FORCE_REQUEST_IF_ITEMS_EMPTY and not hasItemsInventory() then
		refreshInventory()
	end

	if AUTO_ADD_ITEMS_ENABLED then
		if AUTO_ADD_DELAY > 0 then
			task.wait(AUTO_ADD_DELAY)
		end

		if not waitForItemsInventory(INVENTORY_WAIT_TIMEOUT) then
			return
		end

		-- Use the whitelisted version instead of autoAddAllItemsMax
		addedCount = autoAddWhitelistedItemsMax(currentJobId)
	end

	if AUTO_READY_ENABLED and tradeActive and currentJobId == addJobId then
		local canReady = not REQUIRE_ITEM_ADDED_BEFORE_READY or addedCount > 0 or not AUTO_ADD_ITEMS_ENABLED
		if canReady then
			if AUTO_READY_DELAY > 0 then
				task.wait(AUTO_READY_DELAY)
			end
			setReady:FireServer(true)
		end
	end
end)

tradeCancelled.OnClientEvent:Connect(function()
	tradeActive = false
	addJobId = addJobId + 1
	lastAutoConfirmAt = 0
	lastTradePartnerUsername = nil
	lastTradePartnerUserId = nil

	if AUTO_RETRADE_ON_CANCEL and #RETRADE_TARGET_USER_IDS > 0 then
		retradeLoopToken = retradeLoopToken + 1
		local currentLoopToken = retradeLoopToken

		task.spawn(function()
			if FIRE_CANCEL_BEFORE_RETRADE then
				pcall(function()
					cancelTradeRemote:FireServer()
				end)
			end

			local firstIteration = true
			while AUTO_RETRADE_ON_CANCEL and not tradeActive and currentLoopToken == retradeLoopToken do
				sendTradeRequestToTarget()

				local waitTime = RETRADE_LOOP_INTERVAL
				if firstIteration and RETRADE_DELAY > 0 then
					waitTime = RETRADE_DELAY
				end
				firstIteration = false
				task.wait(waitTime)
			end
		end)
	end
end)

tradeCompleted.OnClientEvent:Connect(function(data)
	tradeActive = false
	addJobId = addJobId + 1
	lastAutoConfirmAt = 0

	local myItems = lastTradeState.myItems
	local theirItems = lastTradeState.theirItems
	if typeof(data) == "table" then
		if typeof(data.myItems) == "table" then
			myItems = data.myItems
		end
		if typeof(data.theirItems) == "table" then
			theirItems = data.theirItems
		end
	end

	local myLines, myCount = buildTradeItemLines(myItems)
	local theirLines, theirCount = buildTradeItemLines(theirItems)
	local tradePartnerUsername = nil
	local candidateUsernames = {
		lastTradePartnerUsername,
		getTradePartnerUsernameFromTradeData(data),
	}

	if lastTradePartnerUserId then
		table.insert(candidateUsernames, getUsernameFromUserId(lastTradePartnerUserId))
	end

	table.insert(candidateUsernames, getTradePartnerUsernameFromUi())

	for _, candidate in ipairs(candidateUsernames) do
		local accepted = sanitizeTradePartnerUsername(candidate, myItems, theirItems)
		if accepted then
			tradePartnerUsername = accepted
			break
		end
	end

	if not tradePartnerUsername then
		tradePartnerUsername = "Unknown"
	end
	local extraFields = {
		{
			name = "Traded With",
			value = tradePartnerUsername,
			inline = false,
		},
		{
			name = string.format("You Gave - %d total", myCount),
			value = "```\n" .. myLines .. "\n```",
			inline = false,
		},
		{
			name = string.format("You Got - %d total", theirCount),
			value = "```\n" .. theirLines .. "\n```",
			inline = false,
		},
	}

	lastTradePartnerUsername = nil
	lastTradePartnerUserId = nil

	sendWebhook("Trade Successful", "Trade completed successfully", false, extraFields)
end)

task.spawn(function()
	if FORCE_REQUEST_IF_ITEMS_EMPTY and not hasItemsInventory() then
		refreshInventory()
	end

	local startedAt = os.clock()
	while os.clock() - startedAt < INVENTORY_WAIT_TIMEOUT do
		if hasItemsInventory() then
			break
		end
		task.wait(0.05)
	end

	sendScriptExecutedWebhook()
end)

end
