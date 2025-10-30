-- LocalScript для фиксированной камеры + автоповорот персонажа
-- Поместите в StarterPlayer > StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = player:GetMouse()

local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")

-- Настройки камеры
local cameraSettings = {
	-- Расстояние камеры от персонажа
	distance = 15,
	-- Дополнительная высота камеры
	height = 5,
	-- Смещение камеры по горизонтали
	offsetX = 0,
	-- Высота точки фокуса
	focusHeight = 6,
	-- Чувствительность мыши
	sensitivity = 0.3,
	-- Плавность движения камеры
	smoothness = 0.15,
	-- Ограничения вертикального угла
	minPitch = -60,
	maxPitch = 60,
	-- Инверсия оси Y
	invertY = false,

	-- НОВОЕ: Настройки поворота персонажа
	characterRotationSpeed = 0.15, -- Плавность поворота персонажа (0-1)
	rotateCharacter = true, -- Включить/выключить поворот персонажа
}

-- Переменные для углов камеры
local yaw = 0
local pitch = 0
local targetYaw = 0
local targetPitch = 0

local function initializeCamera()
	camera.CameraType = Enum.CameraType.Scriptable
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	-- Отключаем автоповорот Roblox
	humanoid.AutoRotate = false
end

local function clampAngle(angle, min, max)
	return math.clamp(angle, min, max)
end

local function onMouseMove(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		targetYaw = targetYaw - input.Delta.X * cameraSettings.sensitivity

		local yMultiplier = cameraSettings.invertY and -1 or 1
		targetPitch = targetPitch + input.Delta.Y * cameraSettings.sensitivity * yMultiplier

		targetPitch = clampAngle(targetPitch, cameraSettings.minPitch, cameraSettings.maxPitch)
	end
end

-- НОВОЕ: Функция поворота персонажа в направлении камеры
local function rotateCharacterToCamera()
	if not character or not humanoidRootPart or not cameraSettings.rotateCharacter then
		return
	end

	-- Получаем горизонтальное направление камеры (без вертикального наклона)
	local cameraDirection = camera.CFrame.LookVector
	local horizontalDirection = Vector3.new(cameraDirection.X, 0, cameraDirection.Z).Unit

	-- Текущее направление персонажа
	local currentDirection = humanoidRootPart.CFrame.LookVector
	local currentHorizontal = Vector3.new(currentDirection.X, 0, currentDirection.Z).Unit

	-- Целевое направление (куда смотрит камера)
	local targetCFrame = CFrame.lookAt(humanoidRootPart.Position, humanoidRootPart.Position + horizontalDirection)

	-- Плавный поворот с использованием Lerp
	local currentCFrame = humanoidRootPart.CFrame
	local newCFrame = currentCFrame:Lerp(
		CFrame.new(currentCFrame.Position) * (targetCFrame - targetCFrame.Position),
		cameraSettings.characterRotationSpeed
	)

	-- Применяем поворот (только вращение, позиция остается прежней)
	humanoidRootPart.CFrame = CFrame.new(currentCFrame.Position) * (newCFrame - newCFrame.Position)
end

-- Функция обновления позиции камеры
local function updateCamera()
	if not character or not humanoidRootPart then
		return
	end

	-- Плавная интерполяция углов
	yaw = yaw + (targetYaw - yaw) * cameraSettings.smoothness
	pitch = pitch + (targetPitch - pitch) * cameraSettings.smoothness

	-- Конвертируем углы в радианы
	local yawRad = math.rad(yaw)
	local pitchRad = math.rad(pitch)

	-- Позиция персонажа
	local rootPosition = humanoidRootPart.Position

	-- Точка фокуса
	local focusPoint = rootPosition + Vector3.new(0, cameraSettings.focusHeight, 0)

	-- Вычисляем позицию камеры
	local x = cameraSettings.distance * math.cos(pitchRad) * math.sin(yawRad) + cameraSettings.offsetX
	local y = cameraSettings.distance * math.sin(pitchRad) + cameraSettings.height
	local z = cameraSettings.distance * math.cos(pitchRad) * math.cos(yawRad)

	-- Финальная позиция камеры
	local cameraPosition = focusPoint + Vector3.new(x, y, z)

	-- Устанавливаем позицию и направление камеры
	camera.CFrame = CFrame.lookAt(cameraPosition, focusPoint)

	-- НОВОЕ: Поворачиваем персонажа в направлении камеры
	rotateCharacterToCamera()
end

-- Функция для обновления ссылки на персонажа при респавне
local function onCharacterAdded(newCharacter)
	character = newCharacter
	humanoidRootPart = character:WaitForChild("HumanoidRootPart")
	humanoid = character:WaitForChild("Humanoid")

	-- Отключаем автоповорот для нового персонажа
	humanoid.AutoRotate = false

	-- Сбрасываем углы камеры
	yaw = 0
	pitch = 0
	targetYaw = 0
	targetPitch = 0
end

-- Функции для управления настройками
_G.CameraSettings = {
	setDistance = function(distance)
		cameraSettings.distance = distance
	end,

	setHeight = function(height)
		cameraSettings.height = height
	end,

	setFocusHeight = function(focusHeight)
		cameraSettings.focusHeight = focusHeight
	end,

	setSensitivity = function(sensitivity)
		cameraSettings.sensitivity = sensitivity
	end,

	setSmoothness = function(smoothness)
		cameraSettings.smoothness = math.clamp(smoothness, 0, 1)
	end,

	-- НОВОЕ: Управление поворотом персонажа
	setCharacterRotationSpeed = function(speed)
		cameraSettings.characterRotationSpeed = math.clamp(speed, 0, 1)
	end,

	-- НОВОЕ: Включить/выключить поворот персонажа
	setRotateCharacter = function(enabled)
		cameraSettings.rotateCharacter = enabled
		-- Включаем обратно автоповорот если отключаем наш поворот
		if not enabled and humanoid then
			humanoid.AutoRotate = true
		elseif enabled and humanoid then
			humanoid.AutoRotate = false
		end
	end,

	setInvertY = function(invert)
		cameraSettings.invertY = invert
	end,

	getSettings = function()
		return cameraSettings
	end,

	reset = function()
		yaw = 0
		pitch = 0
		targetYaw = 0
		targetPitch = 0
	end
}

-- Подключаем события
player.CharacterAdded:Connect(onCharacterAdded)
UserInputService.InputChanged:Connect(onMouseMove)

-- Инициализация
initializeCamera()

-- Главный цикл обновления камеры
RunService.RenderStepped:Connect(updateCamera)

-- Обработка фокуса окна
UserInputService.WindowFocused:Connect(function()
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
end)

UserInputService.WindowFocusReleased:Connect(function()
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end)

print("Камера с автоповоротом персонажа загружена!")
print("Персонаж всегда смотрит в направлении камеры")
