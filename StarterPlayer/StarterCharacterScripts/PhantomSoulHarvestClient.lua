-- =====================================
-- ЖАТВА ДУШ PHANTOM - КЛИЕНТ (CUSTOM EFFECTS)
-- Place in StarterPlayer → StarterCharacterScripts
-- =====================================
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local mouse = player:GetMouse()

-- Создаём RemoteEvent если нет
if not rs:FindFirstChild("PhantomSoulHarvest") then
	Instance.new("RemoteEvent", rs).Name = "PhantomSoulHarvest"
end

local remote = rs.PhantomSoulHarvest

-- ✅ ЗАГРУЗКА КАСТОМНЫХ ЭФФЕКТОВ
local effectsFolder = rs:WaitForChild("PhantomSoulEffects")
local soulProjectileTemplate = effectsFolder:WaitForChild("SoulProjectile")
local soulImpactTemplate = effectsFolder:WaitForChild("SoulImpact")

-- Настройки
local SOUL_SPEED = 70
local isHarvesting = false
local castConnection = nil

-- =====================================
-- 🔧 ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: Получить PrimaryPart или создать его
-- =====================================
local function getPrimaryPart(object)
	if object:IsA("BasePart") then
		return object
	elseif object:IsA("Model") then
		if object.PrimaryPart then
			return object.PrimaryPart
		else
			-- Ищем первый BasePart в модели
			for _, child in pairs(object:GetDescendants()) do
				if child:IsA("BasePart") then
					return child
				end
			end
		end
	end
	return nil
end

-- =====================================
-- 🔧 ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: Установить позицию/поворот
-- =====================================
local function setObjectCFrame(object, cframe)
	if object:IsA("BasePart") then
		object.CFrame = cframe
	elseif object:IsA("Model") then
		if object.PrimaryPart then
			object:SetPrimaryPartCFrame(cframe)
		else
			-- Используем PivotTo для моделей без PrimaryPart
			object:PivotTo(cframe)
		end
	end
end

-- =====================================
-- 🔧 ВСПОМОГАТЕЛЬНАЯ ФУНКЦИЯ: Получить позицию объекта
-- =====================================
local function getObjectPosition(object)
	if object:IsA("BasePart") then
		return object.Position
	elseif object:IsA("Model") then
		return object:GetPivot().Position
	end
	return Vector3.new(0, 0, 0)
end

