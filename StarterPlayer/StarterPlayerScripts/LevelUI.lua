-- =====================================
-- LEVEL UI - КЛИЕНТСКАЯ ЧАСТЬ
-- Place in StarterPlayer.StarterPlayerScripts
-- ✅ FIXED: Правильные коэффициенты HP (30%) и урона (20%)
-- =====================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Ждём RemoteEvent
local levelUpEvent = ReplicatedStorage:WaitForChild("LevelUpEvent", 10)

-- =====================================
-- КОНСТАНТЫ (должны совпадать с сервером!)
-- =====================================
local HP_BONUS_PER_LEVEL = 0.30   -- ✅ FIXED: было 0.1, теперь 0.30 (30%)
local DAMAGE_BONUS_PER_LEVEL = 0.20  -- ✅ FIXED: было 0.1, теперь 0.20 (20%)
local BASE_EXP_REQUIREMENT = 30
local EXP_SCALING = 1.5

-- =====================================
-- СОЗДАНИЕ UI
-- =====================================
local function createLevelUI()
	-- Проверяем, не существует ли уже UI
	if playerGui:FindFirstChild("LevelUI") then
		playerGui.LevelUI:Destroy()
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LevelUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Главный фрейм
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.new(0, 350, 0, 80)
	mainFrame.Position = UDim2.new(0, 20, 0, 20)
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	mainFrame.BackgroundTransparency = 0.3
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = screenGui

	-- Закругление углов
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = mainFrame

	-- Обводка
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(100, 100, 120)
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Parent = mainFrame

	-- Заголовок (TEAM LEVEL)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -20, 0, 25)
	titleLabel.Position = UDim2.new(0, 10, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "⭐ TEAM LEVEL 1"
	titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
	titleLabel.TextSize = 18
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = mainFrame

	-- Прогресс бар (фон)
	local progressBg = Instance.new("Frame")
	progressBg.Name = "ProgressBg"
	progressBg.Size = UDim2.new(1, -20, 0, 20)
	progressBg.Position = UDim2.new(0, 10, 0, 38)
	progressBg.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
	progressBg.BorderSizePixel = 0
	progressBg.Parent = mainFrame

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 8)
	progressCorner.Parent = progressBg

	-- Прогресс бар (заполнение)
	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 8)
	fillCorner.Parent = progressFill

	-- Градиент для прогресс бара
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 150, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 100, 255))
	}
	gradient.Parent = progressFill

	-- Текст прогресса (EXP)
	local expLabel = Instance.new("TextLabel")
	expLabel.Name = "ExpLabel"
	expLabel.Size = UDim2.new(1, 0, 1, 0)
	expLabel.BackgroundTransparency = 1
	expLabel.Text = "0 / 30 EXP"
	expLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	expLabel.TextSize = 14
	expLabel.Font = Enum.Font.GothamBold
	expLabel.TextStrokeTransparency = 0.5
	expLabel.Parent = progressBg

	-- Бонусы (под прогресс баром)
	local bonusLabel = Instance.new("TextLabel")
	bonusLabel.Name = "BonusLabel"
	bonusLabel.Size = UDim2.new(1, -20, 0, 15)
	bonusLabel.Position = UDim2.new(0, 10, 0, 62)
	bonusLabel.BackgroundTransparency = 1
	bonusLabel.Text = "💚 HP: x1.00  |  🗡️ DMG: x1.00"
	bonusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	bonusLabel.TextSize = 12
	bonusLabel.Font = Enum.Font.Gotham
	bonusLabel.TextXAlignment = Enum.TextXAlignment.Left
	bonusLabel.Parent = mainFrame

	screenGui.Parent = playerGui

	return {
		MainFrame = mainFrame,
		TitleLabel = titleLabel,
		ProgressFill = progressFill,
		ExpLabel = expLabel,
		BonusLabel = bonusLabel
	}
end

-- =====================================
-- ОБНОВЛЕНИЕ UI
-- =====================================
local ui = createLevelUI()

local function updateUI(level, exp, requiredExp, healthBonus, damageBonus)
	if not ui or not ui.MainFrame.Parent then
		ui = createLevelUI()
	end

	-- Обновляем заголовок
	ui.TitleLabel.Text = "⭐ TEAM LEVEL " .. level

	-- Обновляем прогресс бар
	local progress = math.clamp(exp / requiredExp, 0, 1)

	local tween = TweenService:Create(
		ui.ProgressFill,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = UDim2.new(progress, 0, 1, 0)}
	)
	tween:Play()

	-- Обновляем текст опыта
	ui.ExpLabel.Text = exp .. " / " .. requiredExp .. " EXP"

	-- Обновляем бонусы
	ui.BonusLabel.Text = string.format(
		"💚 HP: x%.2f  |  🗡️ DMG: x%.2f",
		healthBonus or 1,
		damageBonus or 1
	)
