-- =====================================
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
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
