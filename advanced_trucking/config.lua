Config = {}

Config.Debug = false
Config.Framework = 'auto' -- auto, qb, esx, standalone
Config.CompanyName = 'Corner Life RP Trucking & Logistics'
Config.TabletCommand = 'trucking'
Config.TabletKey = 'F7'
Config.UseTarget = false
Config.IllegalCargoEnabled = true
Config.PoliceJobNames = { 'police', 'sheriff', 'state' }

Config.Levels = {
    [1] = { xp = 0, label = 'Permit Driver' },
    [2] = { xp = 650, label = 'Local Driver' },
    [3] = { xp = 1800, label = 'Regional Driver' },
    [4] = { xp = 3600, label = 'Long-Haul Driver' },
    [5] = { xp = 6500, label = 'Specialist Driver' },
    [6] = { xp = 10000, label = 'Fleet Owner' }
}

Config.JobTiers = {
    local_delivery = {
        label = 'Local Delivery Driver',
        minLevel = 1,
        requiredLicenses = {},
        basePay = 450,
        xp = 80,
        reputation = 1,
        maxDistance = 4500
    },
    long_haul = {
        label = 'Long-Haul Driver',
        minLevel = 3,
        requiredLicenses = {},
        basePay = 1100,
        xp = 180,
        reputation = 2,
        maxDistance = 15000
    },
    heavy_cargo = {
        label = 'Heavy Cargo Specialist',
        minLevel = 4,
        requiredLicenses = { 'oversized' },
        basePay = 1700,
        xp = 260,
        reputation = 3,
        maxDistance = 14000
    },
    hazmat = {
        label = 'Hazmat Driver',
        minLevel = 5,
        requiredLicenses = { 'hazmat' },
        basePay = 2200,
        xp = 340,
        reputation = 4,
        maxDistance = 16000
    },
    owner_operator = {
        label = 'Owner-Operator Contract',
        minLevel = 6,
        requiredLicenses = {},
        basePay = 2800,
        xp = 420,
        reputation = 5,
        maxDistance = 18000
    }
}

Config.CargoTypes = {
    food = {
        label = 'Fresh Food',
        legal = true,
        trailer = 'refrigerated',
        weight = 15000,
        bonus = 350,
        fragile = true,
        decayPerDamage = 1.15,
        fuelMultiplier = 1.08,
        handling = 0.96
    },
    fuel = {
        label = 'Fuel',
        legal = true,
        trailer = 'tanker',
        weight = 28000,
        bonus = 700,
        fragile = false,
        decayPerDamage = 1.0,
        fuelMultiplier = 1.28,
        handling = 0.86,
        policeInterest = 0.12
    },
    vehicles = {
        label = 'Vehicle Shipment',
        legal = true,
        trailer = 'car_hauler',
        weight = 22000,
        bonus = 900,
        fragile = true,
        decayPerDamage = 1.45,
        fuelMultiplier = 1.2,
        handling = 0.88
    },
    construction = {
        label = 'Construction Materials',
        legal = true,
        trailer = 'flatbed',
        weight = 32000,
        bonus = 850,
        fragile = false,
        decayPerDamage = 0.8,
        fuelMultiplier = 1.34,
        handling = 0.82
    },
    medical = {
        label = 'Medical Supplies',
        legal = true,
        trailer = 'box',
        weight = 9000,
        bonus = 1000,
        fragile = true,
        decayPerDamage = 1.65,
        fuelMultiplier = 1.0,
        handling = 1.0,
        emergencyChance = 0.25
    },
    illegal = {
        label = 'Sealed Private Freight',
        legal = false,
        trailer = 'box',
        weight = 12000,
        bonus = 2200,
        fragile = true,
        decayPerDamage = 1.35,
        fuelMultiplier = 1.05,
        handling = 0.95,
        policeInterest = 0.34,
        repRequired = 5
    }
}

Config.Trailers = {
    box = { label = 'Box Trailer', model = 'trailers2', attachRadius = 8.0, damagePenalty = 1.0 },
    flatbed = { label = 'Flatbed', model = 'trflat', attachRadius = 8.0, damagePenalty = 1.1 },
    tanker = { label = 'Tanker', model = 'tanker', attachRadius = 8.0, damagePenalty = 1.3 },
    car_hauler = { label = 'Car Hauler', model = 'tr4', attachRadius = 8.0, damagePenalty = 1.2 },
    refrigerated = { label = 'Refrigerated Trailer', model = 'trailers2', attachRadius = 8.0, damagePenalty = 1.15 }
}

Config.Trucks = {
    starter = { label = 'Old Hauler', model = 'phantom', price = 35000, fuel = 220.0, reliability = 0.92 },
    highway = { label = 'Highway Sleeper', model = 'hauler', price = 72000, fuel = 300.0, reliability = 0.96 },
    heavy = { label = 'Heavy Puller', model = 'phantom3', price = 125000, fuel = 340.0, reliability = 0.98 }
}

Config.Licenses = {
    hazmat = { label = 'Hazmat License', level = 5, price = 18000 },
    oversized = { label = 'Oversized Load License', level = 4, price = 14000 },
    cold_chain = { label = 'Cold Chain Certification', level = 3, price = 9000 }
}

Config.GarageUpgrades = {
    bay_2 = { label = 'Second Service Bay', price = 55000, driverSlots = 1 },
    dispatch = { label = 'Dispatch Office', price = 85000, contractSlots = 2 },
    cold_storage = { label = 'Cold Storage Dock', price = 70000, cargoUnlock = 'food' },
    hazmat_yard = { label = 'Hazmat Yard', price = 120000, cargoUnlock = 'fuel' }
}

