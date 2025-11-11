local event = {}

function event.new(separateFireFunction)
    local self = {}
    local connections = {}
    local secCode = ""

    local function fire(...)
        
        local args = {...}

        for i=1, #connections do
            local connection = connections[i]
            local func = connection.f
            local disconnectOnFire = connection.disconnectOnFire

            local success, err = pcall(function()
                func(table.unpack(args))
            end)
            if not success then
                print(err)
            end
            if disconnectOnFire then
                connection:Disconnect()
            end
        end
    end


    function self:Fire(...)
        fire(...)
    end

    function self:Connect(func)
        local connection = {}
        connection.f = func
        
        table.insert(connections, connection)
        
        function connection:Disconnect()
            for i=1, #connections do
                if connections[i] == connection then
                    table.remove(connections, i)
                end
            end
        end

        return connection
    end

    function self:ConnectOnce(func)
         local connection = {}
        connection.f = func
        connection.disconnectOnFire = true
        
        table.insert(connections, connection)
        
        function connection:Disconnect()
            for i=1, #connections do
                if connections[i] == connection then
                    table.remove(connections, i)
                end
            end
        end

        return connection
    end

    if separateFireFunction then
        self.Fire = nil
    end

    return self, (separateFireFunction and fire)
end

return event