-- =====================================
-- THORN BANDOLEER HANDLER V4 FINAL
-- Отражает урон обратно атакующему
-- ✅ Работает БЕЗ Owner в снарядах
-- ✅ Расширенный радиус 150 studs
-- ✅ Умный поиск стрелка
-- Place in ServerScriptService
-- =====================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🌵 [THORNS V4] Loading Thorn Bandoleer Handler...")

-- ========================
-- КОНФИГУРАЦИЯ
-- ========================
local CONFIG = {
	DEBUG_MODE = true,
	SEARCH_RADIUS = 150, -- Увеличенный радиус для дальних врагов
	DAMAGE_COOLDOWN = 0.05, -- Минимальное время между отражениями
	DAMAGE_HISTORY_TIME = 1, -- Сколько секунд хранить историю урона
}

-- ========================
-- ХРАНИЛИЩЕ ДАННЫХ
-- ========================
local playerDamageCooldowns = {}
local damageHistory = {} -- {[player.UserId] = {{time = tick(), damage = 10, possibleAttackers = {...}}}}

-- ========================
-- ПОЛУЧИТЬ ЗНАЧЕНИЕ ЭФФЕКТА
-- ========================
local function getEffectValue(character, effectName)
	if not character then return 0 end
	local effectValue = character:FindFirstChild(effectName)
	return effectValue and effectValue.Value or 0
end

-- ========================
-- НАЙТИ ВСЕХ ВРАГОВ В РАДИУСЕ
-- ========================
local function findEnemiesInRadius(victimCharacter, radius)
	if not victimCharacter or not victimCharacter:FindFirstChild("HumanoidRootPart") then
		return {}
	end

	local victimPos = victimCharacter.HumanoidRootPart.Position
	local enemies = {}

	-- Поиск по всем моделям в workspace
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and obj ~= victimCharacter then
			local humanoid = obj:FindFirstChild("Humanoid")
			local rootPart = obj:FindFirstChild("HumanoidRootPart")

			if humanoid and humanoid.Health > 0 and rootPart then
				local distance = (rootPart.Position - victimPos).Magnitude

				if distance <= radius then
					-- Не игрок = враг
					local isPlayer = Players:GetPlayerFromCharacter(obj)
					if not isPlayer then
						table.insert(enemies, {
							model = obj,
							distance = distance,
							position = rootPart.Position
						})
					end
				end
			end
		end
	end

	-- Сортируем по дистанции (ближайшие первые)
	table.sort(enemies, function(a, b)
		return a.distance < b.distance
	end)

	return enemies
end

-- ========================
-- ВЫБРАТЬ ЛУЧШЕГО КАНДИДАТА
-- ========================
local function selectBestAttacker(enemies, victimCharacter)
	if #enemies == 0 then return nil end

	-- Стратегия 1: Если один враг очень близко (<20 studs) - это точно он
	if enemies[1].distance < 20 then
		return enemies[1].model
	end

	-- Стратегия 2: Проверяем направление взгляда врагов
	local victimPos = victimCharacter.HumanoidRootPart.Position
	local bestScore = -math.huge
	local bestEnemy = enemies[1].model

	for _, enemy in ipairs(enemies) do
		local score = 0

		-- Чем ближе - тем выше балл
		local distanceScore = (CONFIG.SEARCH_RADIUS - enemy.distance) / CONFIG.SEARCH_RADIUS * 100

		-- Проверяем направление взгляда
		local enemyHumanoid = enemy.model:FindFirstChild("Humanoid")
		local enemyHead = enemy.model:FindFirstChild("Head") or enemy.model:FindFirstChild("HumanoidRootPart")

		if enemyHead then
			local directionToVictim = (victimPos - enemyHead.Position).Unit
			local enemyLookDir = enemyHead.CFrame.LookVector

			-- Косинус угла между направлениями
			local dotProduct = directionToVictim:Dot(enemyLookDir)

			-- Если враг смотрит в сторону жертвы - бонус
			if dotProduct > 0.7 then -- Угол < 45 градусов
				score = score + 50
			end
		end

		-- Проверяем есть ли визуальная линия видимости
		local rayOrigin = enemy.position
		local rayDirection = (victimPos - rayOrigin).Unit * enemy.distance
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = {enemy.model, victimCharacter}
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

		local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

		if not rayResult then
			-- Прямая видимость - бонус
			score = score + 30
		end

		score = score + distanceScore

		if score > bestScore then
			bestScore = score
			bestEnemy = enemy.model
		end
	end

	return bestEnemy
end