end

-- =====================================
-- ЭФФЕКТ ПОВЫШЕНИЯ УРОВНЯ
-- =====================================
local function playLevelUpEffect()
	-- Создаём временный эффект
	local effect = Instance.new("Frame")
	effect.Name = "LevelUpEffect"
	effect.Size = UDim2.new(0, 400, 0, 100)
	effect.Position = UDim2.new(0.5, -200, 0.3, 0)
	effect.BackgroundTransparency = 1
	effect.Parent = playerGui.LevelUI

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "⭐ LEVEL UP! ⭐"
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.TextSize = 36
	label.Font = Enum.Font.GothamBlack
	label.TextTransparency = 1
	label.TextStrokeTransparency = 0.5
	label.Parent = effect

	-- Анимация появления
	local appearTween = TweenService:Create(
		label,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{TextTransparency = 0, TextSize = 48}
	)
	appearTween:Play()

	-- Анимация исчезновения
	wait(1.5)
	local fadeTween = TweenService:Create(
		label,
		TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{TextTransparency = 1, Position = UDim2.new(0, 0, 0, -50)}
	)
	fadeTween:Play()

	wait(0.5)
	effect:Destroy()

	-- Звук повышения уровня
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://5153944712"
	sound.Volume = 0.5
	sound.Parent = game.SoundService
	sound:Play()
	game.Debris:AddItem(sound, 2)
end

-- =====================================
-- ПОЛУЧЕНИЕ ДАННЫХ ИЗ LEADERBOARD
-- =====================================
local function updateFromLeaderboard()
	local leaderstats = player:WaitForChild("leaderstats", 5)
	if not leaderstats then return end

	local level = leaderstats:FindFirstChild("Level")
	local exp = leaderstats:FindFirstChild("EXP")

	if not level or not exp then return end

	-- Рассчитываем требуемый опыт (совпадает с сервером)
	local requiredExp = BASE_EXP_REQUIREMENT * (EXP_SCALING ^ (level.Value - 1))
	requiredExp = math.floor(requiredExp)

	-- ✅ FIXED: Правильные бонусы (30% HP, 20% урон)
	local healthBonus = 1 + ((level.Value - 1) * HP_BONUS_PER_LEVEL)
	local damageBonus = 1 + ((level.Value - 1) * DAMAGE_BONUS_PER_LEVEL)

	updateUI(level.Value, exp.Value, requiredExp, healthBonus, damageBonus)

	-- Отслеживаем изменения
	level.Changed:Connect(function(newLevel)
		requiredExp = BASE_EXP_REQUIREMENT * (EXP_SCALING ^ (newLevel - 1))
		requiredExp = math.floor(requiredExp)

		-- ✅ FIXED: Правильные бонусы при изменении уровня
		healthBonus = 1 + ((newLevel - 1) * HP_BONUS_PER_LEVEL)
		damageBonus = 1 + ((newLevel - 1) * DAMAGE_BONUS_PER_LEVEL)

		updateUI(newLevel, exp.Value, requiredExp, healthBonus, damageBonus)
	end)

	exp.Changed:Connect(function(newExp)
		updateUI(level.Value, newExp, requiredExp, healthBonus, damageBonus)
	end)
end

-- =====================================
-- ОБРАБОТКА СОБЫТИЙ СЕРВЕРА
-- =====================================
if levelUpEvent then
	levelUpEvent.OnClientEvent:Connect(function(data)
		playLevelUpEffect()

		updateUI(
			data.Level,
			data.Experience,
			data.RequiredExp,
			data.HealthBonus,
			data.DamageBonus
		)
	end)
end

-- =====================================
-- ИНИЦИАЛИЗАЦИЯ
-- =====================================
wait(1)
updateFromLeaderboard()

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ Level UI loaded! (FIXED VERSION)")
print("   UI position: Top-left corner")
print("   Tracking team progress")
print("   ✅ HP Bonus: +" .. (HP_BONUS_PER_LEVEL * 100) .. "% per level")
print("   ✅ Damage Bonus: +" .. (DAMAGE_BONUS_PER_LEVEL * 100) .. "% per level")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
