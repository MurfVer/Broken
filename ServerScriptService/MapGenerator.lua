-- Скрипт процедурной генерации карты для Roblox
-- Версия 2.1 с системой уникальных структур (Portal)
-- Размер блоков 32x32, карта 200x200
-- Поместить в ServerScriptService

warn("СКРИПТ ГЕНЕРАЦИИ КАРТЫ V2.1 ЗАПУЩЕН!")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- ========================
-- НАСТРОЙКИ ГЕНЕРАЦИИ
-- ========================
local CONFIG = {
	-- Размеры карты и блоков
	MAP_RADIUS = 40,          -- Радиус карты в блоках (диаметр 150 блоков)
	BLOCK_SIZE = 32,          -- Размер одного блока в studs (32x32!)

	-- Высоты
	START_HEIGHT = 10,         -- Начальная высота в центре (ground_10)
	MIN_HEIGHT = 1,            -- Минимальная высота блока
	MAX_HEIGHT = 20,           -- Максимальная высота блока

	-- Генерация рельефа
	SMOOTH_FACTOR = 0.6,      -- Плавность переходов
	NOISE_SCALE = 0.1,        -- Масштаб шума (уменьшен для больших блоков)
	NOISE_STRENGTH = 5,        -- Сила влияния шума
	MAX_HEIGHT_DIFF = 1,       -- Максимальная разница высот между соседями

	-- Горы и долины для большой карты
	MOUNTAIN_COUNT = 1,        -- Количество гор
	MOUNTAIN_HEIGHT = 7,       -- Дополнительная высота гор
	MOUNTAIN_SIZE = 12,        -- Радиус горы в блоках (уменьшен для 32x32)
	VALLEY_COUNT = 1,          -- Количество долин
	VALLEY_DEPTH = 5,          -- Глубина долин
	VALLEY_SIZE = 4,           -- Радиус долины в блоках (уменьшен для 32x32)

	-- Выравнивание блоков
	ALIGN_TO_BOTTOM = true,    -- Блоки стоят на полу (Y=0 - нижняя грань)

	-- СИСТЕМА СТРУКТУР
	GLOBAL_STRUCTURE_CHANCE = 0.75,  -- Глобальный шанс появления структуры
	MIN_STRUCTURE_DISTANCE = 1.5,    -- Минимальное расстояние между структурами в блоках (уменьшено)
	STRUCTURE_MIN_SCALE = 0.8,       -- Минимальный масштаб структур (увеличен для больших блоков)
	STRUCTURE_MAX_SCALE = 3,         -- Максимальный масштаб структур (увеличен для больших блоков)

	-- НАСТРОЙКИ ДЛЯ КАМЕННОЙ ГРАНИЦЫ
	EDGE_STONE_MIN_SCALE = 5,   -- Минимальный масштаб камней на краю (увеличен)
	EDGE_STONE_MAX_SCALE = 15,  -- Максимальный масштаб камней на краю (увеличен)
	EDGE_STONE_CHANCE = 1,    -- Шанс появления камня на краю (80%)
	EDGE_THRESHOLD = 0.92,      -- Порог расстояния от центра для края (95% радиуса)

	-- ЗНАЧЕНИЯ ПО УМОЛЧАНИЮ ДЛЯ АТРИБУТОВ
	DEFAULT_SPAWN_CHANCE = 10,  -- 10% если атрибут отсутствует
	DEFAULT_MIN_HEIGHT = 1,     -- может появиться везде
	DEFAULT_MAX_HEIGHT = 20,    -- может появиться везде
	DEFAULT_SPAWN_WEIGHT = 1,   -- равный приоритет

	-- НОВЫЕ НАСТРОЙКИ ДЛЯ УНИКАЛЬНЫХ СТРУКТУР
	UNIQUE_STRUCTURE_MIN_HEIGHT = 8,    -- Минимальная высота для уникальных структур
	UNIQUE_STRUCTURE_MAX_HEIGHT = 15,   -- Максимальная высота для уникальных структур
	UNIQUE_STRUCTURE_MIN_DISTANCE_FROM_CENTER = 10,  -- Минимальное расстояние от центра
	UNIQUE_STRUCTURE_MAX_DISTANCE_FROM_CENTER = 30,  -- Максимальное расстояние от центра
	UNIQUE_STRUCTURE_SCALE = 1,       -- Масштаб уникальных структур
}

-- ========================
-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
-- ========================
local generatedMap = {}
local groundsFolder = nil
local mapFolder = nil
local mountainCenters = {}
local valleyCenters = {}
local structuresFolder = nil
local placedStructures = {}

-- НОВЫЕ ПЕРЕМЕННЫЕ ДЛЯ УНИКАЛЬНЫХ СТРУКТУР
local portalModel = nil
local portalPlaced = false
local portalCandidates = {}  -- Список подходящих мест для Portal

-- База данных структур
local StructureDatabase = {}  -- [height] = {структуры для этой высоты}
local AllStructures = {}      -- Все структуры для статистики

-- Рандомизация шума Перлина
local rng = nil
local NOISE = { ox = 0, oz = 0, ot1 = 0, ot2 = 0, ot3 = 0 }

local function initNoise()
	rng = Random.new()
	NOISE.ox = rng:NextNumber(-1e6, 1e6)
	NOISE.oz = rng:NextNumber(-1e6, 1e6)
	NOISE.ot1 = rng:NextNumber(-1e6, 1e6)
	NOISE.ot2 = rng:NextNumber(-1e6, 1e6)
	NOISE.ot3 = rng:NextNumber(-1e6, 1e6)
