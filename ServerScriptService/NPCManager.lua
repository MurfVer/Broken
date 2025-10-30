-- =====================================
-- NPC MANAGER - CENTRALIZED AI SYSTEM
-- Supports 400+ NPCs without lag
-- Batch processing and adaptive optimization
-- Place in ServerScriptService
-- =====================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🤖 [NPC MANAGER] Loading...")

-- ========================
-- КОНФИГУРАЦИЯ
-- ========================
local CONFIG = {
	DEBUG_MODE = true,

	-- Производительность
	BATCH_SIZE = 50, -- NPCs обрабатываемых за раз
	UPDATE_INTERVAL = 0.1, -- Секунд между обновлениями
	FPS_TARGET = 30, -- Целевой FPS
	AUTO_OPTIMIZE = true, -- Автоматическая оптимизация

	-- AI параметры
	DETECTION_RANGE = 100, -- Дальность обнаружения игроков
	ATTACK_RANGE_MELEE = 5, -- Дальность атаки ближнего боя
	ATTACK_RANGE_RANGED = 80, -- Дальность атаки дальнего боя
	ATTACK_COOLDOWN = 1.5, -- Секунд между атаками

	-- Движение
	MOVE_SPEED = 16, -- Скорость передвижения
	JUMP_POWER = 50, -- Сила прыжка
	JUMP_CHECK_DISTANCE = 5, -- Дистанция проверки препятствий
	STUCK_CHECK_TIME = 3, -- Секунд до проверки застревания

	-- Ranged AI
	PROJECTILE_SPEED = 100, -- Скорость снаряда
	PROJECTILE_DAMAGE = 10, -- Урон снаряда
	PROJECTILE_SIZE = Vector3.new(1, 1, 1),
	PROJECTILE_LIFETIME = 5, -- Секунд до удаления снаряда
	CHARGING_RADIUS = 150, -- Радиус зарядки портала
	MAX_PROJECTILES = 200, -- Максимум снарядов
}

-- ========================
-- ХРАНИЛИЩЕ ДАННЫХ
-- ========================
local NPCManager = {
	registeredNPCs = {}, -- {npcData, ...}
	currentBatch = 1,
	totalNPCs = 0,
	projectilePool = {}, -- Пул снарядов для переиспользования
	activeProjectiles = 0,
}

local CombatSystem = nil
local DOTSystem = nil

-- ========================
-- ЗАГРУЗКА СИСТЕМ
-- ========================
local function loadSystems()
	task.wait(2)

	-- CombatSystem
	local combatModule = ReplicatedStorage:FindFirstChild("CombatSystem")
	if combatModule and combatModule:IsA("ModuleScript") then
		local success, result = pcall(function()
			return require(combatModule)
		end)
		if success then
			CombatSystem = result
			print("✅ [NPC MANAGER] CombatSystem loaded!")
		else
			warn("⚠️ [NPC MANAGER] Failed to load CombatSystem: " .. tostring(result))
		end
	end

	-- DOTSystem
	local dotModule = script.Parent:FindFirstChild("DOTSystem")
	if dotModule and dotModule:IsA("ModuleScript") then
		local success, result = pcall(function()
			return require(dotModule)
		end)
		if success then
			DOTSystem = result
			print("✅ [NPC MANAGER] DOTSystem loaded!")
		else
			warn("⚠️ [NPC MANAGER] Failed to load DOTSystem: " .. tostring(result))
		end
	end
end

task.spawn(loadSystems)

-- ========================
-- РЕГИСТРАЦИЯ NPC
-- ========================
function NPCManager:Register(npc, aiType, settings)
	if not npc or not npc:FindFirstChildOfClass("Humanoid") then
		warn("⚠️ [NPC MANAGER] Invalid NPC!")
		return
	end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local rootPart = npc:FindFirstChild("HumanoidRootPart")

	if not rootPart then
		warn("⚠️ [NPC MANAGER] NPC missing HumanoidRootPart!")
		return
	end

	local npcData = {
		npc = npc,
		humanoid = humanoid,
		rootPart = rootPart,
		aiType = aiType or "melee",
		settings = settings or {},

		-- Состояние
		currentTarget = nil,
		lastAttackTime = 0,
		lastPosition = rootPart.Position,
		stuckTime = 0,
		isCharging = false,

		-- Настройки
		attackRange = aiType == "ranged" and CONFIG.ATTACK_RANGE_RANGED or CONFIG.ATTACK_RANGE_MELEE,
		attackCooldown = settings.attackCooldown or CONFIG.ATTACK_COOLDOWN,
		damage = npc:GetAttribute("Damage") or CONFIG.PROJECTILE_DAMAGE,
	}

	table.insert(self.registeredNPCs, npcData)
	self.totalNPCs = #self.registeredNPCs

	-- Очистка при смерти
	humanoid.Died:Connect(function()
		self:Unregister(npc)
	end)

	if CONFIG.DEBUG_MODE then
		print("🤖 [NPC MANAGER] Registered " .. npc.Name .. " (" .. aiType .. ") - Total: " .. self.totalNPCs)
	end