-- ========================
-- НАНЕСТИ УРОН ОТРАЖЕНИЯ
-- ========================
local function applyThornsDamage(victimPlayer, damageTaken)
	if not victimPlayer or not victimPlayer.Character then return end

	local victimCharacter = victimPlayer.Character
	local currentTime = tick()

	-- Проверяем кулдаун
	local lastDamageTime = playerDamageCooldowns[victimPlayer.UserId] or 0
	if currentTime - lastDamageTime < CONFIG.DAMAGE_COOLDOWN then
		return
	end

	-- Проверяем наличие эффекта Thorns
	local thornsValue = getEffectValue(victimCharacter, "Thorns")
	if thornsValue <= 0 then return end

	-- Рассчитываем урон отражения
	local reflectedDamage = damageTaken * (thornsValue / 100)

	-- Ищем врагов в радиусе
	local enemies = findEnemiesInRadius(victimCharacter, CONFIG.SEARCH_RADIUS)

	if #enemies == 0 then
		if CONFIG.DEBUG_MODE then
			print("🌵 [THORNS] ❌ No enemies found within " .. CONFIG.SEARCH_RADIUS .. " studs")
		end
		return
	end

	-- Выбираем лучшего кандидата
	local attacker = selectBestAttacker(enemies, victimCharacter)

	if not attacker then
		if CONFIG.DEBUG_MODE then
			print("🌵 [THORNS] ❌ Could not select attacker from " .. #enemies .. " candidates")
		end
		return
	end

	-- Обновляем кулдаун
	playerDamageCooldowns[victimPlayer.UserId] = currentTime

	-- Получаем дистанцию
	local attackerRoot = attacker:FindFirstChild("HumanoidRootPart")
	local distance = attackerRoot and (attackerRoot.Position - victimCharacter.HumanoidRootPart.Position).Magnitude or 0

	if CONFIG.DEBUG_MODE then
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("🌵 [THORNS V4] Reflecting damage!")
		print("   Victim: " .. victimPlayer.Name)
		print("   Attacker: " .. attacker.Name)
		print("   Distance: " .. string.format("%.1f", distance) .. " studs")
		print("   Candidates found: " .. #enemies)
		print("   Damage taken: " .. string.format("%.1f", damageTaken))
		print("   Thorns value: " .. thornsValue .. "%")
		print("   🔥 Reflected damage: " .. string.format("%.1f", reflectedDamage))
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	end

	-- Наносим урон атакующему
	local attackerPlayer = Players:GetPlayerFromCharacter(attacker)

	if attackerPlayer then
		-- Атакующий - игрок
		local CombatSystem = ReplicatedStorage:FindFirstChild("CombatSystem")
		if CombatSystem then
			CombatSystem = require(CombatSystem)
			if CombatSystem.ApplyDamage then
				pcall(function()
					CombatSystem.ApplyDamage(attackerPlayer, reflectedDamage, victimPlayer, attacker.HumanoidRootPart.Position)
				end)
			end
		end
		print("🌵 [THORNS] ⚔️ " .. attackerPlayer.Name .. " took " .. string.format("%.1f", reflectedDamage) .. " reflected damage!")
	else
		-- Атакующий - NPC
		local humanoid = attacker:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			local hpBefore = humanoid.Health
			humanoid:TakeDamage(reflectedDamage)
			local hpAfter = humanoid.Health

			print("🌵 [THORNS] ⚔️ " .. attacker.Name .. " (NPC) took " .. string.format("%.1f", reflectedDamage) .. " reflected damage! (HP: " .. string.format("%.1f", hpAfter) .. "/" .. humanoid.MaxHealth .. ")")

			-- Визуальный эффект попадания
			if CONFIG.DEBUG_MODE and attackerRoot then
				-- Эффект шипов
				local effect = Instance.new("Part")
				effect.Size = Vector3.new(4, 4, 4)
				effect.Position = attackerRoot.Position + Vector3.new(0, 5, 0)
				effect.Anchored = true
				effect.CanCollide = false
				effect.Transparency = 0.3
				effect.Color = Color3.fromRGB(100, 100, 100)
				effect.Material = Enum.Material.Neon
				effect.Shape = Enum.PartType.Ball
				effect.Parent = workspace

				-- Партиклы
				local attach = Instance.new("Attachment", effect)
				local particles = Instance.new("ParticleEmitter", attach)
				particles.Texture = "rbxassetid://8534045152" -- Шипы
				particles.Color = ColorSequence.new(Color3.fromRGB(80, 80, 80))
				particles.Size = NumberSequence.new(2, 0)
				particles.Lifetime = NumberRange.new(0.5, 0.8)
				particles.Rate = 100
				particles.Speed = NumberRange.new(10, 20)
				particles.SpreadAngle = Vector2.new(360, 360)
				particles.Enabled = true

				-- Звук
				local sound = Instance.new("Sound", effect)
				sound.SoundId = "rbxassetid://142070127" -- Звук шипов
				sound.Volume = 0.3
				sound.PlaybackSpeed = 1.2
				sound:Play()

				task.delay(0.2, function()
					particles.Enabled = false
				end)

				Debris:AddItem(effect, 1)
			end
		end
	end
end

-- ========================
-- ПОДКЛЮЧЕНИЕ К ИГРОКАМ
-- ========================
local function setupThornsForPlayer(player)
	local function onCharacterAdded(character)
		task.wait(1) -- Ждём полной загрузки

		local humanoid = character:WaitForChild("Humanoid", 5)
		if not humanoid then return end

		local lastHealth = humanoid.Health

		humanoid.HealthChanged:Connect(function(newHealth)
			-- Проверяем что здоровье уменьшилось (получен урон)
			if newHealth < lastHealth and newHealth > 0 then
				local damageTaken = lastHealth - newHealth

				-- Проверяем есть ли Thorns
				local thornsValue = getEffectValue(character, "Thorns")
				if thornsValue > 0 then
					-- Отражаем урон
					applyThornsDamage(player, damageTaken)
				end
			end

			lastHealth = newHealth
		end)

		if CONFIG.DEBUG_MODE then
			print("🌵 [THORNS V4] Monitoring " .. player.Name .. " for damage reflection")
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
-- Подключаем существующих игроков
for _, player in ipairs(Players:GetPlayers()) do
	setupThornsForPlayer(player)
end

-- Подключаем новых игроков
Players.PlayerAdded:Connect(setupThornsForPlayer)

-- Очистка при выходе
Players.PlayerRemoving:Connect(function(player)
	playerDamageCooldowns[player.UserId] = nil
	damageHistory[player.UserId] = nil
end)

print("✅ [THORNS V4] Handler loaded!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🌵 [THORN BANDOLEER V4 FINAL] Handler loaded!")
print("   Effect: Reflects damage back to attacker")
print("   Formula: Reflected = Damage × (Thorns%/100)")
print("   Search radius: " .. CONFIG.SEARCH_RADIUS .. " studs")
print("   Damage cooldown: " .. CONFIG.DAMAGE_COOLDOWN .. " seconds")
print("   ✅ Works WITHOUT Owner/Creator in projectiles")
print("   ✅ Smart attacker detection (distance + direction + visibility)")
print("   ✅ Supports ranged enemies up to 150 studs")
print("   Works on: Players and NPCs")
print("   🔴 DEBUG MODE: " .. tostring(CONFIG.DEBUG_MODE))
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- ========================
-- DEBUG КОМАНДЫ
-- ========================
_G.ThornsDebug = function(enabled)
	CONFIG.DEBUG_MODE = enabled
	print("🌵 [THORNS V4] Debug mode: " .. tostring(enabled))
end

_G.ThornsSearchRadius = function(radius)
	CONFIG.SEARCH_RADIUS = radius
	print("🌵 [THORNS V4] Search radius: " .. radius .. " studs")
end

_G.TestThorns = function(playerName)
	local player = Players:FindFirstChild(playerName)
	if not player or not player.Character then
		print("❌ Player not found!")
		return
	end

	local character = player.Character
	local thornsValue = getEffectValue(character, "Thorns")

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🌵 [THORNS TEST] " .. playerName)
	print("   Thorns value: " .. thornsValue .. "%")
	print("   Search radius: " .. CONFIG.SEARCH_RADIUS .. " studs")
	print("   Example: 10 damage → " .. string.format("%.1f", 10 * (thornsValue / 100)) .. " reflected")
	print("")

	-- Показываем врагов
	local enemies = findEnemiesInRadius(character, CONFIG.SEARCH_RADIUS)
	print("   🔍 Enemies in radius: " .. #enemies)

	for i = 1, math.min(5, #enemies) do
		local enemy = enemies[i]
		print("      " .. i .. ". " .. enemy.model.Name .. " - " .. string.format("%.1f", enemy.distance) .. " studs")
	end

	if #enemies > 0 then
		local best = selectBestAttacker(enemies, character)
		if best then
			print("")
			print("   ⭐ Best candidate: " .. best.Name)
		end
	end
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

_G.ListNearbyEnemies = function(playerName, radius)
	local player = Players:FindFirstChild(playerName)
	if not player or not player.Character then
		print("❌ Player not found!")
		return
	end

	radius = radius or CONFIG.SEARCH_RADIUS
	local character = player.Character
	local enemies = findEnemiesInRadius(character, radius)

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🌵 [THORNS] Enemies near " .. playerName .. " (radius: " .. radius .. ")")

	for i, enemy in ipairs(enemies) do
		local rangeLabel = ""
		if enemy.distance <= 20 then
			rangeLabel = "[MELEE]"
		elseif enemy.distance <= 50 then
			rangeLabel = "[CLOSE]"
		elseif enemy.distance <= 100 then
			rangeLabel = "[MID]"
		else
			rangeLabel = "[FAR]"
		end

		print("   " .. i .. ". " .. enemy.model.Name .. " - " .. string.format("%.1f", enemy.distance) .. " studs " .. rangeLabel)
	end

	print("")
	print("   Total enemies: " .. #enemies)
	print("   Melee (<20): " .. #(function() local t={} for _,e in ipairs(enemies) do if e.distance<=20 then table.insert(t,e) end end return t end)())
	print("   Ranged (>50): " .. #(function() local t={} for _,e in ipairs(enemies) do if e.distance>50 then table.insert(t,e) end end return t end)())
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

_G.SimulateThorns = function(playerName, damageAmount)
	local player = Players:FindFirstChild(playerName)
	if not player or not player.Character then
		print("❌ Player not found!")
		return
	end

	damageAmount = damageAmount or 10
	print("🧪 [THORNS] Simulating " .. damageAmount .. " damage to " .. playerName)
	applyThornsDamage(player, damageAmount)
end
