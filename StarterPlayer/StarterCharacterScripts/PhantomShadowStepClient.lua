-- =====================================
-- ТЕНЕВОЙ ШАГ PHANTOM - КЛИЕНТ (CUSTOM EFFECT FIXED)
-- Place in StarterPlayer → StarterCharacterScripts
-- =====================================
local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local rs = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

if not rs:FindFirstChild("PhantomShadowStep") then
	Instance.new("RemoteEvent", rs).Name = "PhantomShadowStep"
end

local remote = rs.PhantomShadowStep

-- Путь к твоему эффекту
local effectFolder = rs:WaitForChild("PhantomShadowStepEffects")
local teleportEffectTemplate = effectFolder:WaitForChild("TeleportEffect")

-- Настройки
local COOLDOWN = 7
local lastDashTime = 0
local isInvisible = false

-- Активный эффект
local activeEffect = nil
local effectConnection = nil

-- Функция установки эффекта на игрока
local function attachEffect()
	if activeEffect then
		-- Удаляем старый эффект если есть
		if effectConnection then
			effectConnection:Disconnect()
			effectConnection = nil
		end
		activeEffect:Destroy()
	end

	-- Клонируем твой эффект
	activeEffect = teleportEffectTemplate:Clone()

	-- КРИТИЧЕСКИ ВАЖНО: делаем невидимым для физики
	activeEffect.CanCollide = false
	activeEffect.Anchored = true  -- Anchored = true чтобы не влиял на физику
	activeEffect.Transparency = 1  -- Сам Part невидим
	activeEffect.Size = Vector3.new(0.1, 0.1, 0.1)  -- Минимальный размер

	activeEffect.Parent = character

	-- Обновляем позицию каждый кадр
	effectConnection = RunService.RenderStepped:Connect(function()
		if activeEffect and activeEffect.Parent and rootPart and rootPart.Parent then
			activeEffect.CFrame = rootPart.CFrame
		end
	end)

	-- Включаем все эффекты внутри (ParticleEmitters, Lights и т.д.)
	for _, descendant in pairs(activeEffect:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = true
		elseif descendant:IsA("Light") then
			descendant.Enabled = true
		elseif descendant:IsA("BasePart") then
			-- Все части внутри тоже делаем неколлизионными
			descendant.CanCollide = false
			descendant.Anchored = true
		end
	end

	print("✨ Эффект прикреплён к игроку")
end

-- Функция удаления эффекта
local function removeEffect()
	if effectConnection then
		effectConnection:Disconnect()
		effectConnection = nil
	end

	if activeEffect then
		-- Выключаем эмиттеры
		for _, descendant in pairs(activeEffect:GetDescendants()) do
			if descendant:IsA("ParticleEmitter") then
				descendant.Enabled = false
			end
		end

		-- Удаляем через секунду (чтобы частицы успели исчезнуть)
		game:GetService("Debris"):AddItem(activeEffect, 1)
		activeEffect = nil

		print("🚫 Эффект удалён")
	end
end

-- Выполнить дэш
local function performDash()
	local currentTime = tick()
	if currentTime - lastDashTime < COOLDOWN then
		local remaining = COOLDOWN - (currentTime - lastDashTime)
		print(string.format("⏱️ Теневой шаг перезаряжается! Осталось: %.1f сек", remaining))
		return
	end

	if humanoid.Health <= 0 then return end

	print("🌫️ ТЕНЕВОЙ ШАГ!")

	local camera = workspace.CurrentCamera
	local direction = camera.CFrame.LookVector
	local startPos = rootPart.Position

	-- Отправляем на сервер
	remote:FireServer("dash", {
		direction = direction,
		startPos = startPos
	})

	lastDashTime = currentTime

	-- Небольшая задержка перед показом эффекта
	task.delay(0.1, function()
		if rootPart and rootPart.Parent then
			attachEffect()
		end
	end)
end

-- Обработка атаки из невидимости
local attackConnection = nil

local function setupStealthAttack()
	attackConnection = UIS.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 or
			input.UserInputType == Enum.UserInputType.MouseButton2 then

			if isInvisible then
				print("💥 Атака из невидимости!")
				remote:FireServer("attack")
				removeEffect()
			end
		end
	end)
end

setupStealthAttack()

-- Обработка событий от сервера
remote.OnClientEvent:Connect(function(action, ...)
	if action == "setInvisible" then
		local targetPlayer, invisible = ...

		if targetPlayer == player then
			isInvisible = invisible

			if invisible then
				print("👁️ Невидимость активирована!")
			else
				print("👁️ Невидимость закончилась")
				removeEffect()
			end
		else
			-- Другой игрок
			if targetPlayer.Character then
				for _, part in pairs(targetPlayer.Character:GetDescendants()) do
					if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
						part.Transparency = invisible and 0.8 or 0
					end
				end
			end
		end
	end
end)

-- Обработка Q
UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Q then
		performDash()
	end
end)

-- Остановка при смерти
humanoid.Died:Connect(function()
	removeEffect()
	isInvisible = false

	if attackConnection then
		attackConnection:Disconnect()
		attackConnection = nil
	end
end)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🌫️ [PHANTOM SHADOW STEP CLIENT] Loaded!")
print("   Press Q to teleport")
print("   Using CUSTOM effect from ReplicatedStorage")
print("   Effect: PhantomShadowStepEffects/TeleportEffect")
print("   Cooldown:", COOLDOWN, "seconds")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
