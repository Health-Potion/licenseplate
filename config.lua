Config = {}

-- ============================================================
--  PLATE SHOP LOCATION  (NLTA Office — fictional in GTA world)
--  Change coords to wherever you want the NPC/interaction zone.
-- ============================================================
Config.ShopCoords = vector3(-559.71, -901.04, 24.0)

Config.ShopBlip = {
    enabled = true,
    sprite  = 480,    -- vehicle services icon
    color   = 3,      -- blue
    scale   = 0.8,
    label   = 'NLTA – License Plate Office',
}

-- ============================================================
--  PRICES  (in-game money, mirroring real MUR costs)
-- ============================================================
Config.Prices = {
    -- Old Series (Specific Registration Mark)
    old_series = 25000,   -- full purchase
    old_reserve = 2000,   -- non-deductible reservation (deducted first, remainder on confirm)

    -- New Series (Extended Personalised)
    new_series = {
        ['3L4N'] = 50000,   -- ABC 1234
        ['4L4N'] = 75000,   -- ABCD1234
        ['5L4N'] = 100000,  -- ABCDE123  (truncated to 8 chars for GTA)
        ['6L3N'] = 125000,  -- ABCDEF12  (truncated to 8 chars for GTA)
        ['name'] = 150000,  -- custom name up to 8 alphanumeric chars
    },
    new_reserve = 5000,
}

-- 'cash' or 'bank'
Config.PaymentType = 'bank'

-- Interaction distance for the NLTA shop zone (metres)
Config.ShopRadius = 3.0

-- ============================================================
--  STANDARD PLATE GENERATION
--  Mauritius standard format: XX NNNN  (2 letters, space, 4 digits)
--  Letters I, O, Q are excluded per NLTA convention.
-- ============================================================
Config.AllowedLetters = 'ABCDEFGHJKLMNPRSTUVWXYZ'

-- ============================================================
--  NEW-SERIES FORMAT DESCRIPTIONS (shown in menus)
-- ============================================================
Config.NewSeriesFormats = {
    { key = '3L4N', label = '3 Letters + 4 Numbers',        example = 'ABC 1234',  price = 50000  },
    { key = '4L4N', label = '4 Letters + 4 Numbers',        example = 'ABCD1234',  price = 75000  },
    { key = '5L4N', label = '5 Letters + 4 Numbers',        example = 'ABCDE123',  price = 100000 },
    { key = '6L3N', label = '6 Letters + 3 Numbers',        example = 'ABCDEF12',  price = 125000 },
    { key = 'name', label = 'Custom Name (up to 8 chars)',  example = 'MAURITIUS', price = 150000 },
}
