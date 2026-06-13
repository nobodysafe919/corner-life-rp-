local activeJob = nil
local tabletOpen = false
local truckEntity = nil
local trailerEntity = nil
local routeBlip = nil
local eventState = {}
local eventAttempts = {}
local profileCache = nil
local lastWeighCheck = 0
local lastSpeedFine = 0
local initialFuel = 0.0

local function debugPrint(...)
    if Config.Debug then
        print('[advanced_trucking:client]', ...)
    end
end

local function notify(message, kind)
    kind = kind or 'primary'
    if GetResourceState('qb-core') == 'started' then
        exports['qb-core']:GetCoreObject().Functions.Notify(message, kind)
    elseif GetResourceState('es_extended') == 'started' then
        TriggerEvent('esx:showNotification', message)
    else
        BeginTextCommandThefeedPost('STRING')
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandThefeedPostTicker(false, false)
    end
end

local function requestModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    RequestModel(hash)
    local started = GetGameTimer()
    while not HasModelLoaded(hash) do
        Wait(25)
        if GetGameTimer() - started > 8000 then
            return nil
        end
    end
    return hash
end

local function getDepot(id)
    for _, depot in ipairs(Config.Depots) do
        if depot.id == id then
            return depot
        end
    end
end

local function vecDistance(a, b)
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

