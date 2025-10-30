-- =====================================
-- NPC CACHE MANAGER - ЦЕНТРАЛИЗОВАННЫЙ КЕШ NPC
-- Оптимизирует поиск NPC для всех систем
-- ✅ Обновляется только при спавне/смерти
-- ✅ Пространственное хеширование
-- ✅ Region-based поиск
-- Place in ServerScriptService
-- =====================================

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🗂️ [NPC CACHE] Loading...")

-- ========================
-- КОНФИГУРАЦИЯ
-- ========================
local CONFIG = {
	DEBUG_MODE = false,
	GRID_SIZE = 50, -- Размер ячейки сетки для spatial partitioning
	CACHE_UPDATE_INTERVAL = 0.5, -- Обновление кеша раз в 0.5 сек (на всякий случай)
}

-- ========================
-- ХРАНИЛИЩЕ ДАННЫХ
-- ========================
local NPCCache = {
	-- Список всех живых NPC
	allNPCs = {}, -- {[npc] = {model, humanoid, rootPart, position, lastUpdate}}

	-- Spatial grid для быстрого поиска
	spatialGrid = {}, -- {["x_z"] = {npc1, npc2, ...}}

	-- Статистика
	totalNPCs = 0,
	lastFullUpdate = 0,
}

-- ========================
-- ПОЛУЧИТЬ КЛЮЧ ЯЧЕЙКИ СЕТКИ
-- ========================
local function getGridKey(position)
	local gridX = math.floor(position.X / CONFIG.GRID_SIZE)
	local gridZ = math.floor(position.Z / CONFIG.GRID_SIZE)
	return gridX .. "_" .. gridZ
end

-- ========================
-- ДОБАВИТЬ NPC В КЕШ
-- ========================
function NPCCache:AddNPC(npc)
	if not npc or not npc:IsA("Model") then return end

	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	local rootPart = npc:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart then return end

	-- Проверяем что это не игрок
	local isPlayer = Players:GetPlayerFromCharacter(npc)
	if isPlayer then return end

	-- Проверяем что NPC ещё не в кеше
	if self.allNPCs[npc] then return end

	local npcData = {
		model = npc,
		humanoid = humanoid,
		rootPart = rootPart,
		position = rootPart.Position,
		lastUpdate = tick(),
		gridKey = getGridKey(rootPart.Position),
	}

	self.allNPCs[npc] = npcData
	self.totalNPCs = self.totalNPCs + 1

	-- Добавляем в spatial grid
	local gridKey = npcData.gridKey
	if not self.spatialGrid[gridKey] then
		self.spatialGrid[gridKey] = {}
	end
	table.insert(self.spatialGrid[gridKey], npc)

	-- Подписываемся на смерть
	humanoid.Died:Connect(function()
		self:RemoveNPC(npc)
	end)

	if CONFIG.DEBUG_MODE then
		print("🗂️ [NPC CACHE] Added " .. npc.Name .. " (Total: " .. self.totalNPCs .. ")")
	end
end

-- ========================
-- УДАЛИТЬ NPC ИЗ КЕША
-- ========================
function NPCCache:RemoveNPC(npc)
	local npcData = self.allNPCs[npc]
	if not npcData then return end

	-- Удаляем из spatial grid
	local gridKey = npcData.gridKey
	if self.spatialGrid[gridKey] then
		for i, cachedNPC in ipairs(self.spatialGrid[gridKey]) do
			if cachedNPC == npc then
				table.remove(self.spatialGrid[gridKey], i)
				break
			end
		end

		-- Удаляем пустую ячейку
		if #self.spatialGrid[gridKey] == 0 then
			self.spatialGrid[gridKey] = nil
		end
	end

	-- Удаляем из основного списка
	self.allNPCs[npc] = nil
	self.totalNPCs = math.max(0, self.totalNPCs - 1)

	if CONFIG.DEBUG_MODE then
		print("🗂️ [NPC CACHE] Removed " .. npc.Name .. " (Total: " .. self.totalNPCs .. ")")
	end
end

