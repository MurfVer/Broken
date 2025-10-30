local UIS = game:GetService("UserInputService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local rs = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local BACK_POSITION_X = 0
local BACK_POSITION_Y = 0.5
local BACK_POSITION_Z = 1
local BACK_ANGLE_PITCH = 30
local BACK_ANGLE_YAW = 0
local BACK_ANGLE_ROLL = 45
local SHOW_HANDLE_ON_BACK = false
local SHOW_HANDLE_IN_HANDS = false
local THROW_ANIMATION_ID = "rbxassetid://106916438821764"
local SHOW_WEAPON_DELAY_BEFORE_THROW = 0.2
local HIDE_WEAPON_DELAY_AFTER_THROW = 0.7
local HIDE_BACK_DELAY_ON_THROW = 0.2
local ABILITY_CAST_DELAY = 0.5
local CATCH_ANIMATION_ID = "rbxassetid://94320235737265"
local SHOW_BACK_DELAY_AFTER_CATCH = -0.3

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

task.wait(0.5)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

if not rs:FindFirstChild("PhantomScythe") then
	Instance.new("RemoteEvent", rs).Name = "PhantomScythe"
end

local remote = rs.PhantomScythe
local effectsFolder = rs:FindFirstChild("PhantomScytheEffects")
local scytheProjectileTemplate = effectsFolder and effectsFolder:FindFirstChild("ScytheProjectile")
local scytheImpactTemplate = effectsFolder and effectsFolder:FindFirstChild("ScytheImpact")
local useCustomEffects = (scytheProjectileTemplate and scytheImpactTemplate)

local SCYTHE_SPEED = 80
local COOLDOWN = 7
local lastThrowTime = 0

local weaponTemplate = rs:FindFirstChild("Weapon")
local weaponTool, backScythe, backScytheWeld, throwAnimTrack, catchAnimTrack

local function setupBackScythe()
	if not weaponTemplate then return false end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso then return false end

	local weaponClone = weaponTemplate:Clone()
	backScythe = Instance.new("Model")
	backScythe.Name = "BackScythe"
	backScythe.Parent = character

	for _, child in pairs(weaponClone:GetChildren()) do
		child.Parent = backScythe
	end
	weaponClone:Destroy()

	local handle = backScythe:FindFirstChild("Handle")
	if not handle then
		backScythe:Destroy()
		return false
	end

	for _, part in pairs(backScythe:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			part.Anchored = false
			part.Transparency = (part.Name == "Handle" and not SHOW_HANDLE_ON_BACK) and 1 or 0
		end
	end

	backScytheWeld = Instance.new("Weld")
	backScytheWeld.Name = "BackScytheWeld"
	backScytheWeld.Part0 = torso
	backScytheWeld.Part1 = handle
	backScytheWeld.C0 = CFrame.new(BACK_POSITION_X, BACK_POSITION_Y, BACK_POSITION_Z) * CFrame.Angles(math.rad(BACK_ANGLE_PITCH), math.rad(BACK_ANGLE_YAW), math.rad(BACK_ANGLE_ROLL))
	backScytheWeld.C1 = CFrame.new(0, 0, 0)
	backScytheWeld.Parent = handle
	return true
end

local function hideBackScythe()
	if not backScythe then return end
	for _, part in pairs(backScythe:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end
end

local function showBackScythe()
	if not backScythe then return end
	for _, part in pairs(backScythe:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = (part.Name == "Handle" and not SHOW_HANDLE_ON_BACK) and 1 or 0
		end
	end
end

local function setupInvisibleTool()
	if not weaponTemplate then return false end
	weaponTool = weaponTemplate:Clone()
	weaponTool.CanBeDropped = false
	weaponTool.Parent = player.Backpack

	for _, part in pairs(weaponTool:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end
	return true
end

task.wait(0.5)
setupBackScythe()
setupInvisibleTool()

local function equipWeaponQuickly()
	if not weaponTool then return false end
	if weaponTool.Parent == player.Backpack then
		humanoid:EquipTool(weaponTool)
		return true
	elseif weaponTool.Parent == character then
		return true
	end
	return false
end

local function unequipWeaponQuickly()
	if weaponTool and weaponTool.Parent == character then
		humanoid:UnequipTools()
	end
end

local function showWeaponInHands()
	if not weaponTool then return end
	for _, part in pairs(weaponTool:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = (part.Name == "Handle" and not SHOW_HANDLE_IN_HANDS) and 1 or 0
		end
	end
end

local function hideWeaponInHands()
	if not weaponTool then return end
	for _, part in pairs(weaponTool:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end
end

local function playThrowAnimation()
	if not humanoid or humanoid.Health <= 0 then return end

	if HIDE_BACK_DELAY_ON_THROW < 0 then
		task.wait(math.abs(HIDE_BACK_DELAY_ON_THROW))
		hideBackScythe()
	elseif HIDE_BACK_DELAY_ON_THROW == 0 then
		hideBackScythe()
	end

	if not equipWeaponQuickly() then return end
	task.wait(0.05)

	if SHOW_WEAPON_DELAY_BEFORE_THROW < 0 then
		showWeaponInHands()
	elseif SHOW_WEAPON_DELAY_BEFORE_THROW == 0 then
		showWeaponInHands()
	end

	if THROW_ANIMATION_ID ~= "" then
		if throwAnimTrack then
			throwAnimTrack:Stop()
			task.wait(0.05)
			throwAnimTrack = nil
		end

		local throwAnim = Instance.new("Animation")
		throwAnim.AnimationId = THROW_ANIMATION_ID

		local success, result = pcall(function()
			return humanoid:LoadAnimation(throwAnim)
		end)

		if success then
			throwAnimTrack = result
			throwAnimTrack.Priority = Enum.AnimationPriority.Action4
			throwAnimTrack.Looped = false

			if SHOW_WEAPON_DELAY_BEFORE_THROW > 0 then
				task.delay(SHOW_WEAPON_DELAY_BEFORE_THROW, showWeaponInHands)
			end

			if HIDE_WEAPON_DELAY_AFTER_THROW >= 0 then
				task.delay(HIDE_WEAPON_DELAY_AFTER_THROW, hideWeaponInHands)
			else
				local hideTime = throwAnimTrack.Length + HIDE_WEAPON_DELAY_AFTER_THROW
				if hideTime > 0 then
					task.delay(hideTime, hideWeaponInHands)
				end
			end

			if HIDE_BACK_DELAY_ON_THROW > 0 then
				task.delay(HIDE_BACK_DELAY_ON_THROW, hideBackScythe)
			end

			throwAnimTrack:Play()

			throwAnimTrack.Stopped:Connect(function()
				task.wait(0.1)
				hideWeaponInHands()
				unequipWeaponQuickly()
				throwAnim:Destroy()
				throwAnimTrack = nil
			end)
		else
			hideWeaponInHands()
			unequipWeaponQuickly()
		end
	else
		if SHOW_WEAPON_DELAY_BEFORE_THROW >= 0 then
			task.wait(SHOW_WEAPON_DELAY_BEFORE_THROW)
			showWeaponInHands()
		else
			showWeaponInHands()
		end

		if HIDE_WEAPON_DELAY_AFTER_THROW >= 0 then
			task.wait(HIDE_WEAPON_DELAY_AFTER_THROW)
		end

		hideWeaponInHands()
		unequipWeaponQuickly()

		if HIDE_BACK_DELAY_ON_THROW > 0 then
			task.wait(HIDE_BACK_DELAY_ON_THROW)
		end
		hideBackScythe()
	end
end

local function playCatchAnimation()
	if not humanoid or humanoid.Health <= 0 then return end
	if not equipWeaponQuickly() then
		if SHOW_BACK_DELAY_AFTER_CATCH >= 0 then
			task.wait(SHOW_BACK_DELAY_AFTER_CATCH)
		end
		showBackScythe()
		return
	end

	task.wait(0.05)
	showWeaponInHands()

	if catchAnimTrack then
		catchAnimTrack:Stop()
		task.wait(0.05)
		catchAnimTrack = nil
	end

	local catchAnim = Instance.new("Animation")
	catchAnim.AnimationId = CATCH_ANIMATION_ID

	local success, result = pcall(function()
		return humanoid:LoadAnimation(catchAnim)
	end)

	if not success then
		hideWeaponInHands()
		unequipWeaponQuickly()
		if SHOW_BACK_DELAY_AFTER_CATCH >= 0 then
			task.wait(SHOW_BACK_DELAY_AFTER_CATCH)
		end
		showBackScythe()
		return
	end

	catchAnimTrack = result
	catchAnimTrack.Priority = Enum.AnimationPriority.Action4
	catchAnimTrack.Looped = false

	if SHOW_BACK_DELAY_AFTER_CATCH < 0 then
		local showTime = catchAnimTrack.Length + SHOW_BACK_DELAY_AFTER_CATCH
		if showTime > 0 then
			task.delay(showTime, function()
				hideWeaponInHands()
				task.wait(0.05)
				unequipWeaponQuickly()
				showBackScythe()
			end)
		end
	end

	catchAnimTrack:Play()

	catchAnimTrack.Stopped:Connect(function()
		if SHOW_BACK_DELAY_AFTER_CATCH >= 0 then
			task.wait(0.2)
			hideWeaponInHands()
			task.wait(0.05)
			unequipWeaponQuickly()
			task.wait(SHOW_BACK_DELAY_AFTER_CATCH)
			showBackScythe()
		end
		catchAnim:Destroy()
		catchAnimTrack = nil
	end)
end

local function createScytheVisual(startPos, targetPos)
	if not useCustomEffects or not scytheProjectileTemplate then return nil end

	local scythe = scytheProjectileTemplate:Clone()

	if scythe:IsA("Model") then
		if not scythe.PrimaryPart then
			local biggestPart, biggestVolume = nil, 0
			for _, child in pairs(scythe:GetDescendants()) do
				if child:IsA("BasePart") then
					local volume = child.Size.X * child.Size.Y * child.Size.Z
					if volume > biggestVolume then
						biggestVolume = volume
						biggestPart = child
					end
				end
			end
			if not biggestPart then return nil end
			scythe.PrimaryPart = biggestPart
		end

		for _, part in pairs(scythe:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		scythe:SetPrimaryPartCFrame(CFrame.new(startPos))
	else
		scythe.CFrame = CFrame.new(startPos)
		scythe.Anchored = true
		scythe.CanCollide = false
	end

	scythe.Parent = workspace

	for _, desc in pairs(scythe:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then desc.Enabled = true end
		if desc:IsA("Trail") then desc.Enabled = true end
		if desc:IsA("PointLight") or desc:IsA("SpotLight") then desc.Enabled = true end
	end

	return scythe
end

local function animateScytheThrow(scythe, startPos, targetRoot)
	if not scythe then return end

	task.spawn(function()
		local isModel = scythe:IsA("Model")
		local targetPos = targetRoot.Position + Vector3.new(0, 2, 0)
		local currentPos = startPos
		local startTime = tick()

		while tick() - startTime < 3 and scythe.Parent do
			if not targetRoot.Parent then break end

			targetPos = targetRoot.Position + Vector3.new(0, 2, 0)
			local direction = (targetPos - currentPos).Unit
			local distance = (targetPos - currentPos).Magnitude

			if distance < 3 then break end

			local dt = task.wait()
			local moveDistance = SCYTHE_SPEED * dt
			currentPos = currentPos + (direction * moveDistance)

			local lookCFrame = CFrame.new(currentPos, targetPos)
			local rotation = (tick() - startTime) * 1200

			local rotatedCFrame = lookCFrame * CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, 0, math.rad(rotation))

			if isModel then
				pcall(function()
					scythe:SetPrimaryPartCFrame(rotatedCFrame)
				end)
			else
				scythe.CFrame = rotatedCFrame
			end
		end

		for _, desc in pairs(scythe:GetDescendants()) do
			if desc:IsA("ParticleEmitter") then desc.Enabled = false end
			if desc:IsA("Trail") then desc.Enabled = false end
		end

		if isModel then
			for _, part in pairs(scythe:GetDescendants()) do
				if part:IsA("BasePart") then
					TweenService:Create(part, TweenInfo.new(0.2), {Transparency = 1}):Play()
				end
			end
		else
			TweenService:Create(scythe, TweenInfo.new(0.2), {Transparency = 1}):Play()
		end

		task.wait(0.3)
		scythe:Destroy()
	end)
end

local function animateScytheBounce(startPos, bounceTargets, playerRoot)
	if not useCustomEffects or not scytheProjectileTemplate or not bounceTargets or #bounceTargets == 0 then return end

	task.spawn(function()
		local scythe = createScytheVisual(startPos)
		if not scythe then return end

		local isModel = scythe:IsA("Model")
		local currentPos = startPos

		for i, target in ipairs(bounceTargets) do
			if not target or not target.Parent then break end

			local targetPos = target.Position + Vector3.new(0, 2, 0)
			local startBounceTime = tick()

			while tick() - startBounceTime < 1 and scythe.Parent do
				if not target.Parent then break end

				targetPos = target.Position + Vector3.new(0, 2, 0)
				local direction = (targetPos - currentPos).Unit
				local distance = (targetPos - currentPos).Magnitude

				if distance < 2 then
					currentPos = targetPos
					break
				end

				local dt = task.wait()
				local moveDistance = (SCYTHE_SPEED * 2) * dt
				currentPos = currentPos + (direction * moveDistance)

				local lookCFrame = CFrame.new(currentPos, targetPos)
				local rotation = (tick() - startBounceTime) * 1500

				local rotatedCFrame = lookCFrame * CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, 0, math.rad(rotation))

				if isModel then
					pcall(function()
						scythe:SetPrimaryPartCFrame(rotatedCFrame)
					end)
				else
					scythe.CFrame = rotatedCFrame
				end
			end
		end

		local returnStartTime = tick()
		local animationPlayed = false

		while tick() - returnStartTime < 5 and scythe.Parent do
			if not playerRoot or not playerRoot.Parent then break end

			local playerCurrentPos = playerRoot.Position + Vector3.new(0, 2, 0)
			local direction = (playerCurrentPos - currentPos).Unit
			local distance = (playerCurrentPos - currentPos).Magnitude

			if distance < 10 and not animationPlayed then
				playCatchAnimation()
				animationPlayed = true
			end

			if distance < 3 then break end

			local dt = task.wait()
			local moveDistance = (SCYTHE_SPEED * 1.5) * dt
			currentPos = currentPos + (direction * moveDistance)

			local lookCFrame = CFrame.new(currentPos, playerCurrentPos)
			local rotation = (tick() - returnStartTime) * -1200

			local rotatedCFrame = lookCFrame * CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, math.rad(180), 0) * CFrame.Angles(0, 0, math.rad(rotation))

			if isModel then
				pcall(function()
					scythe:SetPrimaryPartCFrame(rotatedCFrame)
				end)
			else
				scythe.CFrame = rotatedCFrame
			end
		end

		for _, desc in pairs(scythe:GetDescendants()) do
			if desc:IsA("ParticleEmitter") then desc.Enabled = false end
			if desc:IsA("Trail") then desc.Enabled = false end
		end

		if isModel then
			for _, part in pairs(scythe:GetDescendants()) do
				if part:IsA("BasePart") then
					TweenService:Create(part, TweenInfo.new(0.2), {Transparency = 1}):Play()
				end
			end
		else
			TweenService:Create(scythe, TweenInfo.new(0.2), {Transparency = 1}):Play()
		end

		task.wait(0.3)
		scythe:Destroy()
	end)
end

local function animateScytheReturn(returnStart, playerRoot)
	if not useCustomEffects or not scytheProjectileTemplate then return end

	task.spawn(function()
		local scythe = createScytheVisual(returnStart)
		if not scythe then return end

		local isModel = scythe:IsA("Model")
		local currentPos = returnStart
		local returnStartTime = tick()
		local animationPlayed = false

		while tick() - returnStartTime < 5 and scythe.Parent do
			if not playerRoot or not playerRoot.Parent then break end

			local playerCurrentPos = playerRoot.Position + Vector3.new(0, 2, 0)
			local direction = (playerCurrentPos - currentPos).Unit
			local distance = (playerCurrentPos - currentPos).Magnitude

			if distance < 10 and not animationPlayed then
				playCatchAnimation()
				animationPlayed = true
			end

			if distance < 3 then break end

			local dt = task.wait()
			local moveDistance = (SCYTHE_SPEED * 1.5) * dt
			currentPos = currentPos + (direction * moveDistance)

			local lookCFrame = CFrame.new(currentPos, playerCurrentPos)
			local rotation = (tick() - returnStartTime) * -1200

			local rotatedCFrame = lookCFrame * CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, math.rad(180), 0) * CFrame.Angles(0, 0, math.rad(rotation))

			if isModel then
				pcall(function()
					scythe:SetPrimaryPartCFrame(rotatedCFrame)
				end)
			else
				scythe.CFrame = rotatedCFrame
			end
		end

		for _, desc in pairs(scythe:GetDescendants()) do
			if desc:IsA("ParticleEmitter") then desc.Enabled = false end
			if desc:IsA("Trail") then desc.Enabled = false end
		end

		if isModel then
			for _, part in pairs(scythe:GetDescendants()) do
				if part:IsA("BasePart") then
					TweenService:Create(part, TweenInfo.new(0.2), {Transparency = 1}):Play()
				end
			end
		else
			TweenService:Create(scythe, TweenInfo.new(0.2), {Transparency = 1}):Play()
		end

		task.wait(0.3)
		scythe:Destroy()
	end)
end

local function createHitEffect(position, isCrit)
	if not useCustomEffects or not scytheImpactTemplate then return end

	local impact = scytheImpactTemplate:Clone()

	if impact:IsA("Model") then
		if not impact.PrimaryPart then
			for _, child in pairs(impact:GetDescendants()) do
				if child:IsA("BasePart") then
					impact.PrimaryPart = child
					break
				end
			end
		end
		if impact.PrimaryPart then
			impact:SetPrimaryPartCFrame(CFrame.new(position))
		end
	else
		impact.CFrame = CFrame.new(position)
		impact.Anchored = true
	end

	impact.Parent = workspace

	for _, part in pairs(impact:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Size = part.Size * 2
		end
	end

	if isCrit then
		for _, part in pairs(impact:GetDescendants()) do
			if part:IsA("BasePart") and part.Material == Enum.Material.Neon then
				part.Color = Color3.fromRGB(255, 200, 0)
			end
			if part:IsA("PointLight") or part:IsA("SpotLight") then
				part.Color = Color3.fromRGB(255, 200, 0)
			end
			if part:IsA("ParticleEmitter") then
				part.Color = ColorSequence.new(Color3.fromRGB(255, 200, 0))
			end
		end
	end

	for _, desc in pairs(impact:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			desc:Emit(desc:GetAttribute("EmitCount") or 20)
		end
	end

	for _, part in pairs(impact:GetDescendants()) do
		if part:IsA("BasePart") then
			TweenService:Create(part, TweenInfo.new(0.5), {Transparency = 1}):Play()
		end
	end

	Debris:AddItem(impact, 0.5)
end

remote.OnClientEvent:Connect(function(action, ...)
	if action == "createScythe" then
		local throwingPlayer, startPos, targetRoot = ...
		local scythe = createScytheVisual(startPos, targetRoot.Position)
		if scythe then
			animateScytheThrow(scythe, startPos, targetRoot)
			Debris:AddItem(scythe, 3)
		end
	elseif action == "scytheHit" then
		local hitPos, isCrit = ...
		createHitEffect(hitPos, isCrit)
	elseif action == "scytheReturn" then
		local returnStart, playerRoot = ...
		animateScytheReturn(returnStart, playerRoot)
	elseif action == "scytheBounce" then
		local startPos, bounceTargets, playerRoot = ...
		animateScytheBounce(startPos, bounceTargets, playerRoot)
	end
end)

local function throwScythe()
	if tick() - lastThrowTime < COOLDOWN or humanoid.Health <= 0 then return end
	playThrowAnimation()
	task.delay(ABILITY_CAST_DELAY, function()
		remote:FireServer("throw")
	end)
	lastThrowTime = tick()
end

UIS.InputBegan:Connect(function(input, gameProcessed)
	if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton2 then
		throwScythe()
	end
end)

humanoid.Died:Connect(function()
	hideWeaponInHands()
	unequipWeaponQuickly()
	if throwAnimTrack then
		throwAnimTrack:Stop()
		throwAnimTrack = nil
	end
	if catchAnimTrack then
		catchAnimTrack:Stop()
		catchAnimTrack = nil
	end
	if weaponTool then
		weaponTool:Destroy()
		weaponTool = nil
	end
	if backScythe then
		backScythe:Destroy()
		backScythe = nil
	end
end)

player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid")
	rootPart = newCharacter:WaitForChild("HumanoidRootPart")
	task.wait(0.5)
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	task.wait(0.1)
	setupBackScythe()
	setupInvisibleTool()
end)
