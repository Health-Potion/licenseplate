--[[
    shared/utils.lua
    Mauritius License Plate — shared utilities (client + server)

    ┌──────────────────────────────────────────────────────────────┐
    │  Standard  │  NNNMONYR   │  345OCT23   │  8 chars  │  auto  │
    │  Tier 1    │  AA 0000    │  ZW 1234    │  7 chars  │  $25k  │
    │  Tier 2    │  AAA 0000   │  ZIL 1234   │  8 chars  │  $50k  │
    │  Tier 3    │  letters    │  ISMAIL     │  3–8 chr  │  var   │
    └──────────────────────────────────────────────────────────────┘

    GTA5 plate text limit: 8 characters.
    Standard uses 3-digit sequential number (not 4) so the full
    NNN + MON + YY fits in 8 chars with no spaces: e.g. 345OCT23.
--]]

MauPlate = {}

-- ─── helpers ─────────────────────────────────────────────────────────────────

local function trim(s)
    return s:match('^%s*(.-)%s*$')
end

-- ─── standard plate generation ───────────────────────────────────────────────

--- Returns a plate in "NNNMONYR" format, e.g. "345OCT23"  (exactly 8 chars).
--- 3-digit sequential number + 3-letter month + 2-digit year, no spaces.
function MauPlate.GenerateStandard()
    local num   = string.format('%03d', math.random(1, 999))
    local month = Config.PlateMonths[math.random(1, #Config.PlateMonths)]
    local year  = Config.PlateYears[math.random(1, #Config.PlateYears)]
    return num .. month .. year   -- 3 + 3 + 2 = 8 chars exactly
end

-- ─── GTA display formatting ──────────────────────────────────────────────────

--- Uppercase and clamp to GTA's 8-character plate limit.
function MauPlate.FormatForGTA(plate)
    plate = trim(plate):upper()
    if #plate > 8 then plate = plate:sub(1, 8) end
    return plate
end

-- ─── custom plate validation ─────────────────────────────────────────────────

--[[
    Tier 1 — AA 0000  (2 uppercase letters + space + 4 digits)
    Example: ZW 1234  (7 chars)
    Returns: ok, err, displayPlate
--]]
function MauPlate.ValidateTier1(rawPlate)
    local plate = trim(rawPlate:upper())

    -- Accept with or without space; normalise to "LL DDDD"
    local noSpace = plate:gsub('%s+', '')
    local letters, digits = noSpace:match('^([A-Z][A-Z])(%d%d%d%d)$')

    if not letters or not digits then
        return false, 'Invalid format. Expected 2 letters + 4 digits  (e.g. ZW 1234)', nil
    end

    return true, nil, letters .. ' ' .. digits   -- "ZW 1234" = 7 chars
end

--[[
    Tier 2 — AAA 0000  (3 uppercase letters + space + 4 digits)
    Example: ZIL 1234  (8 chars)
    Returns: ok, err, displayPlate
--]]
function MauPlate.ValidateTier2(rawPlate)
    local plate = trim(rawPlate:upper())

    local noSpace = plate:gsub('%s+', '')
    local letters, digits = noSpace:match('^([A-Z][A-Z][A-Z])(%d%d%d%d)$')

    if not letters or not digits then
        return false, 'Invalid format. Expected 3 letters + 4 digits  (e.g. ZIL 1234)', nil
    end

    return true, nil, letters .. ' ' .. digits   -- "ZIL 1234" = 8 chars
end

--[[
    Tier 3 — letters only, 3–8 characters (full word / name / vanity)
    Example: ISMAIL (6), ZILWARE (7)
    Returns: ok, err, displayPlate, price
--]]
function MauPlate.ValidateTier3(rawPlate)
    local plate = trim(rawPlate:upper()):gsub('%s+', '')

    if #plate < 3 or #plate > 8 then
        return false, 'Name plate must be 3–8 characters long', nil, nil
    end

    if not plate:match('^[A-Z]+$') then
        return false, 'Name plate must contain letters only (no numbers or spaces)', nil, nil
    end

    local price = Config.Prices.tier3[#plate] or Config.Prices.tier3_default
    return true, nil, plate, price
end

--- Price for a Tier 3 plate by its character count.
function MauPlate.Tier3Price(displayPlate)
    return Config.Prices.tier3[#displayPlate] or Config.Prices.tier3_default
end
