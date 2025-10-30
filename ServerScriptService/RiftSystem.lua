-- =====================================
-- RIFT SYSTEM - ITEM LOOT SYSTEM
-- Uses ItemDatabase for item drops
-- Supports Mimic's Luck for better drops
-- Place in ServerScriptService
-- =====================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🌀 [RIFT SYSTEM] Loading...")

-- ========================
-- КОНФИГУРАЦИЯ
-- ========================
local CONFIG = {
	DEBUG_MODE = true,

	-- Спавн рифтов
	RIFTS_PER_PLAYER = 12, -- Рифтов на игрока
	MIN_RIFT_COST = 12, -- Минимальная стоимость
	MAX_RIFT_COST = 20, -- Максимальная стоимость
	SPAWN_RADIUS = 120, -- Радиус спавна от центра
	MIN_SPAWN_DISTANCE = 60, -- Минимальное расстояние от центра

	-- Визуализация
	RIFT_SIZE = Vector3.new(6, 10, 0.5),
	RIFT_COLOR = Color3.fromRGB(138, 43, 226), -- Фиолетовый
	ROTATION_SPEED = 1, -- Скорость вращения

	-- Лут
	ITEMS_PER_RIFT = 1, -- Предметов за рифт
	LUCKY_REROLL_CHANCE = 0.5, -- Шанс перероллить с Mimic's Luck
}

-- ========================
-- ХРАНИЛИЩЕ ДАННЫХ
-- ========================
local RiftState = {
	activeRifts = {}, -- {rift, ...}
	totalRiftsCreated = 0,
	totalItemsDropped = 0,
}

local CrystalSystem = nil
local ItemDatabase = nil
local ItemEffectSystem = nil

-- ========================
-- ЗАГРУЗКА СИСТЕМ
-- ========================
local function loadSystems()
	task.wait(2)

	-- CrystalSystem
	local crystalScript = script.Parent:FindFirstChild("CrystalSystem")
	if crystalScript then
		CrystalSystem = require(crystalScript)
		print("✅ [RIFT] CrystalSystem loaded!")
	else
		warn("⚠️ [RIFT] CrystalSystem not found!")
	end

	-- ItemDatabase
	local itemDBModule = ReplicatedStorage:FindFirstChild("ItemDatabase")
	if itemDBModule then
		ItemDatabase = require(itemDBModule)
		print("✅ [RIFT] ItemDatabase loaded!")
	else
		warn("⚠️ [RIFT] ItemDatabase not found!")
	end

	-- ItemEffectSystem
	local itemEffectModule = ReplicatedStorage:FindFirstChild("ItemEffectSystem")
	if itemEffectModule then
		ItemEffectSystem = require(itemEffectModule)
		print("✅ [RIFT] ItemEffectSystem loaded!")
	else
		warn("⚠️ [RIFT] ItemEffectSystem not found!")
	end
end

task.spawn(loadSystems)

-- ========================
-- ПОЛУЧИТЬ СТАКИ ПРЕДМЕТА
-- ========================
local function getItemStacks(character, itemKey)
	if not character then return 0 end

	local value1 = character:FindFirstChild(itemKey)
	local value2 = character:FindFirstChild(itemKey .. "_Stacks")

	if value1 and value1:IsA("NumberValue") then
		return value1.Value
	elseif value2 and value2:IsA("NumberValue") then
		return value2.Value
	end

	return 0
end

-- ========================
-- ВЫБРАТЬ СЛУЧАЙНЫЙ ПРЕДМЕТ
-- ========================
local function selectRandomItem(player)
	if not ItemDatabase then
		warn("⚠️ [RIFT] ItemDatabase not available!")
		return nil
	end

	local item = ItemDatabase.GetRandomItem()

	-- Mimic's Luck: Шанс перероллить на лучший предмет
	if player and player.Character then
		local mimicStacks = getItemStacks(player.Character, "MimicsLuck")

		if mimicStacks > 0 then
			for i = 1, mimicStacks do
				if math.random() < CONFIG.LUCKY_REROLL_CHANCE then
					local rerolledItem = ItemDatabase.GetRandomItem()

					-- Выбираем лучший (редкий)
					if rerolledItem.Rarity > item.Rarity then
						item = rerolledItem

						if CONFIG.DEBUG_MODE then
							print("🎲 [RIFT] Mimic's Luck reroll #" .. i .. ": " .. item.Name .. " (" .. item.RarityName .. ")")
						end
					end
				end
			end
		end
	end

	return item
