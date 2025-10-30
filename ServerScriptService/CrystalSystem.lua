-- =====================================
-- CRYSTAL SYSTEM - TEAM PROGRESSION
-- Shared crystals, experience, and levels for all players
-- +30% HP and +20% damage per level (additive)
-- Place in ServerScriptService
-- =====================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("💎 [CRYSTAL SYSTEM] Loading...")

-- ========================
-- КОНФИГУРАЦИЯ
-- ========================
local CONFIG = {
	DEBUG_MODE = true,

	-- Система уровней
	LEVEL_SYSTEM = {
		BASE_EXP_REQUIREMENT = 30, -- Опыт для 1 уровня
		EXP_SCALING = 1.5, -- Множитель для следующих уровней
		HP_BONUS_PER_LEVEL = 0.30, -- +30% HP за уровень (аддитивно)
		DAMAGE_BONUS_PER_LEVEL = 0.20, -- +20% урона за уровень (аддитивно)
	},

	-- Дроп кристаллов
	CRYSTAL_DROP = {
		MIN_CRYSTALS = 1,
		MAX_CRYSTALS = 3,
		SCAVENGER_BONUS_MIN = 1, -- Бонус от Scavenger's Pouch
		SCAVENGER_BONUS_MAX = 2,
	},

	-- Визуализация
	CRYSTAL_COLOR = Color3.fromRGB(0, 255, 255), -- Cyan
	CRYSTAL_SIZE = Vector3.new(1, 1, 1),
	CRYSTAL_LIFETIME = 30, -- Секунд до исчезновения
}

-- ========================
-- ХРАНИЛИЩЕ ДАННЫХ
-- ========================
local TeamData = {
	Crystals = 0,
	Experience = 0,
	Level = 0,
}

local PlayerBonuses = {} -- {[UserId] = {HPMultiplier, DamageMultiplier}}

-- ========================
-- ПОЛУЧИТЬ ТРЕБОВАНИЕ ОПЫТА ДЛЯ УРОВНЯ
-- ========================
local function getExpRequirement(level)
	if level <= 0 then return CONFIG.LEVEL_SYSTEM.BASE_EXP_REQUIREMENT end
	return math.floor(CONFIG.LEVEL_SYSTEM.BASE_EXP_REQUIREMENT * (CONFIG.LEVEL_SYSTEM.EXP_SCALING ^ level))
end

-- ========================
-- ОБНОВИТЬ УРОВЕНЬ
-- ========================
local function updateLevel()
	local expRequired = getExpRequirement(TeamData.Level)

	while TeamData.Experience >= expRequired do
		TeamData.Experience = TeamData.Experience - expRequired
		TeamData.Level = TeamData.Level + 1

		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("🎉 [CRYSTAL] LEVEL UP!")
		print("   New Level: " .. TeamData.Level)
		print("   HP Bonus: +" .. (TeamData.Level * CONFIG.LEVEL_SYSTEM.HP_BONUS_PER_LEVEL * 100) .. "%")
		print("   Damage Bonus: +" .. (TeamData.Level * CONFIG.LEVEL_SYSTEM.DAMAGE_BONUS_PER_LEVEL * 100) .. "%")
		print("   Next level requires: " .. getExpRequirement(TeamData.Level) .. " EXP")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

		-- Уведомление всем игрокам
		local remoteEvent = ReplicatedStorage:FindFirstChild("ShowNotification")
		if remoteEvent then
			for _, player in ipairs(Players:GetPlayers()) do
				pcall(function()
					remoteEvent:FireClient(player, "🎉 TEAM LEVEL " .. TeamData.Level .. "!", CONFIG.CRYSTAL_COLOR)
				end)
			end
		end

		-- Обновляем бонусы всех игроков
		for _, player in ipairs(Players:GetPlayers()) do
			applyLevelBonuses(player)
		end

		expRequired = getExpRequirement(TeamData.Level)
	end
end

