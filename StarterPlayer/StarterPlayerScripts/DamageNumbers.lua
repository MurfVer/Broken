-- =====================================
-- DAMAGE NUMBERS CLIENT
-- Отображение урона только для игрока
-- =====================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ShowDamageEvent = ReplicatedStorage:WaitForChild("ShowDamageNumber")

local function createDamageNumber(position, damage)
	-- Создаём BillboardGui (меньше размером)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 30, 0, 15) -- Уменьшен размер
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = workspace

	-- Привязываем к позиции
	local attachment = Instance.new("Attachment")
	attachment.Position = position
	attachment.Parent = workspace.Terrain
	billboard.Adornee = attachment

	-- Создаём текст
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = "-" .. tostring(math.floor(damage))
	textLabel.TextColor3 = Color3.new(1, 1, 1) -- Белый
	textLabel.TextStrokeTransparency = 0 -- Черная обводка (видимая)
	textLabel.TextStrokeColor3 = Color3.new(0, 0, 0) -- Черный цвет обводки
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.Parent = billboard

	-- НОВОЕ: Рандомное направление разлета
	local randomX = math.random(-20, 20) / 10 -- От -2 до 2
	local randomZ = math.random(-20, 20) / 10 -- От -2 до 2
	local randomY = math.random(15, 30) / 10   -- От 1.5 до 3 (вверх)

	-- Анимация: летит в рандомном направлении и исчезает
	local tweenInfo = TweenInfo.new(
		1, -- Длительность
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(billboard, tweenInfo, {
		StudsOffset = Vector3.new(randomX, randomY + 3, randomZ)
	})

	local fadeTween = TweenService:Create(textLabel, tweenInfo, {
		TextTransparency = 1,
		TextStrokeTransparency = 1
	})

	tween:Play()
	fadeTween:Play()

	-- Удаляем после анимации
	task.delay(1, function()
		billboard:Destroy()
		attachment:Destroy()
	end)
end

-- Слушаем событие (когда МЫ наносим урон NPC)
ShowDamageEvent.OnClientEvent:Connect(function(npcPosition, damage)
	createDamageNumber(npcPosition, damage)
end)

print("✅ Damage Numbers Client загружен (показывает урон ПО NPC)")