end

-- ========================
-- СОЗДАТЬ ПАДАЮЩИЙ ПРЕДМЕТ
-- ========================
local function createFloatingItem(position, itemKey)
	if not ItemDatabase then return nil end

	local itemData = ItemDatabase.GetItem(itemKey)
	if not itemData then
		warn("⚠️ [RIFT] Item not found: " .. itemKey)
		return nil
	end

	-- Создаём модель предмета
	local itemModel = Instance.new("Model")
	itemModel.Name = "Item_" .. itemKey

	local itemPart = Instance.new("Part")
	itemPart.Name = "ItemPart"
	itemPart.Size = Vector3.new(2, 2, 2)
	itemPart.Material = Enum.Material.Neon
	itemPart.Color = itemData.RarityColor
	itemPart.Anchored = true
	itemPart.CanCollide = false
	itemPart.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))
	itemPart.Parent = itemModel

	-- Подсветка
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 15
	light.Color = itemData.RarityColor
	light.Parent = itemPart

	-- Название предмета
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = itemPart
	billboard.Size = UDim2.new(0, 200, 0, 100)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = itemPart

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0.5, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = itemData.Name
	titleLabel.TextColor3 = itemData.RarityColor
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextStrokeTransparency = 0.5
	titleLabel.Parent = billboard

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Position = UDim2.new(0, 0, 0.5, 0)
	rarityLabel.Size = UDim2.new(1, 0, 0.5, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = itemData.RarityName
	rarityLabel.TextColor3 = itemData.RarityColor
	rarityLabel.TextScaled = true
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.TextStrokeTransparency = 0.5
	rarityLabel.Parent = billboard

	-- Атрибуты
	itemModel:SetAttribute("ItemKey", itemKey)

	itemModel.Parent = Workspace

	-- Вращение и плавание
	task.spawn(function()
		local startTime = tick()
		while itemModel.Parent do
			local elapsed = tick() - startTime
			itemPart.CFrame = CFrame.new(position + Vector3.new(0, 3 + math.sin(elapsed * 2) * 0.5, 0))
				* CFrame.Angles(0, elapsed * CONFIG.ROTATION_SPEED, math.sin(elapsed) * 0.2)
			task.wait()
		end
	end)

	-- Сбор предмета
	itemPart.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and itemModel.Parent then
			applyItemEffect(player, hit.Parent, itemKey, 1)
			itemModel:Destroy()
		end
	end)

	return itemModel
end

-- ========================
-- ПРИМЕНИТЬ ЭФФЕКТ ПРЕДМЕТА
-- ========================
function applyItemEffect(player, character, itemKey, stackCount)
	if not ItemEffectSystem then
		warn("⚠️ [RIFT] ItemEffectSystem not available!")
		return
	end

	local success = ItemEffectSystem.ApplyItem(character, itemKey, stackCount)

	if success then
		local itemData = ItemDatabase.GetItem(itemKey)

		-- Уведомление игроку
		local remoteEvent = ReplicatedStorage:FindFirstChild("ShowNotification")
		if remoteEvent and itemData then
			pcall(function()
				local message = "+" .. stackCount .. "x " .. itemData.Name
				remoteEvent:FireClient(player, message, itemData.RarityColor)
			end)
		end

		if CONFIG.DEBUG_MODE then
			print("✅ [RIFT] Applied " .. itemKey .. " x" .. stackCount .. " to " .. player.Name)
		end

		RiftState.totalItemsDropped = RiftState.totalItemsDropped + stackCount
	else
		warn("⚠️ [RIFT] Failed to apply item: " .. itemKey)
	end
