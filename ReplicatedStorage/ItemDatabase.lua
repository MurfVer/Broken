-- =====================================
-- ITEM DATABASE (Cleaned Version)
-- Place in ReplicatedStorage as ModuleScript
-- ❌ REMOVED: InfinityDash, OverflowingChalice
-- =====================================

local ItemDatabase = {}

-- =====================================
-- RARITY WEIGHTS (для drop system)
-- =====================================
ItemDatabase.RarityWeights = {
	Common = 50,      -- 50%
	Uncommon = 35,    -- 35%
	Rare = 12,        -- 12%
	Legendary = 3     -- 3%
}

-- =====================================
-- ITEMS DATABASE
-- =====================================
ItemDatabase.Items = {
	-- ========================
	-- COMMON (White) - 50% [8 предметов]
	-- ========================
	SprintShoes = {
		ID = "sprint_shoes",
		Name = "Sprint Shoes",
		Description = "Increases movement speed",
		Rarity = "Common",
		Effect = "Speed",
		BaseValue = 5,
		StackValue = 5,
		Color = Color3.fromRGB(255, 255, 255),
		ModelName = "SpeedBoots"
	},
	HealingCrystal = {
		ID = "healing_crystal",
		Name = "Healing Crystal",
		Description = "Increases maximum health",
		Rarity = "Common",
		Effect = "Health",
		BaseValue = 20,
		StackValue = 20,
		Color = Color3.fromRGB(200, 255, 200),
		ModelName = "HpBuff"
	},
	SharpStone = {
		ID = "sharp_stone",
		Name = "Sharp Stone",
		Description = "Increases damage by %",
		Rarity = "Common",
		Effect = "DamagePercent",
		BaseValue = 10,
		StackValue = 10,
		Color = Color3.fromRGB(255, 200, 200),
		ModelName = "SharpStone"
	},
	IronArmor = {
		ID = "iron_armor",
		Name = "Iron Armor",
		Description = "Reduces damage taken",
		Rarity = "Common",
		Effect = "Defense",
		BaseValue = 10,
		StackValue = 10,
		Color = Color3.fromRGB(200, 200, 200),
		ModelName = "IronArmor"
	},
	ScavengerPouch = {
		ID = "scavenger_pouch",
		Name = "Scavenger's Pouch",
		Description = "Enemies drop +15% crystals",
		Rarity = "Common",
		Effect = "CrystalBonus",
		BaseValue = 15,
		StackValue = 15,
		Color = Color3.fromRGB(255, 215, 100),
		ModelName = "ScavengerPouch"
	},
	QuickDraw = {
		ID = "quick_draw",
		Name = "Quick Draw",
		Description = "First attack after 3 sec: +20% damage",
		Rarity = "Common",
		Effect = "QuickDraw",
		BaseValue = 20,
		StackValue = 20,
		Color = Color3.fromRGB(255, 180, 120),
		ModelName = "QuickDraw"
	},
	SurvivorWill = {
		ID = "survivor_will",
		Name = "Survivor's Will",
		Description = "Block 100% damage at HP<10% (30s cooldown)",
		Rarity = "Common",
		Effect = "SurvivorWill",
		BaseValue = 1,
		StackValue = 1,
		Color = Color3.fromRGB(255, 100, 100),
		ModelName = "SurvivorWill"
	},
	OldLighter = {
		ID = "old_lighter",
		Name = "Old Lighter",
		Description = "10% to apply burn (30% damage over 3s)",
		Rarity = "Common",
		Effect = "BurnChance",
		BaseValue = 10,
		StackValue = 10,
		BurnDamage = 30,
		BurnDuration = 3,
		Color = Color3.fromRGB(255, 100, 0),
		ModelName = "OldLighter"
	},

	-- ========================
	-- UNCOMMON (Green) - 35% [7 предметов]
	-- ========================
	LuckyClover = {
		ID = "lucky_clover",
		Name = "Lucky Clover",
		Description = "Critical hit chance +10%",
		Rarity = "Uncommon",
		Effect = "CritChance",
		BaseValue = 10,
		StackValue = 10,
		Color = Color3.fromRGB(100, 255, 100),
		ModelName = "LuckyClover"
	},
	LifeStone = {
		ID = "life_stone",
		Name = "Life Stone",
		Description = "Regenerate +2 HP/sec",
		Rarity = "Uncommon",
		Effect = "Regen",
		BaseValue = 2,
		StackValue = 2,
		Color = Color3.fromRGB(150, 255, 150),
		ModelName = "LifeStone"
	},
	AntiGravityBelt = {
		ID = "anti_gravity_belt",
		Name = "Anti-Gravity Belt",
		Description = "Increases jump power",
		Rarity = "Uncommon",
		Effect = "JumpPower",
		BaseValue = 15,
		StackValue = 15,
		Color = Color3.fromRGB(150, 255, 255),
		ModelName = "AntiGravityBelt"
	},
	BerserkerRage = {
		ID = "berserker_rage",
		Name = "Berserker's Rage",
		Description = "HP<30%: +25% damage",
		Rarity = "Uncommon",
		Effect = "BerserkerRage",
		BaseValue = 25,
		StackValue = 25,
		Color = Color3.fromRGB(255, 50, 50),
		ModelName = "BerserkerRage"
	},
	MomentumChain = {
		ID = "momentum_chain",
		Name = "Momentum Chain",
		Description = "Kills without taking damage: +8% damage (max 5 stacks)",
		Rarity = "Uncommon",
		Effect = "MomentumChain",
		BaseValue = 8,
		StackValue = 8,
		MaxStacks = 5,
		Color = Color3.fromRGB(200, 150, 255),
		ModelName = "MomentumChain"
	},
	BagOfCaltrops = {
		ID = "bag_of_caltrops",
		Name = "Bag of Caltrops",
		Description = "Dashing (Q) leaves damaging spikes",
		Rarity = "Uncommon",
		Effect = "Caltrops",
		BaseValue = 15,
		StackValue = 15,
		Duration = 5,
		Radius = 15,
		Color = Color3.fromRGB(100, 100, 100),
		ModelName = "BagOfCaltrops"
	},
	ThornBandoleer = {
		ID = "thorn_bandoleer",
		Name = "Thorn Bandoleer",
		Description = "+100% damage retaliation",
		Rarity = "Uncommon",
		Effect = "Thorns",
		BaseValue = 100,
		StackValue = 100,
		Color = Color3.fromRGB(100, 150, 100),
		ModelName = "ThornBandoleer"
	},

	-- ========================
	-- RARE (Purple) - 12% [9 предметов]
	-- ========================
	EnergyShield = {
		ID = "energy_shield",
		Name = "Energy Shield",
		Description = "Grants a regenerating shield",
		Rarity = "Rare",
		Effect = "Shield",
		BaseValue = 30,
		StackValue = 30,
		Color = Color3.fromRGB(100, 150, 255),
		ModelName = "EnergyShield"
	},
	VampireFang = {
		ID = "vampire_fang",
		Name = "Vampire Fang",
		Description = "Heal on hit (5% damage)",
		Rarity = "Rare",
		Effect = "Lifesteal",
		BaseValue = 5,
		StackValue = 5,
		Color = Color3.fromRGB(200, 50, 50),
		ModelName = "VampireFang"
	},
	BladeEcho = {
		ID = "blade_echo",
		Name = "Blade Echo",
		Description = "20% chance to repeat last attack",
		Rarity = "Rare",
		Effect = "BladeEcho",
		BaseValue = 20,
		StackValue = 20,
		Delay = 0.5,
		Color = Color3.fromRGB(150, 150, 255),
		ModelName = "BladeEcho"
	},
	PhoenixAsh = {
		ID = "phoenix_ash",
		Name = "Phoenix Ash",
		Description = "Revive with 25% HP (ONE-TIME USE)",
		Rarity = "Rare",
		Effect = "PhoenixAsh",
		BaseValue = 25,
		StackValue = 0,
		Color = Color3.fromRGB(255, 150, 0),
		ModelName = "PhoenixAsh"
	},
	SoulEater = {
		ID = "soul_eater",
		Name = "Soul Eater",
		Description = "+1 MaxHP per kill (max 200, reset on death)",
		Rarity = "Rare",
		Effect = "SoulEater",
		BaseValue = 1,
		StackValue = 1,
		MaxStacks = 200,
		Color = Color3.fromRGB(100, 0, 100),
		ModelName = "SoulEater"
	},
	ExecutionerBlade = {
		ID = "executioner_blade",
		Name = "Executioner's Blade",
		Description = "+100% damage to enemies with HP<20%",
		Rarity = "Rare",
		Effect = "ExecuteDamage",
		BaseValue = 100,
		StackValue = 100,
		Color = Color3.fromRGB(150, 0, 0),
		ModelName = "ExecutionerBlade"
	},
	ChainLightning = {
		ID = "chain_lightning",
		Name = "Chain Lightning Core",
		Description = "25% chance: damage jumps to 3 enemies",
		Rarity = "Rare",
		Effect = "ChainLightning",
		BaseValue = 25,
		StackValue = 25,
		Targets = 3,
		ChainDamage = 50,
		Range = 30,
		Color = Color3.fromRGB(255, 255, 100),
		ModelName = "ChainLightning"
	},
	CritMultiplier = {
		ID = "crit_multiplier",
		Name = "Crit Multiplier",
		Description = "Crits deal x2 damage",
		Rarity = "Rare",
		Effect = "CritDamage",
		BaseValue = 100,
		StackValue = 0,
		Color = Color3.fromRGB(255, 200, 0),
		ModelName = "CritMultiplier"
	},
	VileVial = {
		ID = "vile_vial",
		Name = "Vile Vial",
		Description = "20% to poison (50% damage over 5s)",
		Rarity = "Rare",
		Effect = "PoisonChance",
		BaseValue = 20,
		StackValue = 20,
		PoisonDamage = 50,
		PoisonDuration = 5,
		Color = Color3.fromRGB(50, 255, 50),
		ModelName = "VileVial"
	},

	-- ========================
	-- LEGENDARY (Gold) - 3% [4 предмета]
	-- ❌ REMOVED: InfinityDash, OverflowingChalice
	-- ========================
	WingsOfFreedom = {
		ID = "wings_of_freedom",
		Name = "Wings of Freedom",
		Description = "Enables double jump",
		Rarity = "Legendary",
		Effect = "DoubleJump",
		BaseValue = 1,
		StackValue = 1,
		Color = Color3.fromRGB(255, 215, 0),
		ModelName = "WingsOfFreedom"
	},
	OverchargedBattery = {
		ID = "overcharged_battery",
		Name = "Overcharged Battery",
		Description = "Every 10th attack: x5 damage + AOE",
		Rarity = "Legendary",
		Effect = "OverchargedBattery",
		BaseValue = 5,
		StackValue = 0,
		ExplosionRadius = 15,
		Color = Color3.fromRGB(255, 255, 0),
		ModelName = "OverchargedBattery"
	},
	DivineIntervention = {
		ID = "divine_intervention",
		Name = "Divine Intervention",
		Description = "5% to dodge damage → +50% damage for 5s",
		Rarity = "Legendary",
		Effect = "DivineIntervention",
		BaseValue = 5,
		StackValue = 5,
		DamageBonus = 50,
		BuffDuration = 5,
		Color = Color3.fromRGB(255, 255, 255),
		ModelName = "DivineIntervention"
	},
	MimicLuck = {
		ID = "mimic_luck",
		Name = "Mimic's Luck",
		Description = "Shifts rarity weights toward balance",
		Rarity = "Legendary",
		Effect = "MimicLuck",
		BaseValue = 1,
		StackValue = 1,
		MaxStacks = 8,
		Color = Color3.fromRGB(255, 100, 255),
		ModelName = "MimicLuck"
	},
}

