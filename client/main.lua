--[[
    client/main.lua
    Mauritius License Plate System — client side

    Responsibilities
    ─────────────────
    • Apply Mauritius plates to ALL nearby streamed vehicles every few seconds
    • For player-owned vehicles: persist via server DB lookup
    • For world/NPC vehicles: apply a locally generated plate (ephemeral, no DB)
    • Render the NLTA shop interaction zone (3-D prompt + blip)
    • Drive qb-menu / qb-input dialogs for purchasing & assigning plates
--]]

local QBCore = exports['qb-core']:GetCoreObject()

local trackedVehicle  = 0    -- handle of vehicle whose DB plate we last requested
local stampedEntities = {}   -- [entityHandle] = true  — world vehicles already plated

-- ─── notification helper ─────────────────────────────────────────────────────

local function Notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary', 4000)
end

-- ─── 3-D text helper ────────────────────────────────────────────────────────

local function Draw3DText(x, y, z, text)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end

    local camCoords = GetGameplayCamCoords()
    local dist      = #(camCoords - vector3(x, y, z))
    local scale     = (1 / dist) * 2.2 * (1 / GetGameplayCamFov()) * 100

    SetTextScale(0.0, scale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 220)
    SetTextEntry('STRING')
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(sx, sy)
end

-- ─── plate application ───────────────────────────────────────────────────────

local function ApplyPlate(vehicle, plateText)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleNumberPlateText(vehicle, MauPlate.FormatForGTA(plateText))
    -- Style 0 = blue-on-white (closest built-in to MU white bg + black text).
    -- True white front / yellow rear requires a stream texture replacement.
    SetVehicleNumberPlateTextIndex(vehicle, Config.PlateStyle)
end

-- ─── world vehicle stamp thread ──────────────────────────────────────────────
-- Runs every 4 seconds. Iterates all streamed vehicles and applies a local
-- Mauritius plate to any that haven't been stamped yet.
-- Player's own vehicle is handled separately via the DB (see thread below).

CreateThread(function()
    while true do
        Wait(4000)

        local playerPed     = PlayerPedId()
        local playerVehicle = GetVehiclePedIsIn(playerPed, false)

        -- Purge stale handles to keep the table lean
        for handle in pairs(stampedEntities) do
            if not DoesEntityExist(handle) then
                stampedEntities[handle] = nil
            end
        end

        local vehicles = GetGamePool('CVehicle')
        for _, veh in ipairs(vehicles) do
            -- Skip the vehicle the player is driving (DB handles that one)
            if veh ~= playerVehicle and not stampedEntities[veh] then
                local plate = MauPlate.GenerateStandard()
                SetVehicleNumberPlateText(veh, plate)
                stampedEntities[veh] = true
            end
        end
    end
end)

-- ─── player vehicle tracking thread ──────────────────────────────────────────
-- Fires a server request once per new driver-seat entry so the player's own
-- vehicle always shows their correct Mauritius plate (standard or custom).

CreateThread(function()
    while true do
        Wait(500)
        local ped     = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and vehicle ~= trackedVehicle then
            -- Only care about the driver seat (-1 = driver)
            if GetPedInVehicleSeat(vehicle, -1) == ped then
                trackedVehicle = vehicle
                local rawPlate = GetVehicleNumberPlateText(vehicle):upper():gsub('%s+', '')
                TriggerServerEvent('mu-licenseplate:server:GetVehiclePlate', rawPlate)
            end
        elseif vehicle == 0 then
            trackedVehicle = 0
        end
    end
end)

-- Server sends back the plate to display
RegisterNetEvent('mu-licenseplate:client:ApplyPlate', function(muPlate)
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        ApplyPlate(vehicle, muPlate)
    end
end)

-- ─── NLTA shop — blip setup ──────────────────────────────────────────────────

CreateThread(function()
    if not Config.ShopBlip.enabled then return end

    local blip = AddBlipForCoord(Config.ShopCoords.x, Config.ShopCoords.y, Config.ShopCoords.z)
    SetBlipSprite(blip, Config.ShopBlip.sprite)
    SetBlipColour(blip, Config.ShopBlip.color)
    SetBlipScale(blip, Config.ShopBlip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.ShopBlip.label)
    EndTextCommandSetBlipName(blip)
end)

