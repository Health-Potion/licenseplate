--[[
    shared/utils.lua
    Mauritius License Plate — shared utilities (client + server)

    ┌──────────────────────────────────────────────────────────────┐
    │  Standard  │  NNNNMMYY   │  5026JL20   │  8 chars  │  auto  │
    │  Tier 1    │  AA 0000    │  ZW 1234    │  7 chars  │  $25k  │
    │  Tier 2    │  AAA 0000   │  ZIL 1234   │  8 chars  │  $50k  │
    │  Tier 3    │  letters    │  ISMAIL     │  3–8 chr  │  var   │
    └──────────────────────────────────────────────────────────────┘

    GTA5 plate text limit: 8 characters.
    Standard: 4 digits + 2-letter month code + 2-digit year = 8 chars.
    2-letter month codes match real Mauritius plates (JL=July, OC=Oct…)
--]]

MauPlate = {}

-- ─── helpers ─────────────────────────────────────────────────────────────────

local function trim(s)
    return s:match('^%s*(.-)%s*$')
end

-- ─── standard plate generation ───────────────────────────────────────────────

--- Returns a random plate in "NNNNMMYY" format, e.g. "5026JL20" (8 chars).
--- Used when generating a new persistent plate for a registered vehicle.
function MauPlate.GenerateStandard()
    local num   = string.format('%04d', math.random(1, 9999))
    local month = Config.PlateMonths[math.random(1, #Config.PlateMonths)]
    local year  = Config.PlateYears[math.random(1, #Config.PlateYears)]
    return num .. month .. year   -- 4 + 2 + 2 = 8 chars exactly
end

--- Derives a deterministic Mauritius plate from a GTA native plate string.
--- The same input always produces the same output — no DB, no randomness.
--- Used for stolen / NPC vehicles so the plate looks Mauritian but never
--- changes between sessions.
function MauPlate.GenerateFromSeed(gtaPlate)
    -- Simple polynomial hash of the plate characters
    local hash = 5381
    for i = 1, #gtaPlate do
        hash = (hash * 33 + string.byte(gtaPlate, i)) % 2147483647
    end

    local num   = string.format('%04d', (hash % 9999) + 1)
    local month = Config.PlateMonths[(hash % #Config.PlateMonths) + 1]
    local year  = Config.PlateYears[(math.floor(hash / #Config.PlateMonths) % #Config.PlateYears) + 1]
    return num .. month .. year
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
    Tier 1 — 2 letters + 1–4 digits
    Examples: ZW 1, ZW 12, ZW 123, ZW 1234
    Returns: ok, err, displayPlate
--]]
function MauPlate.ValidateTier1(rawPlate)
    local plate   = trim(rawPlate:upper())
    local noSpace = plate:gsub('%s+', '')

    local letters, digits = noSpace:match('^([A-Z][A-Z])(%d%d?%d?%d?)$')
    if not letters or not digits or #digits < 1 then
        return false, 'Invalid format. Expected 2 letters + 1–4 digits  (e.g. ZW 1234)', nil
    end

    return true, nil, letters .. ' ' .. digits
end

--[[
    Tier 2 — 3 letters + 1–4 digits
    Examples: ZIL 1, ZIL 12, ZIL 1234
    Returns: ok, err, displayPlate
--]]
function MauPlate.ValidateTier2(rawPlate)
    local plate   = trim(rawPlate:upper())
    local noSpace = plate:gsub('%s+', '')

    local letters, digits = noSpace:match('^([A-Z][A-Z][A-Z])(%d%d?%d?%d?)$')
    if not letters or not digits or #digits < 1 then
        return false, 'Invalid format. Expected 3 letters + 1–4 digits  (e.g. ZIL 1234)', nil
    end

    return true, nil, letters .. ' ' .. digits
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