-- ========================
-- ОБНОВИТЬ ПОЗИЦИЮ NPC
-- ========================
function NPCCache:UpdateNPCPosition(npc)
	local npcData = self.allNPCs[npc]
	if not npcData then return end

	local rootPart = npcData.rootPart
	if not rootPart or not rootPart.Parent then
		self:RemoveNPC(npc)
		return
	end

	local newPosition = rootPart.Position
	local newGridKey = getGridKey(newPosition)

	-- Если NPC переместился в другую ячейку
	if newGridKey ~= npcData.gridKey then
		-- Удаляем из старой ячейки
		if self.spatialGrid[npcData.gridKey] then
			for i, cachedNPC in ipairs(self.spatialGrid[npcData.gridKey]) do
				if cachedNPC == npc then
					table.remove(self.spatialGrid[npcData.gridKey], i)
					break
				end
			end

			if #self.spatialGrid[npcData.gridKey] == 0 then
				self.spatialGrid[npcData.gridKey] = nil
			end
		end

		-- Добавляем в новую ячейку
		if not self.spatialGrid[newGridKey] then
			self.spatialGrid[newGridKey] = {}
		end
		table.insert(self.spatialGrid[newGridKey], npc)

		npcData.gridKey = newGridKey
	end

	npcData.position = newPosition
	npcData.lastUpdate = tick()
end

-- ========================
-- ПОЛУЧИТЬ NPC В РАДИУСЕ
-- ========================
function NPCCache:GetNPCsInRadius(position, radius)
	local result = {}
	local radiusSquared = radius * radius

	-- Определяем какие ячейки нужно проверить
	local gridRadius = math.ceil(radius / CONFIG.GRID_SIZE)
	local centerGridX = math.floor(position.X / CONFIG.GRID_SIZE)
	local centerGridZ = math.floor(position.Z / CONFIG.GRID_SIZE)

	-- Проверяем только ближайшие ячейки
	for gridX = centerGridX - gridRadius, centerGridX + gridRadius do
		for gridZ = centerGridZ - gridRadius, centerGridZ + gridRadius do
			local gridKey = gridX .. "_" .. gridZ
			local npcsInCell = self.spatialGrid[gridKey]

			if npcsInCell then
				for _, npc in ipairs(npcsInCell) do
					local npcData = self.allNPCs[npc]
					if npcData and npcData.humanoid.Health > 0 then
						-- Используем Magnitude² для производительности
						local dx = npcData.position.X - position.X
						local dy = npcData.position.Y - position.Y
						local dz = npcData.position.Z - position.Z
						local distanceSquared = dx*dx + dy*dy + dz*dz

						if distanceSquared <= radiusSquared then
							table.insert(result, {
								model = npcData.model,
								humanoid = npcData.humanoid,
								rootPart = npcData.rootPart,
								position = npcData.position,
								distanceSquared = distanceSquared,
								distance = math.sqrt(distanceSquared),
							})
						end
					end
				end
			end
		end
	end

	-- Сортируем по дистанции (ближайшие первые)
	table.sort(result, function(a, b)
		return a.distanceSquared < b.distanceSquared
	end)

	return result
end

-- ========================
-- ПОЛУЧИТЬ ВСЕХ NPC
-- ========================
function NPCCache:GetAllNPCs()
	local result = {}
	for npc, npcData in pairs(self.allNPCs) do
		if npcData.humanoid.Health > 0 then
			table.insert(result, {
				model = npcData.model,
				humanoid = npcData.humanoid,
				rootPart = npcData.rootPart,
				position = npcData.position,
			})
		end
	end
	return result
end

-- ========================
-- ПОЛНОЕ ОБНОВЛЕНИЕ КЕША
-- ========================
function NPCCache:FullUpdate()
	local currentTime = tick()

	-- Проверяем всех NPC на валидность
	local toRemove = {}
	for npc, npcData in pairs(self.allNPCs) do
		if not npc.Parent or not npcData.rootPart.Parent or npcData.humanoid.Health <= 0 then
			table.insert(toRemove, npc)
		else
			self:UpdateNPCPosition(npc)
		end
	end

	-- Удаляем невалидных
	for _, npc in ipairs(toRemove) do
		self:RemoveNPC(npc)
	end

	self.lastFullUpdate = currentTime

	if CONFIG.DEBUG_MODE then
		print("🗂️ [NPC CACHE] Full update complete - " .. self.totalNPCs .. " NPCs")
	end
end

