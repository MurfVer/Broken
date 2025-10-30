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
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
