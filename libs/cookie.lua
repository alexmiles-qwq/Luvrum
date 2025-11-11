local cookie = {}


function cookie.parse(header)
    local cookies = {}
    if not header or header == "" then
        return cookies
    end

    for key, value in header:gmatch("([^=;]+)=([^;]*)") do
        key = key:match("^%s*(.-)%s*$")   -- trim spaces
        value = value:match("^%s*(.-)%s*$")
        cookies[key] = value
    end

    return cookies
end

function cookie.serialize(name, value, options)
    assert(type(name) == "string", "cookie name must be a string")
    assert(type(value) == "string", "cookie value must be a string")

    local header = string.format("%s=%s", name, value)
    options = options or {}

    if options.path then
        header = header .. "; Path=" .. options.path
    end

    if options.domain then
        header = header .. "; Domain=" .. options.domain
    end

    if options.maxAge then
        header = header .. "; Max-Age=" .. tostring(options.maxAge)
    end

    if options.expires then
        header = header .. "; Expires=" .. os.date("!%a, %d %b %Y %H:%M:%S GMT", options.expires)
    end

    if options.secure then
        header = header .. "; Secure"
    end

    if options.httpOnly then
        header = header .. "; HttpOnly"
    end

    if options.sameSite then
        header = header .. "; SameSite=" .. options.sameSite
    end

    return header
end

function cookie.serializeAll(tbl)
    local result = {}
    for name, data in pairs(tbl) do
        local value, opts = data.value, data.options
        table.insert(result, cookie.serialize(name, value, opts))
    end
    return result
end

return cookie
