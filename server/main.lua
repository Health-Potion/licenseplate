--[[
    server/main.lua
    Mauritius License Plate System — server side

    Database tables  (see mu_licenseplate.sql)
    ─────────────────────────────────────────────
    mu_plate_map      : vehicle_plate (GTA) → mu_plate (displayed)
    mu_custom_plates  : custom plates purchased by citizens
--]]

local QBCore = exports['qb-core']:GetCoreObject()

-- ─── helpers ─────────────────────────────────────────────────────────────────

local function Notify(src, msg, ntype)
    TriggerClientEvent('mu-licenseplate:client:Notify', src, msg, ntype or 'primary')
end

local function HasMoney(Player, amount)
    return Player.PlayerData.money[Config.PaymentType] >= amount
end

local function TakeMoney(Player, amount, reason)
    Player.Functions.RemoveMoney(Config.PaymentType, amount, reason or 'mu-licenseplate')
end

local function IsPlateAvailable(muPlate)
    local inCustom = MySQL.scalar.await('SELECT 1 FROM mu_custom_plates WHERE mu_plate = ?', { muPlate })
    local inMap    = MySQL.scalar.await('SELECT 1 FROM mu_plate_map    WHERE mu_plate = ?', { muPlate })
    return not inCustom and not inMap
end

--- Generate a standard Mauritius plate not already in mu_plate_map.
local function GenerateUniquePlate()
    for _ = 1, 200 do
        local candidate = MauPlate.GenerateStandard()
        local exists    = MySQL.scalar.await('SELECT 1 FROM mu_plate_map WHERE mu_plate = ?', { candidate })
        if not exists then return candidate end
    end
    return MauPlate.GenerateStandard()  -- fallback (collision astronomically unlikely after 200 tries)
end

-- ─── GET / AUTO-ASSIGN STANDARD PLATE FOR A VEHICLE ─────────────────────────

