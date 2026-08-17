print('[distortionz_picklocks] server.lua is loading...')

local activePicklocks = {}
local activeSearches = {}
local playerCooldowns = {}
local vehicleRobbed = {}

local function DebugPrint(message)
    if Config.Debug then
        print(('[%s:server] %s'):format(Config.ResourceName, message))
    end
end

local function Notify(src, message, status, duration)
    TriggerClientEvent('distortionz_picklocks:client:notify', src, message, status or 'info', duration or 5000)
end

local function GetPlayer(src)
    if GetResourceState('qbx_core') == 'started' then
        local ok, player = pcall(function()
            return exports.qbx_core:GetPlayer(src)
        end)

        if ok and player then
            return player
        end
    end

    if GetResourceState('qb-core') == 'started' then
        local ok, QBCore = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)

        if ok and QBCore then
            return QBCore.Functions.GetPlayer(src)
        end
    end

    return nil
end

local function GetCitizenId(src)
    local player = GetPlayer(src)

    if not player then
        return ('source:%s'):format(src)
    end

    if player.PlayerData and player.PlayerData.citizenid then
        return player.PlayerData.citizenid
    end

    if player.citizenid then
        return player.citizenid
    end

    return ('source:%s'):format(src)
end

local function GetPlayerJob(src)
    local player = GetPlayer(src)

    if not player then return nil end

    if player.PlayerData and player.PlayerData.job and player.PlayerData.job.name then
        return player.PlayerData.job.name
    end

    if player.job and player.job.name then
        return player.job.name
    end

    return nil
end

local function GetItemCount(src, item)
    local ok, count = pcall(function()
        return exports.ox_inventory:Search(src, 'count', item)
    end)

    if not ok then return 0 end

    return tonumber(count) or 0
end

local function RemoveItem(src, item, amount)
    amount = math.floor(tonumber(amount) or 0)

    if amount <= 0 then return true end

    local ok, removed = pcall(function()
        return exports.ox_inventory:RemoveItem(src, item, amount)
    end)

    if not ok then return false end

    return removed == true or removed == amount
end

local function AddItem(src, item, amount)
    amount = math.floor(tonumber(amount) or 0)

    if not item or item == '' or amount <= 0 then
        return false
    end

    local ok, added = pcall(function()
        return exports.ox_inventory:AddItem(src, item, amount)
    end)

    if not ok then
        print(('[%s] Failed to add item %s x%s to source %s'):format(Config.ResourceName, item, amount, src))
        return false
    end

    return added ~= false
end

local function AddCash(src, amount)
    amount = math.floor(tonumber(amount) or 0)

    if amount <= 0 then return false end

    if GetResourceState('qbx_core') == 'started' then
        local player = GetPlayer(src)

        if player and player.Functions and player.Functions.AddMoney then
            local ok, result = pcall(function()
                return player.Functions.AddMoney('cash', amount, 'distortionz-picklocks')
            end)

            if ok then return result ~= false end
        end

        local ok, result = pcall(function()
            return exports.qbx_core:AddMoney(src, 'cash', amount, 'distortionz-picklocks')
        end)

        if ok then return result ~= false end
    end

    if GetResourceState('qb-core') == 'started' then
        local player = GetPlayer(src)

        if player and player.Functions and player.Functions.AddMoney then
            local ok, result = pcall(function()
                return player.Functions.AddMoney('cash', amount, 'distortionz-picklocks')
            end)

            if ok then return result ~= false end
        end
    end

    return false
end

local function FormatTime(seconds)
    seconds = tonumber(seconds) or 0

    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60

    if minutes <= 0 then
        return ('%ss'):format(remainingSeconds)
    end

    return ('%sm %ss'):format(minutes, remainingSeconds)
end

local function IsOnPlayerCooldown(citizenId)
    if not Config.Picklock.playerCooldown.enabled then
        return false, 0
    end

    local expires = playerCooldowns[citizenId]

    if not expires then return false, 0 end

    local now = os.time()

    if now >= expires then
        playerCooldowns[citizenId] = nil
        return false, 0
    end

    return true, expires - now
end

local function SetPlayerCooldown(citizenId)
    if not Config.Picklock.playerCooldown.enabled then return end

    playerCooldowns[citizenId] = os.time() + Config.Picklock.playerCooldown.seconds
end

local function CleanPlate(plate)
    plate = tostring(plate or 'UNKNOWN')
    return plate:gsub('^%s*(.-)%s*$', '%1')
end

local function IsVehicleRobbed(plate)
    plate = CleanPlate(plate)

    local expires = vehicleRobbed[plate]

    if not expires then return false, 0 end

    local now = os.time()

    if now >= expires then
        vehicleRobbed[plate] = nil
        return false, 0
    end

    return true, expires - now
end

