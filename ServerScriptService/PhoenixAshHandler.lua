-- =====================================
-- PHOENIX ASH HANDLER - NO EFFECTS
-- Предотвращает смерть игрока один раз
-- ✅ БЕЗ визуальных эффектов
-- Place in ServerScriptService
-- =====================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🔥 [PHOENIX ASH] Loading Handler...")

-- ========================
-- КОНФИГУРАЦИЯ
-- ========================
local CONFIG = {
	DEBUG_MODE = true,
	INVULNERABILITY_DURATION = 5, -- Секунды неуязвимости
	HP_RESTORE_PERCENT = 25, -- Восстанавливает 25% от макс HP
	ACTIVATION_THRESHOLD = 1, -- Активируется когда HP <= этого значения
}

-- ========================
-- ХРАНИЛИЩЕ ДАННЫХ
-- ========================
local invulnerablePlayers = {} -- {[player.UserId] = endTime}
local reviveConnections = {} -- {[player.UserId] = {connections}}
local phoenixActivating = {} -- Предотвращает двойную активацию

-- ========================
-- ЗАГРУЗКА СИСТЕМ
-- ========================
local CombatSystem = nil
task.spawn(function()
	task.wait(3)
	local module = ReplicatedStorage:FindFirstChild("CombatSystem")
	if module then
		CombatSystem = require(module)
		print("✅ [PHOENIX ASH] CombatSystem loaded!")
	end
end)

-- ========================
-- ПОЛУЧИТЬ СТАКИ ПРЕДМЕТА
-- ========================
local function getItemStacks(character, itemId)
	if not character then return 0 end
	local stacks = character:FindFirstChild(itemId .. "_Stacks")
	return stacks and stacks.Value or 0
end

-- ========================
-- УДАЛИТЬ ПРЕДМЕТ
-- ========================
local function removePhoenixAsh(character)
	if not character then return end

	local stacksValue = character:FindFirstChild("PhoenixAsh_Stacks")
	if stacksValue then
		stacksValue.Value = 0
		stacksValue:Destroy()
	end

	local effectValue = character:FindFirstChild("PhoenixAsh")
	if effectValue then
		effectValue:Destroy()
	end

	if CONFIG.DEBUG_MODE then
		print("🔥 [PHOENIX ASH] Item removed from character")
	end
end

-- ========================
-- ПРОВЕРИТЬ НЕУЯЗВИМОСТЬ
-- ========================
local function isInvulnerable(player)
	local endTime = invulnerablePlayers[player.UserId]
	if endTime and tick() < endTime then
		return true
	end

	if endTime then
		invulnerablePlayers[player.UserId] = nil
	end

	return false
end

-- ========================
-- ДАТЬ НЕУЯЗВИМОСТЬ
-- ========================
local function grantInvulnerability(player, duration)
	invulnerablePlayers[player.UserId] = tick() + duration

	if CONFIG.DEBUG_MODE then
		print("🛡️ [PHOENIX ASH] " .. player.Name .. " is invulnerable for " .. duration .. " seconds")
	end
end