end

-- ========================
-- БАЗОВЫЕ ФУНКЦИИ
-- ========================

local function getGroundsFolder()
	local folder = ReplicatedStorage:WaitForChild("Grounds", 5)
	if not folder then
		error("Папка 'Grounds' не найдена в ReplicatedStorage!")
	end
	return folder
end

local function getStructuresFolder()
	local folder = ReplicatedStorage:FindFirstChild("RandomStructures")
	if not folder then
		warn("Папка 'RandomStructures' не найдена в ReplicatedStorage! Структуры не будут размещены.")
		return nil
	end

	local structureCount = 0
	for _, child in pairs(folder:GetChildren()) do
		if child:IsA("Model") or child:IsA("BasePart") then
			structureCount = structureCount + 1
		end
	end

	if structureCount > 0 then
		warn("Папка RandomStructures найдена! Обнаружено структур: " .. structureCount)
	else
		warn("Папка RandomStructures найдена, но не содержит моделей!")
		return nil
	end

	return folder
end

-- НОВАЯ ФУНКЦИЯ ДЛЯ ПОИСКА PORTAL
local function getPortalModel()
	local portal = ReplicatedStorage:FindFirstChild("Portal")
	if portal then
		warn("Portal найден в ReplicatedStorage!")
		return portal
	else
		warn("Portal не найден в ReplicatedStorage! Уникальная структура не будет размещена.")
		return nil
	end
end

local function createMapFolder()
	local folder = workspace:FindFirstChild("GeneratedMap")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "GeneratedMap"
	folder.Parent = workspace
	return folder
end

local function getGroundBlock(level)
	level = math.clamp(level, CONFIG.MIN_HEIGHT, CONFIG.MAX_HEIGHT)
	local blockName = "ground_" .. tostring(level)
	local block = groundsFolder:FindFirstChild(blockName)
	if not block then
		for i = level - 1, CONFIG.MIN_HEIGHT, -1 do
			local altBlock = groundsFolder:FindFirstChild("ground_" .. i)
			if altBlock then
				return altBlock
			end
		end
		return groundsFolder:FindFirstChild("ground_1")
	end
	return block
end

local function isInCircle(x, z)
	local distance = math.sqrt(x * x + z * z)
	return distance <= CONFIG.MAP_RADIUS
end

local function getHeightAt(x, z)
	local key = x .. "," .. z
	if generatedMap[key] then
		return generatedMap[key].height
	end
	return nil
end

-- ========================
-- НОВАЯ СИСТЕМА УНИКАЛЬНЫХ СТРУКТУР
-- ========================

-- Проверка, подходит ли место для Portal
local function isValidPortalLocation(x, z, height)
	-- Проверяем высоту
	if height < CONFIG.UNIQUE_STRUCTURE_MIN_HEIGHT or height > CONFIG.UNIQUE_STRUCTURE_MAX_HEIGHT then
		return false
	end

	-- Проверяем расстояние от центра
	local distanceFromCenter = math.sqrt(x * x + z * z)
	if distanceFromCenter < CONFIG.UNIQUE_STRUCTURE_MIN_DISTANCE_FROM_CENTER or
		distanceFromCenter > CONFIG.UNIQUE_STRUCTURE_MAX_DISTANCE_FROM_CENTER then
		return false
	end

	-- Проверяем, что не слишком близко к другим структурам
	for _, structurePos in ipairs(placedStructures) do
		local distance = math.sqrt((x - structurePos.x)^2 + (z - structurePos.z)^2)
		if distance < CONFIG.MIN_STRUCTURE_DISTANCE * 2 then -- Удвоенное расстояние для Portal
			return false
		end
	end

	-- Проверяем, что место относительно ровное (соседи не сильно отличаются по высоте)
	local neighbors = {
		{x - 1, z}, {x + 1, z}, {x, z - 1}, {x, z + 1}
	}

	for _, neighbor in ipairs(neighbors) do
		local neighborHeight = getHeightAt(neighbor[1], neighbor[2])
		if neighborHeight and math.abs(height - neighborHeight) > 2 then
			return false -- Слишком неровное место
		end
	end

	return true
end

-- Добавление кандидата для Portal
local function addPortalCandidate(x, z, height)
	if not portalPlaced and portalModel and isValidPortalLocation(x, z, height) then
		table.insert(portalCandidates, {x = x, z = z, height = height})
	end
end