local function MarkVehicleRobbedServer(plate)
    plate = CleanPlate(plate)
    vehicleRobbed[plate] = os.time() + (Config.Picklock.vehicleRobbedCooldown or 1800)
end

local function GetBestLockpick(src)
    local advanced = Config.Items.advancedLockpick
    local normal = Config.Items.lockpick

    if advanced and advanced ~= '' and GetItemCount(src, advanced) > 0 then
        return advanced, true
    end

    if normal and normal ~= '' and GetItemCount(src, normal) > 0 then
        return normal, false
    end

    return nil, false
end

local function BreakLockpick(src, item, chance)
    if not Config.Picklock.breakLockpick then return false end
    if not item then return false end

    if math.random(1, 100) <= (tonumber(chance) or 0) then
        RemoveItem(src, item, 1)
        Notify(src, 'Your lockpick broke.', 'warning', 5000)
        return true
    end

    return false
end

local function AlertPolice(coords, message, chance)
    if not Config.Police or not Config.Police.enabled then return end

    if math.random(1, 100) > (tonumber(chance) or 0) then return end

    for _, playerId in ipairs(GetPlayers()) do
        local playerSrc = tonumber(playerId)
        local job = GetPlayerJob(playerSrc)

        if job and Config.Police.jobs[job] then
            TriggerClientEvent('distortionz_picklocks:client:policeAlert', playerSrc, {
                coords = coords,
                message = message or 'Vehicle tampering reported.'
            })
        end
    end
end

local function RollChance(chance)
    return math.random(1, 100) <= (tonumber(chance) or 0)
end

local function RollWeightedItem(pool)
    local totalWeight = 0

    for _, itemData in ipairs(pool or {}) do
        totalWeight = totalWeight + (tonumber(itemData.chance) or 0)
    end

    if totalWeight <= 0 then return nil end

    local roll = math.random(1, totalWeight)
    local current = 0

    for _, itemData in ipairs(pool or {}) do
        current = current + (tonumber(itemData.chance) or 0)

        if roll <= current then
            return itemData
        end
    end

    return nil
end

