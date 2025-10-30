-- =====================================
-- ЖАТВА ДУШ PHANTOM - КЛИЕНТ (ULT)
-- Place in StarterPlayer → StarterCharacterScripts
-- =====================================
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

if not rs:FindFirstChild("PhantomHarvest") then
	Instance.new("RemoteEvent", rs).Name = "PhantomHarvest"
end

local remote = rs.PhantomHarvest

-- Загрузка эффектов
local effectsFolder = rs:WaitForChild("PhantomHarvestEffects")
local scytheImpactTemplate = effectsFolder:WaitForChild("ScytheImpact")
local enemyMarkTemplate = effectsFolder:WaitForChild("EnemyMark")
local impactHitTemplate = effectsFolder:WaitForChild("ImpactHit")

-- Настройки
local COOLDOWN = 30
local lastUltTime = 0

-- ════════════════════════════════════
-- РАСШИРЯЮЩАЯСЯ СФЕРА С ЭФФЕКТАМИ
-- ════════════════════════════════════
local function createExpandingSphere(position)
	-- Основная сфера
	local sphere = Instance.new("Part")
	sphere.Name = "HarvestSphere"
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(5, 5, 5)
	sphere.Material = Enum.Material.ForceField
	sphere.Color = Color3.fromRGB(0, 0, 0)
	sphere.Transparency = 0.4
	sphere.CanCollide = false
	sphere.Anchored = true
	sphere.Position = position
	sphere.Parent = workspace

	-- Внутреннее свечение
	local innerGlow = Instance.new("Part")
	innerGlow.Name = "InnerGlow"
	innerGlow.Shape = Enum.PartType.Ball
	innerGlow.Size = Vector3.new(4, 4, 4)
	innerGlow.Material = Enum.Material.Neon
	innerGlow.Color = Color3.fromRGB(100, 50, 150)
	innerGlow.Transparency = 0.6
	innerGlow.CanCollide = false
	innerGlow.Anchored = true
	innerGlow.Position = position
	innerGlow.Parent = sphere

	-- Фиолетовое свечение
	local light = Instance.new("PointLight")
	light.Brightness = 12
	light.Color = Color3.fromRGB(150, 100, 255)
	light.Range = 50
	light.Parent = sphere

	-- ═══════════════════════════════════
	-- КАСТОМНЫЕ ЭФФЕКТЫ ИЗ REPLICATEDSTORAGE
	-- ═══════════════════════════════════
	local clonedEmitters = {}

	if effectsFolder:FindFirstChild("ActivationSphere") then
		local sphereEffects = effectsFolder.ActivationSphere

		-- Клонируем всю структуру (Attachment с партиклами внутри)
		for _, child in pairs(sphereEffects:GetChildren()) do

			if child:IsA("Attachment") then
				-- Клонируем весь Attachment с партиклами
				local clonedAttachment = child:Clone()
				clonedAttachment.Parent = sphere

				-- Включаем все ParticleEmitter внутри
				for _, emitter in pairs(clonedAttachment:GetDescendants()) do
					if emitter:IsA("ParticleEmitter") then
						emitter.Enabled = true

						-- Сохраняем для скейлинга
						table.insert(clonedEmitters, {
							emitter = emitter,
							originalSpeed = emitter.Speed,
							originalSize = emitter.Size
						})

						-- Отключаем через 2.5 секунды
						task.delay(2.5, function()
							emitter.Enabled = false
						end)
					end
				end

			elseif child:IsA("Sound") then
				local clonedSound = child:Clone()
				clonedSound.Parent = sphere
				clonedSound:Play()
			end
		end

		print("✅ Загружено эффектов на сферу:", #clonedEmitters)
	else
		print("⚠️ ActivationSphere не найдена!")
	end

	-- Пульсация света
	local lightTween = TweenService:Create(
		light,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{Brightness = 6}
	)
	lightTween:Play()

	-- ═══════════════════════════════════
	-- СКЕЙЛИНГ ЭФФЕКТОВ ПО РАЗМЕРУ СФЕРЫ
	-- ═══════════════════════════════════
	local startSize = 5
	local endSize = 100
	local duration = 2.5

	task.spawn(function()
		local startTime = tick()

		while tick() - startTime < duration do
			local elapsed = tick() - startTime
			local progress = elapsed / duration
			local currentSize = startSize + (endSize - startSize) * progress
			local scale = currentSize / startSize

			-- Скейлим все эффекты
			for _, data in pairs(clonedEmitters) do
				if data.emitter and data.emitter.Parent then
					-- Скейлим скорость партиклов
					local originalSpeedMin = data.originalSpeed.Min
					local originalSpeedMax = data.originalSpeed.Max
					data.emitter.Speed = NumberRange.new(
						originalSpeedMin * scale,
						originalSpeedMax * scale
					)

					-- Скейлим размер партиклов
					local sizeKeypoints = {}
					for i, keypoint in pairs(data.originalSize.Keypoints) do
						table.insert(sizeKeypoints, NumberSequenceKeypoint.new(
							keypoint.Time,
							keypoint.Value * scale,
							keypoint.Envelope
							))
					end
					data.emitter.Size = NumberSequence.new(sizeKeypoints)
				end
			end

			task.wait()
		end
	end)

	-- Расширение сферы
	local expandTween = TweenService:Create(
		sphere,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(endSize, endSize, endSize), Transparency = 0.9}
	)
	expandTween:Play()

	-- Расширение свечения
	local glowTween = TweenService:Create(
		innerGlow,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(95, 95, 95), Transparency = 1}
	)
	glowTween:Play()

	-- Звук колокола судьбы (если нет кастомного звука)
	if not effectsFolder:FindFirstChild("ActivationSphere") or
		not effectsFolder.ActivationSphere:FindFirstChildWhichIsA("Sound") then
		local bellSound = Instance.new("Sound")
		bellSound.SoundId = "rbxassetid://5841558668"
		bellSound.Volume = 0.8
		bellSound.Parent = sphere
		bellSound:Play()
	end

	Debris:AddItem(sphere, 3)
