-- Plugin Example

local function logo()
    local strs = {}
    strs[1] = '        .__                 '
    strs[2] = ' ______ |  |  __ __  ____   '
    strs[3] = ' \\____ \\|  | |  |  \\/ ___\\  '
    strs[4] = ' |  |_> >  |_|  |  / /_/  > '
    strs[5] = ' |   __/|____/____/\\___  /  '
    strs[6] = ' |__|             /_____/   '

    io.write('\n')
    io.flush()

    for i=1, 6 do
        print(ansi.gradient(
        ansi.gradientBackground(strs[i], {255, 0, 0}, {0, 0, 255}), 
        {255, 255, 0}, {0,255,255}
            )
        )
    end
    print(ansi.gradientBackground('   Plugin for luvit forum   ', {255, 0, 0}, {0,0,255}).. '\n')
end

local function main()   -- Main function. Its recomended to call main functon on All Plugins Loaded Event Fired.
    
    local TestService = core:getService('TestService')
    local milesApi = require('milesApi')    -- Other pluigns accessable from the require.
    if not milesApi then
        print('ERROR: MilesApi is missing.')
        return
    end

    local webConn = web.events.server.onServerReq:Connect(function(req)
        print('web Request detected!')
    end)
    
    logo()

end


local pluginsLoaded = neco.events.onAllPluginsLoaded:Connect(function()
   main()
end)