-- =====================================
-- HELPER FUNCTIONS
-- =====================================

-- Получить все предметы определенной редкости
function ItemDatabase:GetItemsByRarity(rarity)
	local items = {}
	for key, item in pairs(self.Items) do
		if item.Rarity == rarity then
			table.insert(items, {Key = key, Data = item})
		end
	end
	return items
end

-- Получить случайный предмет с учетом весов редкости
function ItemDatabase:GetRandomItem(mimicLuckStacks)
	local weights = {}

	-- Копируем базовые веса
	for rarity, weight in pairs(self.RarityWeights) do
		weights[rarity] = weight
	end

	-- Применить Mimic's Luck если есть (балансирует веса)
	if mimicLuckStacks and mimicLuckStacks > 0 then
		local stacks = math.min(mimicLuckStacks, 8) -- максимум 8 стаков
		local balanceAmount = stacks * 2

		-- Уменьшаем Common, увеличиваем Legendary
		weights.Common = math.max(weights.Common - balanceAmount, 15)
		weights.Legendary = weights.Legendary + balanceAmount
	end

	-- Weighted random selection
	local totalWeight = 0
	for _, weight in pairs(weights) do
		totalWeight += weight
	end

	local random = math.random() * totalWeight
	local currentWeight = 0
	local selectedRarity = "Common"

	for rarity, weight in pairs(weights) do
		currentWeight += weight
		if random <= currentWeight then
			selectedRarity = rarity
			break
		end
	end

	-- Выбрать случайный предмет из этой редкости
	local rarityItems = self:GetItemsByRarity(selectedRarity)
	if #rarityItems > 0 then
		local randomItem = rarityItems[math.random(1, #rarityItems)]
		return randomItem.Key, randomItem.Data
	end

	return nil, nil
end

-- Получить данные предмета по ключу
function ItemDatabase:GetItem(itemKey)
	return self.Items[itemKey]
end

-- Получить предмет по ID
function ItemDatabase:GetItemByID(itemID)
	for key, item in pairs(self.Items) do
		if item.ID == itemID then
			return key, item
		end
	end
	return nil, nil
end

-- Получить список всех предметов
function ItemDatabase:GetAllItems()
	local items = {}
	for key, item in pairs(self.Items) do
		table.insert(items, {Key = key, Data = item})
	end
	return items
end

-- Подсчет предметов
function ItemDatabase:GetItemCount()
	local count = 0
	for _ in pairs(self.Items) do
		count += 1
	end
	return count
end

-- Подсчет предметов по редкости
function ItemDatabase:GetRarityCount(rarity)
	local count = 0
	for _, item in pairs(self.Items) do
		if item.Rarity == rarity then
			count += 1
		end
	end
	return count
end

-- Вывод статистики
function ItemDatabase:PrintStats()
	print("=================================")
	print("📦 ITEM DATABASE STATISTICS")
	print("=================================")
	print("Total Items: " .. self:GetItemCount())
	print("Common: " .. self:GetRarityCount("Common"))
	print("Uncommon: " .. self:GetRarityCount("Uncommon"))
	print("Rare: " .. self:GetRarityCount("Rare"))
	print("Legendary: " .. self:GetRarityCount("Legendary"))
	print("=================================")
end

-- Инициализация
ItemDatabase:PrintStats()

return ItemDatabase