end

-- ════════════════════════════════════
-- ИЗМЕНЕНИЕ АТМОСФЕРЫ
-- ════════════════════════════════════
local function createAtmosphereEffect()
	local originalBrightness = Lighting.Brightness
	local originalAmbient = Lighting.Ambient

	-- Затемнение
	local darkTween = TweenService:Create(
		Lighting,
		TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{Brightness = 0.5, Ambient = Color3.fromRGB(50, 0, 100)}
	)
	darkTween:Play()

	-- Возвращение через 3 секунды
	task.delay(3, function()
		TweenService:Create(
			Lighting,
			TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
			{Brightness = originalBrightness, Ambient = originalAmbient}
		):Play()
	end)
end

-- ════════════════════════════════════
-- МЕТКА НА ВРАГЕ (EnemyMark)
-- ════════════════════════════════════
local function createEnemyMark(targetRoot)
	local mark = enemyMarkTemplate:Clone()
	mark.CFrame = targetRoot.CFrame
	mark.Parent = targetRoot

	-- Включаем все ParticleEmitter
	for _, descendant in pairs(mark:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = true
			task.delay(2.5, function()
				descendant.Enabled = false
			end)
		end
	end

	-- Привязка к врагу
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = targetRoot
	weld.Part1 = mark
	weld.Parent = mark

	Debris:AddItem(mark, 3)
end

-- ════════════════════════════════════
-- КОСА (ScytheImpact) + УДАР (ImpactHit)
-- ════════════════════════════════════
local function spawnScytheAndImpact(position, isCrit)
	-- Находим землю под позицией
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Исключаем персонажа игрока
	local ignoreList = {character}
	rayParams.FilterDescendantsInstances = ignoreList

	local rayResult = workspace:Raycast(
		position + Vector3.new(0, 5, 0),
		Vector3.new(0, -100, 0),
		rayParams
	)

	local groundPos = rayResult and rayResult.Position or (position - Vector3.new(0, 3, 0))

	-- 1. КОСА
	local scythe = scytheImpactTemplate:Clone()

	-- Начальная позиция (ГЛУБЖЕ под землёй)
	local startPos = groundPos - Vector3.new(0, 30, 0)
	-- Конечная позиция (выше над землёй)
	local endPos = groundPos + Vector3.new(0, 7, 0)
	-- Позиция возврата (ГЛУБЖЕ под землю)
	local returnPos = groundPos - Vector3.new(0, 40, 0)

	-- Устанавливаем начальную позицию
	if scythe:IsA("Model") then
		if scythe.PrimaryPart then
			scythe:SetPrimaryPartCFrame(CFrame.new(startPos))
		else
			scythe:PivotTo(CFrame.new(startPos))
		end
	else
		scythe.CFrame = CFrame.new(startPos)
	end

	scythe.Parent = workspace

	-- Включаем все эффекты косы
	for _, descendant in pairs(scythe:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = true
		elseif descendant:IsA("Sound") then
			descendant:Play()
		elseif descendant:IsA("PointLight") then
			if isCrit then
				descendant.Color = Color3.fromRGB(255, 200, 0)
				descendant.Brightness = descendant.Brightness * 1.5
			end
		end
	end

	-- ═══════════════════════════════════
	-- АНИМАЦИЯ ВЫЛЕТА ИЗ ЗЕМЛИ + ВРАЩЕНИЕ
	-- ═══════════════════════════════════
	task.spawn(function()
		if scythe:IsA("Model") then
			-- Для Model используем PivotTo
			local initialRotation = scythe:GetPivot().Rotation

			-- ════════════════════════════════
			-- ФАЗА 1: ВЫЛЕТ ИЗ ЗЕМЛИ (0.6 сек)
			-- ════════════════════════════════
			local startTime = tick()
			local riseDuration = 0.2

			while tick() - startTime < riseDuration do
				local progress = (tick() - startTime) / riseDuration
				-- Easing Sine Out (плавный)
				local easedProgress = math.sin(progress * math.pi * 0.5)

				local currentPos = startPos:Lerp(endPos, easedProgress)

				-- Вращение ПРОТИВ часовой: -rotationAngle (минус!)
				local rotationAngle = -progress * math.pi * 2  -- ПРОТИВ ЧАСОВОЙ

				scythe:PivotTo(
					CFrame.new(currentPos)
						* initialRotation
						* CFrame.Angles(0, rotationAngle, 0)
				)
				task.wait()
			end

			-- ════════════════════════════════
			-- ФАЗА 2: ПАДЕНИЕ ОБРАТНО (0.8 сек)
			-- БЕЗ ПАУЗЫ - СРАЗУ НАЧИНАЕМ
			-- ════════════════════════════════
			startTime = tick()
			local fallDuration = 0.4

			while tick() - startTime < fallDuration do
				local progress = (tick() - startTime) / fallDuration
				-- Easing Sine In (плавное ускорение вниз)
				local easedProgress = 1 - math.cos(progress * math.pi * 0.5)

				local currentPos = endPos:Lerp(returnPos, easedProgress)

				-- Продолжаем вращение ПРОТИВ часовой
				local rotationAngle = -(1 + progress) * math.pi * 2  -- ПРОТИВ ЧАСОВОЙ

				scythe:PivotTo(
					CFrame.new(currentPos)
						* initialRotation
						* CFrame.Angles(0, rotationAngle, 0)
				)
				task.wait()
			end

		elseif scythe:IsA("BasePart") then
			-- Для Part (если коса - один Part)
			local initialCFrame = scythe.CFrame

			-- ВЫЛЕТ
			local startTime = tick()
			local riseDuration = 0.2

			while tick() - startTime < riseDuration do
				local progress = (tick() - startTime) / riseDuration
				local easedProgress = math.sin(progress * math.pi * 0.5)

				local currentPos = startPos:Lerp(endPos, easedProgress)
				local rotationAngle = -progress * math.pi * 2  -- ПРОТИВ ЧАСОВОЙ

				scythe.CFrame = CFrame.new(currentPos)
					* initialCFrame.Rotation
					* CFrame.Angles(0, rotationAngle, 0)
				task.wait()
			end

			-- ПАДЕНИЕ (БЕЗ ПАУЗЫ)
			startTime = tick()
			local fallDuration = 0.4

			while tick() - startTime < fallDuration do
				local progress = (tick() - startTime) / fallDuration
				local easedProgress = 1 - math.cos(progress * math.pi * 0.5)

				local currentPos = endPos:Lerp(returnPos, easedProgress)
				local rotationAngle = -(1 + progress) * math.pi * 2  -- ПРОТИВ ЧАСОВОЙ

				scythe.CFrame = CFrame.new(currentPos)
					* initialCFrame.Rotation
					* CFrame.Angles(0, rotationAngle, 0)
				task.wait()
			end
		end
	end)

	-- Отключаем партиклы после вылета
	task.delay(0.6, function()
		for _, descendant in pairs(scythe:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				descendant.Enabled = false
			end
		end
	end)

	Debris:AddItem(scythe, 2.5)

	-- 2. ИМПАКТ УДАРА (появляется на пике косы)
	task.delay(0.6, function()
		local impact = impactHitTemplate:Clone()
		impact.CFrame = CFrame.new(endPos)
		impact.Parent = workspace

		-- Включаем эффекты импакта
		for _, descendant in pairs(impact:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				descendant.Enabled = true
				-- Отключаем через короткое время
				task.delay(0.3, function()
					descendant.Enabled = false
				end)
			elseif descendant:IsA("Sound") then
				descendant:Play()
			elseif descendant:IsA("PointLight") then
				if isCrit then
					descendant.Color = Color3.fromRGB(255, 200, 0)
				end
				-- Вспышка света
				TweenService:Create(
					descendant,
					TweenInfo.new(0.3),
					{Brightness = 0}
				):Play()
			end
		end

		Debris:AddItem(impact, 1)
	end)
end
-- ════════════════════════════════════
-- ОБРАБОТКА СОБЫТИЙ ОТ СЕРВЕРА
-- ════════════════════════════════════
remote.OnClientEvent:Connect(function(action, ...)
	if action == "startHarvest" then
		local casterPlayer, position = ...

		print("⚰️ ЖАТВА НАЧАЛАСЬ!")

		createExpandingSphere(position)
		createAtmosphereEffect()

	elseif action == "markEnemy" then
		local targetRoot = ...
		createEnemyMark(targetRoot)

	elseif action == "spawnScythe" then
		local position, isCrit = ...
		spawnScytheAndImpact(position, isCrit)

	elseif action == "showHeal" then
		local healAmount = ...
		-- Пока без эффекта лечения
		print("💚 Исцелено:", healAmount, "HP")
	end
end)

-- ════════════════════════════════════
-- АКТИВАЦИЯ УЛЬТА (R)
-- ════════════════════════════════════
local function activateUlt()
	local currentTime = tick()
	if currentTime - lastUltTime < COOLDOWN then
		local remaining = COOLDOWN - (currentTime - lastUltTime)
		print(string.format("⏱️ Жатва перезаряжается! Осталось: %.1f сек", remaining))
		return
	end

	if humanoid.Health <= 0 then return end

	print("⚰️ ЖАТВА ДУШ!")

	-- Отправляем на сервер
	remote:FireServer("activate")

	lastUltTime = currentTime
end

-- Обработка R
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.R then
		activateUlt()
	end
end)

-- Остановка при смерти
humanoid.Died:Connect(function()
	-- Очистка
end)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("⚰️ [PHANTOM HARVEST CLIENT] Loaded!")
print("   Press R to unleash HARVEST")
print("   Effects scale with sphere expansion")
print("   Scythes rise from ground and fall back")
print("   Cooldown:", COOLDOWN, "seconds")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
