-- =====================================
-- ITEM EFFECT SYSTEM - CLEANED VERSION
-- ❌ REMOVED: OverflowingChalice logic
-- Place in ReplicatedStorage as ModuleScript
-- =====================================

local ItemEffectSystem = {}

local Players = game:GetService("Players")

-- ========================
-- КОНФИГУРАЦИЯ
-- ========================
local CONFIG = {
	QUICK_DRAW_TIMEOUT = 3, -- Секунд без атаки для активации Quick Draw
	OVERCHARGED_ATTACKS = 10, -- Каждая 10-я атака
	DIVINE_COOLDOWN = 10, -- Кулдаун Divine Intervention
}

-- ========================
-- ХРАНИЛИЩЕ СОСТОЯНИЙ ИГРОКОВ
-- ========================
local playerStates = {}
local baseMaxHealth = {} -- Для Soul Eater

local function getPlayerState(player)
	if not playerStates[player.UserId] then
		playerStates[player.UserId] = {
			lastAttackTime = 0,
			attackCounter = 0,
			momentumStacks = 0,
			lastDamagedTime = 0,
			divineActive = false,
			divineEndTime = 0,
		}
	end
	return playerStates[player.UserId]
end

local function resetPlayerState(player)
	local state = getPlayerState(player)
	state.attackCounter = 0
	state.momentumStacks = 0
	state.divineActive = false
	state.divineEndTime = 0
	print("🔄 [ITEM EFFECTS] State reset for: " .. player.Name)
end

-- ========================
-- РАСЧЁТ PROC ШАНСА - SIMPLIFIED (no double proc)
-- ========================
local function rollProc(character, itemId, baseChance)
	local stacks = character:FindFirstChild(itemId .. "_Stacks")
	if not stacks then return false end

	local ITEM_DATABASE = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemDatabase"))
	local itemData = ITEM_DATABASE.Items and ITEM_DATABASE.Items[itemId] or ITEM_DATABASE[itemId]

	if not itemData then 
		warn("⚠️ [ITEM EFFECTS] Item not found in database:", itemId)
		return false
	end

	-- Рассчитываем общий шанс
	local totalChance = itemData.BaseValue + (itemData.StackValue * (stacks.Value - 1))

	-- Если шанс >= 100%, гарантированный прок
	if totalChance >= 100 then
		return true
	end

	-- Обычный прок (шанс < 100%)
	local roll = math.random(1, 100)
	return roll <= totalChance
end

-- ========================
-- ПОЛУЧИТЬ КОЛИЧЕСТВО СТАКОВ ПРЕДМЕТА
-- ========================
local function getItemStacks(character, itemId)
	local stacks = character:FindFirstChild(itemId .. "_Stacks")
	return stacks and stacks.Value or 0
end

-- ========================
-- QUICK DRAW - Первая атака после тайм-аута
-- ========================
function ItemEffectSystem.CheckQuickDraw(player, character)
	local stacks = getItemStacks(character, "QuickDraw")
	if stacks == 0 then return 0 end

	local state = getPlayerState(player)
	local timeSinceLastAttack = tick() - state.lastAttackTime

	if timeSinceLastAttack >= CONFIG.QUICK_DRAW_TIMEOUT then
		local ITEM_DATABASE = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemDatabase"))
		local itemData = ITEM_DATABASE.Items and ITEM_DATABASE.Items["QuickDraw"] or ITEM_DATABASE["QuickDraw"]

		if not itemData then return 0 end

		local bonus = itemData.BaseValue + (itemData.StackValue * (stacks - 1))

		print("🎯 [QUICK DRAW] Activated! +" .. bonus .. "% damage")
		return bonus / 100 -- Возвращаем множитель (0.2 = +20%)
	end

	return 0
end

-- ========================
-- BERSERKER'S RAGE - Бонус при низком HP
-- ========================
function ItemEffectSystem.CheckBerserkerRage(character)
	local stacks = getItemStacks(character, "BerserkerRage")
	if stacks == 0 then return 0 end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return 0 end

	local healthPercent = (humanoid.Health / humanoid.MaxHealth) * 100

	if healthPercent < 30 then
		local ITEM_DATABASE = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemDatabase"))
		local itemData = ITEM_DATABASE.Items and ITEM_DATABASE.Items["BerserkerRage"] or ITEM_DATABASE["BerserkerRage"]

		if not itemData then return 0 end

		local bonus = itemData.BaseValue + (itemData.StackValue * (stacks - 1))

		print("😡 [BERSERKER] Active! +" .. bonus .. "% damage")
		return bonus / 100
	end

	return 0
