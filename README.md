-- =====================================
-- ЖАТВА ДУШ PHANTOM - ИСПРАВЛЕННАЯ ВЕРСИЯ (ULT)
-- Полная интеграция с CombatSystem
-- Place in ServerScriptService
-- =====================================
local rs = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

if not rs:FindFirstChild("PhantomHarvest") then
	Instance.new("RemoteEvent", rs).Name = "PhantomHarvest"
end

local remote = rs.PhantomHarvest

-- Подключаем CombatSystem
local CombatSystem
if rs:FindFirstChild("CombatSystem") then
	CombatSystem = require(rs.CombatSystem)
end

-- Настройки
local HARVEST_RADIUS = 50
local MARK_DURATION = 2.5
local HARVEST_DAMAGE = 120
local KNOCKUP_FORCE = 20
local HEAL_PER_ENEMY = 10
local COOLDOWN = 30

-- Кулдауны
local playerCooldowns = {}

-- Найти всех врагов в радиусе
local function findAllEnemies(player, position)
	local enemies = {}

	for _, part in pairs(workspace:GetPartBoundsInRadius(position, HARVEST_RADIUS)) do
		local character = part.Parent
		if character and character:FindFirstChild("Humanoid") then
			if character == player.Character then
				continue
			end

			local humanoid = character.Humanoid
			if humanoid.Health > 0 then
				local rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart

				if rootPart then
					-- ИСПРАВЛЕНО: Получаем Player, если это игрок
					local targetPlayer = Players:GetPlayerFromCharacter(character)

					table.insert(enemies, {
						player = targetPlayer, -- Может быть nil для NPC
						humanoid = humanoid,
						character = character,
						rootPart = rootPart
					})
				end
			end
		end
	end

	return enemies
end

