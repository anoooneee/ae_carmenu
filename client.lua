local isMenuOpen = false
local interiorLightsOn = false
local trackedVehicle = 0
local cameraControlActive = false

local localeKey = Config.Locale or 'cs'

Config.Notify = function(msg, type, duration)
    duration = duration or 3000
    type = type or 'info'

    if Config.NotifySystem == 'ox' then
        lib.notify({
            title = 'Vozidlo',
            description = msg,
            type = type,
            duration = duration
        })

    elseif Config.NotifySystem == 'anone' then
        exports['anone-notify']:ShowNotification(msg, type, duration)

    elseif Config.NotifySystem == 'esx' then
        if ESX and ESX.ShowNotification then
            ESX.ShowNotification(msg)
        else
            TriggerEvent('esx:showNotification', msg)
        end

    elseif Config.NotifySystem == 'okok' then
        exports['okokNotify']:Alert('Vozidlo', msg, duration, type)
end

local function getLocale()
    local locales = Locales or Config.Locales or {}
    return locales[localeKey] or locales['cs'] or {}
end

local function translate(path, fallback)
    local scope = getLocale()
    for segment in string.gmatch(path, '([^.]+)') do
        if type(scope) ~= 'table' then break end
        scope = scope[segment]
    end
    if type(scope) == 'string' then
        return scope
    end
    return fallback or path
end

local function notifyLocale(key, notifType, duration)
    if Config.Notify then
        Config.Notify(translate('notify.' .. key, key), notifType, duration)
    end
end

local function pushLocales()
    local locale = getLocale()
    if locale.ui then
        SendNUIMessage({
            type = 'locales',
            locales = locale.ui
        })
    end
end

local function getPlayerVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    return ped, veh
end

local function isVehicleLocked(veh)
    local status = GetVehicleDoorLockStatus(veh)
    return status ~= 0 and status ~= 1
end

local function pushVehicleState(veh)
    SendNUIMessage({
        type = 'update',
        engine = GetIsVehicleEngineRunning(veh),
        locked = isVehicleLocked(veh)
    })
end

local doorButtons = {
    { id = 0, icon = 'chevron-up', labelKey = 'door_labels.front_left', fallback = 'PŘEDNÍ L' },
    { id = 1, icon = 'chevron-up', labelKey = 'door_labels.front_right', fallback = 'PŘEDNÍ P' },
    { id = 2, icon = 'chevron-down', labelKey = 'door_labels.rear_left', fallback = 'ZADNÍ L' },
    { id = 3, icon = 'chevron-down', labelKey = 'door_labels.rear_right', fallback = 'ZADNÍ P' },
    { id = 4, icon = 'gauge', labelKey = 'door_labels.hood', fallback = 'KAPOTA' },
    { id = 5, icon = 'package', labelKey = 'door_labels.trunk', fallback = 'KUFR' }
}

local windowButtons = {
    { id = 0, icon = 'arrow-down-to-dot', doorIndex = 0, labelKey = 'window_labels.front_left', fallback = 'PŘEDNÍ L' },
    { id = 1, icon = 'arrow-down-to-dot', doorIndex = 1, labelKey = 'window_labels.front_right', fallback = 'PŘEDNÍ P' },
    { id = 2, icon = 'arrow-down-to-dot', doorIndex = 2, labelKey = 'window_labels.rear_left', fallback = 'ZADNÍ L' },
    { id = 3, icon = 'arrow-down-to-dot', doorIndex = 3, labelKey = 'window_labels.rear_right', fallback = 'ZADNÍ P' }
}

local seatLabelMap = {
    [-1] = { key = 'seat_labels.driver', fallback = 'ŘIDIČ' },
    [0] = { key = 'seat_labels.passenger', fallback = 'SPOLUJEZDEC' },
    [1] = { key = 'seat_labels.rear_left', fallback = 'ZADNÍ L' },
    [2] = { key = 'seat_labels.rear_right', fallback = 'ZADNÍ P' }
}

local function buildDoorLayout(veh)
    local result = {}
    for _, door in ipairs(doorButtons) do
        if GetIsDoorValid(veh, door.id) then
            result[#result + 1] = {
                id = door.id,
                label = translate('ui.' .. door.labelKey, door.fallback),
                icon = door.icon
            }
        end
    end
    return result
end

local function buildWindowLayout(veh)
    local result = {}
    for _, window in ipairs(windowButtons) do
        if not window.doorIndex or GetIsDoorValid(veh, window.doorIndex) then
            result[#result + 1] = {
                id = window.id,
                label = translate('ui.' .. window.labelKey, window.fallback),
                icon = window.icon
            }
        end
    end
    return result
end

local function pushLayout(veh)
    SendNUIMessage({
        type = 'layout',
        layout = {
            doors = buildDoorLayout(veh),
            windows = buildWindowLayout(veh)
        }
    })
end

local function seatLabelForIndex(idx)
    local data = seatLabelMap[idx]
    if data then
        return translate('ui.' .. data.key, data.fallback)
    end

    local prefix = translate('ui.seat_labels.extra_prefix', 'SEDADLO ')
    return prefix .. (idx + 2)
end

local function seatStatus(occupant, playerPed)
    if occupant == playerPed then
        return 'mine'
    end
    if occupant ~= 0 then
        return 'occupied'
    end
    return 'free'
end

