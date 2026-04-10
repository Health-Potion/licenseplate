--[[
    shared/utils.lua
    Mauritius License Plate — shared utilities (loaded on both client & server)

    Standard format : NNNNMMYY
        4 digits + 2-letter month code + 2-digit year  (8 chars, fits GTA limit)
        Example: 1234OC22  =  October 2022

    Custom tiers:
        Tier 1 — 2 letters + 4 digits   e.g. AB1234        $25,000
        Tier 2 — 3 letters + 4 digits   e.g. ABC1234       $50,000
        Tier 3 — letters only, 4–8 chars e.g. MAURITIUS    $50k–$200k

    Excluded letters for Tier 1 & 2: I, O, Q  (NLTA convention)
--]]

MauPlate = {}

-- ─── helpers ─────────────────────────────────────────────────────────────────

local EXCLUDED = { I = true, O = true, Q = true }

local function hasExcluded(str)
    for i = 1, #str do
        if EXCLUDED[str:sub(i, i)] then return true end
    end
    return false
end

local function trim(s)
    return s:match('^%s*(.-)%s*$')
end

-- ─── standard plate generation ───────────────────────────────────────────────

--- Generate a random standard Mauritius plate: NNNNMMYY
--- e.g. "1234OC22"  (October 2022)
function MauPlate.GenerateStandard()
    local num   = string.format('%04d', math.random(1, 9999))
    local month = Config.PlateMonths[math.random(1, #Config.PlateMonths)]
    local year  = Config.PlateYears[math.random(1, #Config.PlateYears)]
    return num .. month .. year   -- exactly 8 chars
end

-- ─── GTA display formatting ──────────────────────────────────────────────────

--- Clamp to GTA's 8-character plate limit, uppercase.
function MauPlate.FormatForGTA(plate)
    plate = trim(plate):upper()
    if #plate > 8 then plate = plate:sub(1, 8) end
    return plate
end

-- ─── custom plate validation ─────────────────────────────────────────────────

--[[
    Tier 1 — 2 letters + 4 digits
    Examples: AB1234, MU5678
    Returns: ok (bool), err (string|nil), displayPlate (string)
--]]
function MauPlate.ValidateTier1(rawPlate)
    local plate = rawPlate:upper():gsub('%s+', '')

    local letters, digits = plate:match('^([A-Z][A-Z])(%d%d%d%d)$')
    if not letters or not digits then
        return false, 'Invalid format. Expected 2 letters + 4 digits  (e.g. AB1234)', nil
    end

    if hasExcluded(letters) then
        return false, 'Letters I, O and Q are not permitted', nil
    end

    return true, nil, plate   -- 6 chars, fits fine
end

--[[
    Tier 2 — 3 letters + 4 digits
    Examples: ABC1234, MUR2024
    Returns: ok (bool), err (string|nil), displayPlate (string)
--]]
function MauPlate.ValidateTier2(rawPlate)
    local plate = rawPlate:upper():gsub('%s+', '')

    local letters, digits = plate:match('^([A-Z][A-Z][A-Z])(%d%d%d%d)$')
    if not letters or not digits then
        return false, 'Invalid format. Expected 3 letters + 4 digits  (e.g. ABC1234)', nil
    end

    if hasExcluded(letters) then
        return false, 'Letters I, O and Q are not permitted', nil
    end

    return true, nil, plate   -- 7 chars, fits fine
end

--[[
    Tier 3 — letters only, 4–8 characters (name / vanity)
    Examples: MAURITIUS, AFOZ, ADMIN
    Returns: ok (bool), err (string|nil), displayPlate (string), price (number)
--]]
function MauPlate.ValidateTier3(rawPlate)
    local plate = rawPlate:upper():gsub('%s+', '')

    if #plate < 4 or #plate > 8 then
        return false, 'Name plate must be 4–8 characters long', nil, nil
    end

    if not plate:match('^[A-Z]+$') then
        return false, 'Name plate must contain letters only', nil, nil
    end

    local price = Config.Prices.tier3[#plate] or Config.Prices.tier3_default
    return true, nil, plate, price
end

--- Price for a Tier 3 plate by its display length.
function MauPlate.Tier3Price(displayPlate)
    return Config.Prices.tier3[#displayPlate] or Config.Prices.tier3_default
end
