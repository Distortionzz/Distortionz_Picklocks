local isBusy = false
local robbedVehicles = {}
local unlockedVehicles = {}
local picklockedVehicles = {}
local alarmedVehicles = {}

local blacklistedVehicleHashes = {}

local function DebugPrint(message)
    if Config.Debug then
        print(('[%s:client] %s'):format(Config.ResourceName, message))
    end
end

local function Notify(message, status, duration)
    status = status or 'info'
    duration = duration or 5000

    if Config.Notify.useDistortionzNotify and GetResourceState('distortionz_notify') == 'started' then
        local ok = pcall(function()
            exports['distortionz_notify']:Notify(message, status, duration)
        end)

        if ok then return end

        ok = pcall(function()
            exports['distortionz_notify']:Send(message, status, duration)
        end)

        if ok then return end

        ok = pcall(function()
            TriggerEvent('distortionz_notify:client:notify', message, status, duration)
        end)

        if ok then return end
    end

    lib.notify({
        title = Config.Notify.title,
        description = message,
        type = status,
        duration = duration
    })
end

RegisterNetEvent('distortionz_picklocks:client:notify', function(message, status, duration)
    Notify(message, status, duration)
end)

local function LoadAnimDict(dict)
    RequestAnimDict(dict)

    local timeout = GetGameTimer() + 8000

    while not HasAnimDictLoaded(dict) do
        Wait(25)

        if GetGameTimer() > timeout then
            DebugPrint(('Anim dict timeout: %s'):format(dict))
            return false
        end
    end

    return true
end

local function BuildHashes()
    for _, modelName in ipairs(Config.BlacklistedVehicleModels or {}) do
        blacklistedVehicleHashes[joaat(modelName)] = true
    end
end