end

-- ========================
-- EXECUTIONER'S BLADE - Бонус к врагам с низким HP
-- ========================
function ItemEffectSystem.CheckExecutioner(character, targetHumanoid)
	local stacks = getItemStacks(character, "ExecutionerBlade")
	if stacks == 0 then return 0 end

	if not targetHumanoid then return 0 end

	local targetHealthPercent = (targetHumanoid.Health / targetHumanoid.MaxHealth) * 100

	if targetHealthPercent < 20 then
		local ITEM_DATABASE = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemDatabase"))
		local itemData = ITEM_DATABASE.Items and ITEM_DATABASE.Items["ExecutionerBlade"] or ITEM_DATABASE["ExecutionerBlade"]

		if not itemData then return 0 end

		local bonus = itemData.BaseValue + (itemData.StackValue * (stacks - 1))

		print("🗡️ [EXECUTIONER] Execute! +" .. bonus .. "% damage")
		return bonus / 100
	end

	return 0
end

-- ========================
-- MOMENTUM CHAIN - Стаки без получения урона
-- ========================
function ItemEffectSystem.UpdateMomentumChain(player, character, tookDamage)
	local stacks = getItemStacks(character, "MomentumChain")
	if stacks == 0 then return end

	local state = getPlayerState(player)

	if tookDamage then
		-- Сброс стаков
		state.momentumStacks = 0
		print("🔗 [MOMENTUM] Reset! (took damage)")
	else
		local ITEM_DATABASE = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemDatabase"))
		local itemData = ITEM_DATABASE.Items and ITEM_DATABASE.Items["MomentumChain"] or ITEM_DATABASE["MomentumChain"]

		if not itemData then return end

		local maxStacks = itemData.MaxStacks or 5

		state.momentumStacks = math.min(state.momentumStacks + 1, maxStacks)
		print("🔗 [MOMENTUM] Stacks: " .. state.momentumStacks .. "/" .. maxStacks)
	end
end

function ItemEffectSystem.GetMomentumBonus(player, character)
	local stacks = getItemStacks(character, "MomentumChain")
	if stacks == 0 then return 0 end

	local state = getPlayerState(player)
	if state.momentumStacks == 0 then return 0 end

	local ITEM_DATABASE = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemDatabase"))
	local itemData = ITEM_DATABASE.Items and ITEM_DATABASE.Items["MomentumChain"] or ITEM_DATABASE["MomentumChain"]

	if not itemData then return 0 end

	local bonusPerStack = itemData.BaseValue + (itemData.StackValue * (stacks - 1))

	local totalBonus = bonusPerStack * state.momentumStacks
	print("🔗 [MOMENTUM] Bonus: +" .. totalBonus .. "% damage")

	return totalBonus / 100
end

-- ========================
-- DIVINE INTERVENTION - Dodge + Damage Buff (С КУЛДАУНОМ)
-- ========================
function ItemEffectSystem.CheckDivineIntervention(player, character, incomingDamage)
	local stacks = getItemStacks(character, "DivineIntervention")
	if stacks == 0 then return false end

	-- Проверяем кулдаун
	local cooldown = character:FindFirstChild("DivineIntervention_CD")
	if cooldown and (tick() - cooldown.Value) < CONFIG.DIVINE_COOLDOWN then
		return false
	end

	-- Проверяем прок
	local procced = rollProc(character, "DivineIntervention")

	if procced then
		-- Устанавливаем кулдаун
		if not cooldown then
			cooldown = Instance.new("NumberValue")
			cooldown.Name = "DivineIntervention_CD"
			cooldown.Parent = character
		end
		cooldown.Value = tick()

		print("✨ [DIVINE] DODGED! (Cooldown: " .. CONFIG.DIVINE_COOLDOWN .. "s)")

		-- Активируем бафф урона
		local state = getPlayerState(player)
		state.divineActive = true

		local ITEM_DATABASE = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemDatabase"))
		local itemData = ITEM_DATABASE.Items and ITEM_DATABASE.Items["DivineIntervention"] or ITEM_DATABASE["DivineIntervention"]

		if itemData then
			state.divineEndTime = tick() + itemData.BuffDuration
			print("   +50% damage for 5 seconds!")
		end

		return true -- Урон заблокирован
	end

	return false