-- ========================
-- ПРИМЕНИТЬ БОНУСЫ УРОВНЯ К ИГРОКУ
-- ========================
function applyLevelBonuses(player)
	if not player.Character then return end

	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Получаем базовые характеристики
	local baseMaxHealth = player:GetAttribute("BaseMaxHealth") or 100
	local baseDamage = player:GetAttribute("BaseDamage") or 10

	-- Сохраняем базовые значения если их нет
	if not player:GetAttribute("BaseMaxHealth") then
		player:SetAttribute("BaseMaxHealth", humanoid.MaxHealth)
		baseMaxHealth = humanoid.MaxHealth
	end

	if not player:GetAttribute("BaseDamage") then
		player:SetAttribute("BaseDamage", 10)
		baseDamage = 10
	end

	-- АДДИТИВНОЕ масштабирование (не мультипликативное!)
	local hpMultiplier = 1 + (TeamData.Level * CONFIG.LEVEL_SYSTEM.HP_BONUS_PER_LEVEL)
	local damageMultiplier = 1 + (TeamData.Level * CONFIG.LEVEL_SYSTEM.DAMAGE_BONUS_PER_LEVEL)

	-- Применяем бонусы
	local newMaxHealth = baseMaxHealth * hpMultiplier
	local healthPercent = humanoid.Health / humanoid.MaxHealth

	humanoid.MaxHealth = newMaxHealth
	humanoid.Health = newMaxHealth * healthPercent -- Сохраняем процент HP

	player:SetAttribute("DamageMultiplier", damageMultiplier)

	-- Сохраняем бонусы
	PlayerBonuses[player.UserId] = {
		HPMultiplier = hpMultiplier,
		DamageMultiplier = damageMultiplier,
	}

	if CONFIG.DEBUG_MODE then
		print("💎 [CRYSTAL] Applied bonuses to " .. player.Name)
		print("   Base HP: " .. baseMaxHealth .. " → " .. newMaxHealth .. " (x" .. string.format("%.2f", hpMultiplier) .. ")")
		print("   Base Damage: " .. baseDamage .. " → " .. (baseDamage * damageMultiplier) .. " (x" .. string.format("%.2f", damageMultiplier) .. ")")
	end
end

-- ========================
-- ДОБАВИТЬ КРИСТАЛЛЫ
-- ========================
local function addCrystals(amount)
	if amount <= 0 then return end

	TeamData.Crystals = TeamData.Crystals + amount
	TeamData.Experience = TeamData.Experience + amount -- 1 Crystal = 1 Experience

	if CONFIG.DEBUG_MODE then
		print("💎 [CRYSTAL] +(" .. amount .. ") crystals → Total: " .. TeamData.Crystals)
		print("   Experience: " .. TeamData.Experience .. "/" .. getExpRequirement(TeamData.Level))
	end

	updateLevel()
end

-- ========================
-- УДАЛИТЬ КРИСТАЛЛЫ
-- ========================
local function removeCrystals(amount)
	if amount <= 0 then return true end

	if TeamData.Crystals >= amount then
		TeamData.Crystals = TeamData.Crystals - amount

		if CONFIG.DEBUG_MODE then
			print("💎 [CRYSTAL] -" .. amount .. " crystals → Remaining: " .. TeamData.Crystals)
		end

		return true
	end

	return false
end

-- ========================
-- ПОЛУЧИТЬ СТАКИ ПРЕДМЕТА
-- ========================
local function getItemStacks(character, itemId)
	if not character then return 0 end

	-- Проверяем оба возможных формата
	local stacks1 = character:FindFirstChild(itemId .. "_Stacks")
	local stacks2 = character:FindFirstChild(itemId)

	if stacks1 and stacks1:IsA("NumberValue") then
		return stacks1.Value
	elseif stacks2 and stacks2:IsA("NumberValue") then
		return stacks2.Value
	end

	return 0
end

