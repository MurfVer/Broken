-- =====================================
-- PORTAL SYSTEM - BOSS & TELEPORTATION
-- Portal activation spawns boss (BossChimp)
-- Charging system with boss health tracking
-- Place in ServerScriptService
-- =====================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🌀 [PORTAL SYSTEM] Loading...")

-- ========================
-- КОНФИГУРАЦИЯ
-- ========================
local PORTAL_CONFIG = {
	DEBUG_MODE = true,

	-- Зарядка
	CHARGING_TIME = 100, -- Секунд до полной зарядки
	CHARGING_RADIUS = 150, -- Радиус зарядки
	CHARGE_PER_PLAYER_PER_SECOND = 1, -- Заряд за игрока в секунду

	-- Босс
	BOSS_NAME = "BossChimp",
	BOSS_SPAWN_OFFSET = Vector3.new(0, 10, 30), -- Смещение от портала

	-- Телепортация
	TARGET_PLACE_ID = 104935564927197, -- ID целевого места
	STUDIO_TEST_MODE = true, -- В студии не телепортируем
}

-- ========================
-- ХРАНИЛИЩЕ ДАННЫХ
-- ========================
local PortalState = {
	portal = nil,
	portalPart = nil,
	chargeProgress = 0,
	maxCharge = 100,
	isCharging = false,
	boss = nil,
	bossAlive = false,
	playersNearPortal = {},
}

local NPCManager = nil

-- ========================
-- ЗАГРУЗКА СИСТЕМ
-- ========================
local function loadSystems()
	task.wait(2)

	-- NPCManager
	local npcManagerScript = script.Parent:FindFirstChild("NPCManager")
	if npcManagerScript then
		NPCManager = require(npcManagerScript)
		print("✅ [PORTAL] NPCManager loaded!")
	end
end

task.spawn(loadSystems)

-- ========================
-- НАЙТИ ПОРТАЛ
-- ========================
local function findPortal()
	local portal = Workspace:FindFirstChild("Portal")
	if portal then
		local portalPart = portal:FindFirstChild("PortalPart")
		if portalPart then
			PortalState.portal = portal
			PortalState.portalPart = portalPart
			return true
		end
	end
	return false
end

-- ========================
-- СПАВН БОССА
-- ========================
local function spawnBoss()
	if PortalState.bossAlive or not PortalState.portalPart then
		return
	end

	local bossTemplate = ServerStorage:FindFirstChild(PORTAL_CONFIG.BOSS_NAME)
	if not bossTemplate then
		warn("⚠️ [PORTAL] Boss template not found: " .. PORTAL_CONFIG.BOSS_NAME)
		return
	end

	local spawnPosition = PortalState.portalPart.Position + PORTAL_CONFIG.BOSS_SPAWN_OFFSET
	local boss = bossTemplate:Clone()

	-- Устанавливаем позицию
	if boss.PrimaryPart then
		boss:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
	elseif boss:FindFirstChild("HumanoidRootPart") then
		boss.HumanoidRootPart.CFrame = CFrame.new(spawnPosition)
	end

	boss.Parent = Workspace

	-- Регистрируем в NPCManager
	if NPCManager then
		NPCManager:Register(boss, "melee")
	end

	PortalState.boss = boss
	PortalState.bossAlive = true

	-- Отслеживание смерти босса
	local humanoid = boss:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			PortalState.bossAlive = false
			PortalState.isCharging = true
			PortalState.portalPart:SetAttribute("IsCharging", true)

			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
			print("💀 [PORTAL] Boss defeated!")
			print("🌀 [PORTAL] Portal charging started!")
			print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

			-- Уведомление всем игрокам
			local remoteEvent = ReplicatedStorage:FindFirstChild("ShowNotification")
			if remoteEvent then
				for _, player in ipairs(Players:GetPlayers()) do
					pcall(function()
						remoteEvent:FireClient(player, "🌀 Portal is charging! Stay near it!", Color3.fromRGB(138, 43, 226))
					end)
				end
			end

			-- Запуск трекинга здоровья босса
			setupBossHealthTracking(boss)
		end)
	end

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("👹 [PORTAL] Boss spawned: " .. PORTAL_CONFIG.BOSS_NAME)
	print("   Position: " .. tostring(spawnPosition))
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	-- Уведомление всем игрокам
	local remoteEvent = ReplicatedStorage:FindFirstChild("ShowNotification")
	if remoteEvent then
		for _, player in ipairs(Players:GetPlayers()) do
			pcall(function()
				remoteEvent:FireClient(player, "👹 BOSS SPAWNED!", Color3.fromRGB(255, 0, 0))
			end)
		end
	end