end

-- ========================
-- ОТМЕНА РЕГИСТРАЦИИ
-- ========================
function NPCManager:Unregister(npc)
	for i, npcData in ipairs(self.registeredNPCs) do
		if npcData.npc == npc then
			table.remove(self.registeredNPCs, i)
			self.totalNPCs = #self.registeredNPCs
			return
		end
	end
end

-- ========================
-- НАЙТИ БЛИЖАЙШУЮ ЦЕЛЬ
-- ========================
local function findNearestTarget(npcData)
	local nearestPlayer = nil
	local nearestDistance = CONFIG.DETECTION_RANGE

	local playerCount = 0
	for _, player in ipairs(Players:GetPlayers()) do
		playerCount = playerCount + 1
		if player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			local rootPart = player.Character:FindFirstChild("HumanoidRootPart")

			if humanoid and humanoid.Health > 0 and rootPart then
				local distance = (npcData.rootPart.Position - rootPart.Position).Magnitude

				if distance < nearestDistance then
					nearestPlayer = player
					nearestDistance = distance
				end
			end
		end
	end

	if CONFIG.DEBUG_MODE and playerCount == 0 then
		warn("⚠️ [NPC MANAGER] No players found in game!")
	end

	return nearestPlayer
end

-- ========================
-- ПРОВЕРКА ПРЕПЯТСТВИЯ
-- ========================
local function checkObstacle(npcData, targetPosition)
	local direction = (targetPosition - npcData.rootPart.Position).Unit
	local rayOrigin = npcData.rootPart.Position
	local rayDirection = direction * CONFIG.JUMP_CHECK_DISTANCE

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {npcData.npc}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if rayResult and rayResult.Instance then
		-- Проверка высоты препятствия
		local obstacleTop = rayResult.Instance.Position.Y + rayResult.Instance.Size.Y / 2
		local npcBottom = npcData.rootPart.Position.Y - (npcData.rootPart.Size.Y / 2)

		if obstacleTop - npcBottom < 5 then
			return true -- Можно перепрыгнуть
		end
	end

	return false
end

-- ========================
-- ПРОВЕРКА ЗАСТРЕВАНИЯ
-- ========================
local function checkIfStuck(npcData)
	local currentPosition = npcData.rootPart.Position
	local distance = (currentPosition - npcData.lastPosition).Magnitude

	if distance < 1 then
		npcData.stuckTime = npcData.stuckTime + CONFIG.UPDATE_INTERVAL
	else
		npcData.stuckTime = 0
	end

	npcData.lastPosition = currentPosition

	return npcData.stuckTime >= CONFIG.STUCK_CHECK_TIME
end

-- ========================
-- ОБНОВЛЕНИЕ MELEE AI
-- ========================
function NPCManager:UpdateMelee(npcData)
	if npcData.humanoid.Health <= 0 then return end

	if CONFIG.DEBUG_MODE then
		print("⚔️ [NPC MANAGER] UpdateMelee called for: " .. npcData.npc.Name)
	end

	local target = findNearestTarget(npcData)

	if not target or not target.Character then
		npcData.currentTarget = nil
		npcData.humanoid.WalkSpeed = 0
		return
	end

	npcData.currentTarget = target
	local targetRootPart = target.Character:FindFirstChild("HumanoidRootPart")
	if not targetRootPart then return end

	local distance = (npcData.rootPart.Position - targetRootPart.Position).Magnitude

	-- Движение к цели
	npcData.humanoid.WalkSpeed = CONFIG.MOVE_SPEED
	npcData.humanoid:MoveTo(targetRootPart.Position)

	-- Проверка препятствий
	if checkObstacle(npcData, targetRootPart.Position) then
		npcData.humanoid.Jump = true
	end

	-- Проверка застревания
	if checkIfStuck(npcData) then
		npcData.humanoid.Jump = true
		npcData.stuckTime = 0
	end

	-- Атака
	if distance <= npcData.attackRange then
		local currentTime = tick()
		if currentTime - npcData.lastAttackTime >= npcData.attackCooldown then
			npcData.lastAttackTime = currentTime

			if CombatSystem and CombatSystem.ApplyDamage then
				CombatSystem.ApplyDamage(
					target,
					npcData.damage,
					nil,
					npcData.rootPart.Position
				)

				if CONFIG.DEBUG_MODE then
					print("⚔️ [NPC MANAGER] " .. npcData.npc.Name .. " attacked " .. target.Name)
				end
			end
		end
	end