-- ─── NLTA shop — proximity loop ──────────────────────────────────────────────

CreateThread(function()
    while true do
        local ped  = PlayerPedId()
        local pos  = GetEntityCoords(ped)
        local dist = #(pos - Config.ShopCoords)

        if dist < Config.ShopRadius + 15.0 then
            Wait(0)
            if dist < Config.ShopRadius then
                Draw3DText(Config.ShopCoords.x, Config.ShopCoords.y,
                           Config.ShopCoords.z + 1.1,
                           '[E]  NLTA – License Plate Office')

                if IsControlJustReleased(0, 38) then  -- E key
                    OpenMainMenu()
                end
            end
        else
            Wait(1500)
        end
    end
end)

-- ─── MAIN MENU ───────────────────────────────────────────────────────────────

function OpenMainMenu()
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    local assignItem = {
        header = 'Assign Plate to Vehicle',
        txt    = 'Switch which custom plate is displayed on your current vehicle',
        params = { event = 'mu-licenseplate:client:OpenAssign' },
    }
    if vehicle == 0 then
        assignItem = {
            header = 'Assign Plate  (enter a vehicle first)',
            txt    = '',
            params = { event = 'mu-licenseplate:client:NoVehicle' },
        }
    end

    exports['qb-menu']:openMenu({
        { header = '🇲🇺  NLTA — License Plate Office', isMenuHeader = true },
        {
            header = 'Tier 1 — 2 Letters + 4 Digits',
            txt    = 'Example: AB1234  |  $' .. Config.Prices.tier1,
            params = { event = 'mu-licenseplate:client:OpenTier1' },
        },
        {
            header = 'Tier 2 — 3 Letters + 4 Digits',
            txt    = 'Example: ABC1234  |  $' .. Config.Prices.tier2,
            params = { event = 'mu-licenseplate:client:OpenTier2' },
        },
        {
            header = 'Tier 3 — Full Letters / Name  (4–8 chars)',
            txt    = 'Example: MAURITIUS  |  $50k – $200k depending on length',
            params = { event = 'mu-licenseplate:client:OpenTier3' },
        },
        {
            header = 'My Plates',
            txt    = 'View all your purchased custom plates',
            params = { event = 'mu-licenseplate:client:ViewMyPlates' },
        },
        assignItem,
    })
end

-- ─── TIER 1  (2L + 4D) ───────────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:client:OpenTier1', function()
    local dialog = exports['qb-input']:ShowInput({
        header     = 'Tier 1 — 2 Letters + 4 Digits',
        submitText = 'Purchase  ($' .. Config.Prices.tier1 .. ')',
        inputs = {
            {
                type        = 'text',
                name        = 'plate',
                label       = 'Plate  (e.g. AB1234)',
                required    = true,
                placeholder = 'AB1234',
            },
        },
    })
    if not dialog or not dialog.plate or dialog.plate == '' then return end
    TriggerServerEvent('mu-licenseplate:server:PurchaseTier1', dialog.plate:upper())
end)

-- ─── TIER 2  (3L + 4D) ───────────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:client:OpenTier2', function()
    local dialog = exports['qb-input']:ShowInput({
        header     = 'Tier 2 — 3 Letters + 4 Digits',
        submitText = 'Purchase  ($' .. Config.Prices.tier2 .. ')',
        inputs = {
            {
                type        = 'text',
                name        = 'plate',
                label       = 'Plate  (e.g. ABC1234)',
                required    = true,
                placeholder = 'ABC1234',
            },
        },
    })
    if not dialog or not dialog.plate or dialog.plate == '' then return end
    TriggerServerEvent('mu-licenseplate:server:PurchaseTier2', dialog.plate:upper())
end)

-- ─── TIER 3  (letters only, 4–8 chars, price by length) ─────────────────────