-- ========================
-- СОЗДАТЬ ПАДАЮЩИЙ КРИСТАЛЛ
-- ========================
local function createFloatingCrystal(position, amount)
	local crystal = Instance.new("Part")
	crystal.Name = "Crystal"
	crystal.Size = CONFIG.CRYSTAL_SIZE
	crystal.Material = Enum.Material.Neon
	crystal.Color = CONFIG.CRYSTAL_COLOR
	crystal.Anchored = true
	crystal.CanCollide = false
	crystal.Shape = Enum.PartType.Ball
	crystal.CFrame = CFrame.new(position + Vector3.new(0, 2, 0))

	-- Атрибут количества
	crystal:SetAttribute("CrystalAmount", amount)

	-- Подсветка
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 10
	light.Color = CONFIG.CRYSTAL_COLOR
	light.Parent = crystal

	-- Текст с количеством
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = crystal
	billboard.Size = UDim2.new(0, 100, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 1.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = crystal

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "💎 " .. amount
	textLabel.TextColor3 = CONFIG.CRYSTAL_COLOR
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextStrokeTransparency = 0.5
	textLabel.Parent = billboard

	crystal.Parent = workspace

	-- Вращение
	task.spawn(function()
		local startTime = tick()
		while crystal.Parent do
			local elapsed = tick() - startTime
			crystal.CFrame = CFrame.new(position + Vector3.new(0, 2 + math.sin(elapsed * 2) * 0.3, 0))
				* CFrame.Angles(0, elapsed * 2, 0)
			task.wait()
		end
	end)

	-- Сбор касанием
	crystal.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and crystal.Parent then
			local crystalAmount = crystal:GetAttribute("CrystalAmount") or amount
			addCrystals(crystalAmount)

			-- Уведомление игроку
			local remoteEvent = ReplicatedStorage:FindFirstChild("ShowNotification")
			if remoteEvent then
				pcall(function()
					remoteEvent:FireClient(player, "💎 +" .. crystalAmount .. " Crystals", CONFIG.CRYSTAL_COLOR)
				end)
			end

			crystal:Destroy()
		end
	end)

	-- Автоудаление
	game:GetService("Debris"):AddItem(crystal, CONFIG.CRYSTAL_LIFETIME)

	return crystal
end

-- ========================
-- ДРОП КРИСТАЛЛОВ С МОНСТРА
-- ========================
local function dropCrystalsFromMonster(monsterPosition, killer)
	local baseAmount = math.random(CONFIG.CRYSTAL_DROP.MIN_CRYSTALS, CONFIG.CRYSTAL_DROP.MAX_CRYSTALS)
	local bonusAmount = 0

	-- Проверка Scavenger's Pouch у убийцы
	if killer and killer.Character then
		local scavengerStacks = getItemStacks(killer.Character, "ScavengersPouch")
		if scavengerStacks > 0 then
			bonusAmount = math.random(
				CONFIG.CRYSTAL_DROP.SCAVENGER_BONUS_MIN * scavengerStacks,
				CONFIG.CRYSTAL_DROP.SCAVENGER_BONUS_MAX * scavengerStacks
			)

			if CONFIG.DEBUG_MODE then
				print("💰 [CRYSTAL] Scavenger's Pouch bonus: +" .. bonusAmount .. " (stacks: " .. scavengerStacks .. ")")
			end
		end
	end

	local totalAmount = baseAmount + bonusAmount

	-- Создаём кристалл
	createFloatingCrystal(monsterPosition, totalAmount)

	if CONFIG.DEBUG_MODE then
		print("💎 [CRYSTAL] Dropped " .. totalAmount .. " crystals (" .. baseAmount .. " base + " .. bonusAmount .. " bonus)")
	end
end

-- ========================
-- ИНТЕГРАЦИЯ С COMBAT SYSTEM
-- ========================
local function setupCombatIntegration()
	task.wait(3)

	local combatModule = ReplicatedStorage:FindFirstChild("CombatSystem")
	if not combatModule then
		warn("⚠️ [CRYSTAL] CombatSystem not found!")
		return
	end

	local CombatSystem = require(combatModule)
	local originalApplyDamage = CombatSystem.ApplyDamage

	-- Хук на урон для применения бонусов уровня
	CombatSystem.ApplyDamage = function(targetPlayer, damage, attackerPlayer, attackerPosition)
		local modifiedDamage = damage

		-- Применяем бонус урона атакующего
		if attackerPlayer then
			local damageMultiplier = attackerPlayer:GetAttribute("DamageMultiplier") or 1
			modifiedDamage = damage * damageMultiplier

			if CONFIG.DEBUG_MODE and damageMultiplier > 1 then
				print("💎 [CRYSTAL] Damage boost: " .. damage .. " → " .. modifiedDamage .. " (x" .. string.format("%.2f", damageMultiplier) .. ")")
			end
		end

		return originalApplyDamage(targetPlayer, modifiedDamage, attackerPlayer, attackerPosition)
	end

	print("✅ [CRYSTAL] Combat integration hooked!")
end

task.spawn(setupCombatIntegration)