local function GiveSearchRewards(src)
    local rewardMessages = {}
    local gotReward = false

    if RollChance(Config.Search.noRewardChance or 0) then
        return {
            gotReward = false,
            message = 'The vehicle had nothing useful inside.',
            status = 'warning'
        }
    end

    if Config.Rewards.cash.enabled and RollChance(Config.Rewards.cash.chance) then
        local amount = math.random(Config.Rewards.cash.min, Config.Rewards.cash.max)

        if AddCash(src, amount) then
            gotReward = true
            rewardMessages[#rewardMessages + 1] = ('$%s cash'):format(amount)
        end
    end

    if Config.Rewards.dirtyMoney.enabled and RollChance(Config.Rewards.dirtyMoney.chance) then
        local amount = math.random(Config.Rewards.dirtyMoney.min, Config.Rewards.dirtyMoney.max)
        local item = Config.Rewards.dirtyMoney.item

        if AddItem(src, item, amount) then
            gotReward = true
            rewardMessages[#rewardMessages + 1] = ('$%s dirty money'):format(amount)
        end
    end

    if Config.Rewards.items.enabled and RollChance(Config.Rewards.items.chance) then
        local itemData = RollWeightedItem(Config.Rewards.items.pool)

        if itemData then
            local amount = math.random(itemData.min or 1, itemData.max or 1)

            if AddItem(src, itemData.item, amount) then
                gotReward = true
                rewardMessages[#rewardMessages + 1] = ('%sx %s'):format(amount, itemData.item)
            end
        end
    end

    if not gotReward then
        return {
            gotReward = false,
            message = 'You found nothing worth taking.',
            status = 'warning'
        }
    end

    return {
        gotReward = true,
        message = ('You found: %s.'):format(table.concat(rewardMessages, ', ')),
        status = 'success'
    }
end

lib.callback.register('distortionz_picklocks:server:startPicklock', function(src, data)
    if activePicklocks[src] then
        return {
            success = false,
            status = 'warning',
            message = 'You are already picking a lock.'
        }
    end

    local citizenId = GetCitizenId(src)
    local onCooldown, remaining = IsOnPlayerCooldown(citizenId)

    if onCooldown then
        return {
            success = false,
            status = 'warning',
            message = ('Lay low for %s.'):format(FormatTime(remaining))
        }
    end

    local plate = CleanPlate(data and data.plate)
    local robbed, vehicleRemaining = IsVehicleRobbed(plate)

    if robbed then
        return {
            success = false,
            status = 'warning',
            message = ('This vehicle was already hit. Try again in %s.'):format(FormatTime(vehicleRemaining))
        }
    end

    local lockpickItem, isAdvanced = GetBestLockpick(src)

    if Config.Picklock.requireItem and not lockpickItem then
        return {
            success = false,
            status = 'error',
            message = 'You need a lockpick.'
        }
    end

    activePicklocks[src] = {
        citizenId = citizenId,
        plate = plate,
        item = lockpickItem,
        isAdvanced = isAdvanced,
        startedAt = os.time(),
        coords = data and data.coords or nil
    }

    AlertPolice(
        data and data.coords,
        '911 call: someone is tampering with a vehicle.',
        Config.Police.picklockAlertChance
    )

    DebugPrint(('Started picklock for %s | plate %s'):format(src, plate))

    return {
        success = true
    }
end)

lib.callback.register('distortionz_picklocks:server:finishPicklock', function(src, data)
    local picklock = activePicklocks[src]

    if not picklock then
        return {
            success = false,
            status = 'error',
            message = 'No active picklock found.'
        }
    end

    activePicklocks[src] = nil

    local successChance = picklock.isAdvanced and Config.Picklock.advancedSuccessChance or Config.Picklock.normalSuccessChance
    local wasSuccessful = RollChance(successChance)

    local breakChance

    if wasSuccessful then
        breakChance = picklock.isAdvanced and Config.Picklock.advancedLockpickBreakChance or Config.Picklock.normalLockpickBreakChance
    else
        breakChance = picklock.isAdvanced and Config.Picklock.failedAdvancedLockpickBreakChance or Config.Picklock.failedNormalLockpickBreakChance
    end

    BreakLockpick(src, picklock.item, breakChance)

    if not wasSuccessful then
        AlertPolice(
            data and data.coords or picklock.coords,
            '911 call: failed vehicle break-in attempt reported.',
            Config.Police.failedAlertChance
        )

        SetPlayerCooldown(picklock.citizenId)

        return {
            success = false,
            status = 'error',
            startAlarm = true,
            message = 'You failed to pick the lock.'
        }
    end

    AlertPolice(
        data and data.coords or picklock.coords,
        '911 call: vehicle break-in reported.',
        Config.Police.successfulAlertChance
    )

    SetPlayerCooldown(picklock.citizenId)

    return {
        success = true,
        status = 'success',
        message = 'Vehicle unlocked. You can drive it or search it for valuables.'
    }
end)

RegisterNetEvent('distortionz_picklocks:server:cancelPicklock', function()
    local src = source
    local picklock = activePicklocks[src]

    if not picklock then return end

    activePicklocks[src] = nil
    SetPlayerCooldown(picklock.citizenId)

    DebugPrint(('Cancelled picklock for %s'):format(src))
end)

lib.callback.register('distortionz_picklocks:server:startSearch', function(src, data)
    if activeSearches[src] then
        return {
            success = false,
            status = 'warning',
            message = 'You are already searching a vehicle.'
        }
    end

    local plate = CleanPlate(data and data.plate)
    local robbed, vehicleRemaining = IsVehicleRobbed(plate)

    if robbed then
        return {
            success = false,
            status = 'warning',
            message = ('This vehicle was already searched. Try again in %s.'):format(FormatTime(vehicleRemaining))
        }
    end

    activeSearches[src] = {
        plate = plate,
        startedAt = os.time(),
        coords = data and data.coords or nil
    }

    AlertPolice(
        data and data.coords,
        '911 call: suspicious person searching a vehicle.',
        Config.Police.searchAlertChance
    )

    DebugPrint(('Started vehicle search for %s | plate %s'):format(src, plate))

    return {
        success = true
    }
end)

lib.callback.register('distortionz_picklocks:server:finishSearch', function(src, data)
    local search = activeSearches[src]

    if not search then
        return {
            success = false,
            status = 'error',
            message = 'No active vehicle search found.'
        }
    end

    activeSearches[src] = nil

    local plate = CleanPlate(data and data.plate or search.plate)

    local robbed = IsVehicleRobbed(plate)

    if robbed then
        return {
            success = false,
            status = 'warning',
            message = 'This vehicle has already been searched.'
        }
    end

    MarkVehicleRobbedServer(plate)

    local reward = GiveSearchRewards(src)

    return {
        success = true,
        status = reward.status,
        message = reward.message
    }
end)

RegisterNetEvent('distortionz_picklocks:server:cancelSearch', function()
    local src = source

    if not activeSearches[src] then return end

    activeSearches[src] = nil

    DebugPrint(('Cancelled vehicle search for %s'):format(src))
end)

AddEventHandler('playerDropped', function()
    local src = source

    activePicklocks[src] = nil
    activeSearches[src] = nil
end)

CreateThread(function()
    Wait(1000)
    print(('^5[%s]^7 ^2v%s loaded — successChance=%d%%/%d%% (normal/adv)^7'):format(
        Config.ResourceName,
        Config.CurrentVersion,
        Config.Picklock.normalSuccessChance,
        Config.Picklock.advancedSuccessChance
    ))
end)