-- Активация жатвы
remote.OnServerEvent:Connect(function(player, action)
	if action == "activate" then
		-- Проверка кулдауна
		local currentTime = tick()
		if playerCooldowns[player.UserId] and currentTime - playerCooldowns[player.UserId] < COOLDOWN then
			warn("⚠️ [HARVEST] Cooldown active")
			return
		end

		local character = player.Character
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChild("Humanoid")

		if not rootPart or not humanoid or humanoid.Health <= 0 then return end

		-- Находим всех врагов
		local enemies = findAllEnemies(player, rootPart.Position)

		if #enemies == 0 then
			print("⚠️ [HARVEST] No enemies in range")
			return
		end

		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("⚰️ [HARVEST] ULTIMATE ACTIVATED!")
		print("   Phantom:", player.Name)
		print("   Enemies marked:", #enemies)
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

		playerCooldowns[player.UserId] = currentTime

		-- Уведомляем клиентов о начале ульта
		remote:FireAllClients("startHarvest", player, rootPart.Position)

		-- Накладываем метки на врагов
		local markedEnemies = {}

		for _, enemy in pairs(enemies) do
			-- Визуальная метка
			remote:FireAllClients("markEnemy", enemy.rootPart)

			table.insert(markedEnemies, enemy)
		end

		-- ЧЕРЕЗ 2.5 СЕКУНДЫ - УРОН
		task.delay(MARK_DURATION, function()
			local hitCount = 0
			local totalDamageDealt = 0 -- Для Lifesteal

			for _, enemy in pairs(markedEnemies) do
				if enemy.humanoid and enemy.humanoid.Health > 0 then
					print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
					print("⚰️ [HARVEST] Executing enemy!")
					print("   Phantom:", player.Name)
					print("   Target:", enemy.character.Name)
					print("   Base Damage:", HARVEST_DAMAGE)

					-- ✅ ИСПРАВЛЕНО: Используем CombatSystem.ApplyDamage
					if CombatSystem then
						if enemy.player then
							-- Если цель - игрок
							CombatSystem.ApplyDamage(
								enemy.player,           -- victim (Player)
								HARVEST_DAMAGE,         -- damage
								player,                 -- attacker (Player)
								enemy.rootPart.Position -- hitPosition для AOE
							)
							print("   ✅ Applied via CombatSystem (Player)")
						else
							-- Если цель - NPC
							local fakePlayer = {
								UserId = enemy.character:GetAttribute("NPCId") or 0,
								Name = enemy.character.Name,
								Character = enemy.character,
								Team = nil
							}

							CombatSystem.ApplyDamage(
								fakePlayer,              -- victim (fake Player для NPC)
								HARVEST_DAMAGE,          -- damage
								player,                  -- attacker (Player)
								enemy.rootPart.Position  -- hitPosition
							)
							print("   ✅ Applied via CombatSystem (NPC)")
						end

						-- ВАЖНО: Урон уже применён через CombatSystem
						-- CombatSystem.ApplyDamage уже вызвал:
						-- - CalculateOutgoingDamage (бонусы урона, криты)
						-- - CalculateIncomingDamage (защита, щит)
						-- - TriggerOnHitEffects (Burn, Poison, Chain Lightning, etc)
						-- - ApplyLifesteal (вампиризм)

						-- Поэтому мы НЕ вызываем отдельно ApplyLifesteal
					else
						-- Fallback
						enemy.humanoid:TakeDamage(HARVEST_DAMAGE)
						print("   ⚠️ Direct damage (CombatSystem not found)")
					end

					print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

					-- Подбрасывание
					if enemy.rootPart and enemy.rootPart.Parent then
						local bodyVelocity = Instance.new("BodyVelocity")
						bodyVelocity.MaxForce = Vector3.new(0, 1e5, 0)
						bodyVelocity.Velocity = Vector3.new(0, KNOCKUP_FORCE * 3, 0)
						bodyVelocity.Parent = enemy.rootPart
						Debris:AddItem(bodyVelocity, 0.3)
					end

					-- Визуальный эффект косы
					remote:FireAllClients("spawnScythe", enemy.rootPart.Position, false)

					hitCount = hitCount + 1
				end
			end

			-- Лечение за каждого поражённого
			if hitCount > 0 and humanoid and humanoid.Parent then
				local healAmount = hitCount * HEAL_PER_ENEMY
				humanoid.Health = math.min(humanoid.Health + healAmount, humanoid.MaxHealth)

				print("💚 [HARVEST] Healed:", healAmount, "HP (", hitCount, "enemies)")

				-- Визуальный эффект лечения
				remote:FireClient(player, "showHeal", healAmount)
			end

			print("⚰️ [HARVEST] Complete! Hit", hitCount, "enemies")
		end)
	end
end)

-- Очистка
game.Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
end)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ [PHANTOM HARVEST SERVER FIXED] Loaded!")
print("   Radius:", HARVEST_RADIUS, "studs")
print("   Damage:", HARVEST_DAMAGE)
print("   Mark duration:", MARK_DURATION, "sec")
print("   Heal per enemy:", HEAL_PER_ENEMY, "HP")
print("   Cooldown:", COOLDOWN, "sec")
print("   ✨ Full CombatSystem integration!")
print("   ✨ All 31 items work with Harvest!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━") -- =====================================
-- КОСА ЖНЕЦА PHANTOM - ИСПРАВЛЕННАЯ ВЕРСИЯ
-- Полная интеграция с CombatSystem
-- Place in ServerScriptService
-- =====================================
local rs = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")

if not rs:FindFirstChild("PhantomScythe") then
	Instance.new("RemoteEvent", rs).Name = "PhantomScythe"
end

local remote = rs.PhantomScythe

-- Подключаем CombatSystem
local CombatSystem
if rs:FindFirstChild("CombatSystem") then
	CombatSystem = require(rs.CombatSystem)
end

-- Настройки
local SCYTHE_DAMAGE = 60
local BOUNCE_DAMAGE = 50
local SCYTHE_SPEED = 80
local SCYTHE_RANGE = 100
local BOUNCE_RANGE = 80
local MAX_BOUNCES = 15
local COOLDOWN_TIME = 7
local DEATH_MARK_DURATION = 3
local DEATH_MARK_BONUS = 0.20

-- Кулдауны
local playerCooldowns = {}

