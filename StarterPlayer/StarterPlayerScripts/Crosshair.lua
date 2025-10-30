-- LocalScript для прицела
-- Поместите в StarterPlayer > StarterPlayerScripts или StarterGui

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Настройки прицела
local crosshairSettings = {
	-- Размер прицела
	size = 4,  -- Размер точки в пикселях
	gapSize = 8,  -- Размер зазора между линиями (для крестика)
	lineLength = 12,  -- Длина линий (для крестика)
	lineThickness = 2,  -- Толщина линий

	-- Цвет прицела
	color = Color3.fromRGB(255, 255, 255),  -- Белый
	transparency = 0,  -- 0 = непрозрачный, 1 = полностью прозрачный

	-- Обводка (для лучшей видимости на светлом фоне)
	outlineColor = Color3.fromRGB(0, 0, 0),  -- Чёрная обводка
	outlineTransparency = 0.3,

	-- Тип прицела: "dot", "cross", "circle", "combined"
	style = "dot",

	-- Анимация при стрельбе (расширение прицела)
	enableAnimation = true,
	animationScale = 1.5,  -- Насколько увеличивается прицел
	animationSpeed = 0.1,  -- Скорость анимации

	-- НОВОЕ: Смещение прицела
	offsetY = 20  -- Пиксели вниз от центра (положительное = вниз, отрицательное = вверх)
}

-- Создаём ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CrosshairGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999
screenGui.Parent = playerGui

-- Основной контейнер для прицела
local crosshairFrame = Instance.new("Frame")
crosshairFrame.Name = "CrosshairContainer"
crosshairFrame.Size = UDim2.new(0, 100, 0, 100)
-- ИЗМЕНЕНО: Прицел опущен вниз
crosshairFrame.Position = UDim2.new(0.5, 0, 0.5, crosshairSettings.offsetY)
crosshairFrame.AnchorPoint = Vector2.new(0.5, 0.5)
crosshairFrame.BackgroundTransparency = 1
crosshairFrame.Parent = screenGui

-- Функция создания точки
local function createDot()
	-- Основная точка
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.Size = UDim2.new(0, crosshairSettings.size, 0, crosshairSettings.size)
	dot.Position = UDim2.new(0.5, 0, 0.5, 0)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.BackgroundColor3 = crosshairSettings.color
	dot.BackgroundTransparency = crosshairSettings.transparency
	dot.BorderSizePixel = 0
	dot.Parent = crosshairFrame

	-- Обводка для точки
	if crosshairSettings.outlineTransparency < 1 then
		local outline = Instance.new("Frame")
		outline.Name = "DotOutline"
		outline.Size = UDim2.new(0, crosshairSettings.size + 2, 0, crosshairSettings.size + 2)
		outline.Position = UDim2.new(0.5, 0, 0.5, 0)
		outline.AnchorPoint = Vector2.new(0.5, 0.5)
		outline.BackgroundColor3 = crosshairSettings.outlineColor
		outline.BackgroundTransparency = crosshairSettings.outlineTransparency
		outline.BorderSizePixel = 0
		outline.ZIndex = 0
		outline.Parent = crosshairFrame

		dot.ZIndex = 1
	end

	return dot
end

-- Функция создания крестика
local function createCross()
	local lines = {}

	-- Создаём 4 линии крестика
	local positions = {
		{pos = UDim2.new(0.5, 0, 0.5, -(crosshairSettings.gapSize + crosshairSettings.lineLength)),
			size = UDim2.new(0, crosshairSettings.lineThickness, 0, crosshairSettings.lineLength)},  -- Верх
		{pos = UDim2.new(0.5, 0, 0.5, crosshairSettings.gapSize),
			size = UDim2.new(0, crosshairSettings.lineThickness, 0, crosshairSettings.lineLength)},  -- Низ
		{pos = UDim2.new(0.5, -(crosshairSettings.gapSize + crosshairSettings.lineLength), 0.5, 0),
			size = UDim2.new(0, crosshairSettings.lineLength, 0, crosshairSettings.lineThickness)},  -- Лево
		{pos = UDim2.new(0.5, crosshairSettings.gapSize, 0.5, 0),
			size = UDim2.new(0, crosshairSettings.lineLength, 0, crosshairSettings.lineThickness)}   -- Право
	}

	for i, data in ipairs(positions) do
		-- Обводка
		if crosshairSettings.outlineTransparency < 1 then
			local outline = Instance.new("Frame")
			outline.Name = "LineOutline" .. i
			outline.Position = data.pos
			outline.Size = UDim2.new(
				data.size.X.Scale,
				data.size.X.Offset + 2,
				data.size.Y.Scale,
				data.size.Y.Offset + 2
			)
			outline.AnchorPoint = Vector2.new(0.5, 0.5)
			outline.BackgroundColor3 = crosshairSettings.outlineColor
			outline.BackgroundTransparency = crosshairSettings.outlineTransparency
			outline.BorderSizePixel = 0
			outline.ZIndex = 0
			outline.Parent = crosshairFrame
		end

		-- Основная линия
		local line = Instance.new("Frame")
		line.Name = "Line" .. i
		line.Position = data.pos
		line.Size = data.size
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.BackgroundColor3 = crosshairSettings.color
		line.BackgroundTransparency = crosshairSettings.transparency
		line.BorderSizePixel = 0
		line.ZIndex = 1
		line.Parent = crosshairFrame

		table.insert(lines, line)
	end

	return lines
