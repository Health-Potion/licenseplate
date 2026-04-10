--[[
    client/main.lua
    Mauritius License Plate System — client side

    Behaviour
    ─────────────────────────────────────────────────────────────
    • Every vehicle gets a deterministic MU plate on entry (same GTA plate = same MU plate).
    • If the vehicle has a custom plate assigned in DB, the server overrides the seed plate.
    • The player MANUALLY manages plates with /plate → custom NUI.
      They can view, apply, purchase and sell plates from that HUD.
--]]

local QBCore = exports['qb-core']:GetCoreObject()

local trackedVehicle = 0
local nuiOpen        = false

-- ─── notification helper ─────────────────────────────────────────────────────

local function Notify(msg, ntype)
    QBCore.Functions.Notify(msg, ntype or 'primary', 4000)
end

-- ─── balance helper (client-side, always current) ────────────────────────────

local function GetBalance()
    local PlayerData = QBCore.Functions.GetPlayerData()
    local money = PlayerData.money
    if type(money) == 'string' then money = json.decode(money) end
    return (type(money) == 'table' and tonumber(money[Config.PaymentType])) or 0
end

local function PushBalance()
    if nuiOpen then
        SendNUIMessage({ action = 'setBalance', balance = GetBalance() })
    end
end

-- Push updated balance to NUI whenever QBCore updates player data (e.g. after purchase)
AddEventHandler('QBCore:Client:SetPlayerData', function()
    PushBalance()
end)

-- ─── 3-D text helper ─────────────────────────────────────────────────────────

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

-- ─── plate application ────────────────────────────────────────────────────────

local function ApplyPlate(vehicle, plateText)
    if not DoesEntityExist(vehicle) then return end
    SetVehicleNumberPlateText(vehicle, MauPlate.FormatForGTA(plateText))
    SetVehicleNumberPlateTextIndex(vehicle, Config.PlateStyle)
end

-- ─── vehicle tracking thread ──────────────────────────────────────────────────

CreateThread(function()
    while true do
        Wait(500)
        local ped     = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)

        if vehicle ~= 0 and vehicle ~= trackedVehicle then
            if GetPedInVehicleSeat(vehicle, -1) == ped then
                trackedVehicle = vehicle
                local rawPlate = GetVehicleNumberPlateText(vehicle):upper():gsub('%s+', '')

                -- Step 1: instantly stamp a deterministic MU plate (same GTA plate = same MU plate always)
                ApplyPlate(vehicle, MauPlate.GenerateFromSeed(rawPlate))

                -- Step 2: if a custom plate is assigned in the DB, overwrite the seed plate
                TriggerServerEvent('mu-licenseplate:server:GetVehiclePlate', rawPlate)
            end
        elseif vehicle == 0 then
            trackedVehicle = 0
        end
    end
end)

-- Server sends back a custom plate → apply it over the GTA plate
RegisterNetEvent('mu-licenseplate:client:ApplyPlate', function(muPlate)
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        ApplyPlate(vehicle, muPlate)
    end
end)

-- ─── NLTA shop blip ──────────────────────────────────────────────────────────

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

-- ─── NLTA proximity prompt ────────────────────────────────────────────────────

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
                if IsControlJustReleased(0, 38) and not nuiOpen then OpenPlateUI() end
            end
        else
            Wait(1500)
        end
    end
end)

-- ─── Open / close NUI ────────────────────────────────────────────────────────

function OpenPlateUI()
    if nuiOpen then return end   -- already open, ignore re-entry
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    local vPlate  = ''
    if vehicle ~= 0 then
        vPlate = GetVehicleNumberPlateText(vehicle):upper():gsub('%s+', '')
    end

    nuiOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action       = 'open',
        vehiclePlate = vPlate,
        tier3Prices  = Config.Prices.tier3,
        balance      = GetBalance(),   -- send balance immediately on open
    })
end

