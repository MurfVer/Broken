-- =====================================
-- MAP GENERATOR v2.1 - PROCEDURAL TERRAIN
-- 32x32 blocks, 40 block radius (80 diameter)
-- Perlin noise terrain with Portal placement
-- Place in ServerScriptService
-- =====================================

local Workspace = game:GetService("Workspace")
local ServerStorage = game:GetService("ServerStorage")

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🗺️ [MAP GENERATOR] Loading...")

-- ========================
-- КОНФИГУРАЦИЯ
-- ========================
local CONFIG = {
	DEBUG_MODE = true,

	-- Размеры карты
	MAP_RADIUS = 40, -- Блоков от центра (диаметр = 80)
	BLOCK_SIZE = 32, -- Размер одного блока в стадах

	-- Генерация высоты
	PERLIN_SCALE = 0.05, -- Масштаб шума (меньше = более гладкие холмы)
	BASE_HEIGHT = 10, -- Базовая высота
	HEIGHT_VARIATION = 30, -- Максимальное отклонение от базы
	SEED = math.random(1, 1000000), -- Случайный сид

	-- Структуры
	STRUCTURE_CHANCE = 0.05, -- 5% шанс структуры на блоке
	UNIQUE_STRUCTURE_MIN_HEIGHT = 8, -- Мин. высота для уникальных структур

	-- Материалы
	MATERIALS = {
		GRASS = {
			Material = Enum.Material.Grass,
			Color = Color3.fromRGB(107, 142, 35),
			MinHeight = 5,
			MaxHeight = 999,
		},
		STONE = {
			Material = Enum.Material.Slate,
			Color = Color3.fromRGB(100, 100, 100),
			MinHeight = 15,
			MaxHeight = 999,
		},
		SNOW = {
			Material = Enum.Material.Snow,
			Color = Color3.fromRGB(255, 255, 255),
			MinHeight = 25,
			MaxHeight = 999,
		},
	},

	-- Края карты
	EDGE_MATERIAL = Enum.Material.Cobblestone,
	EDGE_COLOR = Color3.fromRGB(70, 70, 70),
}

-- ========================
-- ХРАНИЛИЩЕ ДАННЫХ
-- ========================
local MapState = {
	generatedMap = nil,
	totalBlocks = 0,
	structuresPlaced = 0,
	portalPlaced = false,
	mapBlocks = {}, -- {[x][z] = {block, height}}
}

-- ========================
-- ШУМ ПЕРЛИНА (2D)
-- ========================
local function perlinNoise(x, z, seed)
	-- Простая реализация Perlin Noise
	local function fade(t)
		return t * t * t * (t * (t * 6 - 15) + 10)
	end

	local function lerp(t, a, b)
		return a + t * (b - a)
	end

	local function grad(hash, x, z)
		local h = hash % 4
		if h == 0 then return x + z
		elseif h == 1 then return -x + z
		elseif h == 2 then return x - z
		else return -x - z
		end
	end

	-- Координаты сетки
	local xi = math.floor(x) % 256
	local zi = math.floor(z) % 256

	-- Локальные координаты в ячейке
	local xf = x - math.floor(x)
	local zf = z - math.floor(z)

	-- Сглаживание
	local u = fade(xf)
	local v = fade(zf)

	-- Хеш-функция (используем сид)
	local function hash(i, j)
		return (i * 374761393 + j * 668265263 + seed) % 256
	end

	-- Градиенты углов
	local aa = hash(xi, zi)
	local ab = hash(xi, zi + 1)
	local ba = hash(xi + 1, zi)
	local bb = hash(xi + 1, zi + 1)

	-- Интерполяция
	local x1 = lerp(u, grad(aa, xf, zf), grad(ba, xf - 1, zf))
	local x2 = lerp(u, grad(ab, xf, zf - 1), grad(bb, xf - 1, zf - 1))

	return lerp(v, x1, x2)
end

-- ========================
-- ПОЛУЧИТЬ ВЫСОТУ БЛОКА
-- ========================
local function getBlockHeight(x, z)
	-- Применяем Perlin Noise
	local noise = perlinNoise(x * CONFIG.PERLIN_SCALE, z * CONFIG.PERLIN_SCALE, CONFIG.SEED)

	-- Нормализуем от -1..1 к 0..1
	local normalizedNoise = (noise + 1) / 2

	-- Применяем высоту
	local height = CONFIG.BASE_HEIGHT + (normalizedNoise * CONFIG.HEIGHT_VARIATION)

	-- Округляем до целого
	return math.floor(height + 0.5)