-- Найти ближайшего врага
local function findNearestEnemy(player, position, excludeCharacters)
	local nearestEnemy = nil
	local shortestDistance = math.huge
	excludeCharacters = excludeCharacters or {}

	for _, part in pairs(workspace:GetPartBoundsInRadius(position, SCYTHE_RANGE)) do
		local character = part.Parent
		if character and character:FindFirstChild("Humanoid") then
			if character == player.Character then
				continue
			end

			if excludeCharacters[character] then
				continue
			end

			local humanoid = character.Humanoid
			if humanoid.Health > 0 then
				local distance = (character:GetPivot().Position - position).Magnitude

				if distance < shortestDistance then
					shortestDistance = distance

					-- ИСПРАВЛЕНО: Получаем Player, если это игрок
					local targetPlayer = Players:GetPlayerFromCharacter(character)

					nearestEnemy = {
						player = targetPlayer, -- Может быть nil для NPC
						humanoid = humanoid,
						character = character,
						rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
					}
				end
			end
		end
	end

	return nearestEnemy
end

-- Найти ближайшего врага для рикошета
local function findBounceTarget(player, position, excludeCharacters)
	local nearestEnemy = nil
	local shortestDistance = math.huge

	for _, part in pairs(workspace:GetPartBoundsInRadius(position, BOUNCE_RANGE)) do
		local character = part.Parent
		if character and character:FindFirstChild("Humanoid") then
			if character == player.Character then
				continue
			end

			if excludeCharacters[character] then
				continue
			end

			local humanoid = character.Humanoid
			if humanoid.Health > 0 then
				local distance = (character:GetPivot().Position - position).Magnitude

				if distance < shortestDistance then
					shortestDistance = distance

					-- ИСПРАВЛЕНО: Получаем Player, если это игрок
					local targetPlayer = Players:GetPlayerFromCharacter(character)

					nearestEnemy = {
						player = targetPlayer, -- Может быть nil для NPC
						humanoid = humanoid,
						character = character,
						rootPart = character:FindFirstChild("HumanoidRootPart") or character.PrimaryPart
					}
				end
			end
		end
	end

	return nearestEnemy
end

-- Применить метку смерти
local function applyDeathMark(character, playerName)
	if not character or not character:FindFirstChild("Humanoid") then return end

	local oldMark = character:FindFirstChild("DeathMark")
	if oldMark then oldMark:Destroy() end

	local deathMark = Instance.new("BoolValue")
	deathMark.Name = "DeathMark"
	deathMark.Parent = character

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			remote:FireAllClients("showDeathMark", rootPart)
		end
	end

	print("💀 [DEATH MARK] Applied to:", character.Name, "by", playerName)

	Debris:AddItem(deathMark, DEATH_MARK_DURATION)
end

-- Получить модификатор урона от метки
local function getDamageModifier(character)
	if character and character:FindFirstChild("DeathMark") then
		return 1 + DEATH_MARK_BONUS
	end
	return 1
end

-- Нанести урон (ИСПРАВЛЕНО)
local function dealDamage(player, target, baseDamage, isFirstHit)
	if not target or not target.humanoid or target.humanoid.Health <= 0 then
		return false
	end

	-- Модификатор от метки смерти
	local markMultiplier = getDamageModifier(target.character)
	local adjustedDamage = baseDamage * markMultiplier

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print(isFirstHit and "💀 [SCYTHE] Direct hit!" or "⚡ [SCYTHE] Bounce hit!")
	print("   Phantom:", player.Name)
	print("   Target:", target.character.Name)
	print("   Base Damage:", baseDamage)
	if markMultiplier > 1 then 
		print("   💀 DEATH MARK: x" .. markMultiplier)
		print("   Adjusted Damage:", adjustedDamage)
	end

	-- ✅ ИСПРАВЛЕНО: Используем CombatSystem.ApplyDamage
	if CombatSystem then
		if target.player then
			-- Если цель - игрок
			CombatSystem.ApplyDamage(
				target.player,          -- victim (Player)
				adjustedDamage,         -- damage (с учётом метки)
				player,                 -- attacker (Player)
				target.rootPart.Position -- hitPosition для AOE
			)
			print("   ✅ Applied via CombatSystem (Player)")
		else
			-- Если цель - NPC
			local fakePlayer = {
				UserId = target.character:GetAttribute("NPCId") or 0,
				Name = target.character.Name,
				Character = target.character,
				Team = nil
			}

			CombatSystem.ApplyDamage(
				fakePlayer,              -- victim (fake Player для NPC)
				adjustedDamage,          -- damage
				player,                  -- attacker (Player)
				target.rootPart.Position -- hitPosition
			)
			print("   ✅ Applied via CombatSystem (NPC)")
		end
	else
		-- Fallback
		target.humanoid:TakeDamage(adjustedDamage)
		print("   ⚠️ Direct damage (CombatSystem not found)")
	end

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	-- Применяем метку смерти на первое попадание
	if isFirstHit then
		applyDeathMark(target.character, player.Name)
	end

	-- Визуальный эффект
	remote:FireAllClients("scytheHit", target.rootPart.Position, false)

	return true