-- ========================
-- СКАНИРОВАТЬ WORKSPACE
-- ========================
function NPCCache:ScanWorkspace()
	local function scanDescendants(parent)
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") and child:FindFirstChild("HumanoidRootPart") then
				self:AddNPC(child)
			end

			-- Рекурсивно проверяем папки
			if child:IsA("Folder") or child:IsA("Model") then
				scanDescendants(child)
			end
		end
	end

	scanDescendants(workspace)
	print("🗂️ [NPC CACHE] Workspace scan complete - Found " .. self.totalNPCs .. " NPCs")
end

-- ========================
-- АВТОМАТИЧЕСКОЕ ОТСЛЕЖИВАНИЕ
-- ========================
function NPCCache:StartAutoTracking()
	-- Отслеживаем новых NPC через DescendantAdded
	workspace.DescendantAdded:Connect(function(descendant)
		task.wait(0.1) -- Даём время на загрузку

		if descendant:IsA("Model") then
			local humanoid = descendant:FindFirstChildOfClass("Humanoid")
			if humanoid and descendant:FindFirstChild("HumanoidRootPart") then
				self:AddNPC(descendant)
			end
		end
	end)

	-- Периодическое обновление позиций
	task.spawn(function()
		while true do
			task.wait(CONFIG.CACHE_UPDATE_INTERVAL)
			self:FullUpdate()
		end
	end)

	print("✅ [NPC CACHE] Auto-tracking started!")
end

-- ========================
-- СТАТИСТИКА
-- ========================
function NPCCache:GetStats()
	local gridCells = 0
	local npcsPerCell = {}

	for _, npcs in pairs(self.spatialGrid) do
		gridCells = gridCells + 1
		table.insert(npcsPerCell, #npcs)
	end

	table.sort(npcsPerCell)
	local medianNPCs = #npcsPerCell > 0 and npcsPerCell[math.ceil(#npcsPerCell / 2)] or 0

	return {
		totalNPCs = self.totalNPCs,
		gridCells = gridCells,
		medianNPCsPerCell = medianNPCs,
		gridSize = CONFIG.GRID_SIZE,
	}
end

-- ========================
-- DEBUG КОМАНДЫ
-- ========================
_G.NPCCacheStats = function()
	local stats = NPCCache:GetStats()
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🗂️ [NPC CACHE] Statistics:")
	print("   Total NPCs: " .. stats.totalNPCs)
	print("   Grid cells: " .. stats.gridCells)
	print("   Grid size: " .. stats.gridSize .. " studs")
	print("   Median NPCs/cell: " .. stats.medianNPCsPerCell)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

_G.NPCCacheRadius = function(playerName, radius)
	local player = Players:FindFirstChild(playerName)
	if not player or not player.Character then
		print("❌ Player not found!")
		return
	end

	local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	radius = radius or 50
	local startTime = tick()
	local npcs = NPCCache:GetNPCsInRadius(rootPart.Position, radius)
	local elapsedTime = (tick() - startTime) * 1000

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🗂️ [NPC CACHE] Search in " .. radius .. " studs:")
	print("   Found: " .. #npcs .. " NPCs")
	print("   Time: " .. string.format("%.2f", elapsedTime) .. " ms")

	for i = 1, math.min(10, #npcs) do
		local npc = npcs[i]
		print("   " .. i .. ". " .. npc.model.Name .. " - " .. string.format("%.1f", npc.distance) .. " studs")
	end
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

_G.NPCCacheDebug = function(enabled)
	CONFIG.DEBUG_MODE = enabled
	print("🗂️ [NPC CACHE] Debug mode: " .. tostring(enabled))
end

_G.NPCCacheRescan = function()
	print("🗂️ [NPC CACHE] Rescanning workspace...")
	NPCCache.allNPCs = {}
	NPCCache.spatialGrid = {}
	NPCCache.totalNPCs = 0
	NPCCache:ScanWorkspace()
end

-- ========================
-- ИНИЦИАЛИЗАЦИЯ
-- ========================
task.spawn(function()
	-- Первичное сканирование
	NPCCache:ScanWorkspace()

	-- Запускаем автоматическое отслеживание
	NPCCache:StartAutoTracking()

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("✅ [NPC CACHE MANAGER] Loaded!")
	print("   Grid size: " .. CONFIG.GRID_SIZE .. " studs")
	print("   Update interval: " .. CONFIG.CACHE_UPDATE_INTERVAL .. "s")
	print("   Total NPCs: " .. NPCCache.totalNPCs)
	print("   🔴 DEBUG MODE: " .. tostring(CONFIG.DEBUG_MODE))
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end)

return NPCCache
