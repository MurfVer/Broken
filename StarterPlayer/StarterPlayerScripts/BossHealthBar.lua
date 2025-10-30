-- LocalScript для управления Health Bar босса
-- Поместить в StarterPlayer → StarterPlayerScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Ждём загрузки UI
local bossUI = playerGui:WaitForChild("Boss fight")
local ramkahp = bossUI:WaitForChild("ramkahp")
local hpBar = ramkahp:WaitForChild("hp")

-- RemoteEvent для получения данных от сервера
local bossHealthEvent = ReplicatedStorage:WaitForChild("BossHealthEvent")

-- ========================
-- НАСТРОЙКИ АНИМАЦИЙ
-- ========================
local ANIMATION_CONFIG = {
	-- Скорость изменения HP бара
	HP_TWEEN_TIME = 0.4,
	HP_TWEEN_STYLE = Enum.EasingStyle.Quad,
	HP_TWEEN_DIRECTION = Enum.EasingDirection.Out,

	-- Появление UI
	FADE_IN_TIME = 0.6,

	-- Мигание при уроне
	DAMAGE_FLASH_TIME = 0.15,
	DAMAGE_FLASH_COLOR = Color3.fromRGB(255, 100, 100), -- Красноватый цвет
}

-- ========================
-- ПЕРЕМЕННЫЕ СОСТОЯНИЯ
-- ========================
local maxHealth = 100
local currentHealth = 100
local isUIVisible = false
local currentTween = nil

-- Сохраняем оригинальный цвет HP бара
local originalColor = hpBar.BackgroundColor3

-- ========================
-- ФУНКЦИИ АНИМАЦИИ
-- ========================

-- Плавное появление UI
local function fadeInUI()
	if isUIVisible then return end
	isUIVisible = true

	-- Делаем UI видимым
	bossUI.Enabled = true
	ramkahp.Visible = true

	-- Начинаем с прозрачности
	ramkahp.BackgroundTransparency = 1
	hpBar.BackgroundTransparency = 1

	-- Анимация появления
	local fadeInTween = TweenService:Create(
		ramkahp,
		TweenInfo.new(ANIMATION_CONFIG.FADE_IN_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{BackgroundTransparency = 0}
	)

	local fadeInTweenHP = TweenService:Create(
		hpBar,
		TweenInfo.new(ANIMATION_CONFIG.FADE_IN_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{BackgroundTransparency = 0}
	)

	fadeInTween:Play()
	fadeInTweenHP:Play()

	warn("✅ Health Bar появился!")
end

-- Плавное исчезновение UI
local function fadeOutUI()
	if not isUIVisible then return end

	local fadeOutTween = TweenService:Create(
		ramkahp,
		TweenInfo.new(ANIMATION_CONFIG.FADE_IN_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{BackgroundTransparency = 1}
	)

	local fadeOutTweenHP = TweenService:Create(
		hpBar,
		TweenInfo.new(ANIMATION_CONFIG.FADE_IN_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{BackgroundTransparency = 1}
	)

	fadeOutTween:Play()
	fadeOutTweenHP:Play()

	fadeOutTween.Completed:Connect(function()
		bossUI.Enabled = false
		ramkahp.Visible = false
		isUIVisible = false
	end)

	warn("❌ Health Bar исчез!")
end

-- Мигание при получении урона
local function flashDamage()
	-- Быстро меняем цвет на красноватый
	local flashTween = TweenService:Create(
		hpBar,
		TweenInfo.new(ANIMATION_CONFIG.DAMAGE_FLASH_TIME, Enum.EasingStyle.Linear),
		{BackgroundColor3 = ANIMATION_CONFIG.DAMAGE_FLASH_COLOR}
	)

	flashTween:Play()

	-- Возвращаем обратно
	flashTween.Completed:Connect(function()
		local returnTween = TweenService:Create(
			hpBar,
			TweenInfo.new(ANIMATION_CONFIG.DAMAGE_FLASH_TIME, Enum.EasingStyle.Linear),
			{BackgroundColor3 = originalColor}
		)
		returnTween:Play()
	end)
end

-- Обновление HP бара (уменьшение справа налево)
local function updateHealthBar(newHealth, maxHP)
	-- Вычисляем процент здоровья
	local healthPercent = math.clamp(newHealth / maxHP, 0, 1)

	-- Останавливаем предыдущую анимацию если есть
	if currentTween then
		currentTween:Cancel()
	end

	-- Вычисляем новый размер и позицию
	-- При AnchorPoint (0.5, 0.5) и уменьшении справа налево:
	local newSizeX = healthPercent
	local newPositionX = 0.5 - (1 - healthPercent) / 2

	-- Создаём анимацию изменения размера и позиции
	currentTween = TweenService:Create(
		hpBar,
		TweenInfo.new(
			ANIMATION_CONFIG.HP_TWEEN_TIME,
			ANIMATION_CONFIG.HP_TWEEN_STYLE,
			ANIMATION_CONFIG.HP_TWEEN_DIRECTION
		),
		{
			Size = UDim2.new(newSizeX, 0, 1, 0),
			Position = UDim2.new(newPositionX, 0, 0.5, 0)
		}
	)

	currentTween:Play()

	-- Выводим информацию в консоль
	warn(string.format("💚 HP: %.0f / %.0f (%.1f%%)", newHealth, maxHP, healthPercent * 100))
end

-- ========================
-- ОБРАБОТЧИКИ СОБЫТИЙ
-- ========================

-- Получаем события от сервера
bossHealthEvent.OnClientEvent:Connect(function(eventType, data)

	if eventType == "BossSpawned" then
		-- Босс заспавнился
		warn("🔥 БОСС ПОЯВИЛСЯ: " .. data.BossName)

		maxHealth = data.MaxHealth
		currentHealth = data.CurrentHealth

		-- Сбрасываем HP бар на полное значение
		hpBar.Size = UDim2.new(1, 0, 1, 0)
		hpBar.Position = UDim2.new(0.5, 0, 0.5, 0)
		hpBar.BackgroundColor3 = originalColor

		-- Плавно показываем UI
		fadeInUI()

	elseif eventType == "HealthChanged" then
		-- Здоровье изменилось
		local oldHealth = currentHealth
		currentHealth = data.CurrentHealth

		-- Обновляем бар
		updateHealthBar(currentHealth, maxHealth)

		-- Если получен урон (здоровье уменьшилось) - мигаем
		if currentHealth < oldHealth then
			flashDamage()
		end

	elseif eventType == "BossDied" then
		-- Босс умер
		warn("💀 БОСС ПОБЕЖДЁН!")

		-- Устанавливаем HP на 0
		updateHealthBar(0, maxHealth)

		-- Через 2 секунды убираем UI
		wait(2)
		fadeOutUI()
	end

end)

-- ========================
-- ИНИЦИАЛИЗАЦИЯ
-- ========================

-- Прячем UI в начале
bossUI.Enabled = false
ramkahp.Visible = false

warn("✅ Boss Health Bar система инициализирована!")
warn("⚡ Ожидание появления босса...")
