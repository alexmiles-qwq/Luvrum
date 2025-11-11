local utils = {}


utils.shallowCopy = function(orig)
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = v
    end
    return copy
end

function utils.createEvent(t, name)
    local event, fireFunc = event.new(true)

    if not events[t] then
        events[t] = {}
    end

    events[t][name] = event

    return fireFunc, event
end

local ffi = require("ffi")
local bit = require("bit")


local function randomBytes(n)
    local bytes = {}
    if ffi.os == "Windows" then
        local advapi32 = ffi.load("advapi32")

        ffi.cdef[[
            typedef void* HCRYPTPROV;
            int CryptAcquireContextA(HCRYPTPROV *phProv, const char *pszContainer,
                                     const char *pszProvider, unsigned long dwProvType, unsigned long dwFlags);
            int CryptGenRandom(HCRYPTPROV hProv, unsigned long dwLen, unsigned char *pbBuffer);
            int CryptReleaseContext(HCRYPTPROV hProv, unsigned long dwFlags);
        ]]

        local hProv = ffi.new("HCRYPTPROV[1]")
        local PROV_RSA_FULL = 1
        local CRYPT_VERIFYCONTEXT = 0xF0000000

        if advapi32.CryptAcquireContextA(hProv, nil, nil, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT) == 0 then
            error("Failed to acquire crypto context")
        end

        local buf = ffi.new("uint8_t[?]", n)
        if advapi32.CryptGenRandom(hProv[0], n, buf) == 0 then
            error("Failed to generate crypto random")
        end

        if advapi32.CryptReleaseContext(hProv[0], 0) == 0 then
            error("Failed to release crypto context")
        end

        for i = 0, n-1 do
            bytes[i+1] = buf[i]
        end
    else
        local f = assert(io.open("/dev/urandom", "rb"))
        local data = f:read(n)
        f:close()
        for i = 1, #data do
            bytes[i] = data:byte(i)
        end
    end
    return bytes
end


-- Generate a v4 UUID string
local function generateUUID()
    local b = randomBytes(16)
    b[7] = bit.band(b[7], 0x0F) + 0x40  -- version 4
    b[9] = bit.band(b[9], 0x3F) + 0x80  -- variant
    return string.format("%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
        b[1],b[2],b[3],b[4], b[5],b[6], b[7],b[8],
        b[9],b[10], b[11],b[12],b[13],b[14],b[15],b[16])
end


utils.generateUUID = generateUUID

return utils 