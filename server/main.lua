--[[
    server/main.lua
    Mauritius License Plate System — server side

    GetVehiclePlate   : only returns a plate if a custom one is assigned in the DB.
                        Standard sequential plates are now handled client-side via
                        MauPlate.GenerateFromSeed() — no DB writes for them.
    PurchaseTier1/2/3 : validate, charge, persist to mu_custom_plates.
    AssignPlate       : link a custom plate to a vehicle in both tables.
    SellPlate         : remove plate, refund 50% of purchase price.
    GetMyPlates       : return all custom plates owned by the citizen.
--]]

local QBCore = exports['qb-core']:GetCoreObject()

-- ─── helpers ─────────────────────────────────────────────────────────────────

local function Notify(src, msg, ntype)
    TriggerClientEvent('mu-licenseplate:client:Notify', src, msg, ntype or 'primary')
end

local function HasMoney(Player, amount)
    return Player.Functions.GetMoney(Config.PaymentType) >= amount
end

local function TakeMoney(Player, amount, reason)
    Player.Functions.RemoveMoney(Config.PaymentType, amount, reason or 'mu-licenseplate')
end

local function AddMoney(Player, amount, reason)
    Player.Functions.AddMoney(Config.PaymentType, amount, reason or 'mu-licenseplate')
end

local function IsPlateAvailable(muPlate)
    local inCustom = MySQL.scalar.await('SELECT 1 FROM mu_custom_plates WHERE mu_plate = ?', { muPlate })
    local inMap    = MySQL.scalar.await('SELECT 1 FROM mu_plate_map    WHERE mu_plate = ?', { muPlate })
    return not inCustom and not inMap
end

-- ─── GET CUSTOM PLATE FOR A VEHICLE (on seat entry) ──────────────────────────
-- Only responds if a custom plate is assigned to this vehicle.
-- Standard plates are generated client-side — no DB write needed.

RegisterNetEvent('mu-licenseplate:server:GetVehiclePlate', function(vehiclePlate)
    local src = source
    if not QBCore.Functions.GetPlayer(src) then return end

    vehiclePlate = vehiclePlate:upper():gsub('%s+', '')

    local row = MySQL.single.await(
        'SELECT mu_plate FROM mu_plate_map WHERE vehicle_plate = ?', { vehiclePlate }
    )
    if row then
        TriggerClientEvent('mu-licenseplate:client:ApplyPlate', src, row.mu_plate)
    end
    -- No row = no custom plate assigned → client seed plate stays, nothing sent
end)

-- ─── GET MY PLATES (for NUI) ──────────────────────────────────────────────────
-- Sends both the player's plate list and their current balance so the NUI
-- can disable purchase buttons for plates they can't afford.

RegisterNetEvent('mu-licenseplate:server:GetMyPlates', function()
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local plates = MySQL.query.await(
        'SELECT mu_plate, plate_type, assigned_vehicle, purchased_price FROM mu_custom_plates WHERE citizenid = ?',
        { Player.PlayerData.citizenid }
    )
    -- Balance is read client-side from QBCore.Functions.GetPlayerData() for accuracy
    TriggerClientEvent('mu-licenseplate:client:ShowMyPlates', src, plates)
end)

-- ─── PURCHASE — TIER 1  (AA 0000) ────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:server:PurchaseTier1', function(rawPlate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ok, err, muPlate = MauPlate.ValidateTier1(rawPlate)
    if not ok then Notify(src, err, 'error') return end

    if not IsPlateAvailable(muPlate) then
        Notify(src, 'Plate ' .. muPlate .. ' is already taken.', 'error') return
    end

    local price = Config.Prices.tier1
    if not HasMoney(Player, price) then
        Notify(src, 'Insufficient funds. Required: $' .. price, 'error') return
    end
    TakeMoney(Player, price, 'custom-plate-tier1')

    MySQL.insert.await(
        "INSERT INTO mu_custom_plates (citizenid, mu_plate, plate_type, purchased_price) VALUES (?, ?, 'tier1', ?)",
        { Player.PlayerData.citizenid, muPlate, price }
    )
    TriggerClientEvent('mu-licenseplate:client:PurchaseSuccess', src, muPlate)
end)