local function GetVehicleKey(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return nil
    end

    local plate = GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'
    plate = plate:gsub('%s+', '')

    return plate
end

local function GetPlate(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'
    return plate:gsub('^%s*(.-)%s*$', '%1')
end

local function RequestControl(entity, timeout)
    timeout = timeout or 2000

    if not DoesEntityExist(entity) then
        return false
    end

    if NetworkHasControlOfEntity(entity) then
        return true
    end

    NetworkRequestControlOfEntity(entity)

    local endTime = GetGameTimer() + timeout

    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < endTime do
        Wait(25)
        NetworkRequestControlOfEntity(entity)
    end

    return NetworkHasControlOfEntity(entity)
end

local function ForceUnlockVehicle(vehicle, startEngine)
    if not DoesEntityExist(vehicle) then return end

    RequestControl(vehicle, 1000)

    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleUndriveable(vehicle, false)

    if startEngine and Config.Picklock.allowDriveAway then
        SetVehicleEngineOn(vehicle, true, true, false)
    end
end

local function IsVehicleRobbedRecently(vehicle)
    local key = GetVehicleKey(vehicle)

    if not key then return true end

    local expires = robbedVehicles[key]

    if not expires then
        return false
    end

    if GetGameTimer() >= expires then
        robbedVehicles[key] = nil
        return false
    end

    return true
end

local function MarkVehicleRobbed(vehicle)
    if not Config.Search.markVehicleRobbed then return end

    local key = GetVehicleKey(vehicle)

    if not key then return end

    robbedVehicles[key] = GetGameTimer() + ((Config.Picklock.vehicleRobbedCooldown or 1800) * 1000)

    Entity(vehicle).state:set('distortionz_vehicle_robbed', true, true)
end

local function MarkVehicleUnlocked(vehicle)
    local key = GetVehicleKey(vehicle)

    if not key then return end

    unlockedVehicles[key] = true
    picklockedVehicles[key] = true

    Entity(vehicle).state:set('distortionz_picklocked', true, true)
    Entity(vehicle).state:set('distortionz_alarm_on_enter', true, true)
end

local function IsVehiclePicklocked(vehicle)
    local key = GetVehicleKey(vehicle)

    if not key then return false end

    if unlockedVehicles[key] then return true end
    if picklockedVehicles[key] then return true end

    local state = Entity(vehicle).state

    return state and state.distortionz_picklocked == true
end

local function IsVehicleBlacklisted(vehicle)
    if not DoesEntityExist(vehicle) then return true end

    local class = GetVehicleClass(vehicle)

    if Config.BlacklistedVehicleClasses and Config.BlacklistedVehicleClasses[class] then
        return true
    end

    local model = GetEntityModel(vehicle)

    if blacklistedVehicleHashes[model] then
        return true
    end

    return false
end

local function IsVehicleLocked(vehicle)
    if not DoesEntityExist(vehicle) then return false end

    local lockStatus = GetVehicleDoorLockStatus(vehicle)

    return lockStatus == 2 or lockStatus == 3 or lockStatus == 4 or lockStatus == 7 or lockStatus == 10
end

local function IsValidVehicle(vehicle)
    if isBusy then return false end
    if not vehicle or vehicle == 0 then return false end
    if not DoesEntityExist(vehicle) then return false end
    if IsEntityDead(vehicle) then return false end
    if IsVehicleBlacklisted(vehicle) then return false end

    if Config.Picklock.requireEmptyVehicle and not IsVehicleSeatFree(vehicle, -1) then
        return false
    end

    return true
end

local function CanPickVehicle(vehicle)
    if not IsValidVehicle(vehicle) then return false end

    if IsVehicleRobbedRecently(vehicle) then
        return false
    end

    if IsVehiclePicklocked(vehicle) then
        return false
    end

    if Config.Picklock.requireLockedVehicle and not IsVehicleLocked(vehicle) then
        return false
    end

    return true
end

local function CanSearchVehicle(vehicle)
    if not IsValidVehicle(vehicle) then return false end

    if IsVehicleRobbedRecently(vehicle) then
        return false
    end

    if Config.Search.requirePicklocked and not IsVehiclePicklocked(vehicle) then
        return false
    end

    if Config.Search.requireUnlocked then
        if IsVehicleLocked(vehicle) and not IsVehiclePicklocked(vehicle) then
            return false
        end
    end

    return true
end

local function GetVehicleCoordsTable(vehicle)
    local coords = GetEntityCoords(vehicle)

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z
    }
end

local function PlayAnimation(animData)
    if not animData or not animData.dict or not animData.anim then return end

    local ped = PlayerPedId()

    if LoadAnimDict(animData.dict) then
        TaskPlayAnim(
            ped,
            animData.dict,
            animData.anim,
            8.0,
            -8.0,
            -1,
            animData.flag or 49,
            0.0,
            false,
            false,
            false
        )
    end
end

local function StopAnimation()
    ClearPedTasks(PlayerPedId())
end

local function GiveVehicleKeys(vehicle)
    if not Config.Picklock.giveKeysOnSuccess then return end
    if not DoesEntityExist(vehicle) then return end

    local plate = GetPlate(vehicle)
    local system = Config.Picklock.vehicleKeySystem

    if system == 'none' then
        return
    end

    if system == 'qbx_vehiclekeys' then
        if GetResourceState('qbx_vehiclekeys') == 'started' then
            TriggerServerEvent('qbx_vehiclekeys:server:AcquireVehicleKeys', plate)
            TriggerServerEvent('qbx_vehiclekeys:server:AcquireVehicleKeys', plate, true)
            TriggerEvent('qbx_vehiclekeys:client:AddKeys', plate)
            TriggerEvent('vehiclekeys:client:SetOwner', plate)
            return
        end
    end

    if system == 'qb-vehiclekeys' then
        if GetResourceState('qb-vehiclekeys') == 'started' then
            TriggerEvent('vehiclekeys:client:SetOwner', plate)
            TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
            TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate, true)
            return
        end
    end

    if system == 'custom' then
        if Config.Picklock.customKeyClientEvent and Config.Picklock.customKeyClientEvent ~= '' then
            TriggerEvent(Config.Picklock.customKeyClientEvent, plate, vehicle)
        end

        if Config.Picklock.customKeyServerEvent and Config.Picklock.customKeyServerEvent ~= '' then
            TriggerServerEvent(Config.Picklock.customKeyServerEvent, plate)
        end
    end
end

local function StartVehicleAlarmForDuration(vehicle, duration)
    if not DoesEntityExist(vehicle) then return end

    duration = tonumber(duration) or Config.Picklock.alarmDuration or 12000

    RequestControl(vehicle, 1000)

    SetVehicleAlarm(vehicle, true)
    StartVehicleAlarm(vehicle)

    CreateThread(function()
        Wait(duration)

        if DoesEntityExist(vehicle) then
            RequestControl(vehicle, 1000)
            SetVehicleAlarm(vehicle, false)
        end
    end)
end

