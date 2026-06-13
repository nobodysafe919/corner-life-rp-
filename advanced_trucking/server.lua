local QBCore = nil
local ESX = nil
local Profiles = {}
local ActiveJobs = {}

CreateThread(function()
    if (Config.Framework == 'auto' or Config.Framework == 'qb') and GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    end
    if (Config.Framework == 'auto' or Config.Framework == 'esx') and GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
    end
end)

local function hasMysql()
    return GetResourceState('oxmysql') == 'started' and MySQL ~= nil
end

local function identifier(source)
    if QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        if player then return player.PlayerData.citizenid end
    end
    if ESX then
        local player = ESX.GetPlayerFromId(source)
        if player then return player.identifier end
    end
    for _, id in ipairs(GetPlayerIdentifiers(source)) do
        if id:find('license:') == 1 then return id end
    end
    return 'source:' .. tostring(source)
end

local function playerName(source)
    if QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        if player and player.PlayerData.charinfo then
            return (player.PlayerData.charinfo.firstname or 'Driver') .. ' ' .. (player.PlayerData.charinfo.lastname or '')
        end
    end
    if ESX then
        local player = ESX.GetPlayerFromId(source)
        if player then return player.getName() end
    end
    return GetPlayerName(source) or 'Driver'
end

local function addMoney(source, amount, reason)
    amount = math.floor(amount)
    if amount <= 0 then return end
    if QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        if player then player.Functions.AddMoney('bank', amount, reason or 'trucking') end
    elseif ESX then
        local player = ESX.GetPlayerFromId(source)
        if player then player.addAccountMoney('bank', amount) end
    else
        TriggerClientEvent('advanced_trucking:notify', source, ('Standalone payout: $%s'):format(amount), 'success')
    end
end

local function removeMoney(source, amount, reason)
    amount = math.floor(amount)
    if amount <= 0 then return true end
    if QBCore then
        local player = QBCore.Functions.GetPlayer(source)
        if player then return player.Functions.RemoveMoney('bank', amount, reason or 'trucking') end
    elseif ESX then
        local player = ESX.GetPlayerFromId(source)
        if player and player.getAccount('bank').money >= amount then
            player.removeAccountMoney('bank', amount)
            return true
        end
    else
        return true
    end
    return false
end

local function depot(id)
    for _, item in ipairs(Config.Depots) do
        if item.id == id then return item end
    end
end

local function distanceFor(template)
    local origin = depot(template.origin)
    local destination = depot(template.destination)
    if not origin or not destination then return 0 end
    local a = vector3(origin.coords.x, origin.coords.y, origin.coords.z)
    local b = vector3(destination.coords.x, destination.coords.y, destination.coords.z)
    return #(a - b)
end

local function levelFromXp(xp)
    local level = 1
    for candidate, data in pairs(Config.Levels) do
        if xp >= data.xp and candidate > level then
            level = candidate
        end
    end
    return level
end

local function decode(value, fallback)
    if not value or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    if ok and decoded then return decoded end
    return fallback
end

local function clampNumber(value, minimum, maximum)
    value = tonumber(value) or minimum
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function defaultProfile(source)
    return {
        identifier = identifier(source),
        name = playerName(source),
        xp = 0,
        level = 1,
        reputation = 0,
        completed = 0,
        failed = 0,
        licenses = {},
        stats = { mileage = 0, fuel_used = 0, damage_paid = 0, earned = 0 },
        trucks = {},
        garage = {},
        company = nil
    }
end

local function saveProfile(profile)
    if not hasMysql() then return end
    MySQL.insert.await([[
        INSERT INTO trucking_profiles
            (identifier, name, xp, level, reputation, completed_jobs, failed_jobs, licenses, stats)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            name = VALUES(name),
            xp = VALUES(xp),
            level = VALUES(level),
            reputation = VALUES(reputation),
            completed_jobs = VALUES(completed_jobs),
            failed_jobs = VALUES(failed_jobs),
            licenses = VALUES(licenses),
            stats = VALUES(stats)
    ]], {
        profile.identifier,
        profile.name,
        profile.xp,
        profile.level,
        profile.reputation,
        profile.completed,
        profile.failed,
        json.encode(profile.licenses),
        json.encode(profile.stats)
    })
