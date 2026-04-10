Config = {}

-- ============================================================
--  PLATE SHOP LOCATION  (NLTA Office — fictional in GTA world)
-- ============================================================
Config.ShopCoords = vector3(-559.71, -901.04, 24.0)

Config.ShopBlip = {
    enabled = true,
    sprite  = 480,
    color   = 3,
    scale   = 0.8,
    label   = 'NLTA – License Plate Office',
}

-- ============================================================
--  PRICES
-- ============================================================
Config.Prices = {
    tier1 = 25000,   -- AA 0000  (2 letters + 4 digits)
    tier2 = 50000,   -- AAA 0000 (3 letters + 4 digits)

    -- Tier 3 price scales by character length of the name
    tier3 = {
        [3] = 50000,
        [4] = 75000,
        [5] = 100000,
        [6] = 150000,
        [7] = 175000,
        [8] = 200000,
    },
    tier3_default = 200000,
}

-- 'cash' or 'bank'
Config.PaymentType = 'bank'

-- Interaction radius for NLTA shop zone (metres)
Config.ShopRadius = 3.0

-- ============================================================
--  STANDARD PLATE GENERATION
--  Format: NNNMONYR  (3 digits + 3-letter month + 2-digit year)
--  Exactly 8 characters, no spaces — fits GTA's plate limit.
--  Example: 345OCT23
-- ============================================================
Config.PlateMonths = {
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
}

Config.PlateYears = { '20', '21', '22', '23', '24', '25' }

-- ============================================================
--  PLATE STYLE  (SetVehicleNumberPlateTextIndex)
--  0 = white background / dark text (closest to MU spec)
--  True white front + yellow rear requires stream textures.
-- ============================================================
Config.PlateStyle = 0
