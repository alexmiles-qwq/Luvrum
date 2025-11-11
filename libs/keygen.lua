-- keygen
local keygen = {}
keygen.charMap = 'QWERTYUIOPASDFGHJKLZXCVBNM1234567890'
keygen.charsPerPart = 4
keygen.parts = 4 


math.randomseed(os.time() + os.clock() * 100000)  -- randomize random


local function pickRandomChar()
    
    -- Update Values
    
    local totalChars = #keygen.charMap
    local randomChar = math.random(1, totalChars)

    local char = string.sub(keygen.charMap, randomChar, randomChar)
    
    return char
end

local function generatePart()

    local part = nil

    for i=1, keygen.charsPerPart do
        local randomChar = pickRandomChar()
        if part == nil then part = randomChar else part = part..randomChar end
    end

    return part
end

local function generateKey()
    local key = nil
    
    for i=1, keygen.parts do
        local part = generatePart()
        if key == nil then key = part else key = key..'-'..part end
    end

    return key
    
end

function keygen:GenerateKeyOld()
    local Key = generateKey()
    return Key
end

function keygen:GenerateKey()
    return utils:generateUUID()
end

return keygen