end

-- ========================
-- ПОЛУЧИТЬ МАТЕРИАЛ ПО ВЫСОТЕ
-- ========================
local function getMaterialForHeight(height)
	if height >= 25 then
		return CONFIG.MATERIALS.SNOW.Material, CONFIG.MATERIALS.SNOW.Color
	elseif height >= 15 then
		return CONFIG.MATERIALS.STONE.Material, CONFIG.MATERIALS.STONE.Color
	else
		return CONFIG.MATERIALS.GRASS.Material, CONFIG.MATERIALS.GRASS.Color
	end
end

-- ========================
-- СОЗДАТЬ БЛОК
-- ========================
local function createBlock(x, z, height, isEdge)
	local block = Instance.new("Part")
	block.Name = "Block_" .. x .. "_" .. z
	block.Size = Vector3.new(CONFIG.BLOCK_SIZE, height, CONFIG.BLOCK_SIZE)
	block.Anchored = true
	block.CFrame = CFrame.new(
		x * CONFIG.BLOCK_SIZE,
		height / 2,
		z * CONFIG.BLOCK_SIZE
	)

	if isEdge then
		block.Material = CONFIG.EDGE_MATERIAL
		block.Color = CONFIG.EDGE_COLOR
	else
		local material, color = getMaterialForHeight(height)
		block.Material = material
		block.Color = color
	end

	-- Атрибуты
	block:SetAttribute("BlockX", x)
	block:SetAttribute("BlockZ", z)
	block:SetAttribute("BlockHeight", height)
	block:SetAttribute("IsEdge", isEdge)

	return block
end

-- ========================
-- ПРОВЕРКА КРАЯ КАРТЫ
-- ========================
local function isEdgeBlock(x, z)
	local distance = math.sqrt(x * x + z * z)
	return distance >= CONFIG.MAP_RADIUS - 1
end

