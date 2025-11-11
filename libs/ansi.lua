local ansi = ansi or {}

local ESC = string.char(27) -- \27

ansi.customColor = function(r, g, b, text, terminate)
    local code = string.format("\27[38;2;%d;%d;%dm", r, g, b)
    if text then
        if terminate == false then
            return code .. text
        else
            return code .. text .. "\27[0m"
        end
    else
        return code
    end
end

ansi.customBackground = function(r, g, b, text, terminate)
    local code = string.format("\27[48;2;%d;%d;%dm", r, g, b)
    if text then
        if terminate == false then
            return code .. text
        else
            return code .. text .. "\27[0m"
        end
    else
        return code
    end
end

local function lerpColor(c1, c2, t)
    local r = math.floor(c1[1] + (c2[1] - c1[1]) * t + 0.5)
    local g = math.floor(c1[2] + (c2[2] - c1[2]) * t + 0.5)
    local b = math.floor(c1[3] + (c2[3] - c1[3]) * t + 0.5)
    return r, g, b
end

local function tokenizePreserveAnsi(s)
    local tokens = {}
    local pos = 1
    local len = #s
    while pos <= len do
        local esc_pat = "^(" .. ESC .. "%[[%d;]*m)"
        local esc = s:match(esc_pat, pos)
        if esc then
            table.insert(tokens, { type = "esc", text = esc })
            pos = pos + #esc
        else
            local next_pos = utf8.offset(s, 2, pos) or (len + 1)
            local ch = s:sub(pos, next_pos - 1)
            table.insert(tokens, { type = "char", text = ch })
            pos = next_pos
        end
    end
    return tokens
end

local function gradientPreserveAnsi(text, isBackground, ...)
    local colors = {...}
    if #colors < 2 then
        error("gradient requires at least 2 colors")
    end

    local tokens = tokenizePreserveAnsi(text)

    local visibleCount = 0
    for _, tk in ipairs(tokens) do
        if tk.type == "char" then visibleCount = visibleCount + 1 end
    end
    if visibleCount == 0 then
        return text
    end

    local totalSegments = #colors - 1
    local charsPerSegment = visibleCount / totalSegments

    local out = {}
    local vi = 0
    for _, tk in ipairs(tokens) do
        if tk.type == "esc" then
            table.insert(out, tk.text)
        else
            local i = vi
            local segment = math.floor(i / charsPerSegment) + 1
            if segment >= #colors then segment = #colors - 1 end
            local startColor = colors[segment]
            local endColor   = colors[segment + 1]
            local t = (i % charsPerSegment) / charsPerSegment

            local r, g, b = lerpColor(startColor, endColor, t)

            if isBackground then
                table.insert(out, ansi.customBackground(r, g, b, tk.text, false))
            else
                table.insert(out, ansi.customColor(r, g, b, tk.text, false))
            end

            vi = vi + 1
        end
    end

    table.insert(out, "\27[0m")
    return table.concat(out)
end

ansi.gradient = function(text, ...)
    return gradientPreserveAnsi(text, false, ...)
end

ansi.gradientBackground = function(text, ...)
    return gradientPreserveAnsi(text, true, ...)
end


return ansi

-- local fg = ansi.gradient("Привет", {255,0,0}, {0,255,0})
-- local bg = ansi.gradientBackground("    HELLO    ", {0,100,255}, {255,0,100})
-- print(ansi.customColor(255,255,255, bg))
-- print(ansi.gradient( bg, {255,255,255}, {255,0,255} ))