Config.Depots = {
    { id = 'clrp_hq', label = 'Corner Life Logistics HQ', type = 'depot', coords = vector4(1206.56, -3116.03, 5.54, 0.0) },
    { id = 'docks', label = 'Port of Los Santos', type = 'port', coords = vector4(978.22, -2911.84, 5.9, 91.0) },
    { id = 'sandy', label = 'Sandy Shores Freight Yard', type = 'warehouse', coords = vector4(1737.98, 3310.58, 41.22, 194.0) },
    { id = 'paleto', label = 'Paleto Bay Distribution', type = 'warehouse', coords = vector4(148.73, 6362.21, 31.53, 41.0) },
    { id = 'grocery', label = 'Davis Grocery Receiver', type = 'grocery', coords = vector4(374.35, -1267.46, 32.43, 230.0) },
    { id = 'construction', label = 'Alta Construction Site', type = 'construction', coords = vector4(108.54, -391.41, 41.26, 72.0) },
    { id = 'gas_station', label = 'Route 68 Fuel Stop', type = 'gas', coords = vector4(1200.77, 2657.82, 37.85, 315.0) },
    { id = 'mechanic', label = 'Southside Mechanic Shop', type = 'mechanic', coords = vector4(542.94, -180.47, 54.49, 89.0), hidden = true },
    { id = 'business', label = 'Vinewood Private Business', type = 'business', coords = vector4(-587.01, -1059.72, 22.34, 270.0), hidden = true },
    { id = 'trap_house', label = 'Unmarked Supply Drop', type = 'trap', coords = vector4(1374.61, -1521.64, 57.04, 29.0), hidden = true },
    { id = 'gang_supply', label = 'Back Alley Freight Receiver', type = 'gang', coords = vector4(-154.87, -1611.7, 33.65, 143.0), hidden = true }
}

Config.JobTemplates = {
    { tier = 'local_delivery', cargo = 'food', origin = 'clrp_hq', destination = 'grocery', timeLimit = 900 },
    { tier = 'local_delivery', cargo = 'medical', origin = 'docks', destination = 'business', timeLimit = 780 },
    { tier = 'long_haul', cargo = 'food', origin = 'docks', destination = 'paleto', timeLimit = 1500 },
    { tier = 'long_haul', cargo = 'construction', origin = 'construction', destination = 'sandy', timeLimit = 1300 },
    { tier = 'heavy_cargo', cargo = 'vehicles', origin = 'docks', destination = 'paleto', timeLimit = 1800 },
    { tier = 'heavy_cargo', cargo = 'construction', origin = 'docks', destination = 'construction', timeLimit = 1300 },
    { tier = 'hazmat', cargo = 'fuel', origin = 'gas_station', destination = 'paleto', timeLimit = 1500 },
    { tier = 'owner_operator', cargo = 'medical', origin = 'clrp_hq', destination = 'paleto', timeLimit = 1200 },
    { tier = 'owner_operator', cargo = 'illegal', origin = 'clrp_hq', destination = 'trap_house', timeLimit = 900, illegal = true },
    { tier = 'owner_operator', cargo = 'illegal', origin = 'docks', destination = 'gang_supply', timeLimit = 900, illegal = true }
}

Config.SpawnPoints = {
    truck = vector4(1192.11, -3103.87, 5.68, 91.0),
    trailer = vector4(1178.54, -3103.83, 5.65, 91.0)
}

Config.Payout = {
    distancePerMeter = 0.18,
    onTimeBonus = 300,
    emergencyBonus = 600,
    badWeatherBonus = 450,
    damagePenaltyMultiplier = 14.0,
    trailerDamagePenaltyMultiplier = 9.0,
    latePenaltyPerMinute = 35,
    fuelCostPerUnit = 9.0,
    repairCostMultiplier = 7.5,
    reputationMultiplier = 0.035,
    illegalRiskMultiplier = 1.35
}

Config.Condition = {
    startingEngine = 1000.0,
    startingTires = 100.0,
    startingBrakes = 100.0,
    startingOil = 100.0,
    minPayoutCondition = 35.0,
    serviceWarning = 35.0
}

Config.RandomEvents = {
    tire_blowout = { label = 'Tire Blowout', chance = 0.045, minMinutes = 4 },
    traffic_delay = { label = 'Traffic Delay', chance = 0.06, minMinutes = 3, delaySeconds = 90 },
    trailer_lights = { label = 'Broken Trailer Lights', chance = 0.05, minMinutes = 5 },
    theft_attempt = { label = 'Cargo Theft Attempt', chance = 0.035, minMinutes = 5 },
    bad_weather = { label = 'Bad Weather Bonus', chance = 0.06, minMinutes = 2 },
    emergency_delivery = { label = 'Emergency Delivery Bonus', chance = 0.05, minMinutes = 1 }
}

Config.Police = {
    weighStations = {
        vector3(2554.36, 2621.22, 37.95),
        vector3(-2674.59, 2288.61, 20.82)
    },
    inspectionChance = 0.08,
    checkpointChance = 0.04,
    overweightLimit = 30000,
    speedingFine = 750,
    badDocsFine = 1500,
    illegalCargoFine = 8000
}

Config.Notifications = {
    tabletOpen = 'Corner Life Logistics tablet opened.',
    noJob = 'No active trucking contract.',
    wrongTrailer = 'This cargo needs a different trailer.',
    attachRequired = 'Attach the assigned trailer before leaving.',
    deliveryComplete = 'Delivery completed. Payout processed.',
    deliveryFailed = 'Delivery failed or abandoned.'
}