-- ========================
-- ОТСЛЕЖИВАНИЕ СМЕРТИ МОБОВ
-- ========================
local function setupMobDeathTracking()
	workspace.DescendantAdded:Connect(function(descendant)
		-- Ищем Humanoid в мобах
		if descendant:IsA("Humanoid") and descendant.Parent and not Players:GetPlayerFromCharacter(descendant.Parent) then
			local mob = descendant.Parent

			descendant.Died:Connect(function()
				task.wait(0.1) -- Небольшая задержка

				if mob.PrimaryPart or mob:FindFirstChild("HumanoidRootPart") then
					local position = mob.PrimaryPart and mob.PrimaryPart.Position or mob.HumanoidRootPart.Position

					-- Находим убийцу (последний атаковавший)
					local killer = nil
					local creatorTag = mob:FindFirstChild("creator")
					if creatorTag and creatorTag:IsA("ObjectValue") and creatorTag.Value then
						killer = creatorTag.Value
					end

					dropCrystalsFromMonster(position, killer)
				end
			end)
		end
	end)

	print("✅ [CRYSTAL] Mob death tracking active!")
end

task.spawn(setupMobDeathTracking)

-- ========================
-- МОНИТОРИНГ ИГРОКОВ
-- ========================
local function setupPlayerMonitoring(player)
	local function onCharacterAdded(character)
		task.wait(1)
		applyLevelBonuses(player)
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
end

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayerMonitoring(player)
end

Players.PlayerAdded:Connect(setupPlayerMonitoring)

Players.PlayerRemoving:Connect(function(player)
	PlayerBonuses[player.UserId] = nil
end)

-- ========================
-- КОМАНДЫ УПРАВЛЕНИЯ
-- ========================
_G.CrystalStats = function()
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("💎 [CRYSTAL] Statistics:")
	print("   Crystals: " .. TeamData.Crystals)
	print("   Experience: " .. TeamData.Experience .. "/" .. getExpRequirement(TeamData.Level))
	print("   Level: " .. TeamData.Level)
	print("   HP Bonus: +" .. (TeamData.Level * CONFIG.LEVEL_SYSTEM.HP_BONUS_PER_LEVEL * 100) .. "%")
	print("   Damage Bonus: +" .. (TeamData.Level * CONFIG.LEVEL_SYSTEM.DAMAGE_BONUS_PER_LEVEL * 100) .. "%")
	print("   Players with bonuses: " .. #PlayerBonuses)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

_G.AddCrystals = function(amount)
	addCrystals(amount or 10)
	print("💎 [CRYSTAL] Added " .. (amount or 10) .. " crystals")
end

_G.AddLevel = function(levels)
	local levelsToAdd = levels or 1
	for i = 1, levelsToAdd do
		TeamData.Experience = getExpRequirement(TeamData.Level)
		updateLevel()
	end
end

_G.ResetCrystals = function()
	TeamData.Crystals = 0
	TeamData.Experience = 0
	TeamData.Level = 0

	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("BaseMaxHealth", nil)
		player:SetAttribute("BaseDamage", nil)
		player:SetAttribute("DamageMultiplier", 1)

		if player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.MaxHealth = 100
				humanoid.Health = 100
			end
		end
	end

	PlayerBonuses = {}
	print("💎 [CRYSTAL] System reset!")
end

-- ========================
-- ИНИЦИАЛИЗАЦИЯ
-- ========================
print("✅ [CRYSTAL SYSTEM] Loaded!")
print("   Base EXP requirement: " .. CONFIG.LEVEL_SYSTEM.BASE_EXP_REQUIREMENT)
print("   EXP scaling: x" .. CONFIG.LEVEL_SYSTEM.EXP_SCALING)
print("   HP bonus per level: +" .. (CONFIG.LEVEL_SYSTEM.HP_BONUS_PER_LEVEL * 100) .. "%")
print("   Damage bonus per level: +" .. (CONFIG.LEVEL_SYSTEM.DAMAGE_BONUS_PER_LEVEL * 100) .. "%")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- ========================
-- ЭКСПОРТ
-- ========================
return {
	-- Данные
	GetCrystals = function() return TeamData.Crystals end,
	GetExperience = function() return TeamData.Experience end,
	GetLevel = function() return TeamData.Level end,
	GetExpRequirement = getExpRequirement,

	-- Операции
	AddCrystals = addCrystals,
	RemoveCrystals = removeCrystals,
	DropCrystals = dropCrystalsFromMonster,

	-- Бонусы
	ApplyLevelBonuses = applyLevelBonuses,
	GetPlayerBonuses = function(player) return PlayerBonuses[player.UserId] end,
}