end

-- Бросок косы
remote.OnServerEvent:Connect(function(player, action, data)
	if action == "throw" then
		-- Проверка кулдауна
		local currentTime = tick()
		if playerCooldowns[player.UserId] and currentTime - playerCooldowns[player.UserId] < COOLDOWN_TIME then
			warn("⚠️ [SCYTHE] Cooldown active")
			return
		end

		local character = player.Character
		if not character then return end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then return end

		-- Ищем первую цель
		local startPos = rootPart.Position + Vector3.new(0, 2, 0)
		local firstTarget = findNearestEnemy(player, startPos)

		if not firstTarget then
			print("⚠️ [SCYTHE] No targets in range")
			return
		end

		print("💀 [SCYTHE] Throwing at:", firstTarget.character.Name)

		playerCooldowns[player.UserId] = currentTime

		-- Создаём косу на клиенте
		local targetPos = firstTarget.rootPart.Position
		remote:FireAllClients("createScythe", player, startPos, firstTarget.rootPart)

		-- ПРЯМОЙ УДАР
		local distance = (targetPos - startPos).Magnitude
		local flyTime = distance / SCYTHE_SPEED

		task.delay(flyTime, function()
			-- Проверяем что игрок и цель еще живы
			if not character or not character.Parent then
				print("⚠️ [SCYTHE] Player died during flight")
				return
			end

			if not rootPart or not rootPart.Parent then
				print("⚠️ [SCYTHE] Player root lost")
				return
			end

			-- Урон первой цели
			local hitCharacters = {}
			local success = dealDamage(player, firstTarget, SCYTHE_DAMAGE, true)

			if success then
				hitCharacters[firstTarget.character] = true
			end

			-- СИСТЕМА РИКОШЕТА
			local currentPos = firstTarget.rootPart.Position
			local bounceTargets = {}

			for i = 1, MAX_BOUNCES do
				local nextTarget = findBounceTarget(player, currentPos, hitCharacters)

				if not nextTarget then
					print("⚡ [SCYTHE] No more bounce targets (found " .. (i-1) .. " bounces)")
					break
				end

				table.insert(bounceTargets, nextTarget.rootPart)
				hitCharacters[nextTarget.character] = true
				currentPos = nextTarget.rootPart.Position

				print("⚡ [SCYTHE] Bounce " .. i .. " to:", nextTarget.character.Name)
			end

			-- Отправляем на клиент для анимации
			if #bounceTargets > 0 then
				print("🎯 [SCYTHE] Starting bounces:", #bounceTargets)
				remote:FireAllClients("scytheBounce", firstTarget.rootPart.Position, bounceTargets, rootPart)

				-- Наносим урон по каждой цели рикошета с задержкой
				local bounceDelay = 0
				for i, targetRoot in ipairs(bounceTargets) do
					local targetChar = targetRoot.Parent
					if targetChar and targetChar:FindFirstChild("Humanoid") then
						-- ИСПРАВЛЕНО: Получаем Player если это игрок
						local targetPlayer = Players:GetPlayerFromCharacter(targetChar)

						local target = {
							player = targetPlayer, -- Может быть nil для NPC
							humanoid = targetChar.Humanoid,
							character = targetChar,
							rootPart = targetRoot
						}

						-- Рассчитываем задержку до попадания
						local prevPos = i == 1 and firstTarget.rootPart.Position or bounceTargets[i-1].Position
						local dist = (targetRoot.Position - prevPos).Magnitude
						bounceDelay = bounceDelay + (dist / SCYTHE_SPEED)

						task.delay(bounceDelay, function()
							dealDamage(player, target, BOUNCE_DAMAGE, false)
						end)
					end
				end
			else
				-- НЕТ РИКОШЕТОВ - ВОЗВРАЩАЕМ КОСУ К ИГРОКУ
				print("🔄 [SCYTHE] No bounces - returning to player")

				task.wait(0.1)

				if character and character.Parent and rootPart and rootPart.Parent then
					remote:FireAllClients("scytheReturn", firstTarget.rootPart.Position, rootPart)
					print("✅ [SCYTHE] Return event sent!")
				else
					print("⚠️ [SCYTHE] Player died, no return")
				end
			end
		end)
	end
end)

-- Очистка
game.Players.PlayerRemoving:Connect(function(player)
	playerCooldowns[player.UserId] = nil
end)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ [PHANTOM SCYTHE SERVER FIXED] Loaded!")
print("   Damage (throw):", SCYTHE_DAMAGE)
print("   Damage (bounce):", BOUNCE_DAMAGE)
print("   Max bounces:", MAX_BOUNCES)
print("   Bounce range:", BOUNCE_RANGE)
print("   Death Mark: +" .. (DEATH_MARK_BONUS * 100) .. "% damage for", DEATH_MARK_DURATION, "sec")
print("   Cooldown:", COOLDOWN_TIME, "sec")
print("   ✨ Full CombatSystem integration!")
print("   ✨ All 31 items work with Scythe!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")-- =====================================
-- ТЕНЕВОЙ ШАГ PHANTOM - СЕРВЕР (ИСПРАВЛЕН)
-- Place in ServerScriptService
-- =====================================
local rs = game:GetService("ReplicatedStorage")

if not rs:FindFirstChild("PhantomShadowStep") then
	Instance.new("RemoteEvent", rs).Name = "PhantomShadowStep"
end

local remote = rs.PhantomShadowStep

-- Настройки
local DASH_DISTANCE = 40
local INVISIBILITY_DURATION = 1.5
local SPEED_BONUS = 0.5
local STEALTH_CRIT_MULTIPLIER = 2.5
local COOLDOWN = 6

local activeDashes = {}
local playerCooldowns = {}

remote.OnServerEvent:Connect(function(player, action, data)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart or humanoid.Health <= 0 then return end

	if action == "dash" then
		local currentTime = tick()
		if playerCooldowns[player.UserId] and currentTime - playerCooldowns[player.UserId] < COOLDOWN then
			warn("⚠️ [SHADOW STEP] Cooldown active")
			return
		end

		local direction = data.direction
		local startPos = data.startPos

		print("🌫️ [SHADOW STEP] Dash started:", player.Name)

		playerCooldowns[player.UserId] = currentTime

		local endPos = startPos + (direction * DASH_DISTANCE)
		rootPart.CFrame = CFrame.new(endPos)

		print("🎯 [SHADOW STEP] Teleported to:", endPos)

		activeDashes[player.UserId] = {
			player = player,
			character = character,
			originalSpeed = humanoid.WalkSpeed,
			invisEndTime = tick() + INVISIBILITY_DURATION,
			stealthActive = true
		}

		_G.IgnoreStatsChange = true
		humanoid.WalkSpeed = humanoid.WalkSpeed * (1 + SPEED_BONUS)
		task.wait(0.1)
		_G.IgnoreStatsChange = false

		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = 0.7
			elseif part:IsA("Decal") then
				part.Transparency = 0.7
			end
		end

		remote:FireAllClients("setInvisible", player, true)

		task.delay(INVISIBILITY_DURATION, function()
			local dashData = activeDashes[player.UserId]
			if dashData then
				dashData.stealthActive = false

				if character and character.Parent then
					if humanoid then
						_G.IgnoreStatsChange = true
						humanoid.WalkSpeed = dashData.originalSpeed
						task.wait(0.1)
						_G.IgnoreStatsChange = false
					end

					for _, part in pairs(character:GetDescendants()) do
						if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
							part.Transparency = 0
						elseif part:IsA("Decal") then
							part.Transparency = 0
						end
					end

					remote:FireAllClients("setInvisible", player, false)
				end

				activeDashes[player.UserId] = nil
				print("👁️ [SHADOW STEP] Invisibility ended:", player.Name)
			end
		end)

	elseif action == "attack" then
		local dashData = activeDashes[player.UserId]

		if dashData and dashData.stealthActive then
			print("💥 [SHADOW STEP] Stealth attack! Applying crit bonus")

			local critMarker = Instance.new("BoolValue")
			critMarker.Name = "StealthCrit"
			critMarker.Value = true
			critMarker.Parent = character

			dashData.stealthActive = false

			if humanoid then
				_G.IgnoreStatsChange = true
				humanoid.WalkSpeed = dashData.originalSpeed
				task.wait(0.1)
				_G.IgnoreStatsChange = false
			end

			for _, part in pairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.Transparency = 0
				elseif part:IsA("Decal") then
					part.Transparency = 0
				end
			end

			remote:FireAllClients("setInvisible", player, false)

			game:GetService("Debris"):AddItem(critMarker, 0.5)

			activeDashes[player.UserId] = nil
		end
	end
end)

function GetStealthCritMultiplier(player)
	if not player or not player.Character then return 1 end

	local critMarker = player.Character:FindFirstChild("StealthCrit")
	if critMarker and critMarker:IsA("BoolValue") and critMarker.Value then
		critMarker:Destroy()
		return STEALTH_CRIT_MULTIPLIER
	end

	return 1
end

_G.PhantomStealthCrit = GetStealthCritMultiplier

game.Players.PlayerRemoving:Connect(function(player)
	activeDashes[player.UserId] = nil
	playerCooldowns[player.UserId] = nil
end)

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			activeDashes[player.UserId] = nil
		end)
	end)
