-- =====================================
-- COMBAT SYSTEM - CLEANED VERSION V3
-- ❌ REMOVED: OverflowingChalice logic
-- Replace CombatSystem in ReplicatedStorage
-- =====================================

local CombatSystem = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

-- ========================
-- ЗАГРУЗКА СИСТЕМ
-- ========================
local ItemEffectSystem = require(ReplicatedStorage:WaitForChild("ItemEffectSystem", 30))
local DOTSystem = nil

task.spawn(function()
	print("🔍 [COMBAT] Searching for DOTSystem...")

	local attempts = 0
	repeat
		-- Вариант 1: Ищем как ModuleScript в ServerScriptService
		local dotModuleScript = ServerScriptService:FindFirstChild("DOTSystem")
		if dotModuleScript and dotModuleScript:IsA("ModuleScript") then
			local success, result = pcall(function()
				return require(dotModuleScript)
			end)
			if success then
				DOTSystem = result
				print("✅ [COMBAT] DOTSystem loaded from ModuleScript!")
				break
			end
		end

		-- Вариант 2: Проверяем _G (если Script загрузил в _G)
		if _G.DOTSystem then
			DOTSystem = _G.DOTSystem
			print("✅ [COMBAT] DOTSystem connected via _G!")
			break
		end

		task.wait(0.5)
		attempts = attempts + 1

		if attempts % 5 == 0 then
			print("⏳ [COMBAT] Still waiting for DOTSystem... (" .. attempts .. "/40)")
		end
	until attempts > 40

	if not DOTSystem then
		warn("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		warn("⚠️ [COMBAT] DOTSystem NOT FOUND!")
		warn("   Burn/Poison effects will be DISABLED")
		warn("   Make sure DOTSystem exists in ServerScriptService")
		warn("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	end
end)

-- ========================
-- BINDABLE EVENT ДЛЯ УБИЙСТВ
-- ========================
local OnKillEvent = Instance.new("BindableEvent")
OnKillEvent.Name = "OnKillEvent"
OnKillEvent.Parent = ReplicatedStorage

-- ========================
-- ОТСЛЕЖИВАНИЕ ПОСЛЕДНЕГО АТАКУЮЩЕГО
-- ========================
local lastAttacker = {}

-- ========================
-- ЗАЩИТА ОТ РЕКУРСИИ BLADE ECHO
-- ========================
local echoInProgress = {}

-- =====================================
-- ПОЛУЧЕНИЕ БОНУСОВ ОТ УРОВНЯ КОМАНДЫ
-- =====================================
local function getLevelDamageMultiplier()
	if _G.CrystalSystem and _G.CrystalSystem.GetDamageMultiplier then
		return _G.CrystalSystem.GetDamageMultiplier()
	end
	return 1
end

local function getLevelHealthMultiplier()
	if _G.CrystalSystem and _G.CrystalSystem.GetHealthMultiplier then
		return _G.CrystalSystem.GetHealthMultiplier()
	end
	return 1
end

-- ============================================
-- РАСЧЁТ ИСХОДЯЩЕГО УРОНА (от игрока)
-- ============================================
function CombatSystem.CalculateOutgoingDamage(attacker, baseDamage, targetHumanoid)
	local character = attacker.Character
	if not character then return baseDamage, false, false, 0 end

	local finalDamage = baseDamage

	-- 1. SHARP STONE - Процентный урон
	local damagePercent = character:FindFirstChild("DamagePercent")
	if damagePercent and damagePercent:IsA("NumberValue") and damagePercent.Value > 0 then
		local multiplier = 1 + (damagePercent.Value / 100)
		finalDamage = finalDamage * multiplier
		print("💎 [DAMAGE%] x" .. string.format("%.2f", multiplier) .. " → " .. math.floor(finalDamage))
	end

	-- 2. QUICK DRAW - Первая атака после тайм-аута
	if ItemEffectSystem then
		local quickDrawBonus = ItemEffectSystem.CheckQuickDraw(attacker, character)
		if quickDrawBonus > 0 then
			finalDamage = finalDamage * (1 + quickDrawBonus)
			print("🎯 [QUICK DRAW] +" .. (quickDrawBonus * 100) .. "% → " .. math.floor(finalDamage))
		end
	end

	-- 3. BERSERKER'S RAGE - Бонус при низком HP
	if ItemEffectSystem then
		local berserkerBonus = ItemEffectSystem.CheckBerserkerRage(character)
		if berserkerBonus > 0 then
			finalDamage = finalDamage * (1 + berserkerBonus)
			print("😡 [BERSERKER] +" .. (berserkerBonus * 100) .. "% → " .. math.floor(finalDamage))
		end
	end

	-- 4. MOMENTUM CHAIN - Стаки без получения урона
	if ItemEffectSystem then
		local momentumBonus = ItemEffectSystem.GetMomentumBonus(attacker, character)
		if momentumBonus > 0 then
			finalDamage = finalDamage * (1 + momentumBonus)
			print("🔗 [MOMENTUM] +" .. (momentumBonus * 100) .. "% → " .. math.floor(finalDamage))
		end
	end

	-- 5. EXECUTIONER'S BLADE - Бонус к врагам с низким HP
	if ItemEffectSystem and targetHumanoid then
		local executeBonus = ItemEffectSystem.CheckExecutioner(character, targetHumanoid)
		if executeBonus > 0 then
			finalDamage = finalDamage * (1 + executeBonus)
			print("🗡️ [EXECUTIONER] +" .. (executeBonus * 100) .. "% → " .. math.floor(finalDamage))
		end
	end

	-- 6. DIVINE INTERVENTION - Бафф урона после доджа
	if ItemEffectSystem then
		local divineBonus = ItemEffectSystem.GetDivineBonus(attacker, character)
		if divineBonus > 0 then
			finalDamage = finalDamage * (1 + divineBonus)
			print("✨ [DIVINE] +" .. (divineBonus * 100) .. "% → " .. math.floor(finalDamage))
		end
	end

	-- 7. OVERCHARGED BATTERY - Каждая 10-я атака
	local overcharged = false
	local explosionRadius = 0
	if ItemEffectSystem then
		overcharged, explosionRadius = ItemEffectSystem.CheckOverchargedBattery(attacker, character)
		if overcharged then
			finalDamage = finalDamage * 5
			print("⚡ [OVERCHARGED] x5 → " .. math.floor(finalDamage))
		end
	end

	-- 8. БОНУС ОТ УРОВНЯ КОМАНДЫ
	local levelMultiplier = getLevelDamageMultiplier()
	if levelMultiplier > 1 then
		finalDamage = finalDamage * levelMultiplier
		print("⭐ [LEVEL] x" .. string.format("%.2f", levelMultiplier) .. " → " .. math.floor(finalDamage))
	end

	-- 9. КРИТИЧЕСКИЙ УДАР (SIMPLIFIED - no double crit)
	local critChance = character:FindFirstChild("CritChance")
	local isCrit = false

	if critChance and critChance:IsA("NumberValue") then
		local roll = math.random(1, 100)

		if roll <= math.min(critChance.Value, 100) then
			-- КРИТ!
			local critDamageBonus = 100 -- Базовый x2

			local critDamageStat = character:FindFirstChild("CritDamage")
			if critDamageStat and critDamageStat:IsA("NumberValue") then
				critDamageBonus = critDamageBonus + critDamageStat.Value
			end

			finalDamage = finalDamage * (critDamageBonus / 100)
			isCrit = true

			print("💥 [CRIT] x" .. (critDamageBonus/100) .. " → " .. math.floor(finalDamage))

			CombatSystem.ShowCritEffect(character)
		end
	end

	-- Обновляем таймер последней атаки
	if ItemEffectSystem then
		ItemEffectSystem.UpdateLastAttack(attacker)
	end

	return math.floor(finalDamage), isCrit, overcharged, explosionRadius
end

-- ============================================
-- ON-HIT ЭФФЕКТЫ
-- ============================================
function CombatSystem.TriggerOnHitEffects(attacker, victim, damageDealt, hitPosition)
	if not attacker or not attacker.Character then return end
	if not victim then return end

	-- Пропускаем эффекты для Echo атак
	if echoInProgress[victim] then
		return
	end

	local character = attacker.Character

	-- 1. BURN (Old Lighter)
	if ItemEffectSystem and DOTSystem then
		local burnProc, burnStacks = ItemEffectSystem.CheckBurn(character)
		if burnProc then
			for i = 1, burnStacks do
				DOTSystem.ApplyBurn(attacker, victim)
			end
		end
	end

	-- 2. POISON (Vile Vial)
	if ItemEffectSystem and DOTSystem then
		local poisonProc, enhanced = ItemEffectSystem.CheckPoison(character)
		if poisonProc then
			DOTSystem.ApplyPoison(attacker, victim, nil, enhanced)
		end
	end

	-- 3. CHAIN LIGHTNING
	if ItemEffectSystem and hitPosition then
		local chainProc, targets, chainPercent, range = ItemEffectSystem.CheckChainLightning(character)
		if chainProc then
			CombatSystem.TriggerChainLightning(attacker, victim, damageDealt * (chainPercent/100), hitPosition, targets, range)
		end
	end

	-- 4. BLADE ECHO - Повтор атаки
	if ItemEffectSystem then
		local echoProc, echoCount = ItemEffectSystem.CheckBladeEcho(character)
		if echoProc then
			-- Повторяем атаку через 0.5 секунд
			for i = 1, echoCount do
				task.delay(0.5 * i, function()
					if victim and victim.Character then
						local echoHumanoid = victim.Character:FindFirstChildOfClass("Humanoid")
						if echoHumanoid and echoHumanoid.Health > 0 then
							-- Помечаем что это Echo атака
							echoInProgress[victim] = true

							-- Наносим урон напрямую (без новых on-hit эффектов)
							echoHumanoid:TakeDamage(damageDealt)

							-- Визуальный эффект
							CombatSystem.ShowEchoEffect(victim.Character)

							print("⚔️ [ECHO #" .. i .. "] -" .. damageDealt .. " damage")

							-- Снимаем флаг через секунду
							task.delay(1, function()
								echoInProgress[victim] = nil
							end)
						end
					end
				end)
			end
		end
	end
end

-- ============================================
-- CHAIN LIGHTNING
-- ============================================
function CombatSystem.TriggerChainLightning(attacker, initialVictim, chainDamage, origin, maxTargets, range)
	local hitTargets = {[initialVictim] = true}
	local currentPos = origin
	local targetsHit = 0

	-- Определяем команду атакующего
	local attackerTeam = attacker.Team

	print("⚡ [CHAIN] Starting from: " .. (initialVictim and initialVictim.Name or "NPC"))

	for i = 1, maxTargets do
		-- Ищем ближайшего врага в радиусе
		local nearestEnemy = nil
		local nearestDist = math.huge

		for _, part in pairs(workspace:GetPartBoundsInRadius(currentPos, range)) do
			local character = part.Parent
			if character and character:FindFirstChild("Humanoid") then
				local targetPlayer = Players:GetPlayerFromCharacter(character)

				-- Проверяем команду
				local isAlly = false
				if targetPlayer and attackerTeam then
					isAlly = (targetPlayer.Team == attackerTeam)
				end

				-- Пропускаем атакующего, союзников и уже пораженных
				if character ~= attacker.Character
					and not isAlly
					and not hitTargets[targetPlayer or character] then

					local enemyHumanoid = character.Humanoid
					if enemyHumanoid.Health > 0 then
						local rootPart = character:FindFirstChild("HumanoidRootPart")
						if rootPart then
							local dist = (rootPart.Position - currentPos).Magnitude
							if dist < nearestDist then
								nearestDist = dist
								nearestEnemy = character
							end
						end
					end
				end
			end
		end

		if nearestEnemy then
			targetsHit = targetsHit + 1

			-- Визуальная молния
			local enemyRoot = nearestEnemy:FindFirstChild("HumanoidRootPart")
			if enemyRoot then
				CombatSystem.ShowLightningBolt(currentPos, enemyRoot.Position)
				currentPos = enemyRoot.Position
			end

			-- Наносим урон
			local enemyHumanoid = nearestEnemy:FindFirstChildOfClass("Humanoid")
			if enemyHumanoid then
				enemyHumanoid:TakeDamage(chainDamage)

				local targetPlayer = Players:GetPlayerFromCharacter(nearestEnemy)
				hitTargets[targetPlayer or nearestEnemy] = true

				print("   ⚡ Jump #" .. targetsHit .. ": " .. (targetPlayer and targetPlayer.Name or nearestEnemy.Name) .. " (-" .. chainDamage .. ")")
			end
		else
			print("   ⚡ No more targets in range!")
			break
		end
	end

	print("⚡ [CHAIN] Completed! Hit " .. targetsHit .. " targets")
end

-- ============================================
-- ВЗРЫВ OVERCHARGED BATTERY
-- ============================================
function CombatSystem.TriggerExplosion(attacker, originCharacter, position, radius, damage)
	print("💥 [EXPLOSION] Radius: " .. radius .. ", Damage: " .. damage)

	local attackerTeam = attacker.Team
	local hitCount = 0

	for _, part in pairs(workspace:GetPartBoundsInRadius(position, radius)) do
		local character = part.Parent
		if character and character:FindFirstChild("Humanoid") then
			-- Пропускаем атакующего
			if character == attacker.Character then continue end

			-- Проверяем команду
			local targetPlayer = Players:GetPlayerFromCharacter(character)
			if targetPlayer and attackerTeam and targetPlayer.Team == attackerTeam then
				continue -- Пропускаем союзников
			end

			local humanoid = character.Humanoid
			if humanoid.Health > 0 then
				humanoid:TakeDamage(damage)
				hitCount = hitCount + 1
				print("   💥 Hit: " .. (targetPlayer and targetPlayer.Name or character.Name))
			end
		end
	end

	-- Визуальный эффект
	CombatSystem.ShowExplosionEffect(position, radius)

	print("💥 [EXPLOSION] Hit " .. hitCount .. " enemies!")
end

-- ============================================
-- РАСЧЁТ ВХОДЯЩЕГО УРОНА (к игроку)
-- ============================================
function CombatSystem.CalculateIncomingDamage(victim, damage, attacker)
	local character = victim.Character
	if not character then return damage end

	local finalDamage = damage

	-- 1. DIVINE INTERVENTION - Шанс заблокировать
	if ItemEffectSystem then
		local dodged = ItemEffectSystem.CheckDivineIntervention(victim, character, finalDamage)
		if dodged then
			return 0 -- Весь урон заблокирован
		end
	end

	-- 2. ЩИТ
	local shield = character:FindFirstChild("Shield")
	if shield and shield:IsA("NumberValue") and shield.Value > 0 then
		if finalDamage <= shield.Value then
			shield.Value = shield.Value - finalDamage
			print("🛡️ [SHIELD] Absorbed: " .. finalDamage .. " (Remaining: " .. shield.Value .. ")")
			CombatSystem.ResetShieldRegeneration(victim)
			return 0
		else
			local overflow = finalDamage - shield.Value
			print("🛡️ [SHIELD] Broken! Overflow: " .. overflow)
			shield.Value = 0
			finalDamage = overflow
			CombatSystem.ResetShieldRegeneration(victim)
		end
	end

	-- 3. SURVIVOR'S WILL - Блок смертельного урона
	if ItemEffectSystem then
		local blocked = ItemEffectSystem.CheckSurvivorWill(character)
		if blocked then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.Health = 1
				return 0
			end
		end
	end

	-- 4. ЗАЩИТА (Iron Armor + Thorn Bandoleer)
	local defense = character:FindFirstChild("Defense")
	if defense and defense:IsA("NumberValue") and defense.Value > 0 then
		local reduction = 100 / (100 + defense.Value)
		finalDamage = finalDamage * reduction

		print("🛡️ [DEFENSE] Reduced: " .. defense.Value .. " → " .. math.floor(finalDamage))
	end

	-- 5. ОБНОВЛЕНИЕ MOMENTUM CHAIN (сброс при получении урона)
	if ItemEffectSystem and finalDamage > 0 then
		ItemEffectSystem.UpdateMomentumChain(victim, character, true)
	end

	return math.floor(finalDamage)
end

-- ============================================
-- ПРИМЕНЕНИЕ УРОНА (ГЛАВНАЯ ФУНКЦИЯ)
-- ============================================
function CombatSystem.ApplyDamage(victim, damage, attacker, hitPosition)
	local character = victim.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print("💢 [COMBAT] Applying Damage:")
	print("   Victim: " .. victim.Name)
	print("   Raw Damage: " .. damage)

	-- Запоминаем атакующего
	if attacker then
		lastAttacker[victim.UserId] = {
			player = attacker,
			time = tick()
		}
	end

	-- Рассчитываем итоговый урон (получаем overcharged данные)
	local finalDamage = damage
	local overcharged = false
	local explosionRadius = 0

	if attacker then
		finalDamage, _, overcharged, explosionRadius =
			CombatSystem.CalculateOutgoingDamage(attacker, damage, humanoid)
	end

	-- Применяем защиту жертвы
	finalDamage = CombatSystem.CalculateIncomingDamage(victim, finalDamage, attacker)

	if finalDamage <= 0 then
		print("✅ [COMBAT] All damage blocked!")
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		return
	end

	-- Наносим урон
	humanoid:TakeDamage(finalDamage)
	print("❤️ [COMBAT] Final Damage: " .. finalDamage .. " (HP: " .. humanoid.Health .. "/" .. humanoid.MaxHealth .. ")")

	-- Взрыв Overcharged Battery
	if attacker and overcharged and explosionRadius > 0 and hitPosition then
		CombatSystem.TriggerExplosion(attacker, character, hitPosition, explosionRadius, finalDamage * 0.5)
	end

	-- On-hit эффекты (Burn, Poison, Chain Lightning, Blade Echo)
	if attacker then
		CombatSystem.TriggerOnHitEffects(attacker, victim, finalDamage, hitPosition)

		-- Вампиризм
		CombatSystem.ApplyLifesteal(attacker, finalDamage)
	end

	-- Шипы (Thorns)
	local thorns = character:FindFirstChild("Thorns")
	if thorns and thorns:IsA("NumberValue") and thorns.Value > 0 and attacker then
		local reflectDamage = finalDamage * (thorns.Value / 100)
		print("🌵 [THORNS] Reflect: " .. math.floor(reflectDamage))

		local attackerChar = attacker.Character
		if attackerChar then
			local attackerHum = attackerChar:FindFirstChildOfClass("Humanoid")
			if attackerHum then
				attackerHum:TakeDamage(reflectDamage)
			end
		end
	end

	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

-- ============================================
-- ПОЛУЧИТЬ ПОСЛЕДНЕГО АТАКУЮЩЕГО
-- ============================================
function CombatSystem.GetLastAttacker(victim)
	local data = lastAttacker[victim.UserId]
	if data and (tick() - data.time) < 5 then -- В течение 5 секунд
		return data.player
	end
	return nil
end

-- ============================================
-- ОБРАБОТКА УБИЙСТВА
-- ============================================
function CombatSystem.OnKill(killer, victim)
	if not killer or not killer.Character then return end

	local character = killer.Character

	print("💀 [KILL] " .. killer.Name .. " killed " .. (victim and victim.Name or "NPC"))

	-- 1. MOMENTUM CHAIN - Добавить стак
	if ItemEffectSystem then
		ItemEffectSystem.UpdateMomentumChain(killer, character, false)
	end

	-- 2. SOUL EATER - Добавить HP
	if ItemEffectSystem then
		ItemEffectSystem.AddSoulEaterStack(character)
	end

	-- Уведомляем все системы через BindableEvent
	OnKillEvent:Fire(killer, victim)
end

-- ============================================
-- ВАМПИРИЗМ
-- ============================================
function CombatSystem.ApplyLifesteal(attacker, damageDealt)
	local character = attacker.Character
	if not character then return end

	local lifesteal = character:FindFirstChild("Lifesteal")
	if not lifesteal or not lifesteal:IsA("NumberValue") or lifesteal.Value <= 0 then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local healAmount = damageDealt * (lifesteal.Value / 100)
	local newHealth = math.min(humanoid.Health + healAmount, humanoid.MaxHealth)
	humanoid.Health = newHealth

	print("🧛 [LIFESTEAL] +" .. math.floor(healAmount) .. " HP")

	CombatSystem.ShowLifestealEffect(character)
end

-- ============================================
-- РЕГЕНЕРАЦИЯ ЩИТА
-- ============================================
local activeShieldRegens = {}

function CombatSystem.StartShieldRegeneration(player)
	if activeShieldRegens[player] then return end

	local character = player.Character
	if not character then return end

	local shield = character:FindFirstChild("Shield")
	local maxShield = character:FindFirstChild("MaxShield")

	if not shield or not maxShield then return end

	activeShieldRegens[player] = {
		LastDamageTime = tick(),
		Active = true,
	}

	task.spawn(function()
		while activeShieldRegens[player] and activeShieldRegens[player].Active do
			task.wait(0.5)

			local currentCharacter = player.Character
			if not currentCharacter then
				activeShieldRegens[player] = nil
				break
			end

			local currentShield = currentCharacter:FindFirstChild("Shield")
			local currentMaxShield = currentCharacter:FindFirstChild("MaxShield")

			if not currentShield or not currentMaxShield then
				activeShieldRegens[player] = nil
				break
			end

			local timeSinceLastDamage = tick() - activeShieldRegens[player].LastDamageTime

			if timeSinceLastDamage >= 5 then
				if currentShield.Value < currentMaxShield.Value then
					local regenAmount = 10 * 0.5
					currentShield.Value = math.min(
						currentShield.Value + regenAmount,
						currentMaxShield.Value
					)
				end
			end
		end
	end)
end

function CombatSystem.ResetShieldRegeneration(player)
	if activeShieldRegens[player] then
		activeShieldRegens[player].LastDamageTime = tick()
	end
end

function CombatSystem.StopShieldRegeneration(player)
	if activeShieldRegens[player] then
		activeShieldRegens[player].Active = false
		activeShieldRegens[player] = nil
	end
end

-- ============================================
-- ВИЗУАЛЬНЫЕ ЭФФЕКТЫ
-- ============================================
function CombatSystem.ShowCritEffect(character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://2248511809"
	sound.Volume = 0.5
	sound.Parent = rootPart
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 2)
end

function CombatSystem.ShowLifestealEffect(character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://3398620867"
	sound.Volume = 0.3
	sound.Parent = rootPart
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 2)
end

function CombatSystem.ShowEchoEffect(character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Визуальный эффект Echo
	local effect = Instance.new("Part")
	effect.Anchored = true
	effect.CanCollide = false
	effect.Material = Enum.Material.Neon
	effect.Color = Color3.fromRGB(100, 200, 255)
	effect.Size = Vector3.new(3, 3, 3)
	effect.Shape = Enum.PartType.Ball
	effect.Transparency = 0.5
	effect.CFrame = rootPart.CFrame
	effect.Parent = workspace

	game:GetService("Debris"):AddItem(effect, 0.3)
end

function CombatSystem.ShowExplosionEffect(position, radius)
	-- Визуальный эффект взрыва
	local explosion = Instance.new("Part")
	explosion.Anchored = true
	explosion.CanCollide = false
	explosion.Material = Enum.Material.Neon
	explosion.Color = Color3.fromRGB(255, 255, 100)
	explosion.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	explosion.Shape = Enum.PartType.Ball
	explosion.Transparency = 0.3
	explosion.CFrame = CFrame.new(position)
	explosion.Parent = workspace

	-- Звук
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://165969964"
	sound.Volume = 0.7
	sound.Parent = explosion
	sound:Play()

	game:GetService("Debris"):AddItem(explosion, 0.5)
end

function CombatSystem.ShowLightningBolt(startPos, endPos)
	local bolt = Instance.new("Part")
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.Material = Enum.Material.Neon
	bolt.Color = Color3.fromRGB(255, 255, 100)
	bolt.Size = Vector3.new(0.2, 0.2, (endPos - startPos).Magnitude)
	bolt.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -(endPos - startPos).Magnitude / 2)
	bolt.Parent = workspace

	game:GetService("Debris"):AddItem(bolt, 0.1)
end

-- ============================================
-- ОБРАБОТКА СМЕРТЕЙ ИГРОКОВ
-- ============================================
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")

		humanoid.Died:Connect(function()
			-- Находим убийцу
			local killer = CombatSystem.GetLastAttacker(player)
			if killer then
				CombatSystem.OnKill(killer, player)
			end

			-- Очистка
			lastAttacker[player.UserId] = nil
			echoInProgress[player] = nil
		end)
	end)
end)

-- ============================================
-- ОЧИСТКА
-- ============================================
Players.PlayerRemoving:Connect(function(player)
	CombatSystem.StopShieldRegeneration(player)
	lastAttacker[player.UserId] = nil
	echoInProgress[player] = nil
end)

-- ============================================
-- ПОДПИСКА НА ONKILLEVENT (для NPC убийств)
-- ============================================
OnKillEvent.Event:Connect(function(killer, victim)
	print("📢 [COMBAT] OnKillEvent received!")
	CombatSystem.OnKill(killer, victim)
end)

print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ CombatSystem CLEANED loaded!")
print("   ❌ Removed: OverflowingChalice double crit logic")
print("   🔧 Simplified crit calculation")
print("   🔧 Blade Echo: Recursion protection")
print("   🔧 Chain Lightning: Team check added")
print("   🔧 Overcharged: Explosion implemented")
print("   🔧 OnKill: BindableEvent integration")
print("   🔧 Player deaths: Automatic killer tracking")
print("   ✨ ItemEffectSystem integration")
print("   🔥 DOT support (Burn/Poison)")
print("   ⚡ All proc effects working")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

return CombatSystem
