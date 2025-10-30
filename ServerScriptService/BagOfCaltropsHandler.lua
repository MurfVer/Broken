-- =====================================
-- BAG OF CALTROPS HANDLER - DEEP NPC SEARCH
-- Создание зон шипов при использовании Q
-- ✅ РАСШИРЕННЫЙ ПОИСК: ищет NPC везде (workspace, NPCs, Enemies, папки)
-- Place in ServerScriptService
-- =====================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

-- ========================
-- КОНФИГУРАЦИЯ
-- ========================
local CONFIG = {
	ZONE_SIZE = 15, -- 15x15 studs
	ZONE_DURATION = 5, -- 5 секунд
	DAMAGE_TICK_RATE = 1, -- Раз в секунду
	BASE_DAMAGE = 15, -- 🔥 БАЗОВЫЙ УРОН 15 ЗА ТИК
	DEBUG_MODE = true, -- Включить подробный дебаг
	SEARCH_DEPTH = 3, -- Глубина поиска NPC в папках
}

-- ========================
-- ЗАГРУЗКА СИСТЕМ
-- ========================
local ItemDatabase = nil
local CombatSystem = nil

task.spawn(function()
	local attempts = 0
	repeat
		ItemDatabase = ReplicatedStorage:FindFirstChild("ItemDatabase")
		if ItemDatabase then
			ItemDatabase = require(ItemDatabase)
			print("✅ [CALTROPS] ItemDatabase loaded!")
		else
			wait(0.5)
			attempts = attempts + 1
		end
	until ItemDatabase or attempts > 20

	if not ItemDatabase then
		error("❌ [CALTROPS] ItemDatabase not found!")
	end

	attempts = 0
	repeat
		local combatModule = ReplicatedStorage:FindFirstChild("CombatSystem")
		if combatModule then
			CombatSystem = require(combatModule)
			print("✅ [CALTROPS] CombatSystem loaded!")
		else
			wait(0.5)
			attempts = attempts + 1
		end
	until CombatSystem or attempts > 20

	if not CombatSystem then
		warn("⚠️ [CALTROPS] CombatSystem not found - using fallback damage!")
	end
end)

-- ========================
-- ХРАНИЛИЩЕ АКТИВНЫХ ЗОН
-- ========================
local activeZones = {}

-- ========================
-- ПОЛУЧИТЬ СТАКИ ПРЕДМЕТА
-- ========================
local function getItemStacks(character, itemId)
	local stacks = character:FindFirstChild(itemId .. "_Stacks")
	return stacks and stacks.Value or 0
end

-- ========================
-- ПОЛУЧИТЬ DAMAGE MULTIPLIER ПЕРСОНАЖА
-- ========================
local function getPlayerDamageMultiplier(character)
	if not character then return 1 end

	local damageMultiplier = character:FindFirstChild("DamageMultiplier")
	if damageMultiplier and damageMultiplier:IsA("NumberValue") then
		return damageMultiplier.Value
	end

	local damageStat = character:FindFirstChild("DamageStat")
	if damageStat and damageStat:IsA("NumberValue") then
		return damageStat.Value / 100
	end

	local damage = character:FindFirstChild("Damage")
	if damage and damage:IsA("NumberValue") then
		return damage.Value
	end

	local playerStats = character:FindFirstChild("PlayerStats")
	if playerStats then
		local dmg = playerStats:FindFirstChild("Damage") or playerStats:FindFirstChild("DamageMultiplier")
		if dmg and dmg:IsA("NumberValue") then
			return dmg.Value
		end
	end

	return 1
end

-- ========================
-- ПРОВЕРИТЬ НАХОДИТСЯ ЛИ В ЗОНЕ
-- ========================
local function isInZone(targetPosition, zonePosition, zoneSize)
	local dx = math.abs(targetPosition.X - zonePosition.X)
	local dy = math.abs(targetPosition.Y - zonePosition.Y)
	local dz = math.abs(targetPosition.Z - zonePosition.Z)

	local inX = dx <= zoneSize.X / 2
	local inZ = dz <= zoneSize.Z / 2
	local inY = dy <= 10 -- Запас по высоте

	return inX and inZ and inY
end

