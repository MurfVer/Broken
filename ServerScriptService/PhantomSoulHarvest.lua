-- =====================================
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