RegisterNetEvent('mu-licenseplate:server:GetVehiclePlate', function(vehiclePlate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    vehiclePlate = vehiclePlate:upper():gsub('%s+', '')

    -- 1. Already has a Mauritius plate mapped (owned vehicle) — use it
    local row = MySQL.single.await('SELECT mu_plate FROM mu_plate_map WHERE vehicle_plate = ?', { vehiclePlate })
    if row then
        TriggerClientEvent('mu-licenseplate:client:ApplyPlate', src, row.mu_plate)
        return
    end

    -- 2. Check if this vehicle is registered to any player in QBCore
    local registered = MySQL.scalar.await(
        'SELECT 1 FROM player_vehicles WHERE plate = ?', { vehiclePlate }
    )

    if not registered then
        -- Unregistered / NPC / stolen vehicle — leave the plate exactly as
        -- GTA set it. No event fired, no DB write.
        return
    end

    -- 3. Registered vehicle without a MU plate yet — generate and persist one
    local newPlate = GenerateUniquePlate()
    MySQL.insert.await(
        'INSERT INTO mu_plate_map (vehicle_plate, mu_plate, citizenid) VALUES (?, ?, ?)',
        { vehiclePlate, newPlate, Player.PlayerData.citizenid }
    )
    TriggerClientEvent('mu-licenseplate:client:ApplyPlate', src, newPlate)
end)

-- ─── PURCHASE — TIER 1  (2 letters + 4 digits) ───────────────────────────────

RegisterNetEvent('mu-licenseplate:server:PurchaseTier1', function(rawPlate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ok, err, muPlate = MauPlate.ValidateTier1(rawPlate)
    if not ok then Notify(src, err, 'error') return end

    if not IsPlateAvailable(muPlate) then
        Notify(src, 'Plate ' .. muPlate .. ' is already taken.', 'error')
        return
    end

    local price = Config.Prices.tier1
    if not HasMoney(Player, price) then
        Notify(src, 'Insufficient funds. Required: $' .. price, 'error')
        return
    end
    TakeMoney(Player, price, 'custom-plate-tier1')

    MySQL.insert.await(
        "INSERT INTO mu_custom_plates (citizenid, mu_plate, plate_type, purchased_price) VALUES (?, ?, 'tier1', ?)",
        { Player.PlayerData.citizenid, muPlate, price }
    )
    Notify(src, 'Plate ' .. muPlate .. ' purchased! Assign it to your vehicle at the NLTA office.', 'success')
end)

-- ─── PURCHASE — TIER 2  (3 letters + 4 digits) ───────────────────────────────

RegisterNetEvent('mu-licenseplate:server:PurchaseTier2', function(rawPlate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ok, err, muPlate = MauPlate.ValidateTier2(rawPlate)
    if not ok then Notify(src, err, 'error') return end

    if not IsPlateAvailable(muPlate) then
        Notify(src, 'Plate ' .. muPlate .. ' is already taken.', 'error')
        return
    end

    local price = Config.Prices.tier2
    if not HasMoney(Player, price) then
        Notify(src, 'Insufficient funds. Required: $' .. price, 'error')
        return
    end
    TakeMoney(Player, price, 'custom-plate-tier2')

    MySQL.insert.await(
        "INSERT INTO mu_custom_plates (citizenid, mu_plate, plate_type, purchased_price) VALUES (?, ?, 'tier2', ?)",
        { Player.PlayerData.citizenid, muPlate, price }
    )
    Notify(src, 'Plate ' .. muPlate .. ' purchased! Assign it to your vehicle at the NLTA office.', 'success')
end)

-- ─── PURCHASE — TIER 3  (letters only, 4–8 chars, price by length) ───────────

RegisterNetEvent('mu-licenseplate:server:PurchaseTier3', function(rawPlate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ok, err, muPlate, price = MauPlate.ValidateTier3(rawPlate)
    if not ok then Notify(src, err, 'error') return end

    if not IsPlateAvailable(muPlate) then
        Notify(src, 'Plate ' .. muPlate .. ' is already taken.', 'error')
        return
    end

    if not HasMoney(Player, price) then
        Notify(src, 'Insufficient funds. Required: $' .. price .. ' for a ' .. #muPlate .. '-char plate.', 'error')
        return
    end
    TakeMoney(Player, price, 'custom-plate-tier3')

    MySQL.insert.await(
        "INSERT INTO mu_custom_plates (citizenid, mu_plate, plate_type, purchased_price) VALUES (?, ?, 'tier3', ?)",
        { Player.PlayerData.citizenid, muPlate, price }
    )
    Notify(src, 'Plate ' .. muPlate .. ' purchased for $' .. price .. '! Assign it at the NLTA office.', 'success')
end)

-- ─── GET MY PLATES ───────────────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:server:GetMyPlates', function(forAssign)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local plates = MySQL.query.await(
        'SELECT mu_plate, plate_type, assigned_vehicle FROM mu_custom_plates WHERE citizenid = ?',
        { Player.PlayerData.citizenid }
    )

    if forAssign then
        TriggerClientEvent('mu-licenseplate:client:ShowAssignMenu', src, plates)
    else
        TriggerClientEvent('mu-licenseplate:client:ShowMyPlates', src, plates)
    end
end)

-- ─── ASSIGN PLATE TO VEHICLE ─────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:server:AssignPlate', function(muPlate, vehiclePlate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    muPlate         = muPlate:upper()
    vehiclePlate    = vehiclePlate:upper():gsub('%s+', '')

    local owned = MySQL.scalar.await(
        'SELECT 1 FROM mu_custom_plates WHERE citizenid = ? AND mu_plate = ?',
        { citizenid, muPlate }
    )
    if not owned then
        Notify(src, 'You do not own that plate.', 'error')
        return
    end

    -- Clear any other custom plate assigned to this vehicle
    MySQL.update.await(
        'UPDATE mu_custom_plates SET assigned_vehicle = NULL WHERE citizenid = ? AND assigned_vehicle = ?',
        { citizenid, vehiclePlate }
    )

    -- Mark chosen plate as assigned
    MySQL.update.await(
        'UPDATE mu_custom_plates SET assigned_vehicle = ? WHERE citizenid = ? AND mu_plate = ?',
        { vehiclePlate, citizenid, muPlate }
    )

    -- Upsert mu_plate_map for future lookups
    local mapExists = MySQL.scalar.await('SELECT 1 FROM mu_plate_map WHERE vehicle_plate = ?', { vehiclePlate })
    if mapExists then
        MySQL.update.await(
            'UPDATE mu_plate_map SET mu_plate = ?, citizenid = ? WHERE vehicle_plate = ?',
            { muPlate, citizenid, vehiclePlate }
        )
    else
        MySQL.insert.await(
            'INSERT INTO mu_plate_map (vehicle_plate, mu_plate, citizenid) VALUES (?, ?, ?)',
            { vehiclePlate, muPlate, citizenid }
        )
    end

    TriggerClientEvent('mu-licenseplate:client:ApplyPlate', src, muPlate)
    Notify(src, 'Plate ' .. muPlate .. ' is now displayed on your vehicle.', 'success')
end)
