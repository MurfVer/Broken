-- =====================================
-- DIRECTOR - WAVE SPAWNING SYSTEM
-- Spawns waves of enemies every 5 seconds
-- Supports 400+ NPCs without lag
-- Place in ServerScriptService
-- =====================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("📡 [DIRECTOR] Loading...")

-- ========================
-- КОНФИГУРАЦИЯ
-- ========================
local CONFIG = {
	WAVE_INTERVAL = 5, -- Секунды между волнами
	MAX_MOBS_PER_WAVE = 500, -- Максимум мобов в одной волне
	MAX_MOBS_ALIVE = 1000, -- Максимум живых мобов одновременно

	SPAWN_RADIUS = 150, -- Радиус спавна от центра карты
	MIN_SPAWN_DISTANCE = 80, -- Минимальное расстояние от центра

	-- Масштабирование уровней
	LEVEL_SCALING = {
		HP_MULTIPLIER = 0.30, -- +30% HP за уровень
		DAMAGE_MULTIPLIER = 0.20, -- +20% урона за уровень
	},

	-- Пул мобов и их веса
	MOB_POOL = {
		{Name = "Monster_Close", Weight = 40, Cost = 1},
		{Name = "Monster_Far", Weight = 30, Cost = 1},
		{Name = "Monster_CloseBig", Weight = 20, Cost = 2},
	},

	DEBUG_MODE = true,
}

-- ========================
-- ХРАНИЛИЩЕ ДАННЫХ
-- ========================
local DirectorState = {
	currentWave = 0,
	mobsAlive = 0,
	totalMobsSpawned = 0,
	lastWaveTime = 0,
	isRunning = false,
	mapCenter = Vector3.new(0, 0, 0),
}

local NPCManager = nil
local CrystalSystem = nil
local activeMobs = {}

-- ========================
-- ЗАГРУЗКА СИСТЕМ
-- ========================
local function loadSystems()
	task.wait(2)

	-- Загружаем NPCManager
	local npcManagerScript = script.Parent:FindFirstChild("NPCManager")
	if npcManagerScript then
		NPCManager = require(npcManagerScript)
		print("✅ [DIRECTOR] NPCManager loaded!")
	else
		warn("⚠️ [DIRECTOR] NPCManager not found!")
	end

	-- Загружаем CrystalSystem
	local crystalScript = script.Parent:FindFirstChild("CrystalSystem")
	if crystalScript then
		CrystalSystem = require(crystalScript)
		print("✅ [DIRECTOR] CrystalSystem loaded!")
	else
		warn("⚠️ [DIRECTOR] CrystalSystem not found!")
	end
end

task.spawn(loadSystems)

-- ========================
-- ПОЛУЧИТЬ УРОВЕНЬ КОМАНДЫ
-- ========================
local function getTeamLevel()
	if CrystalSystem and CrystalSystem.GetLevel then
		return CrystalSystem.GetLevel()
	end
	return 0
end

-- ========================
-- НАЙТИ ЦЕНТР КАРТЫ
-- ========================
local function findMapCenter()
	local generatedMap = Workspace:FindFirstChild("GeneratedMap")
	if generatedMap then
		local cf, size = generatedMap:GetBoundingBox()
		DirectorState.mapCenter = cf.Position
		print("🗺️ [DIRECTOR] Map center: " .. tostring(DirectorState.mapCenter))
		return true
	end
	return false
end

-- ========================
-- ПОЛУЧИТЬ СЛУЧАЙНУЮ ТОЧКУ СПАВНА
-- ========================
local function getRandomSpawnPoint()
	local angle = math.random() * math.pi * 2
	local distance = math.random(CONFIG.MIN_SPAWN_DISTANCE, CONFIG.SPAWN_RADIUS)

	local x = DirectorState.mapCenter.X + math.cos(angle) * distance
	local z = DirectorState.mapCenter.Z + math.sin(angle) * distance

	-- Ищем землю под точкой спавна
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
		return rayResult.Position + Vector3.new(0, 3, 0)
	end

	return Vector3.new(x, DirectorState.mapCenter.Y + 5, z)
end

