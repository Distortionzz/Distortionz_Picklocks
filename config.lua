Config = {}

Config.Debug = false

Config.ResourceName = 'distortionz_picklocks'
Config.CurrentVersion = '1.0.0'

Config.VersionCheck = {
    enabled = true,
    url = 'https://raw.githubusercontent.com/Distortionzz/Distortionz_Picklocks/main/version.json',
    checkOnStart = true
}

Config.Notify = {
    title = 'Vehicle Picklocks',
    useDistortionzNotify = true
}

Config.Target = {
    pickLock = {
        icon = 'fa-solid fa-screwdriver-wrench',
        label = 'Pick Vehicle Lock',
        distance = 2.5
    },

    searchVehicle = {
        icon = 'fa-solid fa-box-open',
        label = 'Search Vehicle',
        distance = 2.5
    }
}

Config.Items = {
    lockpick = 'lockpick',
    advancedLockpick = 'advancedlockpick'
}

Config.Picklock = {
    -- Set false so Pick Vehicle Lock can show even before GTA updates the door lock state.
    requireLockedVehicle = false,

    -- Vehicle must be empty before picklocking.
    requireEmptyVehicle = true,

    duration = 10000,

    -- No player cooldown because requested.
    playerCooldown = {
        enabled = false,
        seconds = 0
    },

    -- Prevents farming/searching the same vehicle repeatedly.
    vehicleRobbedCooldown = 30 * 60,

    -- Player must have lockpick or advancedlockpick.
    requireItem = true,

    -- Lockpicks can break.
    breakLockpick = true,

    normalLockpickBreakChance = 35,
    advancedLockpickBreakChance = 15,

    failedNormalLockpickBreakChance = 60,
    failedAdvancedLockpickBreakChance = 30,

    -- Chance the picklock attempt succeeds.
    normalSuccessChance = 70,
    advancedSuccessChance = 90,

    -- Unlock vehicle after successful picklock.
    unlockVehicleOnSuccess = true,

    -- Allows player to drive away after successful picklock.
    allowDriveAway = true,

    -- Gives vehicle keys if your key script supports it.
    giveKeysOnSuccess = true,

    -- Supported values:
    -- 'qbx_vehiclekeys'
    -- 'qb-vehiclekeys'
    -- 'custom'
    -- 'none'
    vehicleKeySystem = 'qbx_vehiclekeys',

    -- Used only if vehicleKeySystem = 'custom'
    customKeyClientEvent = '',
    customKeyServerEvent = '',

    -- Alarm on failed picklock.
    alarmOnFail = true,
    alarmDuration = 12000,

    -- Alarm when the player enters the successfully picklocked vehicle.
    alarmOnEnterAfterPicklock = true,
    alarmOnEnterDuration = 60 * 1000,
    alarmOnEnterOnlyOnce = true
}

Config.Search = {
    duration = 8000,

    -- Vehicle must be successfully picklocked before Search Vehicle appears.
    requirePicklocked = true,

    -- Vehicle must be unlocked/picklocked before searching.
    requireUnlocked = true,

    -- Marks vehicle as robbed once searched.
    markVehicleRobbed = true,

    noRewardChance = 12
}

Config.Police = {
    enabled = true,

    -- High police risk.
    picklockAlertChance = 80,
    failedAlertChance = 95,
    successfulAlertChance = 65,
    searchAlertChance = 45,

    jobs = {
        police = true,
        sheriff = true,
        state = true
    },

    alertBlip = {
        sprite = 225,
        color = 1,
        scale = 1.1,
        duration = 60,
        label = 'Vehicle Tampering'
    }
}

Config.Rewards = {
    cash = {
        enabled = true,
        chance = 55,
        min = 15,
        max = 180
    },

    dirtyMoney = {
        enabled = true,
        chance = 25,
        item = 'black_money',
        min = 50,
        max = 400
    },

    items = {
        enabled = true,
        chance = 65,

        pool = {
            { item = 'phone', min = 1, max = 1, chance = 15 },
            { item = 'lockpick', min = 1, max = 1, chance = 8 },
            { item = 'radio', min = 1, max = 1, chance = 8 },
            { item = 'watch', min = 1, max = 1, chance = 12 },
            { item = 'lighter', min = 1, max = 1, chance = 20 },
            { item = 'goldchain', min = 1, max = 1, chance = 7 },
            { item = 'bandage', min = 1, max = 2, chance = 15 }
        }
    }
}

Config.BlacklistedVehicleClasses = {
    -- 18 = emergency
    [18] = true,

    -- 15 = helicopters
    [15] = true,

    -- 16 = planes
    [16] = true,

    -- 14 = boats
    [14] = true
}

Config.BlacklistedVehicleModels = {
    -- Add models here if needed.
    -- 'police',
    -- 'police2',
    -- 'police3',
    -- 'sheriff',
    -- 'ambulance'
}

Config.Animations = {
    picklock = {
        dict = 'veh@break_in@0h@p_m_one@',
        anim = 'low_force_entry_ds',
        flag = 49
    },

    search = {
        dict = 'mini@repair',
        anim = 'fixing_a_ped',
        flag = 49
    }
}