-- =====================================
-- СОЗДАНИЕ ДУШИ (ТВОЙ ПРОДЖЕКТАЙЛ)
-- =====================================
local function createSoulVisual(startPos, targetPart)
	-- Клонируем твой кастомный проджектайл
	local soul = soulProjectileTemplate:Clone()

	-- Устанавливаем начальную позицию
	setObjectCFrame(soul, CFrame.new(startPos))

	-- Настраиваем физику для всех частей
	for _, descendant in pairs(soul:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.Anchored = true
		end
	end

	soul.Parent = workspace

	-- Включаем все ParticleEmitters
	for _, descendant in pairs(soul:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = true
		end
	end

	-- Включаем Trail если есть
	for _, descendant in pairs(soul:GetDescendants()) do
		if descendant:IsA("Trail") then
			descendant.Enabled = true
		end
	end

	-- Включаем свет если есть
	for _, descendant in pairs(soul:GetDescendants()) do
		if descendant:IsA("PointLight") or descendant:IsA("SpotLight") then
			descendant.Enabled = true
		end
	end

	-- Звук полёта души (опционально)
	local primaryPart = getPrimaryPart(soul)
	if primaryPart then
		local soulSound = Instance.new("Sound")
		soulSound.SoundId = "rbxassetid://5841558668" -- Призрачный вой
		soulSound.Volume = 0.3
		soulSound.Looped = false
		soulSound.Parent = primaryPart
		soulSound:Play()
	end

	-- =====================================
	-- АНИМАЦИЯ ПОЛЁТА К ЦЕЛИ
	-- =====================================
	task.spawn(function()
		local startTime = tick()
		local duration = 1.5 -- Максимальное время жизни души
		local currentPos = startPos

		while tick() - startTime < duration and soul.Parent and targetPart and targetPart.Parent do
			local dt = task.wait()

			-- Направление к цели
			local direction = (targetPart.Position - currentPos).Unit
			local distance = (targetPart.Position - currentPos).Magnitude

			-- Скорость движения
			local moveDistance = SOUL_SPEED * dt
			local newPos = currentPos + (direction * moveDistance)

			-- ✨ ВОЛНООБРАЗНОЕ ДВИЖЕНИЕ (призрачный эффект)
			local wave = math.sin(tick() * 5) * 0.03
			newPos = newPos + Vector3.new(wave, math.sin(tick() * 3) * 0.1, 0)

			-- 🎯 ПОВОРОТ В НАПРАВЛЕНИИ ПОЛЁТА
			local lookDirection = (targetPart.Position - newPos).Unit

			-- Вариант C: Модель смотрит вверх (наклон на 90°)
			local newCFrame = CFrame.lookAt(newPos, newPos + lookDirection) * CFrame.Angles(math.rad(0), math.rad(90), 0)

			setObjectCFrame(soul, newCFrame)
			currentPos = newPos

			-- Проверка достижения цели
			if distance < 6 then
				break
			end
		end

		-- =====================================
		-- УДАЛЕНИЕ ДУШИ
		-- =====================================

		-- Отключаем все эффекты
		for _, descendant in pairs(soul:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				descendant.Enabled = false
			end
			if descendant:IsA("Trail") then
				descendant.Enabled = false
			end
		end

		-- Fade out всех частей
		for _, descendant in pairs(soul:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 then
				TweenService:Create(descendant, TweenInfo.new(0.3), {Transparency = 1}):Play()
			end
		end

		-- Удаляем через время
		task.wait(0.4)
		soul:Destroy()
	end)
end

-- =====================================
-- ЭФФЕКТ ПОПАДАНИЯ (ТВОЙ ИМПАКТ)
-- =====================================
local function createHitEffect(position, isCrit)
	-- Клонируем твой кастомный импакт
	local impact = soulImpactTemplate:Clone()

	setObjectCFrame(impact, CFrame.new(position))

	-- Настраиваем физику для всех частей
	for _, descendant in pairs(impact:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.Anchored = true
		end
	end

	impact.Parent = workspace

	-- ✅ УВЕЛИЧИВАЕМ ВСЕ ЧАСТИ В 2 РАЗА
	for _, descendant in pairs(impact:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Size = descendant.Size * 2
		end
	end

	-- ✨ МЕНЯЕМ ЦВЕТ ДЛЯ КРИТА
	if isCrit then
		for _, descendant in pairs(impact:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant.Transparency < 1 then
				descendant.Color = Color3.fromRGB(255, 200, 0)
			end
		end

		for _, descendant in pairs(impact:GetDescendants()) do
			if descendant:IsA("PointLight") or descendant:IsA("SpotLight") then
				descendant.Color = Color3.fromRGB(255, 200, 0)
				descendant.Brightness = descendant.Brightness * 1.5
			end
		end

		for _, descendant in pairs(impact:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				descendant.Color = ColorSequence.new(Color3.fromRGB(255, 200, 0), Color3.fromRGB(255, 150, 0))
			end
		end
	end

	-- =====================================
	-- АКТИВАЦИЯ ВСЕХ PARTICLEEMITTERS
	-- =====================================
	for _, descendant in pairs(impact:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			local emitCount = descendant:GetAttribute("EmitCount") or 30
			descendant:Emit(emitCount)
		end
	end

	-- Звук попадания
	local primaryPart = getPrimaryPart(impact)
	if primaryPart then
		local hitSound = Instance.new("Sound")
		hitSound.SoundId = isCrit and "rbxassetid://2248511809" or "rbxassetid://9113685005"
		hitSound.Volume = isCrit and 0.7 or 0.5
		hitSound.Parent = primaryPart
		hitSound:Play()
	end

	-- ✅ ИСЧЕЗНОВЕНИЕ ЗА 0.2 СЕКУНДЫ + РАСШИРЕНИЕ В 4 РАЗА (было *2)
	for _, descendant in pairs(impact:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			local expandTween = TweenService:Create(
				descendant,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{Size = descendant.Size * 4, Transparency = 1} -- ✅ *4 потому что уже увеличили *2 выше
			)
			expandTween:Play()
		end
	end

	-- ✅ УДАЛЕНИЕ ЧЕРЕЗ 0.25 СЕКУНДЫ
	Debris:AddItem(impact, 0.25)
end

-- =====================================
-- ОБРАБОТКА СОБЫТИЙ ОТ СЕРВЕРА
-- =====================================
remote.OnClientEvent:Connect(function(action, ...)
	if action == "createSoul" then
		local startPos, targetPart = ...
		createSoulVisual(startPos, targetPart)

	elseif action == "soulHit" then
		local hitPos, isCrit = ...
		createHitEffect(hitPos, isCrit)
	end
end)

-- =====================================
-- НАЧАЛО ЖАТВЫ (ЗАЖАТИЕ ЛКМ)
-- =====================================
local function startHarvest()
	if isHarvesting or humanoid.Health <= 0 then return end

	isHarvesting = true
	print("👻 [CLIENT] Soul Harvest started")

	-- Уведомляем сервер о начале
	remote:FireServer("start")

	-- Постоянно посылаем запросы на создание душ
	castConnection = task.spawn(function()
		while isHarvesting do
			task.wait(0.5) -- Каждые 0.5 секунды
			if isHarvesting and humanoid.Health > 0 then
				remote:FireServer("cast", mouse.Hit.Position)
			end
		end
	end)
end

-- =====================================
-- ОСТАНОВКА ЖАТВЫ (ОТПУСКАНИЕ ЛКМ)
-- =====================================
local function stopHarvest()
	if not isHarvesting then return end

	isHarvesting = false
	print("🔴 [CLIENT] Soul Harvest stopped")

	-- Останавливаем цикл создания душ
	if castConnection then
		task.cancel(castConnection)
		castConnection = nil
	end

	-- Уведомляем сервер об остановке
	remote:FireServer("stop")
end

-- =====================================
-- ОБРАБОТКА ВВОДА (ЛКМ)
-- =====================================
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		startHarvest()
	end
end)

UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		stopHarvest()
	end
end)

-- Остановка при смерти персонажа
humanoid.Died:Connect(function()
	stopHarvest()
end)

local projectileType = soulProjectileTemplate:IsA("Model") and "Model" or "Part"
local impactType = soulImpactTemplate:IsA("Model") and "Model" or "Part"

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("👻 [PHANTOM SOUL HARVEST CLIENT] Loaded!")
print("   Hold LMB to harvest souls")
print("   Using CUSTOM projectile & impact effects")
print("   Projectile:", soulProjectileTemplate.Name, "(" .. projectileType .. ")")
print("   Impact:", soulImpactTemplate.Name, "(" .. impactType .. ")")
print("   ✅ Model & Part support enabled")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
