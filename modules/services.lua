local servicesModule = {}
local services = {}


local function NewService(servicename, methods)
    do
        if type(servicename) ~= 'string' then
            error('arg #1: string expected, got '..type(servicename), 2)
        end

        if type(methods) ~= 'table' then
            error('arg #1: table expected, got '..type(methods), 2)
        end

        if services[servicename] then
            error('Such service is already exist')
        end
    end

    local self = {}

    for method, func in pairs(methods) do
        self[method] = func
    end

    services[servicename] = self
end

local function RemoveSevice(servicename)
    do
        if type(servicename) ~= 'string' then
            error('arg #1: string expected, got '..type(servicename), 2)
        end

        if type(methods) ~= 'table' then
            error('arg #1: table expected, got '..type(methods), 2)
        end

        if not services[servicename] then
            error('Service ' .. tostring(servicename) .. ' does not exist', 2)
        end
    end

    services[servicename] = nil

end

local function GetService(servicename)
    do
        if type(servicename) ~= 'string' then
            error('arg #1: string expected, got '..type(servicename), 2)
        end

        if not services[servicename] then
            error('Service ' .. tostring(servicename) .. ' does not exist', 2)
        end
    end

    return services[servicename]
end

local function ModifyMethodsOfService(servicename, methods)
    do
        if type(servicename) ~= 'string' then
            error('arg #1: string expected, got '..type(servicename), 2)
        end

        if type(methods) ~= 'table' then
            error('arg #1: table expected, got '..type(methods), 2)
        end

        if not services[servicename] then
            error('Service ' .. tostring(servicename) .. ' does not exist', 2)
        end
    end

    local self = services[servicename]

    for method, func in pairs(methods) do
        self[method] = func
    end
    
end


servicesModule.NewService = NewService
servicesModule.RemoveSevice = RemoveSevice
servicesModule.ModifyMethodsOfService = ModifyMethodsOfService
servicesModule.GetService = GetService


return servicesModule
