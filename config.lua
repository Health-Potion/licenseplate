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
--  PRICES  (in-game money)
-- ============================================================
Config.Prices = {
    -- Tier 1: 2 letters + 4 digits  e.g. AB1234
    tier1 = 25000,

    -- Tier 2: 3 letters + 4 digits  e.g. ABC1234
    tier2 = 50000,

    -- Tier 3: full letters / name up to 8 chars  (price scales with length)
    tier3 = {
        [4] = 50000,
        [5] = 75000,
        [6] = 100000,
        [7] = 150000,
        [8] = 200000,
    },
    tier3_default = 200000,
}

-- 'cash' or 'bank'
Config.PaymentType = 'bank'

-- Interaction distance for the NLTA shop zone (metres)
Config.ShopRadius = 3.0

-- ============================================================
--  STANDARD PLATE FORMAT
--  NNNNMMYY  — 4 digits + 2-letter month code + 2-digit year
--  Example: 1234OC22  (October 2022)
--  Years generated from this range:
-- ============================================================
Config.PlateYears  = { '20', '21', '22', '23', '24', '25' }
Config.PlateMonths = {
    'JA', 'FE', 'MR', 'AP', 'MA', 'JN',
    'JL', 'AU', 'SE', 'OC', 'NV', 'DE',
}

-- ============================================================
--  PLATE STYLE INDICES  (SetVehicleNumberPlateTextIndex)
--  GTA built-in styles — closest available to MU spec:
--    0 = Blue on White  (front plate — white bg, dark text)
--    1 = Yellow on Black (not ideal)
--    2 = Yellow on Blue
--    4 = worn blue/white
--  True white/yellow split requires a custom stream texture.
-- ============================================================
Config.PlateStyle = 0   -- applied to all vehicles (white-ish background)