-- ========================
-- ВЫБРАТЬ СЛУЧАЙНОГО МОБА
-- ========================
local function selectRandomMob()
	local totalWeight = 0
	for _, mobData in ipairs(CONFIG.MOB_POOL) do
		totalWeight = totalWeight + mobData.Weight
	end

	local roll = math.random() * totalWeight
	local currentWeight = 0

	for _, mobData in ipairs(CONFIG.MOB_POOL) do
		currentWeight = currentWeight + mobData.Weight
		if roll <= currentWeight then
			return mobData
		end
	end

	return CONFIG.MOB_POOL[1]
end

-- ========================
-- МАСШТАБИРОВАТЬ МОБА ПО УРОВНЮ
-- ========================
local function scaleMobByLevel(mob, level)
	if level <= 0 then return end

	local humanoid = mob:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Базовые характеристики
	local baseMaxHealth = humanoid.MaxHealth
	local baseDamage = mob:GetAttribute("BaseDamage") or 10

	-- Масштабирование (аддитивное)
	local hpMultiplier = 1 + (level * CONFIG.LEVEL_SCALING.HP_MULTIPLIER)
	local damageMultiplier = 1 + (level * CONFIG.LEVEL_SCALING.DAMAGE_MULTIPLIER)

	humanoid.MaxHealth = baseMaxHealth * hpMultiplier
	humanoid.Health = humanoid.MaxHealth

	mob:SetAttribute("Damage", baseDamage * damageMultiplier)
	mob:SetAttribute("Level", level)

	-- Визуальная индикация уровня
	if level > 0 then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "LevelIndicator"
		billboard.Adornee = mob:FindFirstChild("Head") or mob.PrimaryPart
		billboard.Size = UDim2.new(0, 100, 0, 30)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = mob

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = "⚡ Lv." .. level
		textLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		textLabel.TextScaled = true
		textLabel.Font = Enum.Font.GothamBold
		textLabel.Parent = billboard
	end
end

-- ========================
-- СПАВН ОДНОГО МОБА
-- ========================
local function spawnMob()
	if DirectorState.mobsAlive >= CONFIG.MAX_MOBS_ALIVE then
		return nil
	end

	local mobData = selectRandomMob()
	local mobTemplate = ServerStorage:FindFirstChild(mobData.Name)

	if not mobTemplate then
		warn("⚠️ [DIRECTOR] Mob template not found: " .. mobData.Name)
		return nil
	end

	local spawnPosition = getRandomSpawnPoint()
	local mob = mobTemplate:Clone()

	-- Устанавливаем позицию
	if mob.PrimaryPart then
		mob:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
	elseif mob:FindFirstChild("HumanoidRootPart") then
		mob.HumanoidRootPart.CFrame = CFrame.new(spawnPosition)
	end

	-- Масштабируем по уровню команды
	local teamLevel = getTeamLevel()
	scaleMobByLevel(mob, teamLevel)

	mob.Parent = Workspace

	-- Регистрируем в NPCManager
	if NPCManager then
		local aiType = mobData.Name:find("Far") and "ranged" or "melee"
		NPCManager:Register(mob, aiType)
	end

	-- Отслеживаем смерть
	DirectorState.mobsAlive = DirectorState.mobsAlive + 1
	DirectorState.totalMobsSpawned = DirectorState.totalMobsSpawned + 1
	activeMobs[mob] = true

	local humanoid = mob:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			DirectorState.mobsAlive = math.max(0, DirectorState.mobsAlive - 1)
			activeMobs[mob] = nil

			-- Удаляем моба через 5 секунд
			task.delay(5, function()
				if mob and mob.Parent then
					mob:Destroy()
				end
			end)
		end)
	end

	if CONFIG.DEBUG_MODE and DirectorState.totalMobsSpawned % 50 == 0 then
		print("📡 [DIRECTOR] Spawned " .. DirectorState.totalMobsSpawned .. " mobs total")
	end

	return mob, mobData.Cost
end