end

function ItemEffectSystem.GetDivineBonus(player, character)
	local stacks = getItemStacks(character, "DivineIntervention")
	if stacks == 0 then return 0 end

	local state = getPlayerState(player)

	if state.divineActive and tick() < state.divineEndTime then
		local ITEM_DATABASE = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemDatabase"))
		local itemData = ITEM_DATABASE.Items and ITEM_DATABASE.Items["DivineIntervention"] or ITEM_DATABASE["DivineIntervention"]

		if not itemData then return 0 end

		return itemData.DamageBonus / 100
	else
		state.divineActive = false
		return 0
	end
end

-- ========================
-- OVERCHARGED BATTERY - Каждая 10-я атака
-- ========================
function ItemEffectSystem.CheckOverchargedBattery(player, character)
	local stacks = getItemStacks(character, "OverchargedBattery")
	if stacks == 0 then return false, 0 end

	local state = getPlayerState(player)
	state.attackCounter = state.attackCounter + 1

	if state.attackCounter >= CONFIG.OVERCHARGED_ATTACKS then
		state.attackCounter = 0

		local ITEM_DATABASE = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemDatabase"))
		local itemData = ITEM_DATABASE.Items and ITEM_DATABASE.Items["OverchargedBattery"] or ITEM_DATABASE["OverchargedBattery"]

		if not itemData then return false, 0 end

		print("⚡ [OVERCHARGED] 10th attack! x5 damage + explosion!")
		return true, itemData.ExplosionRadius
	end

	return false, 0
end

-- ========================
-- BLADE ECHO - Повтор атаки (SIMPLIFIED)
-- ========================
function ItemEffectSystem.CheckBladeEcho(character)
	local stacks = getItemStacks(character, "BladeEcho")
	if stacks == 0 then return false, 0 end

	local procced = rollProc(character, "BladeEcho")

	if procced then
		print("⚔️ [BLADE ECHO] Attack repeated!")
		return true, 1 -- Повторить 1 раз
	end

	return false, 0
end

-- ========================
-- CHAIN LIGHTNING - Урон перепрыгивает (SIMPLIFIED)
-- ========================
function ItemEffectSystem.CheckChainLightning(character)
	local stacks = getItemStacks(character, "ChainLightning")
	if stacks == 0 then return false, 0, 0, 0 end

	local procced = rollProc(character, "ChainLightning")

	if procced then
		local ITEM_DATABASE = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemDatabase"))
		local itemData = ITEM_DATABASE.Items and ITEM_DATABASE.Items["ChainLightning"] or ITEM_DATABASE["ChainLightning"]

		if not itemData then return false, 0, 0, 0 end

		local targets = itemData.Targets
		local chainDamage = itemData.ChainDamage
		local range = itemData.Range

		print("⚡ [CHAIN LIGHTNING] Jumping to " .. targets .. " enemies!")

		return true, targets, chainDamage, range
	end

	return false, 0, 0, 0
end

-- ========================
-- BURN - Шанс поджечь (SIMPLIFIED)
-- ========================
function ItemEffectSystem.CheckBurn(character)
	local stacks = getItemStacks(character, "OldLighter")
	if stacks == 0 then return false, 0 end

	local procced = rollProc(character, "OldLighter")

	if procced then
		print("🔥 [BURN] Applied!")
		return true, 1
	end

	return false, 0
end

-- ========================
-- POISON - Шанс отравить (SIMPLIFIED)
-- ========================
function ItemEffectSystem.CheckPoison(character)
	local stacks = getItemStacks(character, "VileVial")
	if stacks == 0 then return false, false end

	local procced = rollProc(character, "VileVial")

	if procced then
		print("☠️ [POISON] Applied!")
		return true, false -- (applied, not enhanced)
	end

	return false, false
end

