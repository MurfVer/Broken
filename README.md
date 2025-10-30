# Broken - Roblox Combat System

Боевая система для Roblox с персонажем **Phantom** и полной интеграцией предметов.

## 📁 Структура проекта

```
Broken/
├── ReplicatedStorage/                  # Модули (shared between server/client)
│   ├── CombatSystem.lua               # Главная боевая система (v3)
│   ├── ItemDatabase.lua               # База данных предметов (28 items)
│   └── ItemEffectSystem.lua           # Система эффектов предметов
├── ServerScriptService/                # Серверные скрипты
│   ├── PhantomHarvest.lua             # Жатва Душ (Ультимейт)
│   ├── PhantomScythe.lua              # Коса Жнеца
│   ├── PhantomShadowStep.lua          # Теневой Шаг
│   └── PhantomSoulHarvest.lua         # Жатва Душ (Канальная)
└── StarterPlayer/
    └── StarterCharacterScripts/        # Клиентские скрипты
        ├── PhantomHarvestClient.lua    # Клиент: Жатва Душ (Ультимейт)
        ├── PhantomScytheClient.lua     # Клиент: Коса Жнеца
        ├── PhantomShadowStepClient.lua # Клиент: Теневой Шаг
        └── PhantomSoulHarvestClient.lua# Клиент: Жатва Душ (Канальная)
```

---

## 📦 Модули (ReplicatedStorage)

### 1. ⚔️ CombatSystem.lua

Главная боевая система с расчётом урона, эффектов и интеграцией всех предметов.

**Основные функции:**
```lua
-- Применить урон с полной интеграцией предметов
CombatSystem.ApplyDamage(victim, damage, attacker, hitPosition)

-- Расчёт исходящего урона (бонусы атакующего)
CombatSystem.CalculateOutgoingDamage(attacker, baseDamage, targetHumanoid)

-- Расчёт входящего урона (защита, щиты жертвы)
CombatSystem.CalculateIncomingDamage(victim, damage, attacker)

-- On-hit эффекты (поджог, яд, молнии)
CombatSystem.TriggerOnHitEffects(attacker, victim, damage, hitPosition)

-- Вампиризм
CombatSystem.ApplyLifesteal(attacker, damageDealt)
```

**Поддерживаемые предметы:**
- 💥 **Урон:** Sharp Stone, Quick Draw, Berserker's Rage, Momentum Chain, Executioner's Blade, Overcharged Battery
- 🛡️ **Защита:** Iron Armor, Energy Shield, Divine Intervention, Survivor's Will
- ⚡ **Эффекты:** Old Lighter (Burn), Vile Vial (Poison), Chain Lightning, Blade Echo
- 🧛 **Вампиризм:** Vampire Fang
- 💀 **Прочее:** Soul Eater, Phoenix Ash

**Интеграция с NPC:**
```lua
-- Для NPC создайте fake player:
local fakePlayer = {
    UserId = npc:GetAttribute("NPCId") or 0,
    Name = npc.Name,
    Character = npc,
    Team = nil
}
CombatSystem.ApplyDamage(fakePlayer, damage, attacker, hitPosition)
```

---

### 2. 📋 ItemDatabase.lua

База данных всех предметов с их характеристиками и редкостью.

**Структура предмета:**
```lua
ItemName = {
    ID = "unique_id",
    Name = "Display Name",
    Description = "Item description",
    Rarity = "Common/Uncommon/Rare/Legendary",
    Effect = "EffectName",
    BaseValue = 10,           -- Базовое значение
    StackValue = 5,           -- Значение за каждый доп. стак
    Color = Color3.fromRGB(...),
    ModelName = "ModelName"
}
```

**Предметы по редкости:**
- **Common (50%):** 8 предметов - Sprint Shoes, Healing Crystal, Sharp Stone, Iron Armor, Scavenger's Pouch, Quick Draw, Survivor's Will, Old Lighter
- **Uncommon (35%):** 7 предметов - Lucky Clover, Life Stone, Anti-Gravity Belt, Berserker's Rage, Momentum Chain, Bag of Caltrops, Thorn Bandoleer
- **Rare (12%):** 9 предметов - Energy Shield, Vampire Fang, Blade Echo, Phoenix Ash, Soul Eater, Executioner's Blade, Chain Lightning, Crit Multiplier, Vile Vial
- **Legendary (3%):** 4 предмета - Wings of Freedom, Overcharged Battery, Divine Intervention, Mimic's Luck