-- ========================
-- АКТИВИРОВАТЬ PHOENIX ASH
-- ========================
local function activatePhoenixAsh(player, character, humanoid, incomingDamage)
	-- Проверка на двойную активацию
	if phoenixActivating[player.UserId] then
		return false
	end
	phoenixActivating[player.UserId] = true

	-- Проверяем наличие предмета
	local stacks = getItemStacks(character, "PhoenixAsh")
	if stacks <= 0 then
		phoenixActivating[player.UserId] = nil
		return false
	end

	if CONFIG.DEBUG_MODE then
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("🔥 [PHOENIX ASH] ACTIVATING!")
		print("   Player: " .. player.Name)
		print("   Current HP: " .. humanoid.Health)
		print("   Incoming damage: " .. (incomingDamage or "unknown"))
		print("   Max HP: " .. humanoid.MaxHealth)
	end

	-- КРИТИЧНО: Восстанавливаем HP немедленно
	local restoreHP = humanoid.MaxHealth * (CONFIG.HP_RESTORE_PERCENT / 100)
	humanoid.Health = restoreHP

	-- Сбрасываем ВСЕ блокирующие состояния
	humanoid.PlatformStand = false
	humanoid.Sit = false
	humanoid.AutoRotate = true

	-- НЕ отключаем Dead/Ragdoll/FallingDown навсегда!
	-- Просто меняем текущее состояние
	if humanoid:GetState() == Enum.HumanoidStateType.Dead then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Ragdoll then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end

	-- Сбрасываем физику
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		rootPart.Anchored = false
		rootPart.Velocity = Vector3.new(0, 0, 0)
		rootPart.RotVelocity = Vector3.new(0, 0, 0)
	end

	if CONFIG.DEBUG_MODE then
		print("   ❤️ Restored HP: " .. restoreHP .. " (" .. CONFIG.HP_RESTORE_PERCENT .. "%)")
	end

	-- Удаляем предмет
	removePhoenixAsh(character)

	-- Даем неуязвимость
	grantInvulnerability(player, CONFIG.INVULNERABILITY_DURATION)

	-- Уведомление
	local remoteEvent = ReplicatedStorage:FindFirstChild("ShowNotification")
	if remoteEvent then
		pcall(function()
			remoteEvent:FireClient(player, "🔥 PHOENIX ASH ACTIVATED!", Color3.fromRGB(255, 150, 0))
		end)
	end

	if CONFIG.DEBUG_MODE then
		print("   ✅ Phoenix Ash activated successfully!")
		print("   🛡️ Invulnerable for " .. CONFIG.INVULNERABILITY_DURATION .. " seconds")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	end

	-- Снимаем блокировку через секунду
	task.delay(1, function()
		phoenixActivating[player.UserId] = nil
	end)

	return true
end

-- ========================
-- БЛОКИРОВКА УРОНА (ГЛАВНАЯ ЛОГИКА)
-- ========================
local function setupDamageInterception()
	task.wait(3)

	local module = ReplicatedStorage:FindFirstChild("CombatSystem")
	if not module then
		warn("⚠️ [PHOENIX ASH] CombatSystem not found!")
		return
	end

	CombatSystem = require(module)
	local originalApplyDamage = CombatSystem.ApplyDamage

	CombatSystem.ApplyDamage = function(targetPlayer, damage, attackerPlayer, attackerPosition)
		-- Проверка 1: Неуязвимость
		if isInvulnerable(targetPlayer) then
			if CONFIG.DEBUG_MODE then
				print("🛡️ [PHOENIX ASH] Blocked " .. damage .. " damage (invulnerable)")
			end
			return
		end

		-- Проверка 2: Phoenix Ash активация
		if targetPlayer and targetPlayer.Character then
			local character = targetPlayer.Character
			local humanoid = character:FindFirstChildOfClass("Humanoid")

			if humanoid then
				local stacks = getItemStacks(character, "PhoenixAsh")

				-- ТОЛЬКО если есть Phoenix Ash И урон смертельный
				if stacks > 0 and (humanoid.Health - damage) <= CONFIG.ACTIVATION_THRESHOLD then
					-- ПРЕДОТВРАЩАЕМ СМЕРТЬ!
					if CONFIG.DEBUG_MODE then
						print("🔥 [PHOENIX ASH] Intercepting lethal damage! (" .. damage .. " damage would kill)")
					end

					-- Активируем Phoenix Ash
					local success = activatePhoenixAsh(targetPlayer, character, humanoid, damage)

					if success then
						-- НЕ применяем урон, предмет активирован
						if CONFIG.DEBUG_MODE then
							print("🔥 [PHOENIX ASH] Damage blocked - Phoenix Ash activated")
						end
						return -- Выходим БЕЗ применения урона
					else
						-- Активация не удалась - пропускаем обычный урон
						if CONFIG.DEBUG_MODE then
							print("🔥 [PHOENIX ASH] Activation failed - applying normal damage")
						end
					end
				elseif CONFIG.DEBUG_MODE and (humanoid.Health - damage) <= 0 then
					-- Смертельный урон но нет Phoenix Ash
					print("💀 [PHOENIX ASH] Lethal damage (" .. damage .. ") but no Phoenix Ash (stacks: " .. stacks .. ") - player will die normally")
				end
			end
		end

		-- Обычный урон
		return originalApplyDamage(targetPlayer, damage, attackerPlayer, attackerPosition)
	end

	print("✅ [PHOENIX ASH] Damage interception hooked!")
end