end)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ [PHANTOM SHADOW STEP SERVER] Loaded!")
print("   Dash distance:", DASH_DISTANCE, "studs")
print("   Invisibility:", INVISIBILITY_DURATION, "sec")
print("   Speed bonus: +" .. (SPEED_BONUS * 100) .. "%")
print("   Stealth crit: x" .. STEALTH_CRIT_MULTIPLIER)
print("   Cooldown:", COOLDOWN, "sec")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")-- =====================================
-- ЖАТВА ДУШ PHANTOM - ИСПРАВЛЕННАЯ ВЕРСИЯ
-- Теперь использует CombatSystem.ApplyDamage
-- Place in ServerScriptService
-- =====================================
local rs = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

if not rs:FindFirstChild("PhantomSoulHarvest") then
	Instance.new("RemoteEvent", rs).Name = "PhantomSoulHarvest"
end

local remote = rs.PhantomSoulHarvest

-- Подключаем CombatSystem
local CombatSystem
if rs:FindFirstChild("CombatSystem") then
	CombatSystem = require(rs.CombatSystem)
end

-- Настройки
local SOUL_DAMAGE = 15
local SOUL_SPEED = 60
local SOUL_LIFETIME = 3
local SEARCH_RADIUS = 100
local SOULS_PER_CAST = 1
local CAST_DELAY = 0.5