end

-- ========================
-- ПОЛУЧИТЬ СНАРЯД ИЗ ПУЛА
-- ========================
function NPCManager:GetProjectile()
	-- Проверяем пул
	for i, projectile in ipairs(self.projectilePool) do
		if projectile and projectile.Parent == nil then
			table.remove(self.projectilePool, i)
			return projectile
		end
	end

	-- Создаём новый если не достигли лимита
	if self.activeProjectiles < CONFIG.MAX_PROJECTILES then
		local projectile = Instance.new("Part")
		projectile.Size = CONFIG.PROJECTILE_SIZE
		projectile.Shape = Enum.PartType.Ball
		projectile.Material = Enum.Material.Neon
		projectile.Color = Color3.fromRGB(255, 0, 0)
		projectile.CanCollide = false
		projectile.Anchored = false
		projectile.CastShadow = false

		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.MaxForce = Vector3.new(1, 1, 1) * 10000
		bodyVelocity.Parent = projectile

		return projectile
	end

	return nil
end

-- ========================
-- ВЫСТРЕЛ СНАРЯДОМ
-- ========================
function NPCManager:FireProjectile(npcData, target)
	local projectile = self:GetProjectile()
	if not projectile then return end

	local targetRootPart = target.Character:FindFirstChild("HumanoidRootPart")
	if not targetRootPart then return end

	-- Позиция спавна снаряда
	local startPosition = npcData.rootPart.Position + Vector3.new(0, 2, 0)
	projectile.Position = startPosition

	-- Направление с предсказанием
	local targetVelocity = targetRootPart.AssemblyLinearVelocity
	local timeToTarget = (targetRootPart.Position - startPosition).Magnitude / CONFIG.PROJECTILE_SPEED
	local predictedPosition = targetRootPart.Position + (targetVelocity * timeToTarget)

	local direction = (predictedPosition - startPosition).Unit
	local bodyVelocity = projectile:FindFirstChildOfClass("BodyVelocity")
	if bodyVelocity then
		bodyVelocity.Velocity = direction * CONFIG.PROJECTILE_SPEED
	end

	projectile.Parent = Workspace
	self.activeProjectiles = self.activeProjectiles + 1

	-- Обработка столкновения
	local touchConnection
	touchConnection = projectile.Touched:Connect(function(hit)
		if hit.Parent and hit.Parent ~= npcData.npc then
			local hitPlayer = Players:GetPlayerFromCharacter(hit.Parent)

			if hitPlayer then
				-- Урон игроку
				if CombatSystem and CombatSystem.ApplyDamage then
					CombatSystem.ApplyDamage(
						hitPlayer,
						npcData.damage,
						nil,
						projectile.Position
					)
				end

				-- Удаляем снаряд
				if touchConnection then touchConnection:Disconnect() end
				projectile.Parent = nil
				table.insert(self.projectilePool, projectile)
				self.activeProjectiles = math.max(0, self.activeProjectiles - 1)
			end
		end
	end)

	-- Автоудаление
	task.delay(CONFIG.PROJECTILE_LIFETIME, function()
		if projectile.Parent then
			if touchConnection then touchConnection:Disconnect() end
			projectile.Parent = nil
			table.insert(self.projectilePool, projectile)
			self.activeProjectiles = math.max(0, self.activeProjectiles - 1)
		end
	end)
end