end

-- ========================
-- ТРЕКИНГ ЗДОРОВЬЯ БОССА
-- ========================
function setupBossHealthTracking(boss)
	local humanoid = boss:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local updateBossHealthEvent = ReplicatedStorage:FindFirstChild("UpdateBossHealth")
	if not updateBossHealthEvent then
		updateBossHealthEvent = Instance.new("RemoteEvent")
		updateBossHealthEvent.Name = "UpdateBossHealth"
		updateBossHealthEvent.Parent = ReplicatedStorage
	end

	-- Обновляем здоровье для всех игроков
	local function updateHealth()
		local healthPercent = (humanoid.Health / humanoid.MaxHealth) * 100

		for _, player in ipairs(Players:GetPlayers()) do
			pcall(function()
				updateBossHealthEvent:FireClient(player, healthPercent, boss.Name)
			end)
		end
	end

	humanoid.HealthChanged:Connect(updateHealth)
	updateHealth() -- Начальное обновление

	humanoid.Died:Connect(function()
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			pcall(function()
				updateBossHealthEvent:FireClient(player, 0, "")
			end)
		end
	end)
end

-- ========================
-- ОБНОВЛЕНИЕ ЗАРЯДКИ
-- ========================
local function updateCharging()
	if not PortalState.isCharging or not PortalState.portalPart then
		return
	end

	-- Подсчёт игроков рядом с порталом
	local playersNearby = 0

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

			if rootPart and humanoid and humanoid.Health > 0 then
				local distance = (rootPart.Position - PortalState.portalPart.Position).Magnitude

				if distance <= PORTAL_CONFIG.CHARGING_RADIUS then
					playersNearby = playersNearby + 1
					PortalState.playersNearPortal[player.UserId] = true
				else
					PortalState.playersNearPortal[player.UserId] = nil
				end
			end
		end
	end

	-- Заряжаем портал
	if playersNearby > 0 then
		local chargeIncrease = playersNearby * PORTAL_CONFIG.CHARGE_PER_PLAYER_PER_SECOND
		PortalState.chargeProgress = math.min(PortalState.chargeProgress + chargeIncrease, PortalState.maxCharge)

		PortalState.portalPart:SetAttribute("ChargeProgress", PortalState.chargeProgress)

		if PORTAL_CONFIG.DEBUG_MODE and math.floor(PortalState.chargeProgress) % 10 == 0 then
			print("🌀 [PORTAL] Charging: " .. math.floor(PortalState.chargeProgress) .. "/" .. PortalState.maxCharge .. " (" .. playersNearby .. " players)")
		end
	end

	-- Портал полностью заряжен
	if PortalState.chargeProgress >= PortalState.maxCharge then
		PortalState.isCharging = false
		PortalState.portalPart:SetAttribute("IsCharging", false)
		PortalState.portalPart:SetAttribute("IsActive", true)

		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("✅ [PORTAL] Portal fully charged!")
		print("🌀 [PORTAL] Portal is now ACTIVE!")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

		-- Уведомление всем игрокам
		local remoteEvent = ReplicatedStorage:FindFirstChild("ShowNotification")
		if remoteEvent then
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(function()
					remoteEvent:FireClient(player, "✅ PORTAL ACTIVE! Enter to teleport!", Color3.fromRGB(0, 255, 0))
				end)
			end
		end

		-- Визуальный эффект активации
		if PortalState.portalPart then
			PortalState.portalPart.Material = Enum.Material.ForceField
			PortalState.portalPart.Color = Color3.fromRGB(0, 255, 0)
		end
	end
end