-- ========================
-- РЕКУРСИВНЫЙ ПОИСК ВСЕХ NPC
-- ========================
local function getAllNPCs(parent, depth, maxDepth, npcs)
	if depth > maxDepth then return end

	npcs = npcs or {}

	for _, child in ipairs(parent:GetChildren()) do
		-- Проверяем это NPC?
		if child:IsA("Model") and child:FindFirstChild("Humanoid") and child:FindFirstChild("HumanoidRootPart") then
			local isPlayer = Players:GetPlayerFromCharacter(child)
			if not isPlayer then
				table.insert(npcs, child)
			end
		end

		-- Рекурсивно ищем в папках
		if child:IsA("Folder") or child:IsA("Model") then
			getAllNPCs(child, depth + 1, maxDepth, npcs)
		end
	end

	return npcs
end

-- ========================
-- СОЗДАТЬ ЗОНУ ШИПОВ
-- ========================
local function createCaltropZone(position, player)
	local character = player.Character
	if not character then return end

	local stacks = getItemStacks(character, "BagOfCaltrops")
	if stacks == 0 then return end

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🌵 [CALTROPS] Creating zone")
	print("   Player: " .. player.Name)
	print("   Position: " .. tostring(position))
	print("   Stacks: " .. stacks)

	if not ItemDatabase then
		warn("⚠️ [CALTROPS] ItemDatabase not loaded yet!")
		return
	end

	local itemData = ItemDatabase:GetItem("BagOfCaltrops")
	if not itemData then
		warn("⚠️ [CALTROPS] BagOfCaltrops data not found in ItemDatabase!")
		return
	end

	local itemDamageBonus = itemData.BaseValue + (itemData.StackValue * (stacks - 1))
	local playerDamageMultiplier = getPlayerDamageMultiplier(character)
	local finalDamage = itemDamageBonus * playerDamageMultiplier

	print("   📊 Damage Calculation:")
	print("      Base damage: " .. CONFIG.BASE_DAMAGE)
	print("      Item bonus: " .. itemDamageBonus .. " (" .. stacks .. " stacks)")
	print("      Player multiplier: " .. string.format("%.2f", playerDamageMultiplier))
	print("      🔥 FINAL DAMAGE: " .. string.format("%.1f", finalDamage) .. "/sec")

	-- Создаём визуальную зону
	local zone = Instance.new("Part")
	zone.Name = "CaltropZone"
	zone.Size = Vector3.new(CONFIG.ZONE_SIZE, 0.5, CONFIG.ZONE_SIZE)
	zone.Position = position
	zone.Anchored = true
	zone.CanCollide = false
	zone.Transparency = 0.5
	zone.Color = Color3.fromRGB(100, 100, 100)
	zone.Material = Enum.Material.Metal
	zone.Parent = workspace

	local decal = Instance.new("Decal")
	decal.Texture = "rbxassetid://8534045152"
	decal.Face = Enum.NormalId.Top
	decal.Parent = zone

	local attachment = Instance.new("Attachment")
	attachment.Parent = zone

	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(Color3.fromRGB(150, 150, 150))
	particles.Lifetime = NumberRange.new(0.5, 1)
	particles.Rate = 5
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(360, 180)
	particles.Parent = attachment

	-- DEBUG: Красная зона
	if CONFIG.DEBUG_MODE then
		local debugZone = Instance.new("Part")
		debugZone.Name = "DebugZone"
		debugZone.Size = Vector3.new(CONFIG.ZONE_SIZE, 0.1, CONFIG.ZONE_SIZE)
		debugZone.Position = position + Vector3.new(0, 1, 0)
		debugZone.Anchored = true
		debugZone.CanCollide = false
		debugZone.Transparency = 0.7
		debugZone.Color = Color3.fromRGB(255, 0, 0)
		debugZone.Material = Enum.Material.Neon
		debugZone.Parent = zone
		Debris:AddItem(debugZone, CONFIG.ZONE_DURATION)
	end

	local zoneData = {
		part = zone,
		owner = player,
		ownerCharacter = character,
		damagePerSecond = finalDamage,
		endTime = tick() + CONFIG.ZONE_DURATION,
		lastDamageTick = 0,
		affectedEnemies = {},
		damageCount = 0,
		tickCount = 0
	}

	table.insert(activeZones, zoneData)

	print("✅ [CALTROPS] Zone created!")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	Debris:AddItem(zone, CONFIG.ZONE_DURATION)
end

-- ========================
-- ОБРАБОТКА УРОНА ОТ ШИПОВ
-- ========================
local lastUpdateTime = tick()