end

local function loadProfile(source)
    local id = identifier(source)
    if Profiles[id] then return Profiles[id] end

    local profile = defaultProfile(source)
    if hasMysql() then
        local row = MySQL.single.await('SELECT * FROM trucking_profiles WHERE identifier = ?', { id })
        if row then
            profile.xp = row.xp or 0
            profile.level = row.level or levelFromXp(profile.xp)
            profile.reputation = row.reputation or 0
            profile.completed = row.completed_jobs or 0
            profile.failed = row.failed_jobs or 0
            profile.licenses = decode(row.licenses, {})
            profile.stats = decode(row.stats, profile.stats)
        else
            saveProfile(profile)
        end

        local trucks = MySQL.query.await('SELECT * FROM trucking_owned_trucks WHERE owner_identifier = ?', { id }) or {}
        for _, truck in ipairs(trucks) do
            profile.trucks[#profile.trucks + 1] = truck
        end

        local company = MySQL.single.await('SELECT * FROM trucking_companies WHERE owner_identifier = ?', { id })
        if company then
            company.upgrades = decode(company.upgrades, {})
            profile.company = company
            profile.garage = company.upgrades
        end
    end

    Profiles[id] = profile
    return profile
end

local function hasLicense(profile, license)
    for _, owned in ipairs(profile.licenses or {}) do
        if owned == license then return true end
    end
    return false
end

local function canRunTemplate(profile, template)
    local tier = Config.JobTiers[template.tier]
    local cargo = Config.CargoTypes[template.cargo]
    if not tier or not cargo then return false end
    if profile.level < tier.minLevel then return false end
    if cargo.repRequired and profile.reputation < cargo.repRequired then return false end
    if template.illegal and not Config.IllegalCargoEnabled then return false end
    if template.illegal and profile.reputation < 4 then return false end
    for _, license in ipairs(tier.requiredLicenses or {}) do
        if not hasLicense(profile, license) then return false end
    end
    return true
end

local function buildContract(profile, template, index)
    local cargo = Config.CargoTypes[template.cargo]
    local tier = Config.JobTiers[template.tier]
    local origin = depot(template.origin)
    local destination = depot(template.destination)
    local distance = distanceFor(template)
    local distanceBonus = math.floor(distance * Config.Payout.distancePerMeter)
    local basePay = tier.basePay + cargo.bonus + distanceBonus
    if template.illegal then basePay = math.floor(basePay * Config.Payout.illegalRiskMultiplier) end
    return {
        id = ('contract:%s'):format(index),
        tierKey = template.tier,
        tier = tier.label,
        cargoKey = template.cargo,
        cargo = cargo.label,
        legal = cargo.legal,
        illegal = template.illegal or not cargo.legal,
        origin = template.origin,
        originLabel = origin.label,
        destination = template.destination,
        destinationLabel = destination.label,
        requiredTrailer = cargo.trailer,
        requiredTrailerLabel = Config.Trailers[cargo.trailer].label,
        weight = cargo.weight,
        fragile = cargo.fragile,
        timeLimit = template.timeLimit,
        distance = math.floor(distance),
        estimatedPay = basePay,
        xp = tier.xp,
        reputation = tier.reputation,
        truckKey = profile.trucks[1] and profile.trucks[1].truck_key or 'starter'
    }
end

local function availableContracts(profile)
    local contracts = {}
    for index, template in ipairs(Config.JobTemplates) do
        if canRunTemplate(profile, template) then
            contracts[#contracts + 1] = buildContract(profile, template, index)
        end
    end
    return contracts
end

local function recentLogs(id)
    if not hasMysql() then return {} end
    return MySQL.query.await('SELECT * FROM trucking_logs WHERE identifier = ? ORDER BY created_at DESC LIMIT 20', { id }) or {}
end

local function companyData(profile)
    if profile.company then return profile.company end
    return {
        company_name = Config.CompanyName,
        reputation = profile.reputation,
        garage_level = 1,
        driver_slots = 0,
        contract_slots = 1,
        upgrades = {}
    }
end

local function recalculateCompany(profile)
    local company = profile.company or companyData(profile)
    local upgrades = profile.garage or {}
    local garageLevel = 1
    local driverSlots = 0
    local contractSlots = 1

    for upgradeKey, owned in pairs(upgrades) do
        if owned then
            garageLevel = garageLevel + 1
            local upgrade = Config.GarageUpgrades[upgradeKey]
            if upgrade then
                driverSlots = driverSlots + (upgrade.driverSlots or 0)
                contractSlots = contractSlots + (upgrade.contractSlots or 0)
            end
        end
    end

    company.company_name = company.company_name or Config.CompanyName
    company.reputation = profile.reputation
    company.garage_level = garageLevel
    company.driver_slots = driverSlots
    company.contract_slots = contractSlots
    company.upgrades = upgrades
    profile.company = company
    return company
end

local function saveCompany(profile)
    if not hasMysql() then return end
    local company = recalculateCompany(profile)
    MySQL.insert.await([[
        INSERT INTO trucking_companies
            (owner_identifier, company_name, reputation, garage_level, driver_slots, contract_slots, upgrades)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
            company_name = VALUES(company_name),
            reputation = VALUES(reputation),
            garage_level = VALUES(garage_level),
            driver_slots = VALUES(driver_slots),
            contract_slots = VALUES(contract_slots),
            upgrades = VALUES(upgrades)
    ]], {
        profile.identifier,
        company.company_name or Config.CompanyName,
        company.reputation,
        company.garage_level,
        company.driver_slots,
        company.contract_slots,
        json.encode(profile.garage or {})
    })
end

local function triggerDashboard(source, profile)
    TriggerClientEvent('advanced_trucking:dashboard', source, {
        profile = profile,
        contracts = availableContracts(profile),
        company = recalculateCompany(profile),
        logs = recentLogs(profile.identifier)
    })
end

local function destinationDistance(source, job)
    local destination = depot(job.destination)
    if not destination then return 999999.0 end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return 999999.0 end
    local coords = GetEntityCoords(ped)
    return #(coords - vector3(destination.coords.x, destination.coords.y, destination.coords.z))
end

local function sanitizeCompletionResult(source, job, result)
    result = type(result) == 'table' and result or {}
    local elapsed = math.max(0, os.time() - (job.startedAt or os.time()))
    local truckConfig = Config.Trucks[job.truckKey or 'starter'] or Config.Trucks.starter
    local initialFuel = truckConfig.fuel
    local sanitized = {
        jobId = job.id,
        cancelled = result.cancelled == true,
        attached = result.attached == true,
        truckDamage = clampNumber(result.truckDamage, 0.0, 100.0),
        trailerDamage = clampNumber(result.trailerDamage, 0.0, 100.0),
        fuelUsed = clampNumber(result.fuelUsed, 0.0, initialFuel),
        lateBy = math.max(0, elapsed - (job.timeLimit or 0)),
        events = job.events or {},
        deliveredDistance = destinationDistance(source, job)
    }
    return sanitized
end

RegisterNetEvent('advanced_trucking:requestDashboard', function()
    local src = source
    local profile = loadProfile(src)
    triggerDashboard(src, profile)
end)

RegisterNetEvent('advanced_trucking:startJob', function(jobId)
    local src = source
    local profile = loadProfile(src)
    if ActiveJobs[profile.identifier] then
        TriggerClientEvent('advanced_trucking:notify', src, 'You already have an active contract.', 'error')
        return
    end
    for _, contract in ipairs(availableContracts(profile)) do
        if contract.id == jobId then
            contract.id = ('job:%s:%s:%s'):format(profile.identifier, jobId:gsub('[^%w_%-:]', ''), os.time())
            contract.startedAt = os.time()
            contract.events = {}
            contract.eventAttempts = {}
            contract.condition = {
                engine = Config.Condition.startingEngine,
                tires = Config.Condition.startingTires,
                brakes = Config.Condition.startingBrakes,
                oil = Config.Condition.startingOil,
                fuel = (Config.Trucks[contract.truckKey] or Config.Trucks.starter).fuel,
                initialFuel = (Config.Trucks[contract.truckKey] or Config.Trucks.starter).fuel
            }
            ActiveJobs[profile.identifier] = contract
            if hasMysql() then
                MySQL.insert.await([[
                    INSERT INTO trucking_jobs
                        (job_id, identifier, tier, cargo, origin, destination, trailer, estimated_pay, status, started_at, metadata)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active', NOW(), ?)
                ]], {
                    contract.id,
                    profile.identifier,
                    contract.tierKey,
                    contract.cargoKey,
                    contract.origin,
                    contract.destination,
                    contract.requiredTrailer,
                    contract.estimatedPay,
                    json.encode(contract)
                })
            end
            TriggerClientEvent('advanced_trucking:jobStarted', src, contract)
            return
        end
    end
    TriggerClientEvent('advanced_trucking:notify', src, 'That contract is no longer available.', 'error')
end)

RegisterNetEvent('advanced_trucking:failStart', function(jobId)
    local src = source
    local profile = loadProfile(src)
    if ActiveJobs[profile.identifier] and ActiveJobs[profile.identifier].id == jobId then
        if hasMysql() then
            MySQL.update.await('UPDATE trucking_jobs SET status = ?, completed_at = NOW(), metadata = ? WHERE job_id = ?', {
                'start_failed',
                json.encode({ reason = 'vehicle_spawn_failed' }),
                jobId
            })
        end
        ActiveJobs[profile.identifier] = nil
    end
end)

local function calculatePayout(job, result, profile)
    local cargo = Config.CargoTypes[job.cargoKey]
    local basePay = Config.JobTiers[job.tierKey].basePay
    local distanceBonus = math.floor(job.distance * Config.Payout.distancePerMeter)
    local cargoBonus = cargo.bonus
    local damagePenalty = math.floor((result.truckDamage or 0) * Config.Payout.damagePenaltyMultiplier)
    local trailerPenalty = math.floor((result.trailerDamage or 0) * (Config.Trailers[job.requiredTrailer].damagePenalty or 1.0) * Config.Payout.trailerDamagePenaltyMultiplier)
    local fragilePenalty = cargo.fragile and math.floor(((result.truckDamage or 0) + (result.trailerDamage or 0)) * cargo.decayPerDamage * 10.0) or 0
    local latePenalty = math.floor(((result.lateBy or 0) / 60) * Config.Payout.latePenaltyPerMinute)
    local fuelCost = math.floor((result.fuelUsed or 0) * Config.Payout.fuelCostPerUnit)
    local repairCost = math.floor(((result.truckDamage or 0) + (result.trailerDamage or 0)) * Config.Payout.repairCostMultiplier)
    local reputationBonus = math.floor((basePay + cargoBonus) * (profile.reputation * Config.Payout.reputationMultiplier))
    local eventBonus = 0
    if result.events and result.events.bad_weather then eventBonus = eventBonus + Config.Payout.badWeatherBonus end
    if result.events and result.events.emergency_delivery then eventBonus = eventBonus + Config.Payout.emergencyBonus end
    if result.lateBy == 0 then eventBonus = eventBonus + Config.Payout.onTimeBonus end
    if job.illegal then cargoBonus = math.floor(cargoBonus * Config.Payout.illegalRiskMultiplier) end

    local gross = basePay + distanceBonus + cargoBonus + reputationBonus + eventBonus
    local deductions = damagePenalty + trailerPenalty + fragilePenalty + latePenalty + fuelCost + repairCost
    local final = math.max(0, gross - deductions)
    return final, {
        basePay = basePay,
        distanceBonus = distanceBonus,
        cargoBonus = cargoBonus,
        reputationBonus = reputationBonus,
        eventBonus = eventBonus,
        damagePenalty = damagePenalty,
        trailerPenalty = trailerPenalty,
        fragilePenalty = fragilePenalty,
        latePenalty = latePenalty,
        fuelCost = fuelCost,
        repairCost = repairCost,
        finalPay = final
    }
end

RegisterNetEvent('advanced_trucking:finishJob', function(result)
    local src = source
    local profile = loadProfile(src)
    local job = ActiveJobs[profile.identifier]
    if not job or type(result) ~= 'table' or job.id ~= result.jobId then
        TriggerClientEvent('advanced_trucking:notify', src, 'No matching active contract found.', 'error')
        return
    end

    result = sanitizeCompletionResult(src, job, result)
    local status = result.cancelled and 'cancelled' or 'completed'
    if not result.cancelled and result.deliveredDistance > 85.0 then
        TriggerClientEvent('advanced_trucking:notify', src, 'Dispatch rejected the delivery location.', 'error')
        return
    end

    if result.cancelled or not result.attached then
        profile.failed = profile.failed + 1
        profile.reputation = math.max(0, profile.reputation - 1)
        TriggerClientEvent('advanced_trucking:notify', src, Config.Notifications.deliveryFailed, 'error')
    else
        local pay, breakdown = calculatePayout(job, result, profile)
        profile.completed = profile.completed + 1
        profile.xp = profile.xp + job.xp
        profile.level = levelFromXp(profile.xp)
        profile.reputation = profile.reputation + job.reputation
        profile.stats.mileage = math.floor((profile.stats.mileage or 0) + (job.distance / 1609.34))
        profile.stats.fuel_used = math.floor((profile.stats.fuel_used or 0) + (result.fuelUsed or 0))
        profile.stats.damage_paid = math.floor((profile.stats.damage_paid or 0) + breakdown.repairCost)
        profile.stats.earned = math.floor((profile.stats.earned or 0) + pay)
        addMoney(src, pay, 'trucking-delivery')
        TriggerClientEvent('advanced_trucking:notify', src, ('Delivery complete. Paid $%s.'):format(pay), 'success')
        result.breakdown = breakdown
    end

    if hasMysql() then
        MySQL.update.await('UPDATE trucking_jobs SET status = ?, completed_at = NOW(), actual_pay = ?, metadata = ? WHERE job_id = ?', {
            status,
            result.breakdown and result.breakdown.finalPay or 0,
            json.encode(result),
            job.id
        })
        MySQL.insert.await([[
            INSERT INTO trucking_logs
                (identifier, job_id, event_type, message, amount, metadata)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], {
            profile.identifier,
            job.id,
            status,
            ('%s from %s to %s'):format(job.cargo, job.originLabel, job.destinationLabel),
            result.breakdown and result.breakdown.finalPay or 0,
            json.encode({ job = job, result = result })
        })
    end

    ActiveJobs[profile.identifier] = nil
    saveProfile(profile)
    if profile.company then
        saveCompany(profile)
    end
    TriggerClientEvent('advanced_trucking:jobEnded', src)
    triggerDashboard(src, profile)
end)

RegisterNetEvent('advanced_trucking:buyLicense', function(licenseKey)
    local src = source
    local profile = loadProfile(src)
    local license = Config.Licenses[licenseKey]
    if not license then return end
    if profile.level < license.level then
        TriggerClientEvent('advanced_trucking:notify', src, 'You need a higher trucking level for that license.', 'error')
        return
    end
    if hasLicense(profile, licenseKey) then
        TriggerClientEvent('advanced_trucking:notify', src, 'You already have that license.', 'error')
        return
    end
    if not removeMoney(src, license.price, 'trucking-license') then
        TriggerClientEvent('advanced_trucking:notify', src, 'Not enough bank funds.', 'error')
        return
    end
    profile.licenses[#profile.licenses + 1] = licenseKey
    saveProfile(profile)
    TriggerClientEvent('advanced_trucking:notify', src, license.label .. ' purchased.', 'success')
    triggerDashboard(src, profile)
end)

RegisterNetEvent('advanced_trucking:buyTruck', function(truckKey)
    local src = source
    local profile = loadProfile(src)
    local truck = Config.Trucks[truckKey]
    if not truck then return end
    if not removeMoney(src, truck.price, 'trucking-truck') then
        TriggerClientEvent('advanced_trucking:notify', src, 'Not enough bank funds.', 'error')
        return
    end
    local plate = 'CLRP' .. tostring(math.random(1000, 9999))
    profile.trucks[#profile.trucks + 1] = { truck_key = truckKey, label = truck.label, plate = plate }
    if hasMysql() then
        MySQL.insert.await([[
            INSERT INTO trucking_owned_trucks
                (owner_identifier, truck_key, label, plate, engine_health, tire_wear, brake_wear, fuel_level, oil_life)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], { profile.identifier, truckKey, truck.label, plate, 1000.0, 100.0, 100.0, truck.fuel, 100.0 })
    end
    TriggerClientEvent('advanced_trucking:notify', src, truck.label .. ' purchased.', 'success')
    triggerDashboard(src, profile)
end)

RegisterNetEvent('advanced_trucking:upgradeGarage', function(upgradeKey)
    local src = source
    local profile = loadProfile(src)
    local upgrade = Config.GarageUpgrades[upgradeKey]
    if not upgrade then return end
    if profile.garage[upgradeKey] then
        TriggerClientEvent('advanced_trucking:notify', src, 'Garage already has that upgrade.', 'error')
        return
    end
    if not removeMoney(src, upgrade.price, 'trucking-garage') then
        TriggerClientEvent('advanced_trucking:notify', src, 'Not enough bank funds.', 'error')
        return
    end
    profile.garage[upgradeKey] = true
    saveCompany(profile)
    TriggerClientEvent('advanced_trucking:notify', src, upgrade.label .. ' purchased.', 'success')
    triggerDashboard(src, profile)
end)

RegisterNetEvent('advanced_trucking:hireDriver', function(driverName)
    local src = source
    local profile = loadProfile(src)
    if not profile.company then
        profile.company = companyData(profile)
    end
    if hasMysql() then
        MySQL.insert.await([[
            INSERT INTO trucking_employees
                (company_identifier, employee_identifier, employee_name, employee_type, reputation, status)
            VALUES (?, ?, ?, 'npc', ?, 'active')
        ]], { profile.identifier, 'npc:' .. math.random(100000, 999999), driverName, math.random(1, 4) })
    end
    TriggerClientEvent('advanced_trucking:notify', src, driverName .. ' hired to the logistics roster.', 'success')
    triggerDashboard(src, profile)
end)

RegisterNetEvent('advanced_trucking:randomEvent', function(jobId, eventKey)
    local src = source
    local profile = loadProfile(src)
    local job = ActiveJobs[profile.identifier]
    local event = Config.RandomEvents[eventKey]
    if not job or job.id ~= jobId or not event then return end
    local elapsedMinutes = math.floor(math.max(0, os.time() - (job.startedAt or os.time())) / 60)
    if elapsedMinutes < (event.minMinutes or 0) then return end
    job.events = job.events or {}
    job.eventAttempts = job.eventAttempts or {}
    if job.eventAttempts[eventKey] then return end
    job.eventAttempts[eventKey] = true
    if math.random() > (event.chance or 0.0) then return end
    if job.events[eventKey] then return end
    job.events[eventKey] = true
    TriggerClientEvent('advanced_trucking:randomEventAccepted', src, eventKey)
    if eventKey == 'theft_attempt' then
        TriggerEvent('advanced_trucking:dispatchPoliceAlert', src, job, 'Cargo theft attempt in progress')
    end
end)

RegisterNetEvent('advanced_trucking:inspectionResult', function(jobId)
    local src = source
    local profile = loadProfile(src)
    local job = ActiveJobs[profile.identifier]
    if not job or job.id ~= jobId then return end

    local cargo = Config.CargoTypes[job.cargoKey]
    if job.lastInspectionAt and os.time() - job.lastInspectionAt < 90 then return end
    job.lastInspectionAt = os.time()
    local fine = 0
    local data = {
        badDocs = job.illegal and math.random() < 0.45,
        overweight = (cargo.weight or 0) > Config.Police.overweightLimit,
        illegal = job.illegal,
        cargo = cargo.label
    }

    if data.badDocs then fine = fine + Config.Police.badDocsFine end
    if data.overweight then fine = fine + math.floor(Config.Police.badDocsFine * 0.75) end
    if data.illegal then fine = fine + Config.Police.illegalCargoFine end
    if fine > 0 then
        removeMoney(src, fine, 'trucking-dot-fine')
        TriggerClientEvent('advanced_trucking:notify', src, ('DOT inspection fine: $%s'):format(fine), 'error')
        TriggerEvent('advanced_trucking:dispatchPoliceAlert', src, job, 'DOT inspection flagged a truck')
    else
        TriggerClientEvent('advanced_trucking:notify', src, 'DOT inspection passed. Paperwork checks out.', 'success')
    end
end)

RegisterNetEvent('advanced_trucking:speedingPenalty', function(jobId, speedMph)
    local src = source
    local profile = loadProfile(src)
    local job = ActiveJobs[profile.identifier]
    if not job or job.id ~= jobId then return end
    if job.lastSpeedFineAt and os.time() - job.lastSpeedFineAt < 90 then return end
    job.lastSpeedFineAt = os.time()
    speedMph = clampNumber(speedMph, 0, 160)
    removeMoney(src, Config.Police.speedingFine, 'trucking-speeding')
    TriggerClientEvent('advanced_trucking:notify', src, ('Commercial speeding citation: %s mph, $%s fine.'):format(speedMph, Config.Police.speedingFine), 'error')
    if hasMysql() then
        MySQL.insert.await([[
            INSERT INTO trucking_logs
                (identifier, job_id, event_type, message, amount, metadata)
            VALUES (?, ?, 'speeding', ?, ?, ?)
        ]], {
            profile.identifier,
            job.id,
            ('Speeding citation during %s contract'):format(job.cargo),
            -Config.Police.speedingFine,
            json.encode({ speed = speedMph })
        })
    end
end)

RegisterNetEvent('advanced_trucking:policeAlert', function(jobId, message)
    local src = source
    local profile = loadProfile(src)
    local job = ActiveJobs[profile.identifier]
    if not job or job.id ~= jobId then return end
    if job.lastPoliceAlertAt and os.time() - job.lastPoliceAlertAt < 120 then return end
    job.lastPoliceAlertAt = os.time()
    TriggerEvent('advanced_trucking:dispatchPoliceAlert', src, job, 'Suspicious trucking activity')
end)

AddEventHandler('advanced_trucking:dispatchPoliceAlert', function(src, job, message)
    local coords = GetEntityCoords(GetPlayerPed(src))
    for _, playerId in ipairs(GetPlayers()) do
        local send = false
        if QBCore then
            local player = QBCore.Functions.GetPlayer(tonumber(playerId))
            if player and player.PlayerData.job then
                for _, jobName in ipairs(Config.PoliceJobNames) do
                    if player.PlayerData.job.name == jobName then send = true end
                end
            end
        elseif ESX then
            local player = ESX.GetPlayerFromId(tonumber(playerId))
            if player and player.job then
                for _, jobName in ipairs(Config.PoliceJobNames) do
                    if player.job.name == jobName then send = true end
                end
            end
        end
        if send then
            TriggerClientEvent('advanced_trucking:notify', tonumber(playerId), ('%s near %.1f %.1f | Cargo: %s'):format(message, coords.x, coords.y, job.cargo), 'error')
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local id = identifier(src)
    local job = ActiveJobs[id]
    if job and hasMysql() then
        MySQL.update.await('UPDATE trucking_jobs SET status = ?, completed_at = NOW(), metadata = ? WHERE job_id = ?', {
            'abandoned',
            json.encode({ reason = 'player_disconnected', job = job }),
            job.id
        })
    end
    ActiveJobs[id] = nil
    if Profiles[id] then
        saveProfile(Profiles[id])
    end
end)