RegisterNetEvent('mu-licenseplate:client:OpenTier3', function()
    local dialog = exports['qb-input']:ShowInput({
        header     = 'Tier 3 — Name / Vanity Plate',
        submitText = 'Check Price & Purchase',
        inputs = {
            {
                type        = 'text',
                name        = 'plate',
                label       = 'Plate name  (4–8 letters, e.g. MAURITIUS)',
                required    = true,
                placeholder = 'MAURITIUS',
            },
        },
    })
    if not dialog or not dialog.plate or dialog.plate == '' then return end
    TriggerServerEvent('mu-licenseplate:server:PurchaseTier3', dialog.plate:upper())
end)

-- ─── MY PLATES ────────────────────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:client:ViewMyPlates', function()
    TriggerServerEvent('mu-licenseplate:server:GetMyPlates', false)
end)

RegisterNetEvent('mu-licenseplate:client:ShowMyPlates', function(plates)
    if not plates or #plates == 0 then
        Notify('You have no custom plates yet.', 'primary')
        return
    end

    local items = { { header = 'My Custom Plates', isMenuHeader = true } }
    for _, p in ipairs(plates) do
        local assigned = (p.assigned_vehicle and p.assigned_vehicle ~= 'UNASSIGNED')
                         and p.assigned_vehicle or 'Not assigned'
        table.insert(items, {
            header = p.mu_plate,
            txt    = 'Type: ' .. p.plate_type .. '  |  Assigned to: ' .. assigned,
            params = { isMenuHeader = false },
        })
    end

    exports['qb-menu']:openMenu(items)
end)

-- ─── ASSIGN PLATE ─────────────────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:client:OpenAssign', function()
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        Notify('You must be in the driver seat to assign a plate.', 'error')
        return
    end

    TriggerServerEvent('mu-licenseplate:server:GetMyPlates', true)
end)

RegisterNetEvent('mu-licenseplate:client:ShowAssignMenu', function(plates)
    if not plates or #plates == 0 then
        Notify('You have no custom plates to assign.', 'primary')
        return
    end

    local ped            = PlayerPedId()
    local vehicle        = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        Notify('You are no longer in a vehicle.', 'error')
        return
    end
    local vehiclePlate   = GetVehicleNumberPlateText(vehicle):upper():gsub('%s+', '')

    local items = { { header = 'Assign Plate to ' .. vehiclePlate, isMenuHeader = true } }
    for _, p in ipairs(plates) do
        table.insert(items, {
            header = p.mu_plate,
            txt    = 'Type: ' .. p.plate_type,
            params = {
                event = 'mu-licenseplate:client:ConfirmAssign',
                args  = { muPlate = p.mu_plate, vehiclePlate = vehiclePlate },
            },
        })
    end

    exports['qb-menu']:openMenu(items)
end)

RegisterNetEvent('mu-licenseplate:client:ConfirmAssign', function(data)
    TriggerServerEvent('mu-licenseplate:server:AssignPlate', data.muPlate, data.vehiclePlate)
end)

-- ─── misc ────────────────────────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:client:NoVehicle', function()
    Notify('Enter a vehicle first.', 'error')
end)

-- Server-originated notifications
RegisterNetEvent('mu-licenseplate:client:Notify', function(msg, ntype)
    Notify(msg, ntype)
end)

-- Open the NLTA office menu from chat
RegisterCommand('plateoffice', function()
    OpenMainMenu()
end, false)

-- ─── /testplate — quick testing command ──────────────────────────────────────
-- Shows the plate currently displayed on your vehicle and confirms the
-- resource is running. Also forces a re-request from the server.
RegisterCommand('testplate', function()
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 then
        Notify('Get in a vehicle first, then run /testplate.', 'error')
        return
    end

    local displayed = GetVehicleNumberPlateText(vehicle)
    Notify('Current plate: [' .. displayed .. ']  — requesting refresh…', 'primary')

    -- Force a fresh DB lookup so you can confirm server <-> client round-trip
    if GetPedInVehicleSeat(vehicle, -1) == ped then
        trackedVehicle = 0   -- reset so the tracking thread fires again
    end
end, false)
