-- =====================================
-- DOT SYSTEM - DAMAGE OVER TIME (FIXED)
-- Burn (multiple stacks) and Poison (single stack with reset)
-- Uses ItemDatabase for Old Lighter and Vile Vial
-- Place in ServerScriptService
-- =====================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🔥 [DOT SYSTEM] Loading...")

-- ========================
-- КОНФИГУРАЦИЯ
-- ========================
local CONFIG = {
	DEBUG_MODE = true,

	-- Базовый урон способностей
	BASE_ABILITY_DAMAGE = 15,

	-- Интервалы тиков
	TICK_RATE = 1, -- Секунд между тиками урона

	-- Burn (Ожог)
	BURN = {
		DURATION = 3, -- Секунды
		DAMAGE_PER_TICK = 5, -- Урон за тик
		MAX_STACKS = 999, -- Нет лимита стаков
	},

	-- Poison (Яд)
	POISON = {
		DURATION = 5, -- Секунды
		DAMAGE_PER_TICK = 8, -- Урон за тик
		ENHANCED_DURATION = 8, -- Длительность с Vile Vial
		ENHANCED_DAMAGE_PER_TICK = 12, -- Урон с Vile Vial
		MAX_STACKS = 1, -- Только 1 стак (сбрасывается)
	},
}

-- ========================
-- ХРАНИЛИЩЕ ДАННЫХ
-- ========================
local activeDOTs = {
	Burn = {}, -- {[character] = {stacks = {{endTime, damagePerTick, attacker},...}}}
	Poison = {}, -- {[character] = {endTime, damagePerTick, attacker}}
}

local CombatSystem = nil
local ItemDatabase = nil

-- ========================
-- ЗАГРУЗКА СИСТЕМ
-- ========================
local function loadSystems()
	task.wait(2)

	-- CombatSystem
	local combatModule = ReplicatedStorage:FindFirstChild("CombatSystem")
	if combatModule then
		CombatSystem = require(combatModule)
		print("✅ [DOT] CombatSystem loaded!")
	else
		warn("⚠️ [DOT] CombatSystem not found!")
	end

	-- ItemDatabase
	local itemDBModule = ReplicatedStorage:FindFirstChild("ItemDatabase")
	if itemDBModule then
		ItemDatabase = require(itemDBModule)
		print("✅ [DOT] ItemDatabase loaded!")
	else
		warn("⚠️ [DOT] ItemDatabase not found!")
	end
end

task.spawn(loadSystems)

-- ========================
-- ПОЛУЧИТЬ СТАКИ ПРЕДМЕТА
-- ========================
local function getItemStacks(character, itemKey)
	if not character then return 0 end

	-- Проверяем оба формата: "ItemName" и "ItemName_Stacks"
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
-- ПРИМЕНИТЬ УРОН DOT
-- ========================
local function applyDOTDamage(victim, damage, attacker, dotType)
	local player = Players:GetPlayerFromCharacter(victim)
	if not player then return end

	if CombatSystem and CombatSystem.ApplyDamage then
		local attackerPlayer = attacker and Players:GetPlayerFromCharacter(attacker)
		local attackerPos = attacker and attacker.PrimaryPart and attacker.PrimaryPart.Position or Vector3.new(0, 0, 0)

		-- Урон через CombatSystem (чтобы учитывались все модификаторы)
		CombatSystem.ApplyDamage(player, damage, attackerPlayer, attackerPos)

		if CONFIG.DEBUG_MODE then
			print(dotType .. " [DOT] Applied " .. damage .. " damage to " .. player.Name)
		end
	else
		-- Резервный метод
		local humanoid = victim:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid:TakeDamage(damage)
		end
	end
end