**Основные функции:**
```lua
-- Получить случайный предмет с учётом весов редкости
local itemKey, itemData = ItemDatabase:GetRandomItem(mimicLuckStacks)

-- Получить предмет по ключу
local item = ItemDatabase:GetItem("SharpStone")

-- Получить предмет по ID
local key, item = ItemDatabase:GetItemByID("sharp_stone")

-- Получить все предметы определённой редкости
local rareItems = ItemDatabase:GetItemsByRarity("Rare")

-- Статистика
ItemDatabase:PrintStats()
```

**Особенности:**
- ❌ Удалены: InfinityDash, OverflowingChalice (причина: баланс)
- ✅ Система весов редкости с Mimic's Luck
- ✅ Всего 28 предметов

---

### 3. ✨ ItemEffectSystem.lua

Система обработки всех эффектов предметов в реальном времени.

**Основные функции:**
```lua
-- Инициализация предметов игрока
ItemEffectSystem:InitializePlayer(player)

-- Применить эффекты предмета
ItemEffectSystem:ApplyItemEffects(player, humanoid)

-- Обновить статистику после изменения предметов
ItemEffectSystem:UpdatePlayerStats(player)
```

**Поддерживаемые эффекты:**

| Эффект | Предметы | Описание |
|--------|----------|----------|
| **Speed** | Sprint Shoes | +5 WalkSpeed за стак |
| **Health** | Healing Crystal | +20 MaxHealth за стак |
| **DamagePercent** | Sharp Stone | +10% урона за стак |
| **Defense** | Iron Armor | -10 входящего урона за стак |
| **CritChance** | Lucky Clover | +10% шанс крита за стак |
| **Regen** | Life Stone | +2 HP/sec за стак |
| **JumpPower** | Anti-Gravity Belt | +15 JumpPower за стак |
| **Shield** | Energy Shield | +30 HP щита за стак |
| **Lifesteal** | Vampire Fang | +5% вампиризма за стак |
| **DoubleJump** | Wings of Freedom | Двойной прыжок |
| **BurnChance** | Old Lighter | +10% шанс поджога за стак |
| **PoisonChance** | Vile Vial | +20% шанс отравления за стак |
| **QuickDraw** | Quick Draw | +20% урона первой атаки |
| **BerserkerRage** | Berserker's Rage | +25% урона при HP < 30% |
| **MomentumChain** | Momentum Chain | +8% урона за стак (макс 5) |
| **ExecuteDamage** | Executioner's Blade | +100% урона по врагам с HP < 20% |
| **SoulEater** | Soul Eater | +1 MaxHP за убийство (макс 200) |
| **OverchargedBattery** | Overcharged Battery | x5 урон + AOE каждая 10-я атака |

**Система регенерации щита:**
```lua
-- Щит регенерирует 50% от максимума каждые 5 секунд
-- Прерывается при получении урона
```

**Особенности:**
- ✅ Упрощённая система проков (без двойных проков)
- ✅ Поддержка стаков предметов
- ✅ Сохранение базового здоровья при снятии Soul Eater
- ✅ Автоматическое применение всех эффектов через CombatSystem

---

## ⚔️ CombatSystem v3

Очищенная версия боевой системы с полной поддержкой предметов.

### Основные возможности:
- 💥 **Расчёт исходящего урона** - Sharp Stone, Quick Draw, Berserker's Rage, Momentum Chain, Executioner's Blade, Divine Intervention, Overcharged Battery
- 🛡️ **Расчёт входящего урона** - Щиты, Defense, Divine Intervention, Survivor's Will
- ⚡ **On-hit эффекты** - Burn, Poison, Chain Lightning, Blade Echo
- 🧛 **Вампиризм** - Lifesteal от урона
- 💀 **Система убийств** - Отслеживание последнего атакующего
- 💥 **Критические удары** - Simplified (без double crit)
- ⭐ **Бонусы от уровня команды**

### Place в Roblox:
- `CombatSystem.lua` → **ReplicatedStorage** (как ModuleScript)

---

## 👻 Phantom - Способности персонажа