-- Активные атаки
local activeHarvests = {}

-- Поиск ближайших врагов (ИГРОКИ + NPC)
local function findNearestEnemies(player, position, count)
	local enemies = {}

	for _, part in pairs(workspace:GetPartBoundsInRadius(position, SEARCH_RADIUS)) do
		local character = part.Parent
		if character and character:FindFirstChild("Humanoid") then
			if character == player.Character then
				continue
			end

			local humanoid = character.Humanoid
			if humanoid.Health > 0 then
				-- ИСПРАВЛЕНО: Получаем Player, если это игрок
				local targetPlayer = Players:GetPlayerFromCharacter(character)
				local distance = (character:GetPivot().Position - position).Magnitude

				table.insert(enemies, {
					player = targetPlayer, -- Может быть nil для NPC
					humanoid = humanoid,
					character = character,
					distance = distance
				})
			end
		end
	end

	table.sort(enemies, function(a, b)
		return a.distance < b.distance
	end)

	local result = {}
	for i = 1, math.min(count, #enemies) do
		table.insert(result, enemies[i])
	end

	return result
end

local function createSoul(player, startPos, target)
	if not target or not target.humanoid or target.humanoid.Health <= 0 then
		return
	end

	local targetRoot = target.character:FindFirstChild("HumanoidRootPart")
	if not targetRoot then return end

	remote:FireClient(player, "createSoul", startPos, targetRoot)

	-- Отслеживание попадания на сервере
	task.spawn(function()
		local startTime = tick()
		local lastPos = startPos
		local hitDetectionRadius = 6

		while tick() - startTime < SOUL_LIFETIME do
			local dt = task.wait()

			if not target.humanoid or target.humanoid.Health <= 0 then
				break
			end

			if not targetRoot or not targetRoot.Parent then
				break
			end

			local direction = (targetRoot.Position - lastPos).Unit
			local distance = (targetRoot.Position - lastPos).Magnitude
			local moveDistance = SOUL_SPEED * dt

			lastPos = lastPos + (direction * moveDistance)

			-- ПРОВЕРКА ПОПАДАНИЯ
			if distance < hitDetectionRadius then
				print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
				print("👻 [SOUL HARVEST] Hit!")
				print("   Phantom:", player.Name)
				print("   Target:", target.character.Name)

				-- ✅ ИСПРАВЛЕНО: Используем CombatSystem.ApplyDamage
				if CombatSystem and target.player then
					-- Если цель - игрок
					CombatSystem.ApplyDamage(
						target.player,      -- victim (Player)
						SOUL_DAMAGE,        -- base damage
						player,             -- attacker (Player)
						targetRoot.Position -- hitPosition для AOE эффектов
					)
					print("   Applied via CombatSystem (Player)")
				elseif CombatSystem then
					-- Если цель - NPC
					-- Создаём временный "fake player" для NPC
					local fakePlayer = {
						UserId = target.character:GetAttribute("NPCId") or 0,
						Name = target.character.Name,
						Character = target.character,
						Team = nil -- NPC не в команде
					}

					CombatSystem.ApplyDamage(
						fakePlayer,          -- victim (fake Player для NPC)
						SOUL_DAMAGE,         -- base damage  
						player,              -- attacker (Player)
						targetRoot.Position  -- hitPosition
					)
					print("   Applied via CombatSystem (NPC)")
				else
					-- Fallback если CombatSystem не загружен
					target.humanoid:TakeDamage(SOUL_DAMAGE)
					print("   Applied direct damage (fallback)")
				end

				print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

				-- Визуальный эффект попадания
				remote:FireAllClients("soulHit", targetRoot.Position, false)

				break
			end
		end
	end)
end

-- Обработка активации
remote.OnServerEvent:Connect(function(player, action, mousePos)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	if action == "start" then
		if activeHarvests[player.UserId] then
			return
		end

		print("👻 [SOUL HARVEST] Started:", player.Name)

		activeHarvests[player.UserId] = {
			active = true,
			lastCast = 0
		}

	elseif action == "cast" then
		local harvestData = activeHarvests[player.UserId]
		if not harvestData or not harvestData.active then return end

		local currentTime = tick()
		if currentTime - harvestData.lastCast < CAST_DELAY then
			return
		end

		harvestData.lastCast = currentTime

		local startPos = rootPart.Position + Vector3.new(0, 2, 0)
		local targets = findNearestEnemies(player, startPos, SOULS_PER_CAST)

		if #targets == 0 then
			return
		end

		print("👻 [SOUL HARVEST] Casting", #targets, "souls")

		for _, target in pairs(targets) do
			createSoul(player, startPos, target)
		end

	elseif action == "stop" then
		if activeHarvests[player.UserId] then
			print("🔴 [SOUL HARVEST] Stopped:", player.Name)
			activeHarvests[player.UserId] = nil
		end
	end
end)

-- Очистка при выходе
game.Players.PlayerRemoving:Connect(function(player)
	activeHarvests[player.UserId] = nil
end)

-- Очистка при смерти
game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			activeHarvests[player.UserId] = nil
		end)
	end)
end)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ [PHANTOM SOUL HARVEST SERVER FIXED] Loaded!")
print("   Souls per cast:", SOULS_PER_CAST)
print("   Damage per soul:", SOUL_DAMAGE)
print("   Search radius:", SEARCH_RADIUS)
print("   Cast delay:", CAST_DELAY, "sec")
print("   ✨ Full CombatSystem integration!")
print("   ✨ All item effects working!")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
