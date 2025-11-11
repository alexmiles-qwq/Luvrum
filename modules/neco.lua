--[[

    Neco - Plugin manager

]]

local pluginsFolder = './plugins/'
local path = require('path')
local fs = require('fs')

local neco = {}
local plugins = {}

local onPluginLoaded, oplFire = event.new(true)
local onAllPluginsLoaded, naplFire = event.new(true)

neco.events = {}
neco.events.onPluginLoaded = onPluginLoaded
neco.events.onAllPluginsLoaded = onAllPluginsLoaded

local function log(level, ...)
    if _G.niko and type(_G.niko.Log) == 'function' then
        -- niko:Log(message, source, levelStr, verbosity)
        local msg = table.concat({...}, ' ')
        _G.niko:Log(msg, 'Neco', level, 2)
    else
        print('[' .. tostring(level) .. ']', ...)
    end
end

local allowed_requires = {
    json = true,
    fs = true, 
    path = true,

}

local function makeSandboxEnv(plugin_name)
    local orig_require = require
    local function safe_require(name)
        if allowed_requires[name] then
            return orig_require(name)
        else
            for k, plugin in pairs(plugins) do
                if plugin.name == name then
                    return plugin.module
                end
            end
        end
       return nil
    end

    -- Minimal safe environment
    local env = {
        assert = assert,
        error = error,
        ipairs = ipairs,
        next = next,
        pairs = pairs,
        pcall = pcall,
        select = select,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        unpack = unpack or table.unpack,
        xpcall = xpcall,
        core = _G.core,
        niko = _G.niko,

        math = math,
        string = string,
        table = table,
        coroutine = coroutine,

        require = safe_require,
        web = {events = web.events, handler = nil, isIpBlacklisted = web.isIpBlacklisted},
        ansi = ansi,
        utf8 = utf8,
        event = event,
        io = {write = io.write, flush = io.flush},

        print = function(...)
            local args = {...}

            local msg = table.concat(args, ' ')
            niko:Log(msg, plugin_name, 'PLUGIN', 2)
            
        end,
        neco = {events = neco.events}
    }

    -- setmetatable(env, { __index = _G })
    return env
end

local function loadSandboxedChunk(filePath, sandbox_env)
    local ok, content = pcall(function()
        return fs.readFileSync(filePath, "utf8")
    end)
    if not ok then
        return nil, ("Cannot read %s: %s"):format(filePath, tostring(content))
    end

    local fn, err = loadstring(content, filePath)
    if not fn then
        return nil, ("Compile error in %s: %s"):format(filePath, tostring(err))
    end

    if setfenv then
        setfenv(fn, sandbox_env)
    end

    return fn
end

function neco:LoadPlugin(name)
    if not name or type(name) ~= 'string' then
        error('LoadPlugin: name must be a string')
    end

    local pluginPath = path.join(pluginsFolder, name)
    local initPath = path.join(pluginPath, 'init.lua')
    local mainPath = path.join(pluginPath, 'main.lua')

    if not fs.existsSync(pluginPath) then
        error('Plugin '..name..' does not exist.')
    end

    if not fs.existsSync(initPath) then
        error('Plugin '..name..' is corrupted: init.lua does not exist.')
    end

    if not fs.existsSync(mainPath) then
        error('Plugin '..name..' is corrupted: main.lua does not exist.')
    end

    local sandbox = makeSandboxEnv(name)

    -- Load and run init.lua (should return info table)
    local init_fn, err = loadSandboxedChunk(initPath, sandbox)
    if not init_fn then
        log('ERROR', 'Failed to load init.lua for plugin', name, ':', err)
        return nil, err
    end

    local ok, info_or_err = pcall(init_fn)
    if not ok then
        log('ERROR', ('Runtime error in init.lua for plugin %s: %s'):format(name, tostring(info_or_err)))
        return nil, info_or_err
    end

    local info = info_or_err
    if type(info) ~= 'table' then
        log('WARN', ('init.lua for plugin %s did not return a table. Using minimal info.'):format(name))
        info = { name = name }
    end

    local pluginNameForLog = info.name or name
    log('INFO', 'Loading plugin ' .. pluginNameForLog .. ' ver ' .. (info.version or 'unknown'))

    -- Load main.lua
    local main_fn, merr = loadSandboxedChunk(mainPath, sandbox)
    if not main_fn then
        log('ERROR', 'Failed to load main.lua for plugin ' .. pluginNameForLog .. ': ' .. tostring(merr))
        return nil, merr
    end

    local ok2, module_or_err = pcall(main_fn)
    if not ok2 then
        log('ERROR', ('An error occurred while executing main.lua for plugin %s: %s'):format(pluginNameForLog, tostring(module_or_err)))
        return nil, module_or_err
    end

    local pluginModule = module_or_err

    local plug = {
        name = info.name or name,
        module = pluginModule,
        meta = info,
        path = pluginPath,
    }

    table.insert(plugins, plug)

    oplFire(info, pluginModule, plug)

    return plug
end

function neco:LoadAllPlugins()
    local entries = fs.readdirSync(pluginsFolder) or {}

    for _, entry in ipairs(entries) do
        local fullPath = path.join(pluginsFolder, entry)
        local stat = fs.statSync(fullPath)
        if stat and stat.type == 'directory' then
             --  print("Found folder:", entry)
            local ok, res = pcall(function() return neco:LoadPlugin(entry) end)
            if not ok then
                log('ERROR', ('Failed to load plugin %s: %s'):format(entry, tostring(res)))
            end
        end
    end

    naplFire()
end

function neco:GetLoadedPlugins()
    return plugins
end

function neco:UnloadPlugin(name)
    for i, p in ipairs(plugins) do
        if p.name == name or p.path == path.join(pluginsFolder, name) then
            table.remove(plugins, i)
            if p.module and type(p.module.cleanup) == 'function' then
                p.module.cleanup()
            end
            return true
        end
    end
    return false, 'Plugin not loaded'
end

return neco