end

-- Функция создания круга
local function createCircle()
	local circle = Instance.new("ImageLabel")
	circle.Name = "Circle"
	circle.Size = UDim2.new(0, crosshairSettings.size * 4, 0, crosshairSettings.size * 4)
	circle.Position = UDim2.new(0.5, 0, 0.5, 0)
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.BackgroundTransparency = 1
	circle.Image = "rbxasset://textures/ui/Circle.png"
	circle.ImageColor3 = crosshairSettings.color
	circle.ImageTransparency = crosshairSettings.transparency
	circle.Parent = crosshairFrame

	-- Внутренний круг для создания кольца
	local innerCircle = Instance.new("ImageLabel")
	innerCircle.Name = "InnerCircle"
	innerCircle.Size = UDim2.new(0.7, 0, 0.7, 0)
	innerCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
	innerCircle.AnchorPoint = Vector2.new(0.5, 0.5)
	innerCircle.BackgroundTransparency = 1
	innerCircle.Image = "rbxasset://textures/ui/Circle.png"
	innerCircle.ImageColor3 = Color3.fromRGB(0, 0, 0)
	innerCircle.ImageTransparency = 0
	innerCircle.Parent = circle

	return circle
end

-- Функция обновления прицела
local function updateCrosshair()
	-- Очищаем старый прицел
	for _, child in pairs(crosshairFrame:GetChildren()) do
		child:Destroy()
	end

	-- Создаём новый прицел в зависимости от стиля
	if crosshairSettings.style == "dot" then
		createDot()
	elseif crosshairSettings.style == "cross" then
		createCross()
	elseif crosshairSettings.style == "circle" then
		createCircle()
	elseif crosshairSettings.style == "combined" then
		createDot()
		createCross()
	end
end

-- Функция анимации прицела (для стрельбы)
local function animateCrosshair()
	if not crosshairSettings.enableAnimation then
		return
	end

	local TweenService = game:GetService("TweenService")

	-- Увеличиваем
	local expandTween = TweenService:Create(
		crosshairFrame,
		TweenInfo.new(crosshairSettings.animationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = UDim2.new(0, 100 * crosshairSettings.animationScale, 0, 100 * crosshairSettings.animationScale)}
	)

	-- Возвращаем обратно
	local contractTween = TweenService:Create(
		crosshairFrame,
		TweenInfo.new(crosshairSettings.animationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Size = UDim2.new(0, 100, 0, 100)}
	)

	expandTween:Play()
	expandTween.Completed:Connect(function()
		contractTween:Play()
	end)
end

-- Глобальные функции для управления прицелом
_G.CrosshairSettings = {
	-- Изменить стиль прицела
	setStyle = function(style)
		if style == "dot" or style == "cross" or style == "circle" or style == "combined" then
			crosshairSettings.style = style
			updateCrosshair()
		end
	end,

	-- Изменить цвет
	setColor = function(r, g, b)
		crosshairSettings.color = Color3.fromRGB(r, g, b)
		updateCrosshair()
	end,

	-- Изменить размер
	setSize = function(size)
		crosshairSettings.size = size
		updateCrosshair()
	end,

	-- Изменить прозрачность
	setTransparency = function(transparency)
		crosshairSettings.transparency = math.clamp(transparency, 0, 1)
		updateCrosshair()
	end,

	-- Показать/скрыть прицел
	setVisible = function(visible)
		screenGui.Enabled = visible
	end,

	-- Анимация выстрела
	playShootAnimation = function()
		animateCrosshair()
	end,

	-- Изменить параметры крестика
	setCrossSettings = function(gap, length, thickness)
		crosshairSettings.gapSize = gap or crosshairSettings.gapSize
		crosshairSettings.lineLength = length or crosshairSettings.lineLength
		crosshairSettings.lineThickness = thickness or crosshairSettings.lineThickness
		if crosshairSettings.style == "cross" or crosshairSettings.style == "combined" then
			updateCrosshair()
		end
	end,

	-- НОВОЕ: Изменить смещение прицела
	setOffset = function(offsetY)
		crosshairSettings.offsetY = offsetY
		crosshairFrame.Position = UDim2.new(0.5, 0, 0.5, crosshairSettings.offsetY)
	end,

	-- Получить настройки
	getSettings = function()
		return crosshairSettings
	end
}

-- Инициализация прицела
updateCrosshair()

-- Пример подключения к событию стрельбы (раскомментируй и адаптируй под свою игру)
--[[
local mouse = player:GetMouse()
mouse.Button1Down:Connect(function()
    _G.CrosshairSettings.playShootAnimation()
end)
--]]
