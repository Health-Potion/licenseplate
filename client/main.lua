--[[
    client/main.lua
    Mauritius License Plate System — client side

    Responsibilities
    ─────────────────
    • Detect when the local player enters the driver seat of a vehicle
    • Ask the server for the Mauritius plate assigned to that vehicle
    • Apply the plate text via SetVehicleNumberPlateText
    • Render the NLTA shop interaction zone (3-D prompt + blip)
    • Drive qb-menu / qb-input dialogs for purchasing & assigning plates
--]]

local QBCore = exports['qb-core']:GetCoreObject()

local trackedVehicle = 0   -- entity handle of the vehicle whose plate we last requested

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
    if DoesEntityExist(vehicle) then
        SetVehicleNumberPlateText(vehicle, MauPlate.FormatForGTA(plateText))
    end
end

-- ─── vehicle tracking thread ─────────────────────────────────────────────────
-- Fires a server request once per new driver-seat entry so we always display
-- the correct Mauritius plate (standard or custom).

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

    local items = {
        {
            header      = '🇲🇺  NLTA — License Plate Office',
            isMenuHeader = true,
        },
        {
            header = 'Old Series  (Specific Registration Mark)',
            txt    = '1–2 letters + 1–4 numbers  |  Bank: $' .. Config.Prices.old_series,
            params = { event = 'mu-licenseplate:client:OpenOldSeries' },
        },
        {
            header = 'New Series  (Extended Personalised)',
            txt    = '3–6 letters + 3–4 numbers / custom name  |  From $' ..
                     Config.Prices.new_series['3L4N'],
            params = { event = 'mu-licenseplate:client:OpenNewSeries' },
        },
        {
            header = 'My Plates',
            txt    = 'View all your purchased custom plates',
            params = { event = 'mu-licenseplate:client:ViewMyPlates' },
        },
        {
            header = 'Assign Plate to Vehicle',
            txt    = 'Switch which custom plate is displayed on your current vehicle',
            params = { event = 'mu-licenseplate:client:OpenAssign' },
        },
    }

    if vehicle == 0 then
        -- Disable assign option when not in a vehicle
        items[5] = {
            header = 'Assign Plate to Vehicle  (enter a vehicle first)',
            txt    = '',
            params = { event = 'mu-licenseplate:client:NoVehicle' },
        }
    end

    exports['qb-menu']:openMenu(items)
end

-- ─── OLD SERIES ───────────────────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:client:OpenOldSeries', function()
    local dialog = exports['qb-input']:ShowInput({
        header    = 'Old Series — Custom Plate',
        submitText = 'Purchase  ($' .. Config.Prices.old_series .. ')',
        inputs    = {
            {
                type        = 'text',
                name        = 'plate',
                label       = 'Desired plate  (e.g.  AB 123)',
                required    = true,
                placeholder = 'AB 123',
            },
        },
    })
    if not dialog or not dialog.plate or dialog.plate == '' then return end

    local plate = dialog.plate:upper()
    TriggerServerEvent('mu-licenseplate:server:PurchaseOldSeries', plate)
end)

-- ─── NEW SERIES ───────────────────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:client:OpenNewSeries', function()
    local items = {
        { header = 'New Series — Choose Format', isMenuHeader = true },
    }

    for _, fmt in ipairs(Config.NewSeriesFormats) do
        table.insert(items, {
            header = fmt.label,
            txt    = 'Example: ' .. fmt.example .. '  |  Bank: $' .. fmt.price,
            params = {
                event = 'mu-licenseplate:client:PromptNewPlate',
                args  = { key = fmt.key, price = fmt.price, example = fmt.example },
            },
        })
    end

    exports['qb-menu']:openMenu(items)
end)

RegisterNetEvent('mu-licenseplate:client:PromptNewPlate', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header    = 'New Series — ' .. data.key,
        submitText = 'Purchase  ($' .. data.price .. ')',
        inputs    = {
            {
                type        = 'text',
                name        = 'plate',
                label       = 'Desired plate  (e.g. ' .. data.example .. ')',
                required    = true,
                placeholder = data.example,
            },
        },
    })
    if not dialog or not dialog.plate or dialog.plate == '' then return end

    TriggerServerEvent('mu-licenseplate:server:PurchaseNewSeries', data.key, dialog.plate:upper())
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

-- Convenience command (e.g. for admins / testing)
RegisterCommand('plateoffice', function()
    OpenMainMenu()
end, false)
