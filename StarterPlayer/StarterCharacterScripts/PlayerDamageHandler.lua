-- PlayerDamageHandler.lua
-- ОБРАБОТКА ПОЛУЧЕНИЯ УРОНА ИГРОКОМ
-- Place in StarterPlayer > StarterCharacterScripts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")

-- Подключаем CombatSystem
local CombatSystem = nil
local attempts = 0
repeat
	CombatSystem = ReplicatedStorage:FindFirstChild("CombatSystem")
	if not CombatSystem then
		wait(0.5)
		attempts = attempts + 1
	end
until CombatSystem or attempts > 20

if not CombatSystem then
	warn("❌ [DAMAGE HANDLER] CombatSystem not found!")
	return
end

CombatSystem = require(CombatSystem)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ [DAMAGE HANDLER] Loaded for " .. player.Name)
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- ============================================
-- ОТСЛЕЖИВАНИЕ ПОЛУЧЕНИЯ УРОНА
-- ============================================

local lastHealth = humanoid.Health
local lastDamageTime = 0
local DAMAGE_COOLDOWN = 0.1 -- Минимальное время между обработками урона

humanoid.HealthChanged:Connect(function(newHealth)
	-- Проверяем что это урон, а не лечение
	if newHealth >= lastHealth then
		lastHealth = newHealth
		return
	end

	-- Защита от спама
	if tick() - lastDamageTime < DAMAGE_COOLDOWN then
		return
	end
	lastDamageTime = tick()

	local rawDamage = lastHealth - newHealth

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("💢 [DAMAGE HANDLER] Player took damage!")
	print("   Player: " .. player.Name)
	print("   Raw Damage: " .. math.floor(rawDamage))
	print("   HP Before: " .. math.floor(lastHealth))

	-- Применяем защиту (Defense)
	local reducedDamage = CombatSystem.CalculateIncomingDamage(player, rawDamage)

	-- Если есть разница - значит защита сработала
	if reducedDamage < rawDamage then
		local blocked = rawDamage - reducedDamage
		print("🛡️ [DAMAGE HANDLER] Defense blocked: " .. math.floor(blocked) .. " damage")

		-- Восстанавливаем HP до того как была применена защита
		local targetHealth = lastHealth - reducedDamage
		humanoid.Health = math.max(targetHealth, 0)

		print("   Final Damage: " .. math.floor(reducedDamage))
		print("   HP After: " .. math.floor(humanoid.Health))
	else
		print("   No defense applied")
		print("   HP After: " .. math.floor(newHealth))
	end

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	lastHealth = humanoid.Health
end)

-- ============================================
-- ИНИЦИАЛИЗАЦИЯ ЩИТА
-- ============================================

-- Запускаем регенерацию щита
CombatSystem.StartShieldRegeneration(player)

-- Проверяем есть ли уже Shield stat
local shield = character:FindFirstChild("Shield")
if shield and shield:IsA("NumberValue") and shield.Value > 0 then
	print("🔷 [DAMAGE HANDLER] Player has shield: " .. shield.Value)
end

print("✅ [DAMAGE HANDLER] Ready to protect " .. player.Name)