-- ========================
-- ТЕЛЕПОРТАЦИЯ ИГРОКА
-- ========================
local function teleportPlayer(player)
	if PORTAL_CONFIG.STUDIO_TEST_MODE and game:GetService("RunService"):IsStudio() then
		print("🌀 [PORTAL] Studio test mode - Teleportation skipped for " .. player.Name)

		local remoteEvent = ReplicatedStorage:FindFirstChild("ShowNotification")
		if remoteEvent then
			pcall(function()
				remoteEvent:FireClient(player, "🌀 [TEST MODE] Teleportation disabled in Studio", Color3.fromRGB(255, 255, 0))
			end)
		end

		return
	end

	print("🌀 [PORTAL] Teleporting " .. player.Name .. " to Place ID: " .. PORTAL_CONFIG.TARGET_PLACE_ID)

	local success, errorMessage = pcall(function()
		TeleportService:Teleport(PORTAL_CONFIG.TARGET_PLACE_ID, player)
	end)

	if not success then
		warn("⚠️ [PORTAL] Teleportation failed: " .. tostring(errorMessage))
	end
end

-- ========================
-- ОБРАБОТКА КАСАНИЯ ПОРТАЛА
-- ========================
local function setupPortalTouch()
	if not PortalState.portalPart then return end

	PortalState.portalPart.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)

		if player then
			-- Проверка активности портала
			local isActive = PortalState.portalPart:GetAttribute("IsActive")

			if isActive then
				teleportPlayer(player)
			elseif not PortalState.bossAlive and not PortalState.isCharging then
				-- Первое касание - спавн босса
				spawnBoss()
			end
		end
	end)

	print("✅ [PORTAL] Touch detection active!")
end

-- ========================
-- ОСНОВНОЙ ЦИКЛ
-- ========================
local function mainLoop()
	while true do
		updateCharging()
		task.wait(1)
	end
end

-- ========================
-- КОМАНДЫ УПРАВЛЕНИЯ
-- ========================
_G.PortalStats = function()
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🌀 [PORTAL] Statistics:")
	print("   Charge: " .. math.floor(PortalState.chargeProgress) .. "/" .. PortalState.maxCharge)
	print("   Charging: " .. tostring(PortalState.isCharging))
	print("   Boss alive: " .. tostring(PortalState.bossAlive))
	print("   Players nearby: " .. #PortalState.playersNearPortal)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

_G.SpawnBoss = function()
	spawnBoss()
end

_G.ResetPortal = function()
	PortalState.chargeProgress = 0
	PortalState.isCharging = false
	PortalState.bossAlive = false
	PortalState.playersNearPortal = {}

	if PortalState.portalPart then
		PortalState.portalPart:SetAttribute("ChargeProgress", 0)
		PortalState.portalPart:SetAttribute("IsCharging", false)
		PortalState.portalPart:SetAttribute("IsActive", false)
		PortalState.portalPart.Material = Enum.Material.Neon
		PortalState.portalPart.Color = Color3.fromRGB(138, 43, 226)
	end

	if PortalState.boss and PortalState.boss.Parent then
		PortalState.boss:Destroy()
	end

	print("🔄 [PORTAL] Portal reset!")
end

-- ========================
-- ИНИЦИАЛИЗАЦИЯ
-- ========================
print("⏳ [PORTAL] Waiting for portal...")

-- Ищем портал
task.spawn(function()
	for i = 1, 30 do
		if findPortal() then
			print("✅ [PORTAL] Portal found!")
			setupPortalTouch()
			task.spawn(mainLoop)
			break
		end
		task.wait(1)
	end

	if not PortalState.portal then
		warn("❌ [PORTAL] Portal not found after 30 seconds!")
	end
end)

print("✅ [PORTAL SYSTEM] Loaded!")
print("   Boss: " .. PORTAL_CONFIG.BOSS_NAME)
print("   Charging time: " .. PORTAL_CONFIG.CHARGING_TIME .. "s")
print("   Charging radius: " .. PORTAL_CONFIG.CHARGING_RADIUS .. " studs")
print("   Target Place ID: " .. PORTAL_CONFIG.TARGET_PLACE_ID)
print("   Studio test mode: " .. tostring(PORTAL_CONFIG.STUDIO_TEST_MODE))
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- ========================
-- ЭКСПОРТ
-- ========================
return {
	GetPortalState = function() return PortalState end,
	SpawnBoss = spawnBoss,
	TeleportPlayer = teleportPlayer,
}