-- Размещение Portal в лучшем найденном месте
local function placePortal()
	if portalPlaced or not portalModel or #portalCandidates == 0 then
		return
	end

	-- Выбираем случайного кандидата из всех подходящих мест
	local selectedCandidate = portalCandidates[math.random(1, #portalCandidates)]
	local x, z, height = selectedCandidate.x, selectedCandidate.z, selectedCandidate.height

	-- Получаем блок на этой позиции
	local key = x .. "," .. z
	local blockData = generatedMap[key]
	if not blockData then
		warn("Не удалось найти блок для размещения Portal!")
		return
	end

	local blockClone = blockData.block
	local portalClone = portalModel:Clone()

	-- Вычисляем позицию для Portal
	local worldX = x * CONFIG.BLOCK_SIZE
	local worldZ = z * CONFIG.BLOCK_SIZE
	local worldY = 0

	-- Получаем верхнюю поверхность блока
	if blockClone:IsA("BasePart") then
		worldY = blockClone.Position.Y + blockClone.Size.Y / 2
	elseif blockClone:IsA("Model") then
		local cf, size = blockClone:GetBoundingBox()
		worldY = cf.Position.Y + size.Y / 2
	end

	-- Размещаем и масштабируем Portal
	if portalClone:IsA("BasePart") then
		portalClone.Size = portalClone.Size * CONFIG.UNIQUE_STRUCTURE_SCALE
		worldY = worldY + (portalClone.Size.Y / 2)
		portalClone.Position = Vector3.new(worldX, worldY, worldZ)
		portalClone.Anchored = true
		-- Случайный поворот
		portalClone.CFrame = portalClone.CFrame * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)

	elseif portalClone:IsA("Model") then
		local cf, size = portalClone:GetBoundingBox()

		-- Масштабируем все части
		for _, part in pairs(portalClone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Size = part.Size * CONFIG.UNIQUE_STRUCTURE_SCALE
				local offset = part.Position - cf.Position
				part.Position = cf.Position + (offset * CONFIG.UNIQUE_STRUCTURE_SCALE)
				part.Anchored = true

				-- Масштабируем меши
				local mesh = part:FindFirstChildOfClass("SpecialMesh") or part:FindFirstChildOfClass("BlockMesh")
				if mesh then
					mesh.Scale = mesh.Scale * CONFIG.UNIQUE_STRUCTURE_SCALE
				end
			end
		end

		-- Позиционируем модель
		local newCf, newSize = portalClone:GetBoundingBox()
		worldY = worldY + (newSize.Y / 2)
		portalClone:PivotTo(CFrame.new(worldX, worldY, worldZ))

		-- Случайный поворот
		local randomRotation = CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
		portalClone:PivotTo(portalClone:GetPivot() * randomRotation)
	end

	portalClone.Parent = mapFolder
	portalPlaced = true

	-- Записываем в список структур
	table.insert(placedStructures, {
		x = x,
		z = z,
		name = "Portal",
		scale = CONFIG.UNIQUE_STRUCTURE_SCALE,
		height = height,
		isEdgeStone = false,
		isUnique = true
	})

	warn(string.format("Portal размещен в позиции (%d, %d) на высоте %d! Масштаб: %.1f",
		x, z, height, CONFIG.UNIQUE_STRUCTURE_SCALE))
end

-- ========================
-- СИСТЕМА СТРУКТУР (ОБНОВЛЕНА)
-- ========================

-- Инициализация базы данных структур
local function initializeStructureDatabase()
	if not structuresFolder then
		return
	end

	StructureDatabase = {}
	AllStructures = {}

	local processedCount = 0

	for _, model in pairs(structuresFolder:GetChildren()) do
		if model:IsA("Model") or model:IsA("BasePart") then
			-- Читаем атрибуты или используем значения по умолчанию
			local spawnChance = model:GetAttribute("SpawnChance") or CONFIG.DEFAULT_SPAWN_CHANCE
			local minHeight = model:GetAttribute("MinHeight") or CONFIG.DEFAULT_MIN_HEIGHT
			local maxHeight = model:GetAttribute("MaxHeight") or CONFIG.DEFAULT_MAX_HEIGHT
			local spawnWeight = model:GetAttribute("SpawnWeight") or CONFIG.DEFAULT_SPAWN_WEIGHT

			-- Валидация значений
			spawnChance = math.clamp(spawnChance, 0, 100)
			minHeight = math.clamp(minHeight, CONFIG.MIN_HEIGHT, CONFIG.MAX_HEIGHT)
			maxHeight = math.clamp(maxHeight, CONFIG.MIN_HEIGHT, CONFIG.MAX_HEIGHT)
			spawnWeight = math.max(spawnWeight, 0.1) -- Минимальный вес 0.1

			-- Если minHeight > maxHeight, меняем местами
			if minHeight > maxHeight then
				minHeight, maxHeight = maxHeight, minHeight
			end

			-- Добавляем в общий список
			local structureData = {
				model = model,
				chance = spawnChance,
				minHeight = minHeight,
				maxHeight = maxHeight,
				weight = spawnWeight,
				name = model.Name
			}
			table.insert(AllStructures, structureData)

			-- Добавляем в группы по высотам
			for height = minHeight, maxHeight do
				if not StructureDatabase[height] then
					StructureDatabase[height] = {}
				end
				table.insert(StructureDatabase[height], {
					model = model,
					chance = spawnChance,
					weight = spawnWeight,
					name = model.Name
				})
			end

			processedCount = processedCount + 1

			-- Выводим информацию о структуре
			print(string.format("Загружена структура '%s': шанс=%d%%, высоты=%d-%d, вес=%.1f",
				model.Name, spawnChance, minHeight, maxHeight, spawnWeight))
		end
	end

	warn("Инициализация структур завершена! Обработано: " .. processedCount .. " структур")

	-- Показываем статистику по высотам
	local heightStats = {}
	for height = CONFIG.MIN_HEIGHT, CONFIG.MAX_HEIGHT do
		if StructureDatabase[height] then
			heightStats[height] = #StructureDatabase[height]
		end
	end

	print("Распределение структур по высотам:")
	for height = CONFIG.MIN_HEIGHT, CONFIG.MAX_HEIGHT do
		if heightStats[height] and heightStats[height] > 0 then
			print(string.format("  Высота %d: %d структур", height, heightStats[height]))
		end
	end
end

-- Взвешенный случайный выбор
local function weightedRandomChoice(candidates)
	if #candidates == 0 then
		return nil
	end

	if #candidates == 1 then
		return candidates[1]
	end

	-- Считаем общий вес
	local totalWeight = 0
	for _, candidate in ipairs(candidates) do
		totalWeight = totalWeight + candidate.weight
	end

	if totalWeight <= 0 then
		return candidates[1]
	end

	-- Случайное число от 0 до totalWeight
	local randomValue = math.random() * totalWeight

	-- Находим выбранную структуру
	local currentWeight = 0
	for _, candidate in ipairs(candidates) do
		currentWeight = currentWeight + candidate.weight
		if randomValue <= currentWeight then
			return candidate
		end
	end

	-- На всякий случай возвращаем последнюю
	return candidates[#candidates]
end

-- Проверка минимального расстояния между структурами
local function canPlaceStructure(x, z)
	for _, structurePos in ipairs(placedStructures) do
		local distance = math.sqrt((x - structurePos.x)^2 + (z - structurePos.z)^2)
		if distance < CONFIG.MIN_STRUCTURE_DISTANCE then
			return false
		end
	end
	return true
end

-- Размещение структуры на блоке (ОБНОВЛЕНО ДЛЯ 32x32)
local function placeStructureOnBlock(x, z, blockClone, blockHeight)
	if not structuresFolder then
		return
	end

	-- Проверяем, находится ли блок на краю карты
	local distanceFromCenter = math.sqrt(x * x + z * z)
	local isEdge = distanceFromCenter >= (CONFIG.MAP_RADIUS * CONFIG.EDGE_THRESHOLD)

	-- === КРАЕВЫЕ КАМНИ ===
	if isEdge then
		if math.random() > CONFIG.EDGE_STONE_CHANCE then
			return
		end

		local clif = structuresFolder:FindFirstChild("Clif")
		if not clif then
			return
		end

		for _, structurePos in ipairs(placedStructures) do
			local distance = math.sqrt((x - structurePos.x)^2 + (z - structurePos.z)^2)
			if structurePos.isEdgeStone and distance < 1.5 then
				return
			elseif not structurePos.isEdgeStone and distance < CONFIG.MIN_STRUCTURE_DISTANCE then
				return
			end
		end

		local structureClone = clif:Clone()
		local randomScale = CONFIG.EDGE_STONE_MIN_SCALE +
			(math.random() * (CONFIG.EDGE_STONE_MAX_SCALE - CONFIG.EDGE_STONE_MIN_SCALE))

		local worldX = x * CONFIG.BLOCK_SIZE
		local worldZ = z * CONFIG.BLOCK_SIZE
		local worldY = 0

		if blockClone:IsA("BasePart") then
			worldY = blockClone.Position.Y + blockClone.Size.Y / 2
		elseif blockClone:IsA("Model") then
			local cf, size = blockClone:GetBoundingBox()
			worldY = cf.Position.Y + size.Y / 2
		end

		if structureClone:IsA("BasePart") then
			structureClone.Size = structureClone.Size * randomScale
			worldY = worldY + (structureClone.Size.Y / 2)
			structureClone.Position = Vector3.new(worldX, worldY, worldZ)
			structureClone.Anchored = true
			structureClone.CFrame = structureClone.CFrame * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
		elseif structureClone:IsA("Model") then
			local cf, size = structureClone:GetBoundingBox()

			for _, part in pairs(structureClone:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Size = part.Size * randomScale
					local offset = part.Position - cf.Position
					part.Position = cf.Position + (offset * randomScale)
					part.Anchored = true

					local mesh = part:FindFirstChildOfClass("SpecialMesh") or part:FindFirstChildOfClass("BlockMesh")
					if mesh then
						mesh.Scale = mesh.Scale * randomScale
					end
				end
			end

			local newCf, newSize = structureClone:GetBoundingBox()
			worldY = worldY + (newSize.Y / 2)
			structureClone:PivotTo(CFrame.new(worldX, worldY, worldZ))

			local randomRotation = CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
			structureClone:PivotTo(structureClone:GetPivot() * randomRotation)
		end

		structureClone.Parent = mapFolder

		table.insert(placedStructures, {
			x = x,
			z = z,
			name = clif.Name,
			scale = randomScale,
			height = blockHeight,
			isEdgeStone = true
		})

		return
	end

	-- === НОВАЯ СИСТЕМА ДЛЯ ОБЫЧНЫХ СТРУКТУР ===

	-- 1. Глобальный шанс появления структуры
	if math.random() > CONFIG.GLOBAL_STRUCTURE_CHANCE then
		return -- Пустая клетка
	end

	-- 2. Проверяем минимальное расстояние
	if not canPlaceStructure(x, z) then
		return
	end

	-- 3. Получаем структуры, подходящие для данной высоты
	local availableStructures = StructureDatabase[blockHeight]
	if not availableStructures or #availableStructures == 0 then
		return -- Нет подходящих структур
	end

	-- 4. Фильтруем по индивидуальным шансам
	local candidates = {}
	for _, structureData in ipairs(availableStructures) do
		if math.random(1, 100) <= structureData.chance then
			table.insert(candidates, structureData)
		end
	end

	if #candidates == 0 then
		return -- Ни одна структура не "выпала"
	end

	-- 5. Взвешенный выбор из кандидатов
	local selectedStructure = weightedRandomChoice(candidates)
	if not selectedStructure then
		return
	end

	-- 6. Размещаем выбранную структуру
	local structureClone = selectedStructure.model:Clone()
	local randomScale = CONFIG.STRUCTURE_MIN_SCALE +
		(math.random() * (CONFIG.STRUCTURE_MAX_SCALE - CONFIG.STRUCTURE_MIN_SCALE))

	local worldX = x * CONFIG.BLOCK_SIZE
	local worldZ = z * CONFIG.BLOCK_SIZE
	local worldY = 0

	-- Получаем верхнюю поверхность блока
	if blockClone:IsA("BasePart") then
		worldY = blockClone.Position.Y + blockClone.Size.Y / 2
	elseif blockClone:IsA("Model") then
		local cf, size = blockClone:GetBoundingBox()
		worldY = cf.Position.Y + size.Y / 2
	end

	-- Размещаем и масштабируем структуру
	if structureClone:IsA("BasePart") then
		structureClone.Size = structureClone.Size * randomScale
		worldY = worldY + (structureClone.Size.Y / 2)
		structureClone.Position = Vector3.new(worldX, worldY, worldZ)
		structureClone.Anchored = true
		structureClone.CFrame = structureClone.CFrame * CFrame.Angles(0, math.rad(math.random(0, 360)), 0)

	elseif structureClone:IsA("Model") then
		local cf, size = structureClone:GetBoundingBox()

		for _, part in pairs(structureClone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Size = part.Size * randomScale
				local offset = part.Position - cf.Position
				part.Position = cf.Position + (offset * randomScale)
				part.Anchored = true

				local mesh = part:FindFirstChildOfClass("SpecialMesh") or part:FindFirstChildOfClass("BlockMesh")
				if mesh then
					mesh.Scale = mesh.Scale * randomScale
				end
			end
		end

		local newCf, newSize = structureClone:GetBoundingBox()
		worldY = worldY + (newSize.Y / 2)
		structureClone:PivotTo(CFrame.new(worldX, worldY, worldZ))

		local randomRotation = CFrame.Angles(0, math.rad(math.random(0, 360)), 0)
		structureClone:PivotTo(structureClone:GetPivot() * randomRotation)
	end

	structureClone.Parent = mapFolder

	-- Записываем позицию структуры
	table.insert(placedStructures, {
		x = x,
		z = z,
		name = selectedStructure.name,
		scale = randomScale,
		height = blockHeight,
		isEdgeStone = false
	})
end

-- ========================
-- ГЕНЕРАЦИЯ ЛАНДШАФТА
-- ========================

local function generateLandscapeFeatures()
	for i = 1, CONFIG.MOUNTAIN_COUNT do
		local angle = (i - 1) * (2 * math.pi / CONFIG.MOUNTAIN_COUNT) + (math.random() - 0.5)
		local distance = CONFIG.MAP_RADIUS * (0.25 + math.random() * 0.4)
		local x = math.floor(math.cos(angle) * distance)
		local z = math.floor(math.sin(angle) * distance)

		if isInCircle(x, z) then
			table.insert(mountainCenters, {x = x, z = z})
		end
	end

	for i = 1, CONFIG.VALLEY_COUNT do
		local angle = (i - 0.5) * (2 * math.pi / CONFIG.VALLEY_COUNT) + (math.random() - 0.5) * 0.5
		local distance = CONFIG.MAP_RADIUS * (0.3 + math.random() * 0.3)
		local x = math.floor(math.cos(angle) * distance)
		local z = math.floor(math.sin(angle) * distance)

		if isInCircle(x, z) then
			table.insert(valleyCenters, {x = x, z = z})
		end
	end
end

local function getLandscapeInfluence(x, z)
	local influence = 0

	for _, mountain in ipairs(mountainCenters) do
		local distance = math.sqrt((x - mountain.x)^2 + (z - mountain.z)^2)
		if distance < CONFIG.MOUNTAIN_SIZE then
			local strength = 1 - (distance / CONFIG.MOUNTAIN_SIZE)
			strength = strength * strength * strength
			influence = influence + strength * CONFIG.MOUNTAIN_HEIGHT
		end
	end

	for _, valley in ipairs(valleyCenters) do
		local distance = math.sqrt((x - valley.x)^2 + (z - valley.z)^2)
		if distance < CONFIG.VALLEY_SIZE then
			local strength = 1 - (distance / CONFIG.VALLEY_SIZE)
			strength = strength * strength
			influence = influence - strength * CONFIG.VALLEY_DEPTH
		end
	end

	return influence
end

-- ========================
-- ГЕНЕРАЦИЯ ВЫСОТ
-- ========================

local function generateHeight(x, z)
	if x == 0 and z == 0 then
		return CONFIG.START_HEIGHT
	end

	local neighbors = {
		{x - 1, z},
		{x + 1, z},
		{x, z - 1},
		{x, z + 1}
	}

	local neighborHeights = {}
	local totalHeight = 0
	local count = 0

	for _, pos in ipairs(neighbors) do
		local height = getHeightAt(pos[1], pos[2])
		if height then
			table.insert(neighborHeights, height)
			totalHeight = totalHeight + height
			count = count + 1
		end
	end

	if count == 0 then
		return CONFIG.START_HEIGHT
	end

	local averageHeight = totalHeight / count

	local nx = (x + NOISE.ox) * CONFIG.NOISE_SCALE
	local nz = (z + NOISE.oz) * CONFIG.NOISE_SCALE
	local noise1 = math.noise(nx, nz, NOISE.ot1)
	local noise2 = math.noise(nx * 2.5, nz * 2.5, NOISE.ot2) * 0.4
	local noise3 = math.noise(nx * 5,   nz * 5,   NOISE.ot3) * 0.2
	local combinedNoise = (noise1 + noise2 + noise3) * CONFIG.NOISE_STRENGTH

	local landscapeInfluence = getLandscapeInfluence(x, z)

	local targetHeight = averageHeight * CONFIG.SMOOTH_FACTOR +
		(averageHeight + combinedNoise + landscapeInfluence) * (1 - CONFIG.SMOOTH_FACTOR)

	targetHeight = targetHeight + (math.random() - 0.5) * 1.2

	local distanceFromCenter = math.sqrt(x * x + z * z)
	local edgeFactor = distanceFromCenter / CONFIG.MAP_RADIUS
	if edgeFactor > 0.75 then
		targetHeight = targetHeight - (edgeFactor - 0.75) * 8
	end

	local finalHeight = math.floor(targetHeight + 0.5)

	for _, neighborHeight in ipairs(neighborHeights) do
		if math.abs(finalHeight - neighborHeight) > CONFIG.MAX_HEIGHT_DIFF then
			if finalHeight > neighborHeight then
				finalHeight = neighborHeight + CONFIG.MAX_HEIGHT_DIFF
			else
				finalHeight = neighborHeight - CONFIG.MAX_HEIGHT_DIFF
			end
		end
	end

	return math.clamp(finalHeight, CONFIG.MIN_HEIGHT, CONFIG.MAX_HEIGHT)
end

-- ========================
-- РАЗМЕЩЕНИЕ БЛОКОВ (ОБНОВЛЕНО)
-- ========================

local function placeBlock(x, z, height)
	local block = getGroundBlock(height)
	if not block then
		warn("Не найден блок для высоты " .. height)
		return
	end

	local clone = block:Clone()

	local worldX = x * CONFIG.BLOCK_SIZE
	local worldZ = z * CONFIG.BLOCK_SIZE
	local worldY = 0

	if CONFIG.ALIGN_TO_BOTTOM then
		if clone:IsA("BasePart") then
			worldY = clone.Size.Y / 2
		elseif clone:IsA("Model") then
			local cf, size = clone:GetBoundingBox()
			worldY = size.Y / 2
		end
	end

	if clone:IsA("BasePart") then
		clone.Position = Vector3.new(worldX, worldY, worldZ)
		clone.Anchored = true
	elseif clone:IsA("Model") then
		clone:PivotTo(CFrame.new(worldX, worldY, worldZ))
		for _, part in pairs(clone:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
	end

	clone.Parent = mapFolder

	local key = x .. "," .. z
	generatedMap[key] = {
		height = height,
		block = clone
	}

	-- НОВОЕ: Добавляем кандидата для Portal
	addPortalCandidate(x, z, height)

	placeStructureOnBlock(x, z, clone, height)
end

-- ========================
-- ГЛАВНАЯ ГЕНЕРАЦИЯ (ОБНОВЛЕНА)
-- ========================

local function generateMap()
	warn("=== НАЧИНАЕМ ГЕНЕРАЦИЮ КАРТЫ V2.1 (32x32 БЛОКИ + PORTAL) ===")
	warn("Размер: " .. (CONFIG.MAP_RADIUS * 2) .. "x" .. (CONFIG.MAP_RADIUS * 2) .. " блоков")
	warn("Размер блока: " .. CONFIG.BLOCK_SIZE .. "x" .. CONFIG.BLOCK_SIZE .. " studs")
	warn("Ожидаемое количество блоков: ~" .. math.floor(math.pi * CONFIG.MAP_RADIUS * CONFIG.MAP_RADIUS))
	warn("Глобальный шанс структур: " .. (CONFIG.GLOBAL_STRUCTURE_CHANCE * 100) .. "%")

	if portalModel then
		warn("Portal будет размещен единожды на карте!")
	end

	local queue = {{0, 0}}
	local visited = {}
	visited["0,0"] = true

	local blocksGenerated = 0
	local heightStats = {}
	for i = 1, CONFIG.MAX_HEIGHT do
		heightStats[i] = 0
	end

	local startTime = tick()
	local lastYield = tick()
	local lastProgress = 0

	while #queue > 0 do
		local pos = table.remove(queue, 1)
		local x, z = pos[1], pos[2]

		if isInCircle(x, z) then
			local height = generateHeight(x, z)
			placeBlock(x, z, height)

			blocksGenerated = blocksGenerated + 1
			heightStats[height] = heightStats[height] + 1

			if blocksGenerated - lastProgress >= 1000 then
				lastProgress = blocksGenerated
				local elapsed = math.floor(tick() - startTime)
				local speed = math.floor(blocksGenerated / (elapsed + 1))
				print(string.format("Прогресс: %d блоков | %d сек | %d блоков/сек | Portal кандидатов: %d",
					blocksGenerated, elapsed, speed, #portalCandidates))
			end

			if tick() - lastYield > 0.03 then
				RunService.Heartbeat:Wait()
				lastYield = tick()
			end

			local neighbors = {
				{x - 1, z},
				{x + 1, z},
				{x, z - 1},
				{x, z + 1}
			}

			for _, neighbor in ipairs(neighbors) do
				local nx, nz = neighbor[1], neighbor[2]
				local key = nx .. "," .. nz

				if not visited[key] and isInCircle(nx, nz) then
					visited[key] = true
					table.insert(queue, {nx, nz})
				end
			end
		end
	end

	-- НОВОЕ: Размещаем Portal после генерации всей карты
	warn("Размещение Portal...")
	placePortal()

	local totalTime = math.floor(tick() - startTime)

	-- Маркеры гор и долин (масштабированы для 32x32)
	for i, mountain in ipairs(mountainCenters) do
		local marker = Instance.new("Part")
		marker.Name = "Mountain" .. i
		marker.Size = Vector3.new(20, 200, 20)
		marker.Position = Vector3.new(
			mountain.x * CONFIG.BLOCK_SIZE,
			100,
			mountain.z * CONFIG.BLOCK_SIZE
		)
		marker.BrickColor = BrickColor.new("Brown")
		marker.Material = Enum.Material.Rock
		marker.Transparency = 0.5
		marker.CanCollide = false
		marker.Anchored = true
		marker.Parent = mapFolder
	end

	for i, valley in ipairs(valleyCenters) do
		local marker = Instance.new("Part")
		marker.Name = "Valley" .. i
		marker.Size = Vector3.new(25, 25, 25)
		marker.Position = Vector3.new(
			valley.x * CONFIG.BLOCK_SIZE,
			15,
			valley.z * CONFIG.BLOCK_SIZE
		)
		marker.BrickColor = BrickColor.new("Deep blue")
		marker.Material = Enum.Material.ForceField
		marker.Transparency = 0.4
		marker.CanCollide = false
		marker.Anchored = true
		marker.Parent = mapFolder
	end

	-- ========================
	-- РАСШИРЕННАЯ СТАТИСТИКА V2.1
	-- ========================

	print("==========================================")
	print("ГЕНЕРАЦИЯ ЗАВЕРШЕНА! (32x32 БЛОКИ + PORTAL)")
	print("Время: " .. totalTime .. " секунд")
	print("Всего блоков: " .. blocksGenerated)
	print("Размер блока: " .. CONFIG.BLOCK_SIZE .. "x" .. CONFIG.BLOCK_SIZE .. " studs")
	print("Скорость: " .. math.floor(blocksGenerated / (totalTime + 1)) .. " блоков/сек")
	print("==========================================")

	-- Статистика высот
	local minHeight = CONFIG.MAX_HEIGHT
	local maxHeight = 1

	for i = 1, CONFIG.MAX_HEIGHT do
		if heightStats[i] > 0 then
			minHeight = math.min(minHeight, i)
			maxHeight = math.max(maxHeight, i)
			local percent = math.floor(heightStats[i] / blocksGenerated * 100)
			if percent > 0 then
				print(string.format("ground_%02d: %5d блоков (%d%%)", i, heightStats[i], percent))
			end
		end
	end

	print("Диапазон высот: " .. minHeight .. "-" .. maxHeight)

	-- ОБНОВЛЕННАЯ СТАТИСТИКА СТРУКТУР V2.1
	print("==========================================")
	print("СТАТИСТИКА СТРУКТУР V2.1 (с Portal):")
	print("Всего размещено структур: " .. #placedStructures)

	if #AllStructures > 0 then
		print("\nНастройки загруженных структур:")
		for _, structure in ipairs(AllStructures) do
			print(string.format("  %s: шанс=%d%%, высоты=%d-%d, вес=%.1f",
				structure.name, structure.chance, structure.minHeight, structure.maxHeight, structure.weight))
		end
	end

	-- Статистика размещенных структур
	local structureStats = {}
	local scaleStats = {min = 999, max = 0, total = 0}
	local heightDistribution = {}
	local edgeStoneCount = 0
	local edgeStoneScaleStats = {min = 999, max = 0, total = 0}
	local uniqueStructureCount = 0

	for _, structure in ipairs(placedStructures) do
		if structure.isEdgeStone then
			edgeStoneCount = edgeStoneCount + 1
			edgeStoneScaleStats.min = math.min(edgeStoneScaleStats.min, structure.scale)
			edgeStoneScaleStats.max = math.max(edgeStoneScaleStats.max, structure.scale)
			edgeStoneScaleStats.total = edgeStoneScaleStats.total + structure.scale
		elseif structure.isUnique then
			uniqueStructureCount = uniqueStructureCount + 1
		else
			structureStats[structure.name] = (structureStats[structure.name] or 0) + 1

			scaleStats.min = math.min(scaleStats.min, structure.scale)
			scaleStats.max = math.max(scaleStats.max, structure.scale)
			scaleStats.total = scaleStats.total + structure.scale

			if not heightDistribution[structure.name] then
				heightDistribution[structure.name] = {min = 999, max = 0, count = 0}
			end
			local dist = heightDistribution[structure.name]
			dist.min = math.min(dist.min, structure.height)
			dist.max = math.max(dist.max, structure.height)
			dist.count = dist.count + 1
		end
	end

	-- НОВАЯ СТАТИСТИКА УНИКАЛЬНЫХ СТРУКТУР
	if uniqueStructureCount > 0 then
		print(string.format("\nУНИКАЛЬНЫЕ СТРУКТУРЫ: %d", uniqueStructureCount))
		for _, structure in ipairs(placedStructures) do
			if structure.isUnique then
				print(string.format("  ✓ %s размещен в (%d, %d) на высоте %d, масштаб %.1f",
					structure.name, structure.x, structure.z, structure.height, structure.scale))
			end
		end
		print(string.format("Portal кандидатов было найдено: %d", #portalCandidates))
	else
		if portalModel then
			warn("Portal НЕ был размещен! Возможные причины:")
			warn("- Не найдено подходящих мест (высота " .. CONFIG.UNIQUE_STRUCTURE_MIN_HEIGHT .. "-" .. CONFIG.UNIQUE_STRUCTURE_MAX_HEIGHT .. ")")
			warn("- Расстояние от центра должно быть " .. CONFIG.UNIQUE_STRUCTURE_MIN_DISTANCE_FROM_CENTER .. "-" .. CONFIG.UNIQUE_STRUCTURE_MAX_DISTANCE_FROM_CENTER .. " блоков")
			warn("- Все подходящие места заняты другими структурами")
			warn("Найдено кандидатов для Portal: " .. #portalCandidates)
		end
	end

	-- Краевые камни
	if edgeStoneCount > 0 then
		print(string.format("\nКРАЕВЫЕ КАМНИ (граница карты): %d", edgeStoneCount))
		print(string.format("  Масштаб: min=%.2f, max=%.2f, средний=%.2f",
			edgeStoneScaleStats.min, edgeStoneScaleStats.max,
			edgeStoneScaleStats.total / edgeStoneCount))
	end

	-- Обычные структуры
	print("\nОбычные структуры по типам:")
	local totalRegularStructures = 0
	for structureName, count in pairs(structureStats) do
		totalRegularStructures = totalRegularStructures + count
		local percent = (count / blocksGenerated) * 100
		print(string.format("  %s: %d (%.2f%% от всех блоков)", structureName, count, percent))

		if heightDistribution[structureName] then
			local dist = heightDistribution[structureName]
			print(string.format("    └─ На высотах: %d-%d", dist.min, dist.max))
		end
	end

	if totalRegularStructures > 0 then
		print(string.format("\nВСЕГО обычных структур: %d", totalRegularStructures))
		print(string.format("Процент блоков с обычными структурами: %.2f%%",
			(totalRegularStructures / blocksGenerated) * 100))
		print(string.format("Ожидаемый процент (%.0f%% глобальный шанс): %.2f%%",
			CONFIG.GLOBAL_STRUCTURE_CHANCE * 100, CONFIG.GLOBAL_STRUCTURE_CHANCE * 100))
		print(string.format("Масштабы: min=%.2f, max=%.2f, средний=%.2f",
			scaleStats.min, scaleStats.max, scaleStats.total / totalRegularStructures))
	end

	print("==========================================")
end

-- ========================
-- ПРОВЕРКА БЛОКОВ
-- ========================

local function checkBlocks()
	local found = 0
	local missing = {}

	for i = 1, 20 do
		local blockName = "ground_" .. i
		local block = groundsFolder:FindFirstChild(blockName)
		if block then
			found = found + 1
		else
			table.insert(missing, blockName)
		end
	end

	print("Найдено блоков: " .. found .. " из 20")
	if #missing > 0 and #missing <= 5 then
		warn("Отсутствуют: " .. table.concat(missing, ", "))
	end

	if found < 20 then
		CONFIG.MAX_HEIGHT = found
		CONFIG.START_HEIGHT = math.floor(found / 2)
		warn("Изменен MAX_HEIGHT на " .. CONFIG.MAX_HEIGHT)
		warn("Изменен START_HEIGHT на " .. CONFIG.START_HEIGHT)
	end
end

-- ========================
-- ГЛАВНАЯ ФУНКЦИЯ (ОБНОВЛЕНА)
-- ========================

local function main()
	warn("==========================================")
	warn("ЗАПУСК ГЕНЕРАТОРА КАРТЫ V2.1 С БЛОКАМИ 32x32 + PORTAL")
	warn("==========================================")

	groundsFolder = getGroundsFolder()
	structuresFolder = getStructuresFolder()
	portalModel = getPortalModel()  -- НОВОЕ: Ищем Portal
	mapFolder = createMapFolder()

	checkBlocks()

	math.randomseed(tick())
	for i = 1, 10 do math.random() end

	initNoise()

	-- Инициализируем базу данных структур
	initializeStructureDatabase()

	generateLandscapeFeatures()
	generateMap()

	local spawn = Instance.new("SpawnLocation")
	spawn.Position = Vector3.new(0, 150, 0)
	spawn.Size = Vector3.new(15, 1, 15)
	spawn.Anchored = true
	spawn.Material = Enum.Material.Neon
	spawn.BrickColor = BrickColor.new("Lime green")
	spawn.Parent = workspace

	warn("==========================================")
	warn("ГЕНЕРАЦИЯ V2.1 ЗАВЕРШЕНА! БЛОКИ 32x32 + PORTAL АКТИВНЫ!")
	warn("==========================================")
end

-- ЗАПУСК
main()