local function getSeatsData(veh)
    local seats = {}
    local maxSeats = GetVehicleModelNumberOfSeats(GetEntityModel(veh))
    local playerPed = PlayerPedId()

    for i = -1, maxSeats - 2 do
        local occupant = GetPedInVehicleSeat(veh, i)
        local statusKey = seatStatus(occupant, playerPed)

        table.insert(seats, {
            index = i,
            label = seatLabelForIndex(i),
            icon = (i == -1) and "circle-dot" or "circle",
            occupied = (occupant ~= 0),
            isMine = (occupant == playerPed),
            statusKey = statusKey,
            statusLabel = translate('ui.seat_status.' .. statusKey, statusKey)
        })
    end
    return seats
end

CreateThread(function()
    while true do
        if isMenuOpen then
            local ped, veh = getPlayerVehicle()
            if veh ~= 0 then
                if veh ~= trackedVehicle then
                    pushLayout(veh)
                    trackedVehicle = veh
                end
                SendNUIMessage({
                    type = "updateSeats",
                    seats = getSeatsData(veh)
                })
            else
                trackedVehicle = 0
            end
        else
            trackedVehicle = 0
        end
        Wait(1000)
    end
end)

local function openMenu()
    localeKey = Config.Locale or localeKey
    local ped, veh = getPlayerVehicle()

    if veh == 0 then
        notifyLocale('not_in_vehicle', 'error')
        return
    end

    if Config.Access and Config.Access.DriverOnly and GetPedInVehicleSeat(veh, -1) ~= ped then
        notifyLocale('driver_only', 'error')
        return
    end

    isMenuOpen = true
    SetNuiFocus(true, true)
    pushLocales()
    SendNUIMessage({ type = "ui", status = true })
    SendNUIMessage({ type = "updateSeats", seats = getSeatsData(veh) })
    pushLayout(veh)
    pushVehicleState(veh)
    trackedVehicle = veh
    interiorLightsOn = false
    print("^2[CARMENU] ^7Menu otevreno.")
end

local commandName = (Config.Opening and Config.Opening.Command) or 'carmenu'
RegisterCommand(commandName, openMenu, false)

if RegisterKeyMapping then
    local description = translate('ui.keymap_description', 'Vehicle menu')
    local binding = (Config.Opening and Config.Opening.Keybind) or 'F9'
    RegisterKeyMapping(commandName, description, 'keyboard', binding)
end

RegisterNUICallback('toggleDoor', function(data, cb)
    local _, veh = getPlayerVehicle()
    if veh ~= 0 and data.id ~= nil then
        local doorIndex = tonumber(data.id)
        if doorIndex then
            if data.state then
                SetVehicleDoorOpen(veh, doorIndex, false, false)
            else
                SetVehicleDoorShut(veh, doorIndex, false)
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('toggleWindow', function(data, cb)
    local _, veh = getPlayerVehicle()
    if veh ~= 0 and data.id ~= nil then
        local windowIndex = tonumber(data.id)
        if windowIndex then
            if data.state then
                RollDownWindow(veh, windowIndex)
            else
                RollUpWindow(veh, windowIndex)
            end
        end
    end
    cb('ok')
end)

RegisterNUICallback('toggleEngine', function(data, cb)
    local _, veh = getPlayerVehicle()
    if veh ~= 0 then
        local shouldRun = data.state == true
        SetVehicleEngineOn(veh, shouldRun, false, true)
        SetVehicleUndriveable(veh, not shouldRun)
        pushVehicleState(veh)
        notifyLocale(shouldRun and 'engine_on' or 'engine_off', 'info')
    end
    cb('ok')
end)

RegisterNUICallback('toggleLock', function(data, cb)
    local _, veh = getPlayerVehicle()
    if veh ~= 0 then
        local locked = data.state == true
        SetVehicleDoorsLocked(veh, locked and 2 or 1)
        pushVehicleState(veh)
        notifyLocale(locked and 'vehicle_locked' or 'vehicle_unlocked', locked and 'success' or 'info')
    end
    cb('ok')
end)

RegisterNUICallback('toggleInteriorLights', function(_, cb)
    local _, veh = getPlayerVehicle()
    if veh ~= 0 then
        interiorLightsOn = not interiorLightsOn
        SetVehicleInteriorlight(veh, interiorLightsOn)
    end
    cb('ok')
end)

RegisterNUICallback('cameraControl', function(data, cb)
    cameraControlActive = data.active == true
    if cameraControlActive then
        SetNuiFocus(true, false)
        SetNuiFocusKeepInput(true)
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(true, true)
    end
    cb('ok')
end)

RegisterNUICallback('seatShuffle', function(_, cb)
    local ped, veh = getPlayerVehicle()
    if veh ~= 0 then
        TaskShuffleToNextVehicleSeat(ped, veh)
    end
    cb('ok')
end)

RegisterNUICallback('changeSeat', function(data, cb)
    local ped, veh = getPlayerVehicle()
    if veh ~= 0 then
        if IsVehicleSeatFree(veh, data.id) then
            TaskWarpPedIntoVehicle(ped, veh, data.id)
        else
            notifyLocale('seat_occupied', 'error')
        end
    end
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(_, cb)
    isMenuOpen = false
    trackedVehicle = 0
    cameraControlActive = false
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ type = "ui", status = false })
    cb('ok')
end)