-- ========================
-- ОБНОВЛЕНИЕ RANGED AI
-- ========================
function NPCManager:UpdateRanged(npcData)
	if npcData.humanoid.Health <= 0 then return end

	-- Проверка зарядки портала
	local portal = Workspace:FindFirstChild("Portal")
	if portal then
		local portalPart = portal:FindFirstChild("PortalPart")
		if portalPart and portalPart:GetAttribute("IsCharging") then
			local distance = (npcData.rootPart.Position - portalPart.Position).Magnitude

			if distance <= CONFIG.CHARGING_RADIUS then
				npcData.isCharging = true
				npcData.humanoid.WalkSpeed = 0
				return
			end
		end
	end

	npcData.isCharging = false

	local target = findNearestTarget(npcData)

	if not target or not target.Character then
		npcData.currentTarget = nil
		npcData.humanoid.WalkSpeed = 0
		return
	end

	npcData.currentTarget = target
	local targetRootPart = target.Character:FindFirstChild("HumanoidRootPart")
	if not targetRootPart then return end

	local distance = (npcData.rootPart.Position - targetRootPart.Position).Magnitude

	-- Держим дистанцию (60% от макс дальности)
	local idealDistance = npcData.attackRange * 0.6

	if distance > npcData.attackRange then
		-- Слишком далеко - приближаемся
		npcData.humanoid.WalkSpeed = CONFIG.MOVE_SPEED
		npcData.humanoid:MoveTo(targetRootPart.Position)
	elseif distance < idealDistance then
		-- Слишком близко - отступаем
		local retreatPosition = npcData.rootPart.Position + (npcData.rootPart.Position - targetRootPart.Position).Unit * 10
		npcData.humanoid.WalkSpeed = CONFIG.MOVE_SPEED * 0.7
		npcData.humanoid:MoveTo(retreatPosition)
	else
		-- Идеальная дистанция - стоим на месте
		npcData.humanoid.WalkSpeed = 0
	end

	-- Стрельба
	if distance <= npcData.attackRange then
		local currentTime = tick()
		if currentTime - npcData.lastAttackTime >= npcData.attackCooldown then
			npcData.lastAttackTime = currentTime
			self:FireProjectile(npcData, target)

			if CONFIG.DEBUG_MODE then
				print("🏹 [NPC MANAGER] " .. npcData.npc.Name .. " fired at " .. target.Name)
			end
		end
	end
end

-- ========================
-- ОСНОВНОЙ ЦИКЛ
-- ========================
local function mainLoop()
	local loopCount = 0
	while true do
		loopCount = loopCount + 1
		local startTime = tick()
		local npcsToProcess = math.min(CONFIG.BATCH_SIZE, NPCManager.totalNPCs)

		-- Debug: каждые 50 итераций выводим статус
		if CONFIG.DEBUG_MODE and loopCount % 50 == 0 then
			print("🔄 [NPC MANAGER] Loop #" .. loopCount .. " - Total NPCs: " .. NPCManager.totalNPCs .. ", Processing: " .. npcsToProcess)
		end

		for i = 1, npcsToProcess do
			local index = ((NPCManager.currentBatch - 1) * CONFIG.BATCH_SIZE + i)
			if index > NPCManager.totalNPCs then break end

			local npcData = NPCManager.registeredNPCs[index]

			if npcData and npcData.npc and npcData.npc.Parent and npcData.humanoid.Health > 0 then
				if npcData.aiType == "melee" then
					NPCManager:UpdateMelee(npcData)
				elseif npcData.aiType == "ranged" then
					NPCManager:UpdateRanged(npcData)
				end
			end
		end

		-- Переход к следующему батчу
		NPCManager.currentBatch = NPCManager.currentBatch + 1
		if NPCManager.currentBatch > math.ceil(NPCManager.totalNPCs / CONFIG.BATCH_SIZE) then
			NPCManager.currentBatch = 1
		end

		-- Автооптимизация
		if CONFIG.AUTO_OPTIMIZE then
			local elapsedTime = tick() - startTime
			local fps = 1 / elapsedTime

			if fps < CONFIG.FPS_TARGET and CONFIG.BATCH_SIZE > 10 then
				CONFIG.BATCH_SIZE = CONFIG.BATCH_SIZE - 5
				print("⚠️ [NPC MANAGER] Reduced batch size to " .. CONFIG.BATCH_SIZE)
			elseif fps > CONFIG.FPS_TARGET * 1.5 and CONFIG.BATCH_SIZE < 100 then
				CONFIG.BATCH_SIZE = CONFIG.BATCH_SIZE + 5
				print("✅ [NPC MANAGER] Increased batch size to " .. CONFIG.BATCH_SIZE)
			end
		end

		task.wait(CONFIG.UPDATE_INTERVAL)
	end
end

-- ========================
-- КОМАНДЫ УПРАВЛЕНИЯ
-- ========================
_G.NPCStats = function()
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🤖 [NPC MANAGER] Statistics:")
	print("   Total NPCs: " .. NPCManager.totalNPCs)
	print("   Batch size: " .. CONFIG.BATCH_SIZE)
	print("   Active projectiles: " .. NPCManager.activeProjectiles)
	print("   Pooled projectiles: " .. #NPCManager.projectilePool)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

-- ========================
-- ИНИЦИАЛИЗАЦИЯ
-- ========================
print("✅ [NPC MANAGER] Loaded!")
print("   Batch size: " .. CONFIG.BATCH_SIZE)
print("   Update interval: " .. CONFIG.UPDATE_INTERVAL .. "s")
print("   Auto-optimize: " .. tostring(CONFIG.AUTO_OPTIMIZE))
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Запуск основного цикла
task.spawn(mainLoop)

return NPCManager