### 1. ⚰️ **Phantom Harvest (Ультимейт)** - Клавиша `R`

**Описание:** Помечает всех врагов в радиусе, через 2.5 секунды наносит массовый урон и лечит за каждого поражённого врага.

**Характеристики:**
- Радиус: **50 studs**
- Урон: **120 HP**
- Длительность метки: **2.5 секунды**
- Лечение: **10 HP** за врага
- Подбрасывание врагов
- Кулдаун: **30 секунд**

**Файлы:**
- Server: `ServerScriptService/PhantomHarvest.lua`
- Client: `StarterCharacterScripts/PhantomHarvestClient.lua`

**Эффекты (ReplicatedStorage):**
- `PhantomHarvestEffects/ActivationSphere`
- `PhantomHarvestEffects/ScytheImpact`
- `PhantomHarvestEffects/EnemyMark`
- `PhantomHarvestEffects/ImpactHit`

---

### 2. 💀 **Phantom Scythe (Коса Жнеца)** - ПКМ

**Описание:** Бросает косу во врага, которая рикошетит до 15 раз. Первое попадание накладывает Метку Смерти (+20% урона на 3 сек).

**Характеристики:**
- Урон (прямое попадание): **60 HP**
- Урон (рикошет): **50 HP**
- Максимум рикошетов: **15**
- Дальность броска: **100 studs**
- Дальность рикошета: **80 studs**
- Метка Смерти: **+20% урона на 3 секунды**
- Кулдаун: **7 секунд**

**Файлы:**
- Server: `ServerScriptService/PhantomScythe.lua`
- Client: `StarterCharacterScripts/PhantomScytheClient.lua`

**Эффекты (ReplicatedStorage):**
- `PhantomScytheEffects/ScytheProjectile`
- `PhantomScytheEffects/ScytheImpact`
- `Weapon` (модель косы на спине)

**Анимации:**
- Бросок: `rbxassetid://106916438821764`
- Ловля: `rbxassetid://94320235737265`

---

### 3. 🌫️ **Phantom Shadow Step (Теневой Шаг)** - Клавиша `Q`

**Описание:** Телепортация на 40 studs вперёд с невидимостью на 1.5 секунды. Первая атака из невидимости наносит **x2.5 крит**.

**Характеристики:**
- Дистанция рывка: **40 studs**
- Невидимость: **1.5 секунды**
- Бонус скорости: **+50%**
- Крит из стелса: **x2.5 урона**
- Кулдаун: **6 секунд**

**Файлы:**
- Server: `ServerScriptService/PhantomShadowStep.lua`
- Client: `StarterCharacterScripts/PhantomShadowStepClient.lua`

**Эффекты (ReplicatedStorage):**
- `PhantomShadowStepEffects/TeleportEffect`

---

### 4. 👻 **Phantom Soul Harvest (Жатва Душ)** - Зажатие ЛКМ

**Описание:** Канальная способность. Выпускает самонаводящиеся души каждые 0.5 секунды, пока зажата ЛКМ.

**Характеристики:**
- Урон за душу: **15 HP**
- Радиус поиска: **100 studs**
- Скорость души: **60 studs/sec**
- Задержка между выстрелами: **0.5 секунды**
- Самонаводящиеся снаряды
- Без кулдауна (канальная)

**Файлы:**
- Server: `ServerScriptService/PhantomSoulHarvest.lua`
- Client: `StarterCharacterScripts/PhantomSoulHarvestClient.lua`

**Эффекты (ReplicatedStorage):**
- `PhantomSoulEffects/SoulProjectile`
- `PhantomSoulEffects/SoulImpact`

---

## 🎮 Управление

| Клавиша | Способность |
|---------|-------------|
| **R** | Phantom Harvest (Ультимейт) |
| **ПКМ** | Phantom Scythe (Коса Жнеца) |
| **Q** | Phantom Shadow Step (Телепорт) |
| **ЛКМ (зажатие)** | Phantom Soul Harvest (Жатва Душ) |

---

## 🔧 Установка в Roblox Studio

### 1. Модули (ReplicatedStorage)
```lua
-- Place: ReplicatedStorage
-- Type: ModuleScript для каждого файла
```
Скопируйте все файлы из папки `ReplicatedStorage/`:
- **CombatSystem.lua** → ModuleScript "CombatSystem"
- **ItemDatabase.lua** → ModuleScript "ItemDatabase"
- **ItemEffectSystem.lua** → ModuleScript "ItemEffectSystem"

