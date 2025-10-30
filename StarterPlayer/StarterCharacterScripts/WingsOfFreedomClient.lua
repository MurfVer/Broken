-- =====================================
-- WINGS OF FREEDOM - DOUBLE JUMP SYSTEM (WORKING)
-- Place in StarterPlayer.StarterCharacterScripts as LocalScript
-- =====================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- ========================
-- КОНФИГУРАЦИЯ
-- ========================
local CONFIG = {
	JUMP_POWER = 50,
	JUMP_COOLDOWN = 0.3,
	GROUND_CHECK_DISTANCE = 4,
}

-- ========================
-- СОСТОЯНИЕ
-- ========================
local jumpState = {
	maxJumps = 1,
	jumpsUsed = 0,
	isGrounded = true,
	lastJumpTime = 0,
	jumpRequested = false,
}

-- ========================
-- ПОЛУЧИТЬ КОЛИЧЕСТВО КРЫЛЬЕВ (ИСПРАВЛЕНО!)
-- ========================
local function getWingsStacks()
	-- ✅ ИСПРАВЛЕНО: Ищем просто "DoubleJump" без суффикса
	local stacks = character:FindFirstChild("DoubleJump")
	if stacks and stacks:IsA("NumberValue") then
		return stacks.Value, stacks
	end

	return 0, nil
end

-- ========================
-- ОБНОВИТЬ МАКСИМУМ ПРЫЖКОВ
-- ========================
local function updateMaxJumps()
	local stacks, stacksValue = getWingsStacks()

	if stacks > 0 then
		jumpState.maxJumps = 1 + stacks
		print("🪽 [WINGS] Max jumps: " .. jumpState.maxJumps .. " (1 base + " .. stacks .. " extra)")
	else
		jumpState.maxJumps = 1
	end

	return stacksValue
end

-- ========================
-- ПРОВЕРКА ЗЕМЛИ
-- ========================
local function checkGrounded()
	local rayOrigin = rootPart.Position
	local rayDirection = Vector3.new(0, -CONFIG.GROUND_CHECK_DISTANCE, 0)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {character}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	return rayResult ~= nil
end

-- ========================
-- ВЫПОЛНИТЬ ДОПОЛНИТЕЛЬНЫЙ ПРЫЖОК
-- ========================
local function performAirJump()
	local currentTime = tick()

	if currentTime - jumpState.lastJumpTime < CONFIG.JUMP_COOLDOWN then
		return false
	end

	if jumpState.jumpsUsed >= jumpState.maxJumps then
		return false
	end

	local stacks = getWingsStacks()
	if stacks == 0 then
		return false
	end

	jumpState.jumpsUsed = jumpState.jumpsUsed + 1
	jumpState.lastJumpTime = currentTime

	local velocity = rootPart.AssemblyLinearVelocity
	rootPart.AssemblyLinearVelocity = Vector3.new(velocity.X, CONFIG.JUMP_POWER, velocity.Z)

	print("🪽 [WINGS] ✨ AIR JUMP #" .. jumpState.jumpsUsed .. "/" .. jumpState.maxJumps)

	showJumpEffect(jumpState.jumpsUsed)
	return true
end

-- ========================
-- ВИЗУАЛЬНЫЙ ЭФФЕКТ
-- ========================
function showJumpEffect(jumpNumber)
	local effect = Instance.new("Part")
	effect.Anchored = true
	effect.CanCollide = false
	effect.Material = Enum.Material.Neon
	effect.Color = Color3.fromRGB(255, 215, 0)
	effect.Size = Vector3.new(0.5, 0.5, 0.5)
	effect.Shape = Enum.PartType.Ball
	effect.Transparency = 0.3
	effect.CFrame = rootPart.CFrame * CFrame.new(0, -2, 0)
	effect.Parent = workspace

	local tween = game:GetService("TweenService"):Create(
		effect,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = Vector3.new(4, 0.2, 4),
			Transparency = 1
		}
	)
	tween:Play()

	if jumpNumber > 1 then
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://158149887"
		sound.Volume = 0.4 + (jumpNumber * 0.15)
		sound.Pitch = 1 + (jumpNumber * 0.2)
		sound.Parent = rootPart
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 1)
	end

	game:GetService("Debris"):AddItem(effect, 0.5)
end

-- ========================
-- ОБРАБОТКА СОСТОЯНИЙ
-- ========================
humanoid.StateChanged:Connect(function(oldState, newState)
	if newState == Enum.HumanoidStateType.Landed then
		jumpState.isGrounded = true
		jumpState.jumpsUsed = 0
		print("🪽 [WINGS] Landed! Jumps reset (" .. jumpState.maxJumps .. " available)")
	end

	if newState == Enum.HumanoidStateType.Freefall or newState == Enum.HumanoidStateType.Jumping then
		if jumpState.isGrounded then
			jumpState.isGrounded = false
			jumpState.jumpsUsed = 1
			print("🪽 [WINGS] Base jump (#1/" .. jumpState.maxJumps .. ")")
		end
	end
end)

-- ========================
-- ОБРАБОТКА ВВОДА
-- ========================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Space then
		jumpState.jumpRequested = true
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Space then
		jumpState.jumpRequested = false
	end
end)

-- ========================
-- ОСНОВНОЙ ЦИКЛ
-- ========================
RunService.Heartbeat:Connect(function()
	local grounded = checkGrounded()

	if jumpState.isGrounded and not grounded and rootPart.AssemblyLinearVelocity.Y < -5 then
		jumpState.isGrounded = false
		jumpState.jumpsUsed = 1
	end

	if jumpState.jumpRequested and not jumpState.isGrounded then
		local stacks = getWingsStacks()
		if stacks > 0 and jumpState.jumpsUsed < jumpState.maxJumps then
			if performAirJump() then
				jumpState.jumpRequested = false
			end
		end
	end

	if not jumpState.isGrounded and grounded and rootPart.AssemblyLinearVelocity.Y <= 0 then
		jumpState.isGrounded = true
		jumpState.jumpsUsed = 0
	end
end)

-- ========================
-- ОТСЛЕЖИВАНИЕ ИЗМЕНЕНИЙ СТАКОВ
-- ========================
local function setupStacksListener()
	local stacksValue = character:FindFirstChild("DoubleJump")

	if stacksValue and stacksValue:IsA("NumberValue") then
		print("🪽 [WINGS] Connected to DoubleJump listener!")
		stacksValue.Changed:Connect(function()
			print("🪽 [WINGS] Stacks changed to: " .. stacksValue.Value)
			updateMaxJumps()
		end)
		updateMaxJumps()
	else
		print("🪽 [WINGS] Waiting for DoubleJump value...")
		character.ChildAdded:Connect(function(child)
			if child.Name == "DoubleJump" and child:IsA("NumberValue") then
				print("🪽 [WINGS] DoubleJump value detected!")
				task.wait(0.1)
				child.Changed:Connect(function()
					print("🪽 [WINGS] Stacks changed to: " .. child.Value)
					updateMaxJumps()
				end)
				updateMaxJumps()
			end
		end)
	end
end

-- ========================
-- ИНИЦИАЛИЗАЦИЯ
-- ========================
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("🪽 [WINGS OF FREEDOM] Loaded!")
print("   Press SPACE in air for extra jumps")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

task.wait(0.5)
setupStacksListener()
updateMaxJumps()
