--[[
    shared/utils.lua
    Mauritius License Plate — shared utilities (loaded on both client & server)

    Standard format  : XX NNNN   (2 letters + space + 4 digits)  → max 7 chars, fits GTA 8-char limit
    Old-series custom: A–ZZ + 1–4 digits  (e.g. AB 123)
    New-series custom: 3–6 letters + 3–4 digits (various), or name ≤8 chars
    Excluded letters : I, O, Q  (NLTA convention)
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

-- Strip leading/trailing whitespace
local function trim(s)
    return s:match('^%s*(.-)%s*$')
end

-- ─── standard plate generation ───────────────────────────────────────────────

--- Generate a random standard Mauritius plate: "AB 1234"
--- Letters drawn from Config.AllowedLetters (no I, O, Q).
function MauPlate.GenerateStandard()
    local pool = Config.AllowedLetters
    local l1   = pool:sub(math.random(1, #pool), math.random(1, #pool)):sub(1, 1)
    local l2   = pool:sub(math.random(1, #pool), math.random(1, #pool)):sub(1, 1)
    local num  = string.format('%04d', math.random(1, 9999))
    return l1 .. l2 .. ' ' .. num
end

-- ─── GTA display formatting ──────────────────────────────────────────────────

--- Clamp a plate string to GTA's 8-character limit, uppercase.
function MauPlate.FormatForGTA(plate)
    plate = trim(plate):upper()
    if #plate > 8 then plate = plate:sub(1, 8) end
    return plate
end

-- ─── validation ──────────────────────────────────────────────────────────────

--[[
    Old Series validation
    Accepts:  1–2 uppercase letters (no I/O/Q) + optional space + 1–4 digits
    Examples: "AB 123", "M 4", "ZZ 9999"
    Returns:  ok (bool), err (string|nil)
--]]
function MauPlate.ValidateOldSeries(plate)
    plate = trim(plate:upper())

    -- Normalise internal spacing to a single space then remove it for pattern match
    local noSpace = plate:gsub('%s+', '')

    -- Pattern: 1–2 letters followed by 1–4 digits
    local letters, digits = noSpace:match('^([A-Z][A-Z]?)(%d%d?%d?%d?)$')
    if not letters or not digits or #digits < 1 then
        return false, 'Invalid format. Expected 1–2 letters + 1–4 numbers (e.g. AB 123)'
    end

    if hasExcluded(letters) then
        return false, 'Letters I, O and Q are not permitted'
    end

    return true, nil
end

--[[
    New Series validation
    seriesType must be one of: '3L4N', '4L4N', '5L4N', '6L3N', 'name'
    Returns: ok (bool), err (string|nil), displayPlate (string — GTA-safe, 8 chars max)
--]]
function MauPlate.ValidateNewSeries(rawPlate, seriesType)
    local plate = rawPlate:upper():gsub('%s+', '')

    local validators = {
        ['3L4N'] = function(p)
            return p:match('^([A-Z][A-Z][A-Z])(%d%d%d%d)$')
        end,
        ['4L4N'] = function(p)
            return p:match('^([A-Z][A-Z][A-Z][A-Z])(%d%d%d%d)$')
        end,
        ['5L4N'] = function(p)
            -- 5 letters + 4 digits = 9 chars; GTA truncates to 8, so last digit drops
            return p:match('^([A-Z][A-Z][A-Z][A-Z][A-Z])(%d%d%d%d)$')
        end,
        ['6L3N'] = function(p)
            -- 6 letters + 3 digits = 9 chars; GTA truncates to 8, so last digit drops
            return p:match('^([A-Z][A-Z][A-Z][A-Z][A-Z][A-Z])(%d%d%d)$')
        end,
        ['name'] = function(p)
            if #p < 1 or #p > 8 then return nil end
            return p:match('^([A-Z0-9]+)$')
        end,
    }

    if not validators[seriesType] then
        return false, 'Unknown series type: ' .. tostring(seriesType), nil
    end

    local match = validators[seriesType](plate)
    if not match then
        local hints = {
            ['3L4N'] = 'ABC1234 (3 letters + 4 digits)',
            ['4L4N'] = 'ABCD1234 (4 letters + 4 digits)',
            ['5L4N'] = 'ABCDE1234 (5 letters + 4 digits, shown as 8 chars)',
            ['6L3N'] = 'ABCDEF123 (6 letters + 3 digits, shown as 8 chars)',
            ['name'] = 'Up to 8 alphanumeric characters',
        }
        return false, 'Invalid format. Expected: ' .. (hints[seriesType] or ''), nil
    end

    -- Excluded-letter check (not applied to 'name' type for creative freedom)
    if seriesType ~= 'name' then
        local letterPart = plate:match('^([A-Z]+)')
        if letterPart and hasExcluded(letterPart) then
            return false, 'Letters I, O and Q are not permitted', nil
        end
    end

    local displayPlate = MauPlate.FormatForGTA(plate)
    return true, nil, displayPlate
end

--- Get the in-game price for a new-series format key.
function MauPlate.NewSeriesPrice(seriesType)
    return (Config.Prices.new_series and Config.Prices.new_series[seriesType]) or 150000
end