-- ========================
-- РАЗМЕСТИТЬ СТРУКТУРУ НА БЛОКЕ
-- ========================
local function placeStructureOnBlock(x, z, blockClone, blockHeight)
	-- Проверка шанса спавна структуры
	if math.random() > CONFIG.STRUCTURE_CHANCE then
		return false
	end

	-- Не спавним на краях
	if isEdgeBlock(x, z) then
		return false
	end

	-- Список структур
	local structures = ServerStorage:FindFirstChild("Structures")
	if not structures then return false end

	local availableStructures = {}
	for _, structure in ipairs(structures:GetChildren()) do
		if structure:IsA("Model") then
			table.insert(availableStructures, structure)
		end
	end

	if #availableStructures == 0 then return false end

	-- Выбираем случайную структуру
	local chosenStructure = availableStructures[math.random(1, #availableStructures)]
	local structureClone = chosenStructure:Clone()

	-- Позиция на вершине блока
	local structurePosition = Vector3.new(
		x * CONFIG.BLOCK_SIZE,
		blockHeight,
		z * CONFIG.BLOCK_SIZE
	)

	if structureClone.PrimaryPart then
		structureClone:SetPrimaryPartCFrame(CFrame.new(structurePosition))
	elseif structureClone:FindFirstChild("Base") then
		structureClone.Base.CFrame = CFrame.new(structurePosition)
	end

	structureClone.Parent = blockClone

	MapState.structuresPlaced = MapState.structuresPlaced + 1

	if CONFIG.DEBUG_MODE and MapState.structuresPlaced % 10 == 0 then
		print("🏗️ [MAP] Placed " .. MapState.structuresPlaced .. " structures")
	end

	return true
end

-- ========================
-- РАЗМЕСТИТЬ ПОРТАЛ
-- ========================
local function placePortal()
	if MapState.portalPlaced then return end

	-- Ищем подходящий блок (высокий и не на краю)
	local bestBlock = nil
	local bestHeight = 0

	for x = -CONFIG.MAP_RADIUS + 5, CONFIG.MAP_RADIUS - 5 do
		for z = -CONFIG.MAP_RADIUS + 5, CONFIG.MAP_RADIUS - 5 do
			if MapState.mapBlocks[x] and MapState.mapBlocks[x][z] then
				local blockData = MapState.mapBlocks[x][z]
				local height = blockData.height

				if height >= CONFIG.UNIQUE_STRUCTURE_MIN_HEIGHT and height > bestHeight then
					local distance = math.sqrt(x * x + z * z)
					if distance < CONFIG.MAP_RADIUS - 5 then
						bestBlock = blockData
						bestHeight = height
					end
				end
			end
		end
	end

	if not bestBlock then
		warn("⚠️ [MAP] No suitable block found for Portal!")
		return
	end

	-- Создаём портал
	local portal = Instance.new("Model")
	portal.Name = "Portal"

	local portalPart = Instance.new("Part")
	portalPart.Name = "PortalPart"
	portalPart.Size = Vector3.new(6, 10, 0.5)
	portalPart.Material = Enum.Material.Neon
	portalPart.Color = Color3.fromRGB(138, 43, 226)
	portalPart.Anchored = true
	portalPart.CanCollide = false
	portalPart.Transparency = 0.3

	local x = bestBlock.block:GetAttribute("BlockX")
	local z = bestBlock.block:GetAttribute("BlockZ")
	local portalPosition = Vector3.new(
		x * CONFIG.BLOCK_SIZE,
		bestHeight + 5,
		z * CONFIG.BLOCK_SIZE
	)

	portalPart.CFrame = CFrame.new(portalPosition) * CFrame.Angles(0, 0, math.pi / 2)
	portalPart.Parent = portal

	-- Подсветка
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 30
	light.Color = Color3.fromRGB(138, 43, 226)
	light.Parent = portalPart

	-- Частицы
	local particles = Instance.new("ParticleEmitter")
	particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	particles.Color = ColorSequence.new(Color3.fromRGB(138, 43, 226))
	particles.Size = NumberSequence.new(0.5)
	particles.Lifetime = NumberRange.new(1, 2)
	particles.Rate = 50
	particles.Speed = NumberRange.new(2, 4)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = portalPart

	-- Атрибуты состояния
	portalPart:SetAttribute("IsCharging", false)
	portalPart:SetAttribute("IsActive", false)
	portalPart:SetAttribute("ChargeProgress", 0)

	portal.Parent = Workspace
	MapState.portalPlaced = true

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🌀 [MAP] Portal placed!")
	print("   Position: " .. tostring(portalPosition))
	print("   Block height: " .. bestHeight)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

-- ========================
-- ГЕНЕРАЦИЯ КАРТЫ
-- ========================
local function generateMap()
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🗺️ [MAP GENERATOR] Starting generation...")
	print("   Map radius: " .. CONFIG.MAP_RADIUS .. " blocks")
	print("   Block size: " .. CONFIG.BLOCK_SIZE .. " studs")
	print("   Total diameter: " .. (CONFIG.MAP_RADIUS * 2) .. " blocks")
	print("   Seed: " .. CONFIG.SEED)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	local startTime = tick()

	-- Создаём контейнер карты
	local mapContainer = Instance.new("Model")
	mapContainer.Name = "GeneratedMap"

	-- Инициализация таблицы блоков
	for x = -CONFIG.MAP_RADIUS, CONFIG.MAP_RADIUS do
		MapState.mapBlocks[x] = {}
	end

	-- Генерация блоков
	local blocksGenerated = 0

	for x = -CONFIG.MAP_RADIUS, CONFIG.MAP_RADIUS do
		for z = -CONFIG.MAP_RADIUS, CONFIG.MAP_RADIUS do
			-- Проверка радиуса (круглая карта)
			local distance = math.sqrt(x * x + z * z)

			if distance <= CONFIG.MAP_RADIUS then
				local isEdge = isEdgeBlock(x, z)
				local height = getBlockHeight(x, z)

				local block = createBlock(x, z, height, isEdge)
				block.Parent = mapContainer

				-- Сохраняем блок
				MapState.mapBlocks[x][z] = {
					block = block,
					height = height,
				}

				-- Размещаем структуры (не на краях)
				if not isEdge then
					placeStructureOnBlock(x, z, block, height)
				end

				blocksGenerated = blocksGenerated + 1

				-- Прогресс каждые 100 блоков
				if CONFIG.DEBUG_MODE and blocksGenerated % 100 == 0 then
					print("🗺️ [MAP] Generated " .. blocksGenerated .. " blocks...")
				end
			end
		end
	end

	mapContainer.Parent = Workspace
	MapState.generatedMap = mapContainer
	MapState.totalBlocks = blocksGenerated

	local elapsedTime = tick() - startTime

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("✅ [MAP] Generation complete!")
	print("   Blocks created: " .. blocksGenerated)
	print("   Structures placed: " .. MapState.structuresPlaced)
	print("   Generation time: " .. string.format("%.2f", elapsedTime) .. "s")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	-- Размещаем портал
	task.wait(1)
	placePortal()

	return mapContainer
end

-- ========================
-- ОЧИСТКА СТАРОЙ КАРТЫ
-- ========================
local function clearOldMap()
	local oldMap = Workspace:FindFirstChild("GeneratedMap")
	if oldMap then
		oldMap:Destroy()
		print("🧹 [MAP] Old map cleared!")
	end
end

-- ========================
-- КОМАНДЫ УПРАВЛЕНИЯ
-- ========================
_G.RegenerateMap = function(newSeed)
	print("🔄 [MAP] Regenerating map...")

	if newSeed then
		CONFIG.SEED = newSeed
		print("   New seed: " .. CONFIG.SEED)
	else
		CONFIG.SEED = math.random(1, 1000000)
		print("   Random seed: " .. CONFIG.SEED)
	end

	clearOldMap()

	MapState = {
		generatedMap = nil,
		totalBlocks = 0,
		structuresPlaced = 0,
		portalPlaced = false,
		mapBlocks = {},
	}

	generateMap()
end

_G.MapStats = function()
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("🗺️ [MAP] Statistics:")
	print("   Total blocks: " .. MapState.totalBlocks)
	print("   Structures placed: " .. MapState.structuresPlaced)
	print("   Portal placed: " .. tostring(MapState.portalPlaced))
	print("   Map radius: " .. CONFIG.MAP_RADIUS .. " blocks")
	print("   Current seed: " .. CONFIG.SEED)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

_G.GetBlockAt = function(x, z)
	if MapState.mapBlocks[x] and MapState.mapBlocks[x][z] then
		local blockData = MapState.mapBlocks[x][z]
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print("📍 [MAP] Block at (" .. x .. ", " .. z .. "):")
		print("   Height: " .. blockData.height)
		print("   Position: " .. tostring(blockData.block.Position))
		print("   Material: " .. tostring(blockData.block.Material))
		print("   Is edge: " .. tostring(blockData.block:GetAttribute("IsEdge")))
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		return blockData.block
	else
		print("❌ [MAP] No block at (" .. x .. ", " .. z .. ")")
		return nil
	end
end

-- ========================
-- ИНИЦИАЛИЗАЦИЯ
-- ========================
print("✅ [MAP GENERATOR] Loaded!")
print("   Configuration:")
print("   • Map radius: " .. CONFIG.MAP_RADIUS .. " blocks")
print("   • Block size: " .. CONFIG.BLOCK_SIZE .. " studs")
print("   • Perlin scale: " .. CONFIG.PERLIN_SCALE)
print("   • Base height: " .. CONFIG.BASE_HEIGHT .. " studs")
print("   • Height variation: " .. CONFIG.HEIGHT_VARIATION .. " studs")
print("   • Structure chance: " .. (CONFIG.STRUCTURE_CHANCE * 100) .. "%")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

-- Очищаем старую карту и генерируем новую
clearOldMap()
task.spawn(generateMap)

-- ========================
-- ЭКСПОРТ
-- ========================
return {
	GenerateMap = generateMap,
	ClearMap = clearOldMap,
	GetMapState = function() return MapState end,
	GetBlockHeight = getBlockHeight,
	GetBlockAt = function(x, z)
		if MapState.mapBlocks[x] and MapState.mapBlocks[x][z] then
			return MapState.mapBlocks[x][z].block
		end
		return nil
	end,
}