end

-- ========================
-- СОЗДАТЬ РИФТ
-- ========================
local function createRift(position)
	local rift = Instance.new("Model")
	rift.Name = "Rift"

	-- Главная часть
	local riftPart = Instance.new("Part")
	riftPart.Name = "RiftPart"
	riftPart.Size = CONFIG.RIFT_SIZE
	riftPart.Material = Enum.Material.Neon
	riftPart.Color = CONFIG.RIFT_COLOR
	riftPart.Anchored = true
	riftPart.CanCollide = false
	riftPart.Transparency = 0.3
	riftPart.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	riftPart.Parent = rift

	-- Подсветка
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 20
	light.Color = CONFIG.RIFT_COLOR
	light.Parent = riftPart

	-- Частицы
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(CONFIG.RIFT_COLOR)
	particles.Size = NumberSequence.new(0.5)
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 50
	particles.Speed = NumberRange.new(2, 4)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = riftPart

	-- Стоимость
	local cost = math.random(CONFIG.MIN_RIFT_COST, CONFIG.MAX_RIFT_COST)
	rift:SetAttribute("Cost", cost)

	-- Текст стоимости
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = riftPart
	billboard.Size = UDim2.new(0, 150, 0, 80)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = riftPart

	local costLabel = Instance.new("TextLabel")
	costLabel.Size = UDim2.new(1, 0, 1, 0)
	costLabel.BackgroundTransparency = 1
	costLabel.Text = "🌀 RIFT\n💎 " .. cost .. " Crystals"
	costLabel.TextColor3 = CONFIG.RIFT_COLOR
	costLabel.TextScaled = true
	costLabel.Font = Enum.Font.GothamBold
	costLabel.TextStrokeTransparency = 0.5
	costLabel.Parent = billboard

	rift.Parent = Workspace
	table.insert(RiftState.activeRifts, rift)
	RiftState.totalRiftsCreated = RiftState.totalRiftsCreated + 1

	-- Вращение
	task.spawn(function()
		while rift.Parent do
			riftPart.CFrame = riftPart.CFrame * CFrame.Angles(0, CONFIG.ROTATION_SPEED * 0.05, 0)
			task.wait()
		end
	end)

	-- Взаимодействие
	riftPart.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and rift.Parent then
			local riftCost = rift:GetAttribute("Cost")

			if CrystalSystem and CrystalSystem.RemoveCrystals(riftCost) then
				-- Оплата успешна
				if CONFIG.DEBUG_MODE then
					print("🌀 [RIFT] " .. player.Name .. " opened rift for " .. riftCost .. " crystals")
				end

				-- Дроп предметов
				for i = 1, CONFIG.ITEMS_PER_RIFT do
					local item = selectRandomItem(player)

					if item then
						local dropPosition = position + Vector3.new(
							math.random(-5, 5),
							0,
							math.random(-5, 5)
						)

						createFloatingItem(dropPosition, item.Key)

						if CONFIG.DEBUG_MODE then
							print("   Item " .. i .. ": " .. item.Name .. " (" .. item.RarityName .. ")")
						end
					end
				end

				-- Удаляем рифт
				for i, r in ipairs(RiftState.activeRifts) do
					if r == rift then
						table.remove(RiftState.activeRifts, i)
						break
					end
				end

				rift:Destroy()
			else
				-- Недостаточно кристаллов
				local remoteEvent = ReplicatedStorage:FindFirstChild("ShowNotification")
				if remoteEvent then
					pcall(function()
						remoteEvent:FireClient(player, "❌ Not enough crystals! Need " .. riftCost, Color3.fromRGB(255, 0, 0))
					end)
				end
			end
		end
	end)

	if CONFIG.DEBUG_MODE then
		print("🌀 [RIFT] Created rift (cost: " .. cost .. ") at " .. tostring(position))
	end

	return rift
