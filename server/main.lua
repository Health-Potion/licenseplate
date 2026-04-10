--[[
    server/main.lua
    Mauritius License Plate System — server side

    Database tables  (see sql/mu_licenseplate.sql)
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
    local payType = Config.PaymentType
    return Player.PlayerData.money[payType] >= amount
end

local function TakeMoney(Player, amount, reason)
    Player.Functions.RemoveMoney(Config.PaymentType, amount, reason or 'mu-licenseplate')
end

--- Generate a Mauritius plate that does not yet exist in mu_plate_map.
local function GenerateUniquePlate()
    for _ = 1, 200 do
        local candidate = MauPlate.GenerateStandard()
        local exists    = MySQL.scalar.await(
            'SELECT 1 FROM mu_plate_map WHERE mu_plate = ?', { candidate }
        )
        if not exists then return candidate end
    end
    -- Extremely unlikely fallback: append a random suffix
    return MauPlate.GenerateStandard() .. tostring(math.random(10, 99)):sub(1, 2)
end

-- ─── GET / AUTO-ASSIGN PLATE FOR A VEHICLE ───────────────────────────────────

RegisterNetEvent('mu-licenseplate:server:GetVehiclePlate', function(vehiclePlate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    vehiclePlate = vehiclePlate:upper():gsub('%s+', '')

    -- 1. Check if this vehicle already has a Mauritius plate mapped
    local row = MySQL.single.await(
        'SELECT mu_plate FROM mu_plate_map WHERE vehicle_plate = ?', { vehiclePlate }
    )

    if row then
        TriggerClientEvent('mu-licenseplate:client:ApplyPlate', src, row.mu_plate)
        return
    end

    -- 2. Auto-generate a standard plate and persist it
    local newPlate  = GenerateUniquePlate()
    local citizenid = Player.PlayerData.citizenid

    MySQL.insert.await(
        'INSERT INTO mu_plate_map (vehicle_plate, mu_plate, citizenid) VALUES (?, ?, ?)',
        { vehiclePlate, newPlate, citizenid }
    )

    TriggerClientEvent('mu-licenseplate:client:ApplyPlate', src, newPlate)
end)

-- ─── PURCHASE — OLD SERIES ───────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:server:PurchaseOldSeries', function(rawPlate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    rawPlate = rawPlate:upper()

    -- Validate format
    local ok, err = MauPlate.ValidateOldSeries(rawPlate)
    if not ok then
        Notify(src, err, 'error')
        return
    end

    -- Normalise to "XX NNNN" style (remove extra spaces, reinsert one)
    local noSpace  = rawPlate:gsub('%s+', '')
    local letters  = noSpace:match('^([A-Z]+)')
    local digits   = noSpace:match('(%d+)$')
    local muPlate  = letters .. ' ' .. digits
    muPlate        = MauPlate.FormatForGTA(muPlate)

    -- Uniqueness check
    local taken = MySQL.scalar.await(
        'SELECT 1 FROM mu_custom_plates WHERE mu_plate = ?', { muPlate }
    )
    if taken then
        Notify(src, 'Plate ' .. muPlate .. ' is already taken.', 'error')
        return
    end

    -- Also check the auto-generated map so we don't clash
    local inMap = MySQL.scalar.await(
        'SELECT 1 FROM mu_plate_map WHERE mu_plate = ?', { muPlate }
    )
    if inMap then
        Notify(src, 'Plate ' .. muPlate .. ' is already in use.', 'error')
        return
    end

    -- Payment
    local price = Config.Prices.old_series
    if not HasMoney(Player, price) then
        Notify(src, 'Insufficient funds. Required: $' .. price, 'error')
        return
    end
    TakeMoney(Player, price, 'custom-plate-old-series')

    -- Persist
    MySQL.insert.await(
        [[INSERT INTO mu_custom_plates (citizenid, mu_plate, plate_type, purchased_price)
          VALUES (?, ?, 'custom_old', ?)]],
        { Player.PlayerData.citizenid, muPlate, price }
    )

    Notify(src,
        'Plate ' .. muPlate .. ' purchased! Use "Assign Plate" at the NLTA office to apply it.',
        'success'
    )
end)

-- ─── PURCHASE — NEW SERIES ───────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:server:PurchaseNewSeries', function(seriesType, rawPlate)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    rawPlate = rawPlate:upper():gsub('%s+', '')

    -- Validate
    local ok, err, displayPlate = MauPlate.ValidateNewSeries(rawPlate, seriesType)
    if not ok then
        Notify(src, err, 'error')
        return
    end

    -- Inform player if plate was truncated to fit GTA's 8-char limit
    if displayPlate ~= rawPlate then
        Notify(src,
            'Plate truncated to 8 characters: ' .. displayPlate .. '. Continuing purchase.',
            'primary'
        )
    end

    -- Uniqueness
    local taken = MySQL.scalar.await(
        'SELECT 1 FROM mu_custom_plates WHERE mu_plate = ?', { displayPlate }
    )
    if taken then
        Notify(src, 'Plate ' .. displayPlate .. ' is already taken.', 'error')
        return
    end

    local inMap = MySQL.scalar.await(
        'SELECT 1 FROM mu_plate_map WHERE mu_plate = ?', { displayPlate }
    )
    if inMap then
        Notify(src, 'Plate ' .. displayPlate .. ' is already in use.', 'error')
        return
    end

    -- Payment
    local price = MauPlate.NewSeriesPrice(seriesType)
    if not HasMoney(Player, price) then
        Notify(src, 'Insufficient funds. Required: $' .. price, 'error')
        return
    end
    TakeMoney(Player, price, 'custom-plate-new-series')

    -- Persist
    MySQL.insert.await(
        [[INSERT INTO mu_custom_plates (citizenid, mu_plate, plate_type, purchased_price)
          VALUES (?, ?, 'custom_new', ?)]],
        { Player.PlayerData.citizenid, displayPlate, price }
    )

    Notify(src,
        'Plate ' .. displayPlate .. ' purchased! Use "Assign Plate" at the NLTA office to apply it.',
        'success'
    )
end)

-- ─── GET MY PLATES ───────────────────────────────────────────────────────────

RegisterNetEvent('mu-licenseplate:server:GetMyPlates', function(forAssign)
    local src    = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    local plates    = MySQL.query.await(
        'SELECT mu_plate, plate_type, assigned_vehicle FROM mu_custom_plates WHERE citizenid = ?',
        { citizenid }
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

    local citizenid  = Player.PlayerData.citizenid
    muPlate          = muPlate:upper()
    vehiclePlate     = vehiclePlate:upper():gsub('%s+', '')

    -- Verify ownership
    local owned = MySQL.scalar.await(
        'SELECT 1 FROM mu_custom_plates WHERE citizenid = ? AND mu_plate = ?',
        { citizenid, muPlate }
    )
    if not owned then
        Notify(src, 'You do not own that plate.', 'error')
        return
    end

    -- Un-assign any other custom plate currently on this vehicle
    MySQL.update.await(
        [[UPDATE mu_custom_plates SET assigned_vehicle = NULL
          WHERE citizenid = ? AND assigned_vehicle = ?]],
        { citizenid, vehiclePlate }
    )

    -- Mark the chosen plate as assigned
    MySQL.update.await(
        'UPDATE mu_custom_plates SET assigned_vehicle = ? WHERE citizenid = ? AND mu_plate = ?',
        { vehiclePlate, citizenid, muPlate }
    )

    -- Upsert mu_plate_map so future lookups return the custom plate
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

    -- Push the new plate to the client immediately
    TriggerClientEvent('mu-licenseplate:client:ApplyPlate', src, muPlate)
    Notify(src, 'Plate ' .. muPlate .. ' is now displayed on your vehicle.', 'success')
end)