-- ========================
-- ОЖОГ (BURN) - МНОЖЕСТВЕННЫЕ СТАКИ
-- ========================
local function applyBurn(attacker, victim, ignoredDamage)
	if not victim or not attacker then return end

	-- Проверка Old Lighter
	local lighterStacks = getItemStacks(attacker, "OldLighter")
	if lighterStacks <= 0 then return end

	-- Инициализация структуры
	if not activeDOTs.Burn[victim] then
		activeDOTs.Burn[victim] = {stacks = {}}
	end

	local burnData = activeDOTs.Burn[victim]
	local newStack = {
		endTime = tick() + CONFIG.BURN.DURATION,
		damagePerTick = CONFIG.BURN.DAMAGE_PER_TICK * lighterStacks,
		attacker = attacker,
		lastTick = tick(),
	}

	table.insert(burnData.stacks, newStack)

	if CONFIG.DEBUG_MODE then
		print("🔥 [BURN] Applied to " .. (Players:GetPlayerFromCharacter(victim) and Players:GetPlayerFromCharacter(victim).Name or "NPC"))
		print("   Stacks: " .. #burnData.stacks)
		print("   Damage/tick: " .. newStack.damagePerTick)
		print("   Duration: " .. CONFIG.BURN.DURATION .. "s")
	end

	-- Визуальный эффект
	local rootPart = victim:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local fire = rootPart:FindFirstChild("BurnEffect")
		if not fire then
			fire = Instance.new("Fire")
			fire.Name = "BurnEffect"
			fire.Size = 5
			fire.Heat = 10
			fire.Color = Color3.fromRGB(255, 100, 0)
			fire.SecondaryColor = Color3.fromRGB(255, 200, 0)
			fire.Parent = rootPart
		end
	end
end

-- ========================
-- ЯД (POISON) - ОДИН СТАК С ПЕРЕЗАГРУЗКОЙ
-- ========================
local function applyPoison(attacker, victim, ignoredDamage, enhanced)
	if not victim or not attacker then return end

	-- Определяем параметры яда
	local duration = enhanced and CONFIG.POISON.ENHANCED_DURATION or CONFIG.POISON.DURATION
	local damagePerTick = enhanced and CONFIG.POISON.ENHANCED_DAMAGE_PER_TICK or CONFIG.POISON.DAMAGE_PER_TICK

	-- Заменяем существующий стак или создаём новый
	activeDOTs.Poison[victim] = {
		endTime = tick() + duration,
		damagePerTick = damagePerTick,
		attacker = attacker,
		lastTick = tick(),
		enhanced = enhanced,
	}

	if CONFIG.DEBUG_MODE then
		print("☠️ [POISON] Applied to " .. (Players:GetPlayerFromCharacter(victim) and Players:GetPlayerFromCharacter(victim).Name or "NPC"))
		print("   Enhanced: " .. tostring(enhanced))
		print("   Damage/tick: " .. damagePerTick)
		print("   Duration: " .. duration .. "s")
	end

	-- Визуальный эффект
	local rootPart = victim:FindFirstChild("HumanoidRootPart")
	if rootPart then
		local poison = rootPart:FindFirstChild("PoisonEffect")
		if not poison then
			poison = Instance.new("ParticleEmitter")
			poison.Name = "PoisonEffect"
			poison.Texture = "rbxasset://textures/particles/smoke_main.dds"
			poison.Color = ColorSequence.new(Color3.fromRGB(0, 255, 0))
			poison.Size = NumberSequence.new(1)
			poison.Lifetime = NumberRange.new(1, 2)
			poison.Rate = 20
			poison.Speed = NumberRange.new(1, 3)
			poison.SpreadAngle = Vector2.new(30, 30)
			poison.Parent = rootPart
		end
	end
end

-- ========================
-- ОБРАБОТКА BURN ТИКОВ
-- ========================
local function processBurnTicks()
	for victim, burnData in pairs(activeDOTs.Burn) do
		if not victim or not victim.Parent then
			activeDOTs.Burn[victim] = nil
			continue
		end

		local currentTime = tick()
		local activeStacks = {}

		-- Обрабатываем каждый стак
		for i, stack in ipairs(burnData.stacks) do
			if currentTime < stack.endTime then
				-- Стак ещё активен
				if currentTime - stack.lastTick >= CONFIG.TICK_RATE then
					applyDOTDamage(victim, stack.damagePerTick, stack.attacker, "🔥 [BURN]")
					stack.lastTick = currentTime
				end
				table.insert(activeStacks, stack)
			end
		end

		-- Обновляем стаки
		if #activeStacks > 0 then
			burnData.stacks = activeStacks
		else
			-- Все стаки закончились
			activeDOTs.Burn[victim] = nil

			-- Удаляем визуальный эффект
			local rootPart = victim:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local fire = rootPart:FindFirstChild("BurnEffect")
				if fire then fire:Destroy() end
			end

			if CONFIG.DEBUG_MODE then
				print("🔥 [BURN] All stacks expired on " .. (Players:GetPlayerFromCharacter(victim) and Players:GetPlayerFromCharacter(victim).Name or "NPC"))
			end
		end
	end
end

-- ========================
-- ОБРАБОТКА POISON ТИКОВ
-- ========================
local function processPoisonTicks()
	for victim, poisonData in pairs(activeDOTs.Poison) do
		if not victim or not victim.Parent then
			activeDOTs.Poison[victim] = nil
			continue
		end

		local currentTime = tick()

		if currentTime < poisonData.endTime then
			-- Стак ещё активен
			if currentTime - poisonData.lastTick >= CONFIG.TICK_RATE then
				applyDOTDamage(victim, poisonData.damagePerTick, poisonData.attacker, "☠️ [POISON]")
				poisonData.lastTick = currentTime
			end
		else
			-- Стак закончился
			activeDOTs.Poison[victim] = nil

			-- Удаляем визуальный эффект
			local rootPart = victim:FindFirstChild("HumanoidRootPart")
			if rootPart then
				local poison = rootPart:FindFirstChild("PoisonEffect")
				if poison then poison:Destroy() end
			end

			if CONFIG.DEBUG_MODE then
				print("☠️ [POISON] Effect expired on " .. (Players:GetPlayerFromCharacter(victim) and Players:GetPlayerFromCharacter(victim).Name or "NPC"))
			end
		end
	end
end

-- ========================
-- ОСНОВНОЙ ЦИКЛ DOT
-- ========================
task.spawn(function()
	while true do
		processBurnTicks()
		processPoisonTicks()
		task.wait(CONFIG.TICK_RATE)
	end
end)

-- ========================
-- ОЧИСТКА ПРИ СМЕРТИ
-- ========================
local function setupCleanupOnDeath(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	humanoid.Died:Connect(function()
		-- Очищаем все DOT эффекты
		activeDOTs.Burn[character] = nil
		activeDOTs.Poison[character] = nil

		-- Удаляем визуальные эффекты
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local fire = rootPart:FindFirstChild("BurnEffect")
			local poison = rootPart:FindFirstChild("PoisonEffect")
			if fire then fire:Destroy() end
			if poison then poison:Destroy() end
		end
	end)
end

-- Мониторинг игроков
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		setupCleanupOnDeath(character)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		setupCleanupOnDeath(player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		setupCleanupOnDeath(character)
	end)
end

-- Мониторинг NPC
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("Humanoid") and descendant.Parent then
		local character = descendant.Parent
		if not Players:GetPlayerFromCharacter(character) then
			setupCleanupOnDeath(character)
		end
	end
end)

-- ========================
-- КОМАНДЫ УПРАВЛЕНИЯ
-- ========================
_G.DOTStats = function()
	local burnCount = 0
	local poisonCount = 0

	for victim, data in pairs(activeDOTs.Burn) do
		if victim and victim.Parent then
			burnCount = burnCount + #data.stacks
		end
	end

	for victim, _ in pairs(activeDOTs.Poison) do
		if victim and victim.Parent then
			poisonCount = poisonCount + 1
		end
	end

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🔥☠️ [DOT] Statistics:")
	print("   Active Burn stacks: " .. burnCount)
	print("   Active Poison effects: " .. poisonCount)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

_G.ClearAllDOTs = function()
	activeDOTs.Burn = {}
	activeDOTs.Poison = {}
	print("🧹 [DOT] All DOT effects cleared!")
end

-- ========================
-- ИНИЦИАЛИЗАЦИЯ
-- ========================
print("✅ [DOT SYSTEM] Loaded!")
print("   Burn: " .. CONFIG.BURN.DAMAGE_PER_TICK .. " damage/tick, " .. CONFIG.BURN.DURATION .. "s duration")
print("   Poison: " .. CONFIG.POISON.DAMAGE_PER_TICK .. " damage/tick, " .. CONFIG.POISON.DURATION .. "s duration")
print("   Tick rate: " .. CONFIG.TICK_RATE .. "s")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- ========================
-- ЭКСПОРТ
-- ========================
return {
	ApplyBurn = applyBurn,
	ApplyPoison = applyPoison,
	GetActiveBurns = function() return activeDOTs.Burn end,
	GetActivePoisons = function() return activeDOTs.Poison end,
}