-- ========================
-- МОНИТОРИНГ ИГРОКА (ЗАПАСНОЙ МЕХАНИЗМ)
-- ========================
local function setupPhoenixAshForPlayer(player)
	local function onCharacterAdded(character)
		task.wait(1)

		local humanoid = character:WaitForChild("Humanoid", 5)
		if not humanoid then return end

		-- Очищаем старые подключения
		if reviveConnections[player.UserId] then
			for _, conn in pairs(reviveConnections[player.UserId]) do
				if conn then conn:Disconnect() end
			end
		end
		reviveConnections[player.UserId] = {}

		local connections = reviveConnections[player.UserId]
		local lastHealth = humanoid.Health

		-- Запасной механизм через HealthChanged
		local healthConnection = humanoid.HealthChanged:Connect(function(newHealth)
			-- ТОЛЬКО если есть Phoenix Ash
			local stacks = getItemStacks(character, "PhoenixAsh")
			if stacks > 0 and newHealth <= 0 and lastHealth > 0 then
				-- Последняя попытка активации
				if CONFIG.DEBUG_MODE then
					print("🔥 [PHOENIX ASH] Backup mechanism triggered!")
				end
				activatePhoenixAsh(player, character, humanoid, lastHealth)
			end
			lastHealth = math.max(0, newHealth)
		end)

		table.insert(connections, healthConnection)

		if CONFIG.DEBUG_MODE then
			print("🔥 [PHOENIX ASH] Monitoring " .. player.Name)
		end
	end

	if player.Character then
		onCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
end

-- ========================
-- ИНИЦИАЛИЗАЦИЯ
-- ========================
task.spawn(setupDamageInterception)

for _, player in ipairs(Players:GetPlayers()) do
	setupPhoenixAshForPlayer(player)
end

Players.PlayerAdded:Connect(setupPhoenixAshForPlayer)

Players.PlayerRemoving:Connect(function(player)
	invulnerablePlayers[player.UserId] = nil
	phoenixActivating[player.UserId] = nil

	if reviveConnections[player.UserId] then
		for _, conn in pairs(reviveConnections[player.UserId]) do
			if conn then conn:Disconnect() end
		end
		reviveConnections[player.UserId] = nil
	end
end)

print("✅ [PHOENIX ASH] Handler loaded!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🔥 [PHOENIX ASH - NO EFFECTS]")
print("   Effect: PREVENTS death (not revive)")
print("   HP restore: " .. CONFIG.HP_RESTORE_PERCENT .. "% of max HP")
print("   Invulnerability: " .. CONFIG.INVULNERABILITY_DURATION .. " seconds")
print("   ✅ Player CAN MOVE after activation")
print("   ✅ Items are NOT lost")
print("   ✅ NO visual effects")
print("   🔴 DEBUG MODE: " .. tostring(CONFIG.DEBUG_MODE))
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- ========================
-- DEBUG КОМАНДЫ
-- ========================
_G.PhoenixDebug = function(enabled)
	CONFIG.DEBUG_MODE = enabled
	print("🔥 [PHOENIX ASH] Debug mode: " .. tostring(enabled))
end

_G.TestPhoenixAsh = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player or not player.Character then
		print("❌ Player not found!")
		return
	end

	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local stacks = getItemStacks(character, "PhoenixAsh")

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🔥 [PHOENIX ASH TEST] " .. playerName)
	print("   Phoenix Ash stacks: " .. stacks)
	print("   Current HP: " .. humanoid.Health .. "/" .. humanoid.MaxHealth)
	print("   Invulnerable: " .. tostring(isInvulnerable(player)))

	if isInvulnerable(player) then
		local timeLeft = invulnerablePlayers[player.UserId] - tick()
		print("   Time left: " .. string.format("%.1f", timeLeft) .. " seconds")
	end

	if stacks > 0 then
		print("   ✅ Phoenix Ash ready!")
	else
		print("   ❌ No Phoenix Ash")
	end
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

_G.TestPhoenixLethal = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player or not player.Character then
		print("❌ Player not found!")
		return
	end

	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	local lethalDamage = humanoid.Health + 10

	print("🧪 [PHOENIX TEST] Dealing lethal damage: " .. lethalDamage)

	if CombatSystem and CombatSystem.ApplyDamage then
		CombatSystem.ApplyDamage(player, lethalDamage, player, player.Character.HumanoidRootPart.Position)
	else
		humanoid:TakeDamage(lethalDamage)
	end
end
