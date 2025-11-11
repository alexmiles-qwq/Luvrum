--[[
    Niko - nice and simple logger for luvit.
    made by foxi22815
]]

local fs = require('fs')
local path = require('path')

local niko = {}
niko.minPriority = 2
niko.useTemplate = "Default"

niko.Templates = {}

niko.Templates["Default"] = function(message, part, messageType)
    return "[" .. os.date("%X") .. "] " ..
           (messageType and (part and "[" .. part .. "/" .. messageType .. "]: " or "[" .. messageType .. "]: ")
            or (part and "[" .. part .. "]: " or "")) ..
           tostring(message)
end

local logsDir = '../logs'

local function ensureLogsDir(logsDir)
    logsDir = logsDir or "logs"
    local ok, stat = pcall(fs.statSync, logsDir)
    if ok and stat and stat.type == "directory" then
        return true
    end

    local ok2, err = pcall(function()
        fs.mkdirSync(logsDir)
    end)
    if ok2 then return true end

    if fs.mkdir then
        fs.mkdir(logsDir, function(err)
        end)
        return true
    end

    return false
end

local function statTimestamp(stat)
    local t = stat and (stat.birthtime or stat.mtime or stat.ctime)
    if type(t) == "table" and t.sec then
        t = t.sec
    end
    if type(t) ~= "number" then t = os.time() end
    return os.date("%Y-%m-%d_%H-%M-%S", t)
end

local function rotateLatest(latestPath, logsDir)
    logsDir = logsDir or "logs"
    local destName

    local ok, statOrErr = pcall(fs.statSync, latestPath)
    if ok and statOrErr then
        local ts = statTimestamp(statOrErr)
        destName = path.join(logsDir, ("log_%s.log"):format(ts))
        local ok2, err2 = pcall(fs.renameSync, latestPath, destName)
        if ok2 then return true, destName end
    end

    if fs.stat and fs.rename then
        local finished = false
        local success, errmsg
        fs.stat(latestPath, function(statErr, stat)
            if not statErr and stat then
                local ts = statTimestamp(stat)
                destName = path.join(logsDir, ("log_%s.log"):format(ts))
                fs.rename(latestPath, destName, function(renameErr)
                    success = not renameErr
                    errmsg = renameErr
                    finished = true
                end)
            else
                success = false
                errmsg = statErr
                finished = true
            end
        end)
        return false, errmsg
    end

    return false, "no suitable fs.rename/stat available"
end

local function openLatest(latestPath)
    latestPath = latestPath or path.join("logs", "latest.log")

    local file, err
    file, err = io.open(latestPath, "a")
    if not file then
        if fs.openSync and fs.writeSync and fs.closeSync then
            local ok, fdOrErr = pcall(fs.openSync, latestPath, "a")
            if ok and fdOrErr then
                local fd = fdOrErr
                local wrapper = {}
                function wrapper:write(s)
                    fs.writeSync(fd, tostring(s))
                end
                function wrapper:flush()
                end
                function wrapper:close()
                    fs.closeSync(fd)
                end
                return wrapper
            end
        end
        return nil, err
    end

    local wrapper = {}
    function wrapper:write(s)
        file:write(s)
    end
    function wrapper:flush()
        if file.flush then
            pcall(file.flush, file)
        else
            pcall(function() io.flush() end)
        end
    end
    function wrapper:close()
        pcall(file.close, file)
    end

    return wrapper
end

local function initLogging()
    local logsDir = "logs"
    ensureLogsDir(logsDir)

    local latestPath = path.join(logsDir, "latest.log")

    local exists = false
    local okStat, statOrErr = pcall(fs.statSync, latestPath)
    if okStat and statOrErr then
        exists = true
    else
        if fs.stat then
            fs.stat(latestPath, function(statErr, stat)
                if not statErr and stat and fs.rename then
                    local ts = statTimestamp(stat)
                    local destName = path.join(logsDir, ("log_%s.log"):format(ts))
                    fs.rename(latestPath, destName, function() end)
                end
            end)
        end
    end

    if exists then
        local okRotate, destOrErr = rotateLatest(latestPath, logsDir)
    end

    local fh, ferr = openLatest(latestPath)
    if fh then
        niko._logHandle = fh
    else
        niko._logHandle = nil
        print(("[Niko] Warning: could not open log file '%s' for append: %s"):format(latestPath, tostring(ferr)))
    end
end

initLogging()

--[[ Log stuff:
message The message you want to log.
part Some usefull peace of data.
messageType usefull peace of data.
priority numeric priority where lower numbers are quieter
]]
function niko:Log(message, part, messageType, priority)
    local prt = part
    local mType = messageType
    local pr = priority

    if type(mType) == "number" and pr == nil then
        pr = mType
        mType = 'INFO'
    end
    if type(prt) == "number" and pr == nil then
        pr = prt
        prt = nil
    end

    pr = tonumber(pr) or 0

    local tmpl = (self.Templates and self.Templates[self.useTemplate]) or self.Templates["Default"]
    if not tmpl then
        tmpl = self.Templates["Default"]
    end

    if pr < (self.minPriority or 0) then
        return
    end

    local formattedStr = tmpl(message, prt, mType)
    print(formattedStr)

    local fh = self._logHandle
    if fh then
        local ok, err = pcall(function()
            fh:write(formattedStr .. "\n")
            if fh.flush then fh:flush() end
        end)
        if not ok then
            pcall(function() fh:close() end)
            self._logHandle = nil
            print("[Niko] Warning: failed to write to log file, disabled file logging: " .. tostring(err))
        end
    end
end

function niko:Close()
    if self._logHandle then
        pcall(function() self._logHandle:close() end)
        self._logHandle = nil
    end
end

return niko