end

-- ========================
-- НАЙТИ ЦЕНТР КАРТЫ
-- ========================
local function findMapCenter()
	local generatedMap = Workspace:FindFirstChild("GeneratedMap")
	if generatedMap then
		local cf, size = generatedMap:GetBoundingBox()
		return cf.Position
	end
	return Vector3.new(0, 0, 0)
end

-- ========================
-- ПОЛУЧИТЬ СЛУЧАЙНУЮ ТОЧКУ НА КАРТЕ
-- ========================
local function getRandomMapPosition()
	local mapCenter = findMapCenter()
	local angle = math.random() * math.pi * 2
	local distance = math.random(CONFIG.MIN_SPAWN_DISTANCE, CONFIG.SPAWN_RADIUS)

	local x = mapCenter.X + math.cos(angle) * distance
	local z = mapCenter.Z + math.sin(angle) * distance

	-- Ищем землю
	local rayOrigin = Vector3.new(x, 200, z)
	local rayDirection = Vector3.new(0, -400, 0)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include

	local generatedMap = Workspace:FindFirstChild("GeneratedMap")
	if generatedMap then
		raycastParams.FilterDescendantsInstances = {generatedMap}
	end

	local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if rayResult then
		return rayResult.Position + Vector3.new(0, 5, 0)
	end

	return Vector3.new(x, mapCenter.Y + 10, z)
end

-- ========================
-- СОЗДАТЬ ВСЕ РИФТЫ
-- ========================
local function spawnAllRifts()
	print("⏳ [RIFT] Waiting for map generation...")

	-- Ждём карту
	for i = 1, 30 do
		local generatedMap = Workspace:FindFirstChild("GeneratedMap")
		if generatedMap then
			break
		end
		task.wait(1)
	end

	task.wait(2)

	local playerCount = #Players:GetPlayers()
	local totalRifts = playerCount * CONFIG.RIFTS_PER_PLAYER

	print("🌀 [RIFT] Spawning " .. totalRifts .. " rifts for " .. playerCount .. " player(s)...")

	for i = 1, totalRifts do
		local position = getRandomMapPosition()
		createRift(position)
		task.wait(0.1) -- Небольшая задержка между рифтами
	end

	print("✅ [RIFT] All rifts spawned!")
end

-- ========================
-- КОМАНДЫ УПРАВЛЕНИЯ
-- ========================
_G.RiftStats = function()
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🌀 [RIFT] Statistics:")
	print("   Active rifts: " .. #RiftState.activeRifts)
	print("   Total created: " .. RiftState.totalRiftsCreated)
	print("   Total items dropped: " .. RiftState.totalItemsDropped)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

_G.SpawnRift = function(position)
	local pos = position or getRandomMapPosition()
	createRift(pos)
	print("🌀 [RIFT] Spawned rift at " .. tostring(pos))
end

_G.ClearAllRifts = function()
	for _, rift in ipairs(RiftState.activeRifts) do
		if rift and rift.Parent then
			rift:Destroy()
		end
	end
	RiftState.activeRifts = {}
	print("🧹 [RIFT] All rifts cleared!")
end

-- ========================
-- ИНИЦИАЛИЗАЦИЯ
-- ========================
print("✅ [RIFT SYSTEM] Loaded!")
print("   Rifts per player: " .. CONFIG.RIFTS_PER_PLAYER)
print("   Rift cost: " .. CONFIG.MIN_RIFT_COST .. "-" .. CONFIG.MAX_RIFT_COST .. " crystals")
print("   Items per rift: " .. CONFIG.ITEMS_PER_RIFT)
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Автоспавн рифтов
task.spawn(spawnAllRifts)

-- ========================
-- ЭКСПОРТ
-- ========================
return {
	CreateRift = createRift,
	GetActiveRifts = function() return RiftState.activeRifts end,
	GetStats = function() return RiftState end,
}