local function ShouldTriggerEnterAlarm(vehicle)
    if not Config.Picklock.alarmOnEnterAfterPicklock then return false end
    if not DoesEntityExist(vehicle) then return false end

    local key = GetVehicleKey(vehicle)
    if not key then return false end

    local state = Entity(vehicle).state
    local isPicklocked = picklockedVehicles[key] or unlockedVehicles[key] or (state and state.distortionz_picklocked == true)

    if not isPicklocked then return false end

    if Config.Picklock.alarmOnEnterOnlyOnce and alarmedVehicles[key] then
        return false
    end

    return true
end

local function TriggerEnterAlarm(vehicle)
    if not DoesEntityExist(vehicle) then return end

    local key = GetVehicleKey(vehicle)
    if not key then return end

    alarmedVehicles[key] = true

    StartVehicleAlarmForDuration(vehicle, Config.Picklock.alarmOnEnterDuration or 60000)

    Notify('The vehicle alarm is going off!', 'warning', 6000)
end

local function KeepVehicleUnlocked(vehicle, duration)
    if not DoesEntityExist(vehicle) then return end

    duration = tonumber(duration) or 15000

    CreateThread(function()
        local endTime = GetGameTimer() + duration

        while DoesEntityExist(vehicle) and GetGameTimer() < endTime do
            ForceUnlockVehicle(vehicle, true)
            Wait(750)
        end
    end)
end

local function UnlockVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return end

    RequestControl(vehicle, 2500)

    local plate = GetPlate(vehicle)

    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)
    SetVehicleNeedsToBeHotwired(vehicle, false)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)
    SetVehicleIsStolen(vehicle, true)
    SetVehicleUndriveable(vehicle, false)

    if Config.Picklock.allowDriveAway then
        SetVehicleEngineOn(vehicle, true, true, false)
    end

    if NetworkGetEntityIsNetworked(vehicle) then
        local netId = NetworkGetNetworkIdFromEntity(vehicle)
        SetNetworkIdCanMigrate(netId, true)
        SetNetworkIdExistsOnAllMachines(netId, true)
    end

    MarkVehicleUnlocked(vehicle)

    if Config.Picklock.giveKeysOnSuccess then
        GiveVehicleKeys(vehicle)
    end

    KeepVehicleUnlocked(vehicle, 15000)

    Notify(('Vehicle unlocked. Plate: %s'):format(plate), 'success', 6000)
end

local function FaceVehicle(vehicle)
    if not DoesEntityExist(vehicle) then return end

    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(vehicle)

    TaskTurnPedToFaceCoord(playerPed, coords.x, coords.y, coords.z, 750)
    Wait(750)
end

local function PickVehicle(vehicle)
    if isBusy then
        Notify('You are already doing something.', 'warning')
        return
    end

    if not CanPickVehicle(vehicle) then
        Notify('You cannot pick this vehicle.', 'error')
        return
    end

    local plate = GetPlate(vehicle)

    local startResult = lib.callback.await('distortionz_picklocks:server:startPicklock', false, {
        plate = plate,
        coords = GetVehicleCoordsTable(vehicle)
    })

    if not startResult then
        Notify('Failed to start picklock.', 'error')
        return
    end

    if not startResult.success then
        Notify(startResult.message or 'You cannot picklock right now.', startResult.status or 'error')
        return
    end

    isBusy = true

    FaceVehicle(vehicle)
    PlayAnimation(Config.Animations.picklock)

    local progress = lib.progressCircle({
        duration = Config.Picklock.duration,
        label = 'Picking vehicle lock...',
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            sprint = true
        }
    })

    StopAnimation()

    if not progress then
        isBusy = false
        TriggerServerEvent('distortionz_picklocks:server:cancelPicklock')
        Notify('Picklock cancelled.', 'error')
        return
    end

    local finishResult = lib.callback.await('distortionz_picklocks:server:finishPicklock', false, {
        plate = plate,
        coords = GetVehicleCoordsTable(vehicle)
    })

    isBusy = false

    if not finishResult then
        Notify('Picklock failed.', 'error')
        return
    end

    if not finishResult.success then
        if finishResult.startAlarm then
            StartVehicleAlarmForDuration(vehicle, Config.Picklock.alarmDuration or 12000)
        end

        Notify(finishResult.message or 'The lock resisted.', finishResult.status or 'error')
        return
    end

    if Config.Picklock.unlockVehicleOnSuccess then
        UnlockVehicle(vehicle)
    end

    Notify(finishResult.message or 'Vehicle unlocked. You can drive it or search it for valuables.', 'success', 6000)
