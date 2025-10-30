-- LocalScript для UI зарядки портала
-- Поместить в StarterPlayer > StarterPlayerScripts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- ========================
-- НАСТРОЙКИ UI
-- ========================
local UI_CONFIG = {
	UI_HEIGHT_OFFSET = 25,  -- Высота UI над порталом
	UI_SIZE = UDim2.new(0, 150, 0, 150),  -- Фиксированный размер
}

-- ========================
-- ПЕРЕМЕННЫЕ
-- ========================
local portalChargingEvent = nil
local portalBillboardGui = nil
local percentageLabel = nil
local portal = nil

-- ========================
-- ПОИСК ПОРТАЛА
-- ========================

local function findPortal()
	local generatedMap = workspace:FindFirstChild("GeneratedMap")
	if not generatedMap then
		return nil
	end

	for _, child in pairs(generatedMap:GetDescendants()) do
		if child.Name == "Portal" and (child:IsA("Model") or child:IsA("BasePart")) then
			return child
		end
	end

	return nil
end

-- ========================
-- СОЗДАНИЕ UI
-- ========================

local function createPortalUI()
	if portalBillboardGui then
		return -- UI уже создан
	end

	-- Определяем attachment point
	local attachPart
	if portal:IsA("BasePart") then
		attachPart = portal
	elseif portal:IsA("Model") then
		attachPart = portal.PrimaryPart or portal:FindFirstChildOfClass("BasePart")
	end

	if not attachPart then
		warn("Не удалось найти часть для UI!")
		return
	end

	-- Создаём BillboardGui
	portalBillboardGui = Instance.new("BillboardGui")
	portalBillboardGui.Name = "PortalChargingUI"
	portalBillboardGui.Adornee = attachPart
	portalBillboardGui.Size = UI_CONFIG.UI_SIZE
	portalBillboardGui.StudsOffset = Vector3.new(0, UI_CONFIG.UI_HEIGHT_OFFSET, 0)
	portalBillboardGui.AlwaysOnTop = true
	portalBillboardGui.MaxDistance = 1000 -- Видно издалека
	portalBillboardGui.Parent = player.PlayerGui

	-- ТОЛЬКО ТЕКСТ ПРОЦЕНТОВ - никакого дизайна!
	percentageLabel = Instance.new("TextLabel")
	percentageLabel.Name = "PercentageLabel"
	percentageLabel.Size = UDim2.new(1, 0, 1, 0)
	percentageLabel.Position = UDim2.new(0, 0, 0, 0)
	percentageLabel.BackgroundTransparency = 1  -- Полностью прозрачный фон
	percentageLabel.BorderSizePixel = 0  -- Без границ
	percentageLabel.Text = "0%"
	percentageLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	percentageLabel.TextSize = 60  -- ФИКСИРОВАННЫЙ размер текста
	percentageLabel.Font = Enum.Font.GothamBold
	percentageLabel.TextStrokeTransparency = 0.5  -- Лёгкая обводка для читаемости
	percentageLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	percentageLabel.Parent = portalBillboardGui

	warn("✅ UI портала создан (только проценты)!")
end

-- ========================
-- ОБРАБОТКА СОБЫТИЙ
-- ========================

local function setupEventListeners()
	portalChargingEvent = ReplicatedStorage:WaitForChild("PortalChargingEvent")

	portalChargingEvent.OnClientEvent:Connect(function(eventType, data)

		if eventType == "ChargingStarted" then
			warn("🔋 Зарядка началась! Создаём UI...")
			-- СОЗДАЁМ UI ТОЛЬКО ПРИ АКТИВАЦИИ ПОРТАЛА
			createPortalUI()

		elseif eventType == "ChargingProgress" then
			if not portalBillboardGui or not percentageLabel then return end

			local progress = math.floor(data.Progress)
			percentageLabel.Text = progress .. "%"

			-- Меняем цвет в зависимости от прогресса
			if progress < 30 then
				percentageLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Красный
			elseif progress < 70 then
				percentageLabel.TextColor3 = Color3.fromRGB(255, 200, 100) -- Оранжевый
			else
				percentageLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Зелёный
			end

			-- Если полностью заряжен
			if progress >= 100 then
				percentageLabel.Text = "100%"
				percentageLabel.TextColor3 = Color3.fromRGB(100, 255, 100)

				-- Анимация мигания текста
				spawn(function()
					while percentageLabel and percentageLabel.Parent do
						percentageLabel.TextTransparency = 0.3
						wait(0.5)
						percentageLabel.TextTransparency = 0
						wait(0.5)
					end
				end)
			end
		end
	end)
end

-- ========================
-- ГЛАВНАЯ ФУНКЦИЯ
-- ========================

local function main()
	warn("Ожидание портала для UI...")

	-- Ждём пока портал появится
	wait(5)

	portal = findPortal()
	if not portal then
		warn("❌ Портал не найден для UI!")
		return
	end

	warn("✅ Портал найден! Ожидание активации...")

	-- НЕ создаём UI сразу, только слушаем события
	setupEventListeners()

	warn("✅ Система UI готова! UI появится при активации портала.")
end

main()
