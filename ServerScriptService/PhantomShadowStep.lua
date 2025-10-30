-- =====================================
-- ТЕНЕВОЙ ШАГ PHANTOM - СЕРВЕР (ИСПРАВЛЕН)
-- Place in ServerScriptService
-- =====================================
local rs = game:GetService("ReplicatedStorage")

if not rs:FindFirstChild("PhantomShadowStep") then
	Instance.new("RemoteEvent", rs).Name = "PhantomShadowStep"
end

local remote = rs.PhantomShadowStep

-- Настройки
local DASH_DISTANCE = 40
local INVISIBILITY_DURATION = 1.5
local SPEED_BONUS = 0.5
local STEALTH_CRIT_MULTIPLIER = 2.5
local COOLDOWN = 6

local activeDashes = {}
local playerCooldowns = {}

remote.OnServerEvent:Connect(function(player, action, data)
	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not humanoid or not rootPart or humanoid.Health <= 0 then return end

	if action == "dash" then
		local currentTime = tick()
		if playerCooldowns[player.UserId] and currentTime - playerCooldowns[player.UserId] < COOLDOWN then
			warn("⚠️ [SHADOW STEP] Cooldown active")
			return
		end

		local direction = data.direction
		local startPos = data.startPos

		print("🌫️ [SHADOW STEP] Dash started:", player.Name)

		playerCooldowns[player.UserId] = currentTime

		local endPos = startPos + (direction * DASH_DISTANCE)
		rootPart.CFrame = CFrame.new(endPos)

		print("🎯 [SHADOW STEP] Teleported to:", endPos)

		activeDashes[player.UserId] = {
			player = player,
			character = character,
			originalSpeed = humanoid.WalkSpeed,
			invisEndTime = tick() + INVISIBILITY_DURATION,
			stealthActive = true
		}

		_G.IgnoreStatsChange = true
		humanoid.WalkSpeed = humanoid.WalkSpeed * (1 + SPEED_BONUS)
		task.wait(0.1)
		_G.IgnoreStatsChange = false

		for _, part in pairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.Transparency = 0.7
			elseif part:IsA("Decal") then
				part.Transparency = 0.7
			end
		end

		remote:FireAllClients("setInvisible", player, true)

		task.delay(INVISIBILITY_DURATION, function()
			local dashData = activeDashes[player.UserId]
			if dashData then
				dashData.stealthActive = false

				if character and character.Parent then
					if humanoid then
						_G.IgnoreStatsChange = true
						humanoid.WalkSpeed = dashData.originalSpeed
						task.wait(0.1)
						_G.IgnoreStatsChange = false
					end

					for _, part in pairs(character:GetDescendants()) do
						if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
							part.Transparency = 0
						elseif part:IsA("Decal") then
							part.Transparency = 0
						end
					end

					remote:FireAllClients("setInvisible", player, false)
				end

				activeDashes[player.UserId] = nil
				print("👁️ [SHADOW STEP] Invisibility ended:", player.Name)
			end
		end)

	elseif action == "attack" then
		local dashData = activeDashes[player.UserId]

		if dashData and dashData.stealthActive then
			print("💥 [SHADOW STEP] Stealth attack! Applying crit bonus")

			local critMarker = Instance.new("BoolValue")
			critMarker.Name = "StealthCrit"
			critMarker.Value = true
			critMarker.Parent = character

			dashData.stealthActive = false

			if humanoid then
				_G.IgnoreStatsChange = true
				humanoid.WalkSpeed = dashData.originalSpeed
				task.wait(0.1)
				_G.IgnoreStatsChange = false
			end

			for _, part in pairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.Transparency = 0
				elseif part:IsA("Decal") then
					part.Transparency = 0
				end
			end

			remote:FireAllClients("setInvisible", player, false)

			game:GetService("Debris"):AddItem(critMarker, 0.5)

			activeDashes[player.UserId] = nil
		end
	end
end)

function GetStealthCritMultiplier(player)
	if not player or not player.Character then return 1 end

	local critMarker = player.Character:FindFirstChild("StealthCrit")
	if critMarker and critMarker:IsA("BoolValue") and critMarker.Value then
		critMarker:Destroy()
		return STEALTH_CRIT_MULTIPLIER
	end

	return 1
end

_G.PhantomStealthCrit = GetStealthCritMultiplier

game.Players.PlayerRemoving:Connect(function(player)
	activeDashes[player.UserId] = nil
	playerCooldowns[player.UserId] = nil
end)

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			activeDashes[player.UserId] = nil
		end)
	end)
end)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ [PHANTOM SHADOW STEP SERVER] Loaded!")
print("   Dash distance:", DASH_DISTANCE, "studs")
print("   Invisibility:", INVISIBILITY_DURATION, "sec")
print("   Speed bonus: +" .. (SPEED_BONUS * 100) .. "%")
print("   Stealth crit: x" .. STEALTH_CRIT_MULTIPLIER)
print("   Cooldown:", COOLDOWN, "sec")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