-- ========================
-- SURVIVOR'S WILL - Блок смертельного урона
-- ========================
function ItemEffectSystem.CheckSurvivorWill(character)
	local stacks = getItemStacks(character, "SurvivorWill")
	if stacks == 0 then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end

	local healthPercent = (humanoid.Health / humanoid.MaxHealth) * 100

	-- Проверяем каждый стак (у каждого свой кулдаун)
	if healthPercent < 10 then
		for i = 1, stacks do
			local cooldown = character:FindFirstChild("SurvivorWill_CD_" .. i)

			if not cooldown or tick() - cooldown.Value >= 30 then
				-- Активируем блок
				if not cooldown then
					cooldown = Instance.new("NumberValue")
					cooldown.Name = "SurvivorWill_CD_" .. i
					cooldown.Parent = character
				end

				cooldown.Value = tick()

				print("❤️ [SURVIVOR'S WILL] Blocked lethal damage! (#" .. i .. ")")
				return true
			end
		end
	end

	return false
end

-- ========================
-- SOUL EATER - Стаки HP за убийства
-- ========================
function ItemEffectSystem.AddSoulEaterStack(character)
	local stacks = getItemStacks(character, "SoulEater")
	if stacks == 0 then return end

	local currentStacks = character:FindFirstChild("SoulEater_CurrentStacks") or Instance.new("IntValue")
	currentStacks.Name = "SoulEater_CurrentStacks"
	currentStacks.Parent = character

	local ITEM_DATABASE = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemDatabase"))
	local itemData = ITEM_DATABASE.Items and ITEM_DATABASE.Items["SoulEater"] or ITEM_DATABASE["SoulEater"]

	if not itemData then return end

	local maxStacks = itemData.MaxStacks or 200

	if currentStacks.Value < maxStacks then
		currentStacks.Value = currentStacks.Value + 1

		local hpPerStack = itemData.BaseValue + (itemData.StackValue * (stacks - 1))

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.MaxHealth = humanoid.MaxHealth + hpPerStack
			humanoid.Health = humanoid.Health + hpPerStack

			print("💀 [SOUL EATER] Stack added! (" .. currentStacks.Value .. "/" .. maxStacks .. ")")
			print("   MaxHealth: " .. humanoid.MaxHealth)
		end
	end
end

function ItemEffectSystem.ResetSoulEater(character)
	local currentStacks = character:FindFirstChild("SoulEater_CurrentStacks")
	if currentStacks then
		currentStacks.Value = 0
	end

	-- Восстанавливаем базовое здоровье
	if baseMaxHealth[character] then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.MaxHealth = baseMaxHealth[character]
			humanoid.Health = baseMaxHealth[character]
			print("💀 [SOUL EATER] Reset to base health: " .. baseMaxHealth[character])
		end
	end
end

function ItemEffectSystem.InitializeSoulEater(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		baseMaxHealth[character] = humanoid.MaxHealth
		print("💀 [SOUL EATER] Stored base health: " .. baseMaxHealth[character])
	end
end

-- ========================
-- ОБНОВЛЕНИЕ ПОСЛЕДНЕЙ АТАКИ
-- ========================
function ItemEffectSystem.UpdateLastAttack(player)
	local state = getPlayerState(player)
	state.lastAttackTime = tick()
end

-- ========================
-- ИНИЦИАЛИЗАЦИЯ ПЕРСОНАЖА
-- ========================
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		-- Сброс состояния при респавне
		resetPlayerState(player)

		-- Инициализация Soul Eater
		ItemEffectSystem.InitializeSoulEater(character)
		ItemEffectSystem.ResetSoulEater(character)
	end)
end)

-- ========================
-- ОЧИСТКА ПРИ ВЫХОДЕ
-- ========================
Players.PlayerRemoving:Connect(function(player)
	playerStates[player.UserId] = nil

	-- Очистка Soul Eater базового здоровья
	if player.Character then
		baseMaxHealth[player.Character] = nil
	end
end)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ [ITEM EFFECT SYSTEM] CLEANED Loaded!")
print("   ❌ Removed: OverflowingChalice double proc logic")
print("   🔧 All proc chances simplified")
print("   Items: Quick Draw, Berserker, Executioner")
print("   Items: Momentum Chain, Divine Intervention")
print("   Items: Overcharged Battery, Blade Echo")
print("   Items: Chain Lightning, Burn, Poison")
print("   Items: Survivor's Will, Soul Eater")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

return ItemEffectSystem