local function drawText3d(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(0.32, 0.32)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

local function makeBlip(coords, label, sprite, color)
    if routeBlip then
        RemoveBlip(routeBlip)
    end
    routeBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(routeBlip, sprite or 477)
    SetBlipColour(routeBlip, color or 5)
    SetBlipRoute(routeBlip, true)
    SetBlipRouteColour(routeBlip, color or 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(routeBlip)
end

local function setTablet(state)
    tabletOpen = state
    SetNuiFocus(state, state)
    SendNUIMessage({
        action = state and 'open' or 'close',
        company = Config.CompanyName,
        profile = profileCache,
        activeJob = activeJob
    })
    if state then
        TriggerServerEvent('advanced_trucking:requestDashboard')
    end
end

local function spawnAssignedRig(job)
    local truckModel = Config.Trucks[job.truckKey or 'starter'] or Config.Trucks.starter
    local trailerConfig = Config.Trailers[job.requiredTrailer]
    local truckHash = requestModel(truckModel.model)
    local trailerHash = requestModel(trailerConfig.model)
    if not truckHash or not trailerHash then
        notify('Unable to load truck or trailer model.', 'error')
        return false
    end

    local t = Config.SpawnPoints.truck
    local tr = Config.SpawnPoints.trailer
    truckEntity = CreateVehicle(truckHash, t.x, t.y, t.z, t.w, true, true)
    trailerEntity = CreateVehicle(trailerHash, tr.x, tr.y, tr.z, tr.w, true, true)
    SetVehicleOnGroundProperly(truckEntity)
    SetVehicleOnGroundProperly(trailerEntity)
    initialFuel = job.condition.fuel or truckModel.fuel
    SetVehicleFuelLevel(truckEntity, initialFuel)
    SetVehicleEngineHealth(truckEntity, job.condition.engine or Config.Condition.startingEngine)
    SetEntityAsMissionEntity(truckEntity, true, true)
    SetEntityAsMissionEntity(trailerEntity, true, true)
    SetVehicleNumberPlateText(truckEntity, 'CLRP' .. tostring(math.random(100, 999)))
    SetVehicleNumberPlateText(trailerEntity, 'LOG' .. tostring(math.random(100, 999)))
    job.truckNetId = NetworkGetNetworkIdFromEntity(truckEntity)
    job.trailerNetId = NetworkGetNetworkIdFromEntity(trailerEntity)
    return true
end

local function applyCargoHandling()
    if not activeJob or not truckEntity or not DoesEntityExist(truckEntity) then return end
    local cargo = Config.CargoTypes[activeJob.cargoKey]
    if not cargo then return end
    SetVehicleHandlingFloat(truckEntity, 'CHandlingData', 'fInitialDriveMaxFlatVel', 115.0 * cargo.handling)
    SetVehicleHandlingFloat(truckEntity, 'CHandlingData', 'fBrakeForce', 0.85 * cargo.handling)
    SetVehicleEnginePowerMultiplier(truckEntity, -8.0 + ((1.0 - cargo.handling) * -18.0))
end

local function hasCorrectTrailerAttached()
    if not truckEntity or not trailerEntity then return false end
    if not DoesEntityExist(truckEntity) or not DoesEntityExist(trailerEntity) then return false end
    local attached, attachedTrailer = GetVehicleTrailerVehicle(truckEntity)
    return attached and attachedTrailer == trailerEntity
end

local function clearActiveJob()
    if routeBlip then RemoveBlip(routeBlip) end
    activeJob = nil
    eventState = {}
    eventAttempts = {}
    SendNUIMessage({ action = 'jobUpdated', activeJob = nil })
end

local function finishJob(cancelled)
    if not activeJob then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local truckDamage = 100.0
    local trailerDamage = 100.0
    local fuelUsed = 0.0

    if truckEntity and DoesEntityExist(truckEntity) then
        truckDamage = math.max(0.0, 100.0 - (GetVehicleEngineHealth(truckEntity) / 10.0))
        fuelUsed = math.max(0.0, initialFuel - GetVehicleFuelLevel(truckEntity))
    end
    if trailerEntity and DoesEntityExist(trailerEntity) then
        trailerDamage = math.max(0.0, 100.0 - (GetVehicleBodyHealth(trailerEntity) / 10.0))
    end

    TriggerServerEvent('advanced_trucking:finishJob', {
        jobId = activeJob.id,
        cancelled = cancelled or false,
        truckDamage = truckDamage,
        trailerDamage = trailerDamage,
        fuelUsed = fuelUsed,
        attached = hasCorrectTrailerAttached()
    })

    if cancelled then
        clearActiveJob()
    end
end

local function maybeRandomEvent()
    if not activeJob then return end
    local elapsedMinutes = math.floor((GetGameTimer() - activeJob.startedAt) / 60000)
    for key, event in pairs(Config.RandomEvents) do
        if not eventState[key] and not eventAttempts[key] and elapsedMinutes >= event.minMinutes then
            eventAttempts[key] = true
            TriggerServerEvent('advanced_trucking:randomEvent', activeJob.id, key)
        end
    end
end

local function maybePoliceCheck()
    if not activeJob then return end
    local cargo = Config.CargoTypes[activeJob.cargoKey]
    local chance = Config.Police.inspectionChance + (cargo.policeInterest or 0.0)
    if math.random() > chance then return end

    TriggerServerEvent('advanced_trucking:inspectionResult', activeJob.id)
end

local function checkWeighStations(coords)
    if not activeJob or not truckEntity or not DoesEntityExist(truckEntity) then return end
    if GetGameTimer() - lastWeighCheck < 120000 then return end
    for _, station in ipairs(Config.Police.weighStations) do
        if #(coords - station) < 55.0 then
            lastWeighCheck = GetGameTimer()
            notify('Weigh station check requested. Keep paperwork ready.', 'warning')
            maybePoliceCheck()
            return
        end
    end
end

local function checkSpeeding()
    if not activeJob or not truckEntity or not DoesEntityExist(truckEntity) then return end
    if GetGameTimer() - lastSpeedFine < 90000 then return end
    local speedMph = GetEntitySpeed(truckEntity) * 2.236936
    if speedMph > 78.0 and math.random() < 0.18 then
        lastSpeedFine = GetGameTimer()
        TriggerServerEvent('advanced_trucking:speedingPenalty', activeJob.id, math.floor(speedMph))
    end
end

RegisterCommand(Config.TabletCommand, function()
    setTablet(not tabletOpen)
end, false)

RegisterKeyMapping(Config.TabletCommand, 'Open Corner Life Logistics tablet', 'keyboard', Config.TabletKey)

RegisterNUICallback('close', function(_, cb)
    setTablet(false)
    cb(true)
end)

RegisterNUICallback('requestDashboard', function(_, cb)
    TriggerServerEvent('advanced_trucking:requestDashboard')
    cb(true)
end)

RegisterNUICallback('startJob', function(data, cb)
    TriggerServerEvent('advanced_trucking:startJob', data.jobId)
    cb(true)
end)

RegisterNUICallback('cancelJob', function(_, cb)
    finishJob(true)
    cb(true)
end)

RegisterNUICallback('buyLicense', function(data, cb)
    TriggerServerEvent('advanced_trucking:buyLicense', data.license)
    cb(true)
end)

RegisterNUICallback('buyTruck', function(data, cb)
    TriggerServerEvent('advanced_trucking:buyTruck', data.truck)
    cb(true)
end)

RegisterNUICallback('upgradeGarage', function(data, cb)
    TriggerServerEvent('advanced_trucking:upgradeGarage', data.upgrade)
    cb(true)
end)

RegisterNUICallback('hireDriver', function(data, cb)
    TriggerServerEvent('advanced_trucking:hireDriver', data.driverName or 'Contract Driver')
    cb(true)
end)

RegisterNetEvent('advanced_trucking:dashboard', function(payload)
    profileCache = payload.profile
    SendNUIMessage({
        action = 'dashboard',
        company = Config.CompanyName,
        profile = payload.profile,
        contracts = payload.contracts,
        companyData = payload.company,
        logs = payload.logs,
        activeJob = activeJob
    })
end)

RegisterNetEvent('advanced_trucking:notify', function(message, kind)
    notify(message, kind)
end)

RegisterNetEvent('advanced_trucking:jobEnded', function()
    clearActiveJob()
end)

RegisterNetEvent('advanced_trucking:randomEventAccepted', function(eventKey)
    if not activeJob then return end
    local event = Config.RandomEvents[eventKey]
    if not event or eventState[eventKey] then return end
    eventState[eventKey] = true
    notify(event.label .. ' reported on dispatch.', 'warning')
    if eventKey == 'tire_blowout' and truckEntity and DoesEntityExist(truckEntity) then
        SetVehicleTyreBurst(truckEntity, math.random(0, 5), true, 1000.0)
    elseif eventKey == 'traffic_delay' then
        activeJob.timeLimit = activeJob.timeLimit + (event.delaySeconds or 60)
    elseif eventKey == 'trailer_lights' and trailerEntity and DoesEntityExist(trailerEntity) then
        SetVehicleLights(trailerEntity, 1)
    end
    SendNUIMessage({ action = 'jobUpdated', activeJob = activeJob })
end)

RegisterNetEvent('advanced_trucking:jobStarted', function(job)
    if activeJob then
        notify('Finish or cancel the active contract first.', 'error')
        return
    end
    activeJob = job
    activeJob.startedAt = GetGameTimer()
    activeJob.condition = activeJob.condition or {
        engine = Config.Condition.startingEngine,
        tires = Config.Condition.startingTires,
        brakes = Config.Condition.startingBrakes,
        oil = Config.Condition.startingOil,
        fuel = 220.0
    }
    if not spawnAssignedRig(activeJob) then
        TriggerServerEvent('advanced_trucking:failStart', job.id)
        activeJob = nil
        return
    end
    applyCargoHandling()
    local destination = getDepot(activeJob.destination)
    makeBlip(destination.coords, destination.label, 479, activeJob.illegal and 1 or 5)
    notify('Contract accepted. Attach the assigned trailer and follow dispatch.', 'success')
    SendNUIMessage({ action = 'jobUpdated', activeJob = activeJob })
end)

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        for _, depot in ipairs(Config.Depots) do
            if not depot.hidden then
                local dist = #(coords - vector3(depot.coords.x, depot.coords.y, depot.coords.z))
                if dist < 18.0 then
                    sleep = 0
                    DrawMarker(1, depot.coords.x, depot.coords.y, depot.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 4.0, 4.0, 0.8, 33, 150, 243, 135, false, false, 2, nil, nil, false)
                    if dist < 3.0 then
                        drawText3d(vector3(depot.coords.x, depot.coords.y, depot.coords.z + 1.0), '[E] Corner Life Logistics Tablet')
                        if IsControlJustPressed(0, 38) then
                            setTablet(true)
                        end
                    end
                end
            end
        end

        if activeJob then
            local destination = getDepot(activeJob.destination)
            local dist = vecDistance(coords, destination.coords)
            checkWeighStations(coords)
            if dist < 45.0 then
                sleep = 0
                DrawMarker(1, destination.coords.x, destination.coords.y, destination.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 6.0, 6.0, 1.0, 35, 220, 120, 155, false, false, 2, nil, nil, false)
                if dist < 8.0 then
                    drawText3d(vector3(destination.coords.x, destination.coords.y, destination.coords.z + 1.3), '[E] Complete Delivery')
                    if IsControlJustPressed(0, 38) then
                        if not hasCorrectTrailerAttached() then
                            notify(Config.Notifications.attachRequired, 'error')
                        else
                            finishJob(false)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(30000)
        if activeJob and truckEntity and DoesEntityExist(truckEntity) then
            local cargo = Config.CargoTypes[activeJob.cargoKey]
            local speed = GetEntitySpeed(truckEntity)
            local fuel = GetVehicleFuelLevel(truckEntity)
            local burn = (0.18 + (speed * 0.012)) * (cargo.fuelMultiplier or 1.0)
            SetVehicleFuelLevel(truckEntity, math.max(0.0, fuel - burn))
            activeJob.condition.fuel = GetVehicleFuelLevel(truckEntity)
            activeJob.condition.initialFuel = initialFuel
            activeJob.condition.tires = math.max(0.0, (activeJob.condition.tires or 100.0) - (speed > 18.0 and 0.18 or 0.08))
            activeJob.condition.brakes = math.max(0.0, (activeJob.condition.brakes or 100.0) - (IsControlPressed(0, 72) and 0.32 or 0.06))
            activeJob.condition.oil = math.max(0.0, (activeJob.condition.oil or 100.0) - 0.04)
            maybeRandomEvent()
            checkSpeeding()
            if math.random() < Config.Police.checkpointChance then
                maybePoliceCheck()
            end
            SendNUIMessage({ action = 'jobUpdated', activeJob = activeJob })
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    if routeBlip then RemoveBlip(routeBlip) end
    if truckEntity and DoesEntityExist(truckEntity) then DeleteEntity(truckEntity) end
    if trailerEntity and DoesEntityExist(trailerEntity) then DeleteEntity(trailerEntity) end
end)