### 2. Серверные скрипты
```lua
-- Place: ServerScriptService
-- Type: Script (обычный Script, не LocalScript!)
```
Скопируйте все файлы из папки `ServerScriptService/`:
- PhantomHarvest.lua
- PhantomScythe.lua
- PhantomShadowStep.lua
- PhantomSoulHarvest.lua

### 3. Клиентские скрипты
```lua
-- Place: StarterPlayer → StarterCharacterScripts
-- Type: LocalScript
```
Скопируйте все файлы из папки `StarterPlayer/StarterCharacterScripts/`:
- PhantomHarvestClient.lua
- PhantomScytheClient.lua
- PhantomShadowStepClient.lua
- PhantomSoulHarvestClient.lua

### 4. Эффекты (ReplicatedStorage)
Создайте папки в ReplicatedStorage и поместите в них ваши эффекты:
- `PhantomHarvestEffects/` - эффекты ультимейта
- `PhantomScytheEffects/` - эффекты косы
- `PhantomShadowStepEffects/` - эффекты телепорта
- `PhantomSoulEffects/` - эффекты душ

---

## 🔗 Интеграция с другими системами

### ItemEffectSystem
CombatSystem автоматически подключается к ItemEffectSystem для обработки эффектов предметов.

### DOTSystem
Поддержка Burn и Poison эффектов. Система ищет DOTSystem в ServerScriptService или через `_G.DOTSystem`.

### CrystalSystem
Поддержка бонусов от уровня команды через `_G.CrystalSystem`.

---

## ✨ Особенности

### Все способности интегрированы с CombatSystem:
- ✅ Работают **все 31 предмет** из ItemEffectSystem
- ✅ Вампиризм, криты, проки, DOT-эффекты
- ✅ Защита, щиты, блокировка урона
- ✅ Поддержка **игроков И NPC**
- ✅ Командная система (не бьёт союзников)
- ✅ Кастомные визуальные эффекты
- ✅ Анимации и звуки

---

## 📊 Технические детали

### Phantom Harvest (Ультимейт)
- Расширяющаяся сфера с масштабируемыми эффектами
- Динамическое изменение освещения
- Косы вылетают из земли и возвращаются обратно
- Метки на всех врагах

### Phantom Scythe
- Умная система рикошетов (не бьёт одну цель дважды)
- Коса на спине персонажа (видимая/невидимая рукоять)
- Анимации броска и ловли
- Автовозврат при отсутствии рикошетов

### Phantom Shadow Step
- Эффект прикрепляется к игроку и движется вместе с ним
- Невидимость для других игроков (transparency 0.8)
- Автоматическое снятие невидимости при атаке

### Phantom Soul Harvest
- Волнообразное движение снарядов (призрачный эффект)
- Поддержка Model и Part для эффектов
- Автоматическое отслеживание целей
- Канальная способность (без кулдауна)

---

## 🐛 Отладка

Все скрипты выводят подробные логи в консоль:
- `✅` - Успешная загрузка/выполнение
- `⚠️` - Предупреждения
- `❌` - Ошибки
- `💀/⚰️/🌫️/👻` - События способностей

---

## 📝 Changelog

### v3 (Latest)
- ✅ CombatSystem v3 - очищенная версия
- ✅ Убрана логика OverflowingChalice (double crit)
- ✅ Добавлена защита от рекурсии Blade Echo
- ✅ Chain Lightning теперь проверяет команды
- ✅ Overcharged Battery - реализован взрыв AOE
- ✅ Все способности Phantom используют CombatSystem.ApplyDamage
- ✅ Поддержка NPC (fake player)
- ✅ **ItemDatabase.lua** - полная база данных 28 предметов
- ✅ **ItemEffectSystem.lua** - система эффектов предметов
- ✅ Модули перенесены в ReplicatedStorage для правильной архитектуры

---

## 👨‍💻 Автор

Проект создан для Roblox. Все скрипты написаны на Lua (Luau).

---

## 📜 Лицензия

Этот проект предназначен для использования в Roblox. Все права защищены.