-- ========================
-- СПАВН ВОЛНЫ
-- ========================
local function spawnWave()
	DirectorState.currentWave = DirectorState.currentWave + 1
	local waveNumber = DirectorState.currentWave
	local teamLevel = getTeamLevel()

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🌊 [DIRECTOR] WAVE #" .. waveNumber)
	print("   Team Level: " .. teamLevel)
	print("   Mobs alive: " .. DirectorState.mobsAlive .. "/" .. CONFIG.MAX_MOBS_ALIVE)

	local mobsSpawned = 0
	local creditsSpent = 0
	local maxCredits = CONFIG.MAX_MOBS_PER_WAVE

	-- Спавним мобов пока есть кредиты и место
	while creditsSpent < maxCredits and DirectorState.mobsAlive < CONFIG.MAX_MOBS_ALIVE do
		local mob, cost = spawnMob()

		if mob and cost then
			mobsSpawned = mobsSpawned + 1
			creditsSpent = creditsSpent + cost
		else
			break
		end

		-- Небольшая задержка чтобы не спавнить всё одновременно
		if mobsSpawned % 10 == 0 then
			task.wait(0.05)
		end
	end

	print("   Spawned: " .. mobsSpawned .. " mobs")
	print("   Credits used: " .. creditsSpent .. "/" .. maxCredits)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

-- ========================
-- ОСНОВНОЙ ЦИКЛ ДИРЕКТОРА
-- ========================
local function directorLoop()
	-- Ждём загрузки карты
	print("⏳ [DIRECTOR] Waiting for map generation...")

	local mapFound = false
	for i = 1, 30 do
		if findMapCenter() then
			mapFound = true
			break
		end
		task.wait(1)
	end

	if not mapFound then
		warn("❌ [DIRECTOR] Map not found! Director disabled.")
		return
	end

	print("✅ [DIRECTOR] Map found! Starting wave spawning...")
	DirectorState.isRunning = true
	DirectorState.lastWaveTime = tick()

	-- Первая волна сразу
	task.wait(3)
	spawnWave()
	DirectorState.lastWaveTime = tick()

	-- Основной цикл
	while DirectorState.isRunning do
		local currentTime = tick()
		local timeSinceLastWave = currentTime - DirectorState.lastWaveTime

		if timeSinceLastWave >= CONFIG.WAVE_INTERVAL then
			spawnWave()
			DirectorState.lastWaveTime = currentTime
		end

		task.wait(1)
	end
end

-- ========================
-- КОМАНДЫ УПРАВЛЕНИЯ
-- ========================
_G.DirectorStart = function()
	if not DirectorState.isRunning then
		print("▶️ [DIRECTOR] Starting...")
		task.spawn(directorLoop)
	else
		print("⚠️ [DIRECTOR] Already running!")
	end
end

_G.DirectorStop = function()
	DirectorState.isRunning = false
	print("⏸️ [DIRECTOR] Stopped!")
end

_G.DirectorStats = function()
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("📊 [DIRECTOR] Statistics:")
	print("   Current wave: " .. DirectorState.currentWave)
	print("   Mobs alive: " .. DirectorState.mobsAlive)
	print("   Total spawned: " .. DirectorState.totalMobsSpawned)
	print("   Team level: " .. getTeamLevel())
	print("   Running: " .. tostring(DirectorState.isRunning))
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

_G.DirectorClearAll = function()
	local count = 0
	for mob, _ in pairs(activeMobs) do
		if mob and mob.Parent then
			mob:Destroy()
			count = count + 1
		end
	end
	activeMobs = {}
	DirectorState.mobsAlive = 0
	print("🧹 [DIRECTOR] Cleared " .. count .. " mobs")
end

-- ========================
-- ИНИЦИАЛИЗАЦИЯ
-- ========================
print("✅ [DIRECTOR] Loaded!")
print("   Wave interval: " .. CONFIG.WAVE_INTERVAL .. " seconds")
print("   Max mobs per wave: " .. CONFIG.MAX_MOBS_PER_WAVE)
print("   Max mobs alive: " .. CONFIG.MAX_MOBS_ALIVE)
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Автозапуск
task.spawn(directorLoop)

-- Экспорт для других модулей
return {
	GetState = function() return DirectorState end,
	GetMobsAlive = function() return DirectorState.mobsAlive end,
	GetCurrentWave = function() return DirectorState.currentWave end,
}