-- ─── PURCHASE — TIER 2  (AAA 0000) ───────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:server:PurchaseTier2', function(rawPlate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ok, err, muPlate = MauPlate.ValidateTier2(rawPlate)
    if not ok then Notify(src, err, 'error') return end

    if not IsPlateAvailable(muPlate) then
        Notify(src, 'Plate ' .. muPlate .. ' is already taken.', 'error') return
    end

    local price = Config.Prices.tier2
    if not HasMoney(Player, price) then
        Notify(src, 'Insufficient funds. Required: $' .. price, 'error') return
    end
    TakeMoney(Player, price, 'custom-plate-tier2')

    MySQL.insert.await(
        "INSERT INTO mu_custom_plates (citizenid, mu_plate, plate_type, purchased_price) VALUES (?, ?, 'tier2', ?)",
        { Player.PlayerData.citizenid, muPlate, price }
    )
    TriggerClientEvent('mu-licenseplate:client:PurchaseSuccess', src, muPlate)
end)

-- ─── PURCHASE — TIER 3  (letters only, price by length) ──────────────────────

RegisterNetEvent('mu-licenseplate:server:PurchaseTier3', function(rawPlate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local ok, err, muPlate, price = MauPlate.ValidateTier3(rawPlate)
    if not ok then Notify(src, err, 'error') return end

    if not IsPlateAvailable(muPlate) then
        Notify(src, 'Plate ' .. muPlate .. ' is already taken.', 'error') return
    end

    if not HasMoney(Player, price) then
        Notify(src, 'Insufficient funds. Required: $' .. price, 'error') return
    end
    TakeMoney(Player, price, 'custom-plate-tier3')

    MySQL.insert.await(
        "INSERT INTO mu_custom_plates (citizenid, mu_plate, plate_type, purchased_price) VALUES (?, ?, 'tier3', ?)",
        { Player.PlayerData.citizenid, muPlate, price }
    )
    TriggerClientEvent('mu-licenseplate:client:PurchaseSuccess', src, muPlate)
end)

-- ─── ASSIGN PLATE TO VEHICLE ──────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:server:AssignPlate', function(muPlate, vehiclePlate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    muPlate         = muPlate:upper()
    vehiclePlate    = vehiclePlate:upper():gsub('%s+', '')

    -- Verify ownership
    local owned = MySQL.scalar.await(
        'SELECT 1 FROM mu_custom_plates WHERE citizenid = ? AND mu_plate = ?',
        { citizenid, muPlate }
    )
    if not owned then Notify(src, 'You do not own that plate.', 'error') return end

    -- Clear previous assignment for this vehicle
    MySQL.update.await(
        'UPDATE mu_custom_plates SET assigned_vehicle = NULL WHERE citizenid = ? AND assigned_vehicle = ?',
        { citizenid, vehiclePlate }
    )

    -- Mark chosen plate as assigned
    MySQL.update.await(
        'UPDATE mu_custom_plates SET assigned_vehicle = ? WHERE citizenid = ? AND mu_plate = ?',
        { vehiclePlate, citizenid, muPlate }
    )

    -- Upsert mu_plate_map so the plate is restored on next entry
    local mapExists = MySQL.scalar.await(
        'SELECT 1 FROM mu_plate_map WHERE vehicle_plate = ?', { vehiclePlate }
    )
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

    TriggerClientEvent('mu-licenseplate:client:AssignSuccess', src, muPlate)
end)

-- ─── SELL PLATE ───────────────────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:server:SellPlate', function(muPlate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    muPlate         = muPlate:upper()

    local row = MySQL.single.await(
        'SELECT id, purchased_price, assigned_vehicle FROM mu_custom_plates WHERE citizenid = ? AND mu_plate = ?',
        { citizenid, muPlate }
    )
    if not row then Notify(src, 'You do not own that plate.', 'error') return end

    -- Remove from custom plates
    MySQL.update.await('DELETE FROM mu_custom_plates WHERE id = ?', { row.id })

    -- Remove from plate_map if assigned to a vehicle
    if row.assigned_vehicle and row.assigned_vehicle ~= 'UNASSIGNED' then
        MySQL.update.await('DELETE FROM mu_plate_map WHERE vehicle_plate = ? AND mu_plate = ?',
            { row.assigned_vehicle, muPlate })
    end

    -- Refund 50%
    local refund = math.floor((row.purchased_price or 0) * 0.5)
    if refund > 0 then AddMoney(Player, refund, 'plate-sale-refund') end

    Notify(src, 'Plate ' .. muPlate .. ' sold. Refund: $' .. refund, 'success')
    -- Refresh plate list in NUI; balance is read client-side automatically
    local plates = MySQL.query.await(
        'SELECT mu_plate, plate_type, assigned_vehicle, purchased_price FROM mu_custom_plates WHERE citizenid = ?',
        { citizenid }
    )
    TriggerClientEvent('mu-licenseplate:client:ShowMyPlates', src, plates)
end)