local function ClosePlateUI()
    nuiOpen = false
    SetNuiFocus(false, false)
    Citizen.SetTimeout(50, function() SetNuiFocus(false, false) end)
end

-- ─── Lua-side ESC fallback ────────────────────────────────────────────────────
-- If the JS→Lua nuiFetch ever fails, this thread catches ESC and forces close.
-- INPUT_FRONTEND_CANCEL (200) fires even while NUI has focus.

CreateThread(function()
    while true do
        if nuiOpen then
            Wait(0)
            if IsDisabledControlJustReleased(0, 200) then
                ClosePlateUI()
                SendNUIMessage({ action = 'forceClose' })
            end
        else
            Wait(300)
        end
    end
end)

-- ─── NUI callbacks ────────────────────────────────────────────────────────────

-- Close button / ESC (from JS)
RegisterNUICallback('closeUI', function(_, cb)
    ClosePlateUI()
    cb('ok')
end)

-- NUI requests player's plates; balance is now pushed from client side
RegisterNUICallback('getPlates', function(_, cb)
    TriggerServerEvent('mu-licenseplate:server:GetMyPlates')
    PushBalance()
    cb('ok')
end)

-- Server responds with plates → forward to NUI (balance handled separately)
RegisterNetEvent('mu-licenseplate:client:ShowMyPlates', function(plates)
    if nuiOpen then
        SendNUIMessage({ action = 'showPlates', plates = plates, balance = GetBalance() })
    end
end)

-- NUI: apply a plate to current vehicle
RegisterNUICallback('applyPlate', function(data, cb)
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        SendNUIMessage({ action = 'notify', msg = 'You must be in the driver seat.', ntype = 'error' })
        cb('error')
        return
    end
    local vehiclePlate = GetVehicleNumberPlateText(vehicle):upper():gsub('%s+', '')
    TriggerServerEvent('mu-licenseplate:server:AssignPlate', data.muPlate, vehiclePlate)
    cb('ok')
end)

-- NUI: purchase plate
RegisterNUICallback('purchasePlate', function(data, cb)
    local tier  = data.tier
    local plate = (data.plate or ''):upper()

    if tier == 'tier1' then
        TriggerServerEvent('mu-licenseplate:server:PurchaseTier1', plate)
    elseif tier == 'tier2' then
        TriggerServerEvent('mu-licenseplate:server:PurchaseTier2', plate)
    elseif tier == 'tier3' then
        TriggerServerEvent('mu-licenseplate:server:PurchaseTier3', plate)
    end
    cb('ok')
end)

-- NUI: sell plate
RegisterNUICallback('sellPlate', function(data, cb)
    TriggerServerEvent('mu-licenseplate:server:SellPlate', data.muPlate)
    cb('ok')
end)

-- Server notifies client → forward to NUI or show as notification
RegisterNetEvent('mu-licenseplate:client:Notify', function(msg, ntype)
    if nuiOpen then
        SendNUIMessage({ action = 'notify', msg = msg, ntype = ntype })
    else
        Notify(msg, ntype)
    end
end)

-- After purchase, server tells client to refresh the plate list in the NUI
RegisterNetEvent('mu-licenseplate:client:PurchaseSuccess', function(plate)
    if nuiOpen then
        SendNUIMessage({ action = 'purchaseSuccess', plate = plate })
    end
end)

-- After assign, re-apply plate on the vehicle immediately
RegisterNetEvent('mu-licenseplate:client:AssignSuccess', function(muPlate)
    local ped     = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        ApplyPlate(vehicle, muPlate)
    end
    if nuiOpen then
        SendNUIMessage({ action = 'notify', msg = 'Plate ' .. muPlate .. ' applied!', ntype = 'success' })
        TriggerServerEvent('mu-licenseplate:server:GetMyPlates')
    end
end)

-- ─── /plate command ───────────────────────────────────────────────────────────

RegisterCommand('plate', function()
    if nuiOpen then ClosePlateUI() else OpenPlateUI() end
end, false)