RunService.Heartbeat:Connect(function()
	local currentTime = tick()

	if currentTime - lastUpdateTime < CONFIG.DAMAGE_TICK_RATE then
		return
	end

	lastUpdateTime = currentTime

	-- Обрабатываем каждую зону
	for i = #activeZones, 1, -1 do
		local zone = activeZones[i]

		-- Проверяем истёк ли таймер
		if currentTime >= zone.endTime or not zone.part or not zone.part.Parent then
			if CONFIG.DEBUG_MODE and zone.damageCount > 0 then
				print("🌵 [CALTROPS] Zone expired - Total hits: " .. zone.damageCount .. " over " .. zone.tickCount .. " ticks")
			end
			table.remove(activeZones, i)
			continue
		end

		zone.tickCount = zone.tickCount + 1

		-- ОБНОВЛЯЕМ УРОН
		if zone.ownerCharacter and zone.ownerCharacter.Parent then
			local stacks = getItemStacks(zone.ownerCharacter, "BagOfCaltrops")
			if stacks > 0 then
				local itemData = ItemDatabase and ItemDatabase:GetItem("BagOfCaltrops")
				if itemData then
					local itemDamageBonus = itemData.BaseValue + (itemData.StackValue * (stacks - 1))
					local playerDamageMultiplier = getPlayerDamageMultiplier(zone.ownerCharacter)
					zone.damagePerSecond = itemDamageBonus * playerDamageMultiplier
				end
			end
		end

		local zonePosition = zone.part.Position
		local zoneSize = zone.part.Size
		local hitThisTick = 0

		-- 🔍 ГЛУБОКИЙ ПОИСК ВСЕХ NPC
		local allNPCs = getAllNPCs(workspace, 0, CONFIG.SEARCH_DEPTH)

		if CONFIG.DEBUG_MODE and zone.tickCount == 1 then
			print("🔍 [CALTROPS] Found " .. #allNPCs .. " total NPCs in workspace")
		end

		-- ПРОВЕРЯЕМ КАЖДОГО NPC
		for _, npc in ipairs(allNPCs) do
			local humanoid = npc:FindFirstChild("Humanoid")
			local rootPart = npc:FindFirstChild("HumanoidRootPart")

			if humanoid and rootPart and humanoid.Health > 0 then
				local npcPos = rootPart.Position
				local distance = (npcPos - zonePosition).Magnitude

				-- DEBUG: показываем первые 3 тика
				if CONFIG.DEBUG_MODE and zone.tickCount <= 3 then
					print("   📍 NPC: " .. npc.Name .. " - Distance: " .. string.format("%.1f", distance) .. " studs")
				end

				-- Проверяем находится ли в зоне
				if isInZone(npcPos, zonePosition, zoneSize) then
					-- 🔥 НАНОСИМ УРОН
					local damageBefore = humanoid.Health
					humanoid:TakeDamage(zone.damagePerSecond)
					local damageAfter = humanoid.Health
					local actualDamage = damageBefore - damageAfter

					hitThisTick = hitThisTick + 1
					zone.damageCount = zone.damageCount + 1

					print("🌵 [CALTROPS HIT] " .. npc.Name .. " -" .. string.format("%.1f", actualDamage) .. " HP (Remaining: " .. string.format("%.1f", damageAfter) .. "/" .. humanoid.MaxHealth .. ")")

					-- Визуальный эффект
					if CONFIG.DEBUG_MODE then
						local hitEffect = Instance.new("Part")
						hitEffect.Size = Vector3.new(2, 2, 2)
						hitEffect.Position = npcPos + Vector3.new(0, 3, 0)
						hitEffect.Anchored = true
						hitEffect.CanCollide = false
						hitEffect.Transparency = 0.5
						hitEffect.Color = Color3.fromRGB(255, 0, 0)
						hitEffect.Material = Enum.Material.Neon
						hitEffect.Shape = Enum.PartType.Ball
						hitEffect.Parent = workspace
						Debris:AddItem(hitEffect, 0.3)
					end
				end
			end
		end

		-- ПРОВЕРЯЕМ ИГРОКОВ
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= zone.owner and player.Character then
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				local rootPart = player.Character:FindFirstChild("HumanoidRootPart")

				if humanoid and humanoid.Health > 0 and rootPart then
					local playerPos = rootPart.Position

					if isInZone(playerPos, zonePosition, zoneSize) then
						if CombatSystem and CombatSystem.ApplyDamage then
							local success = pcall(function()
								CombatSystem.ApplyDamage(player, zone.damagePerSecond, zone.owner, zonePosition)
							end)

							if success then
								hitThisTick = hitThisTick + 1
								zone.damageCount = zone.damageCount + 1
								print("🌵 [CALTROPS HIT] " .. player.Name .. " -" .. string.format("%.1f", zone.damagePerSecond) .. " HP")
							end
						else
							humanoid:TakeDamage(zone.damagePerSecond)
							hitThisTick = hitThisTick + 1
							zone.damageCount = zone.damageCount + 1
							print("🌵 [CALTROPS HIT] " .. player.Name .. " -" .. string.format("%.1f", zone.damagePerSecond) .. " HP (fallback)")
						end
					end
				end
			end
		end

		-- Debug: сообщаем если никто не был задет
		if CONFIG.DEBUG_MODE and hitThisTick == 0 then
			print("🌵 [CALTROPS] Tick #" .. zone.tickCount .. " - no targets hit (found " .. #allNPCs .. " NPCs)")
		elseif hitThisTick > 0 then
			print("🌵 [CALTROPS] Tick #" .. zone.tickCount .. " - hit " .. hitThisTick .. " targets")
		end
	end
end)

-- ========================
-- ИНТЕГРАЦИЯ
-- ========================
local function setupPhantomIntegration()
	local remote = ReplicatedStorage:FindFirstChild("PhantomShadowStep")

	if not remote then
		warn("⚠️ [CALTROPS] PhantomShadowStep RemoteEvent not found!")
		return
	end

	print("✅ [CALTROPS] Hooked into PhantomShadowStep")

	remote.OnServerEvent:Connect(function(player, action, data)
		if action == "dash" then
			local character = player.Character
			if character then
				local stacks = getItemStacks(character, "BagOfCaltrops")

				if stacks > 0 then
					local startPos = data.startPos
					createCaltropZone(startPos, player)
				end
			end
		end
	end)
end

local function setupUniversalQAbility()
	local qRemote = ReplicatedStorage:FindFirstChild("QAbilityUsed")

	if not qRemote then
		qRemote = Instance.new("RemoteEvent")
		qRemote.Name = "QAbilityUsed"
		qRemote.Parent = ReplicatedStorage
		print("✅ [CALTROPS] Created QAbilityUsed RemoteEvent")
	end

	qRemote.OnServerEvent:Connect(function(player, position)
		local character = player.Character
		if character then
			local stacks = getItemStacks(character, "BagOfCaltrops")

			if stacks > 0 then
				createCaltropZone(position, player)
			end
		end
	end)
end

-- ========================
-- ИНИЦИАЛИЗАЦИЯ
-- ========================
task.spawn(function()
	wait(3)

	setupPhantomIntegration()
	setupUniversalQAbility()

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("✅ [BAG OF CALTROPS] DEEP SEARCH ENABLED!")
	print("   Base damage: " .. CONFIG.BASE_DAMAGE .. "/sec")
	print("   Zone size: " .. CONFIG.ZONE_SIZE .. "x" .. CONFIG.ZONE_SIZE .. " studs")
	print("   Duration: " .. CONFIG.ZONE_DURATION .. " seconds")
	print("   Damage tick: every " .. CONFIG.DAMAGE_TICK_RATE .. " second")
	print("   🔍 Search depth: " .. CONFIG.SEARCH_DEPTH .. " levels")
	print("   🔥 Scales with player damage stat!")
	print("   🔴 DEBUG MODE: " .. tostring(CONFIG.DEBUG_MODE))
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end)

-- ========================
-- DEBUG КОМАНДЫ
-- ========================
_G.GetCaltropZones = function()
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🌵 [CALTROPS] Active Zones: " .. #activeZones)
	for i, zone in ipairs(activeZones) do
		print("   Zone " .. i .. ":")
		print("      Owner: " .. zone.owner.Name)
		print("      Damage: " .. string.format("%.1f", zone.damagePerSecond) .. "/sec")
		print("      Time left: " .. string.format("%.1f", zone.endTime - tick()) .. "s")
		print("      Hits: " .. zone.damageCount .. " (ticks: " .. zone.tickCount .. ")")
	end
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

_G.CaltropsDebug = function(enabled)
	CONFIG.DEBUG_MODE = enabled
	print("🌵 [CALTROPS] Debug mode: " .. tostring(enabled))
end

_G.ListAllNPCs = function()
	local allNPCs = getAllNPCs(workspace, 0, CONFIG.SEARCH_DEPTH)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🔍 [CALTROPS] Total NPCs found: " .. #allNPCs)
	for i, npc in ipairs(allNPCs) do
		local humanoid = npc:FindFirstChild("Humanoid")
		local rootPart = npc:FindFirstChild("HumanoidRootPart")
		print("   " .. i .. ". " .. npc.Name .. " - HP: " .. (humanoid and humanoid.Health or "N/A") .. " - Pos: " .. (rootPart and tostring(rootPart.Position) or "N/A"))
	end
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end