end

local function SearchVehicle(vehicle)
    if isBusy then
        Notify('You are already doing something.', 'warning')
        return
    end

    if not CanSearchVehicle(vehicle) then
        Notify('You cannot search this vehicle.', 'error')
        return
    end

    local plate = GetPlate(vehicle)

    local startResult = lib.callback.await('distortionz_picklocks:server:startSearch', false, {
        plate = plate,
        coords = GetVehicleCoordsTable(vehicle)
    })

    if not startResult then
        Notify('Failed to start search.', 'error')
        return
    end

    if not startResult.success then
        Notify(startResult.message or 'You cannot search this vehicle.', startResult.status or 'error')
        return
    end

    isBusy = true

    FaceVehicle(vehicle)
    PlayAnimation(Config.Animations.search)

    local progress = lib.progressCircle({
        duration = Config.Search.duration,
        label = 'Searching vehicle...',
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            sprint = true
        }
    })

    StopAnimation()

    if not progress then
        isBusy = false
        TriggerServerEvent('distortionz_picklocks:server:cancelSearch')
        Notify('Search cancelled.', 'error')
        return
    end

    local result = lib.callback.await('distortionz_picklocks:server:finishSearch', false, {
        plate = plate,
        coords = GetVehicleCoordsTable(vehicle)
    })

    isBusy = false

    if not result then
        Notify('Search failed.', 'error')
        return
    end

    if not result.success then
        Notify(result.message or 'You found nothing.', result.status or 'error')
        return
    end

    MarkVehicleRobbed(vehicle)

    Notify(result.message or 'You searched the vehicle.', result.status or 'success', 7000)
end

RegisterNetEvent('distortionz_picklocks:client:policeAlert', function(alertData)
    local coords = alertData.coords

    Notify(alertData.message or 'Vehicle tampering reported.', 'warning', 7500)

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

    SetBlipSprite(blip, Config.Police.alertBlip.sprite)
    SetBlipColour(blip, Config.Police.alertBlip.color)
    SetBlipScale(blip, Config.Police.alertBlip.scale)
    SetBlipAsShortRange(blip, false)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Police.alertBlip.label or 'Vehicle Tampering')
    EndTextCommandSetBlipName(blip)

    CreateThread(function()
        Wait((Config.Police.alertBlip.duration or 60) * 1000)

        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
end)

CreateThread(function()
    local lastVehicle = 0

    while true do
        Wait(750)

        local playerPed = PlayerPedId()

        if not IsPedInAnyVehicle(playerPed, false) then
            lastVehicle = 0
            goto continue
        end

        local vehicle = GetVehiclePedIsIn(playerPed, false)

        if vehicle == 0 or vehicle == lastVehicle then
            goto continue
        end

        if GetPedInVehicleSeat(vehicle, -1) ~= playerPed then
            goto continue
        end

        lastVehicle = vehicle

        if IsVehiclePicklocked(vehicle) then
            ForceUnlockVehicle(vehicle, true)
            KeepVehicleUnlocked(vehicle, 15000)
        end

        if ShouldTriggerEnterAlarm(vehicle) then
            TriggerEnterAlarm(vehicle)
        end

        ::continue::
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    if isBusy then
        StopAnimation()
    end

    pcall(function()
        exports.ox_target:removeGlobalVehicle('distortionz_picklocks_pick_vehicle')
        exports.ox_target:removeGlobalVehicle('distortionz_picklocks_search_vehicle')
    end)
end)

CreateThread(function()
    BuildHashes()

    exports.ox_target:addGlobalVehicle({
        {
            name = 'distortionz_picklocks_pick_vehicle',
            icon = Config.Target.pickLock.icon,
            label = Config.Target.pickLock.label,
            distance = Config.Target.pickLock.distance,
            canInteract = function(entity)
                return CanPickVehicle(entity)
            end,
            onSelect = function(data)
                if not data or not data.entity then return end
                PickVehicle(data.entity)
            end
        },
        {
            name = 'distortionz_picklocks_search_vehicle',
            icon = Config.Target.searchVehicle.icon,
            label = Config.Target.searchVehicle.label,
            distance = Config.Target.searchVehicle.distance,
            canInteract = function(entity)
                return CanSearchVehicle(entity)
            end,
            onSelect = function(data)
                if not data or not data.entity then return end
                SearchVehicle(data.entity)
            end
        }
    })

    DebugPrint('Global vehicle targets registered.')
end)