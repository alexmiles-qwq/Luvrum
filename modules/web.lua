local http = require('http')
local url = require('url')
local querystring = require('querystring')
local fs = require('fs')
local path = require('path')
local json = require('json')

local adminRolesList = {1}
local function isAdmin(user)
    local roles = user.roles

    local admin = false
    for _, id in ipairs(roles) do  
        local role = core.getRoleById(id)
        if not role then
            goto continue
        end

        for _, id2 in ipairs(adminRolesList) do
            -- print("Admin roles check:",id, id2, id2 == id)
            
            if id2 == id then
                admin = true
                break
            end
        end

        ::continue::
    end

    return admin
end

local web = {}
web.port = 80
web.rateLimit = {}
web.rateLimit.maxRequestsPerSec = 5
web.rateLimit.ips = {}
web.rateLimit.requests = {}
web.rateLimit.rateLimitTimer = 60 * 10

local blacklistedIPs = {}
--table.insert(blacklistedIPs, '127.0.0.1')

local events = {}


local function createEvent(t, name)
    local event, fireFunc = event.new(true)

    if not events[t] then
        events[t] = {}
    end

    events[t][name] = event

    return fireFunc, event
end

local function escapeHtml(s)
    if not s then return '' end
    s = tostring(s)
    s = s:gsub("&", "&amp;")
    s = s:gsub("<", "&lt;")
    s = s:gsub(">", "&gt;")
    s = s:gsub('"', "&quot;")
    s = s:gsub("'", "&#39;")
    return s
end

local function fof(req, res, err)
    
    res.statusCode = 404
    res:finish('404: Not found: '..((err .. '.') or 'Unknown.'))

end

local function blacklisted(res)
    
    res:finish("You've been blacklisted!")

end

local function isIpBlacklisted(ip)
    for i=1, #blacklistedIPs do
        local p = blacklistedIPs[i]
        if p == ip then return true end
    end
end

local function addIpToBlacklist(ip)
    table.insert(blacklistedIPs, ip)
end

local function removeIpToBlacklist(ip)
    for i=1, #blacklistedIPs do
        local p = blacklistedIPs[i]
        table.remove(blacklistedIPs, i)
    end 
end

local function rateLimitHandler(req, res)
    local now = os.time()
    
    if req and res then
        local found = false
        for _, ip in ipairs(web.rateLimit.ips) do
            if ip == req.socket:address().ip then   
                res:finish("You've been rate limited. Try again in a few minutes")
                return true
            end
        end

        local request = {}
        request.ip = req.socket:address().ip
        request.timestamp = now
        table.insert(web.rateLimit.requests, request)
    end

    local temp = {}

for i, request in pairs(web.rateLimit.requests) do
        local ip = request.ip
        
        if not temp[ip] then
            temp[ip] = 0
        end
        temp[ip] = temp[ip] + 1

        if request.timestamp < now then            -- outdated
            table.remove(web.rateLimit.requests, i)
        end
end

    
end

local function returnMimeByExt(pt)
    local ext = path.extname(pt):sub(2)
    
    local mime = enum.contentType[ext]
    return mime
end

local onServerReqFire = createEvent('server', 'onServerReq')

local handler = function(req, res, body)
    local ip = req.socket:address().ip
    
    local parsed = url.parse(req.url)
    local parsedQuery = (parsed.query and querystring.parse(parsed.query)) or {}

    local cookies = cookie.parse(req.headers.cookie)
    local token = cookies.token

    local tokenUser = core.getUserByToken(token)
    local userIsAdmin = tokenUser and isAdmin(tokenUser)
    print(token, tokenUser)


    if parsed.pathname == '/test' then
        if not token then
            res:finish('Log in first.')
            return
        end
        
        local basePath = './storage/assets'
        local assetName = parsedQuery.name
        local assetContent = fs.readFileSync(path.join(basePath, assetName))
        
        local mime = returnMimeByExt(path.join(basePath, assetName))
        res:setHeader('Content-Type', mime)

        if not assetContent then
            res.statusCode = 404
            res:finish('Not found.')
            return
        end

        res:finish(assetContent)
    elseif parsed.pathname == '/' then
        res:finish('Welcome to the home page!')
    elseif parsed.pathname == '/users' then
        
    local id = parsedQuery and parsedQuery.id and tonumber(parsedQuery.id)
    local user = core.getUserById(id)

    if not user then
            fof(req, res, 'No such user')
            return
    end

    res:setHeader('Content-Type', enum.contentType.json)
    res:finish(json.encode(user))
    
    return
    elseif parsed.pathname == '/register' then
        
        local username = parsedQuery.u
        local password = parsedQuery.p

        if not username or not password then
            res:finish('Error: username or password is empty')
            return
        end

        local s, err = pcall(function()
            core.registerUser(username, password)
        end)

        if not s then
            res:finish('Error: '..tostring(err))
            return
        end

        res:finish('Done!')
        return


    elseif parsed.pathname == '/login' then
        
        if token then
            res:finish('ERROR: '..'log out first in order to login.')
            return
        end

        local username = parsedQuery.u
        local password = parsedQuery.p

        local s, user = pcall(function()
            return core.getUserByUsername(username)
        end)

        if not s then
            res:finish('ERROR: '..user)
            return
        end   

        local token, err = core.loginUser(username, password, req, res)
        if not token then
            res:finish('ERROR: '..err)
            return
        end

        -- cookies
        local c = cookie.serialize('token', tostring(token), {
            httpOnly = true,
            path = "/",
            maxAge = 3600,
            sameSite = "Lax"
        })
        
        res:setHeader('Set-Cookie', c)
        res:finish('Done!')

    elseif parsed.pathname == '/logout' then
        if token or tokenUser then
            core.logoutUser(token)

            local clearHeader = cookie.serialize("token", "", {
                path = "/",
                maxAge = 0,  
                httpOnly = true
            })

            res:setHeader('Set-Cookie', clearHeader)
            res:finish('Done')
            return
        end
        
        res:finish('ERROR: Youre not logged in.')
    elseif parsed.pathname == '/me' then
        if not tokenUser then
            res:finish('Log in first')
            return
        end
        
        local roles = tokenUser and tokenUser.roles or {}
        local message = ""

        if not token then
            res:finish('Log in first')
            return
        end

        local rolesStr = ''

        for _, roleid in ipairs(roles) do
            local role = core.getRoleById(roleid)
            local name = role.name
            rolesStr = rolesStr .. name ..', '
        end

        if rolesStr == '' then
            rolesStr = 'No roles'
        else
            rolesStr = rolesStr:sub(1, #rolesStr - 2)
        end


        message = message .. 'Welcome, '..tokenUser.username .. '!\n'
        message = message .. 'Your roles: ' .. rolesStr

        res:finish(message)

    elseif parsed.pathname == '/admin' then
        if not userIsAdmin or not tokenUser then
            fof(req, res, 'No such page')
            return
        end

        res:finish('You are an admin! Yay!')
    else
        fof(req, res, 'No such page')
    end


end

local routes = {}

local function addRoute(path, mainFunc, requireAuth, onNotAuth)
    if routes[path] then
        error('This route is already exist')
    end

    if requireAuth == nil then
        requireAuth = true
    end

    local self = {}
    self.requireAuth = requireAuth
    self.onNotAuth = function(req, res) res:finish('ERROR: Youre not logged in.') end
    self.main = mainFunc

    routes[path] = self
    return self
end

local function removeRoute(path)
    if not routes[path] then
        error('This route does not exist')
    end

    routes[path] = nil
end

local homeRoute = addRoute('/', function(req, res, body, parsed, parsedQuery, tokenUser)
    res:finish('Welcome to the home page!')
end, false, nil)

local usersRoute = addRoute('/users', function(req, res, body, parsed, parsedQuery, tokenUser)
    local id = parsedQuery and parsedQuery.id and tonumber(parsedQuery.id)
    local user = core.getUserById(id)

    if not user then
        fof(req, res, 'No such user')
        return
    end

    res:setHeader('Content-Type', enum.contentType.json)
    res:finish(json.encode(user))
    
    return
end, false, nil)

local registerRoute = addRoute('/register', function(req, res, body, parsed, parsedQuery, tokenUser)
     
    local username = parsedQuery.u
    local password = parsedQuery.p

    if not username or not password then
        res:finish('Error: username or password is empty')
        return
    end

    local s, err = core.registerUser(username, password)


    if not s then
        res:finish('Error: '..tostring(err))
        return
    end

    res:finish('Done!')
    return
end, false, nil)

local loginRoute = addRoute('/login', function(req, res, body, parsed, parsedQuery, tokenUser)
    
    if tokenUser then
        res:finish('ERROR: '..'log out first in order to login.')
        return
    end

    local username = parsedQuery.u
    local password = parsedQuery.p

    local user = core.getUserByUsername(username)
    if not user then
        res:finish('ERROR: '..'User does not exist.')
        return
    end   

    local token, err = core.loginUser(username, password, req, res)
    if not token then
        res:finish('ERROR: '..err)
        return
    end

    -- cookies
    local c = cookie.serialize('token', tostring(token), {
        httpOnly = true,
        path = "/",
        maxAge = 3600,
        sameSite = "Lax"
    })
    
    res:setHeader('Set-Cookie', c)
    res:finish('Done!')
end, false, nil)

local logoutRoute = addRoute('/logout', function(req, res, body, parsed, parsedQuery, tokenUser)
    core.logoutUser(tokenUser.token)

    local clearHeader = cookie.serialize("token", "", {
        path = "/",
        maxAge = 0,  
        httpOnly = true
    })

    res:setHeader('Set-Cookie', clearHeader)
    res:finish('Done')

end, true)

local meRoute = addRoute('/me', function(req, res, body, parsed, parsedQuery, tokenUser)
    local roles = tokenUser and tokenUser.roles or {}
    local message = ""

    local rolesStr = ''

    for _, roleid in ipairs(roles) do
        local role = core.getRoleById(roleid)
        local name = role.name
        rolesStr = rolesStr .. name ..', '
    end

    if rolesStr == '' then
        rolesStr = 'No roles'
    else
        rolesStr = rolesStr:sub(1, #rolesStr - 2)
    end


    message = message .. 'Welcome, '..tokenUser.displayName .. '!\n'
    message = message .. 'Your roles: ' .. rolesStr
    message = message .. '\nYour Bio: '.. (tokenUser.description or 'empty')

    res:finish(message)

end, true, function(req, res)
    res:finish('Log in in order to see your info.')
end)

local freeRoleRoute = addRoute('/freerole', function(req, res, body, parsed, parsedQuery, tokenUser)

    local hasRole = core.returnUserHasRole(2, tokenUser.userid)
    if not hasRole then
        core.addRoleToUser(2, tokenUser.userid)
        res:finish('You got a free role, yppie!!')
    else
        res:finish('You already have a free role.')
    end
end, true, nil)

local funnyRoute = addRoute('/funny', function(req, res, body, parsed, parsedQuery, tokenUser)
    local hasRole = core.returnUserHasRole(2, tokenUser.userid)
    if not hasRole then
        res:finish('You dont have a free role.')
        return
    end
    res:finish(':p')
end, true, nil)

local funnyRoute = addRoute('/edit', function(req, res, body, parsed, parsedQuery, tokenUser)

    local displayName = parsedQuery.displayName
    local description = parsedQuery.description

    if displayName then
        tokenUser.displayName = displayName
    end

    if description then
        tokenUser.description = description
    end
    res:finish('Done')
end, true, nil)

local userPageRoute = addRoute('/user', function(req, res, body, parsed, parsedQuery, tokenUser)
    -- parsedQuery can contain id or username
    local id = parsedQuery and parsedQuery.id and tonumber(parsedQuery.id)
    local username = parsedQuery and parsedQuery.username

    local targetUser = nil

    -- try id lookup first
    if id then
        local ok, u = pcall(function() return core.getUserById(id) end)
        if ok then targetUser = u end
    end

    -- if no id or not found, and username provided, try username lookup if available
    if not targetUser and username then
        if core.getUserByUsername then
            local ok, u = pcall(function() return core.getUserByUsername(username) end)
            if ok then targetUser = u end
        end
    end

    -- if still not found, try parsedQuery.id as string username fallback (someone passed ?id=username)
    if not targetUser and parsedQuery and parsedQuery.id and not tonumber(parsedQuery.id) then
        local maybeName = parsedQuery.id
        if core.getUserByUsername then
            local ok, u = pcall(function() return core.getUserByUsername(maybeName) end)
            if ok then targetUser = u end
        end
    end

    if not targetUser then
        res.statusCode = 404
        res:setHeader('Content-Type', 'text/plain')
        res:finish('User not found')
        return
    end

    -- If the user is banned, show ban info
    if targetUser.banned then
        res.statusCode = 403
        res:setHeader('Content-Type', 'text/html')
        local htmlBan = ([[<!doctype html>
<html>
<head><meta charset="utf-8"><title>%s — Banned</title></head>
<body>
  <h1>%s</h1>
  <p><strong>Status:</strong> BANNED</p>
  <p><strong>Reason:</strong> %s</p>
</body>
</html>]]):format(
            escapeHtml(targetUser.displayName or targetUser.username or "User"),
            escapeHtml(targetUser.displayName or targetUser.username or "User"),
            escapeHtml(targetUser.banReason or "No reason provided"))
        res:finish(htmlBan)
        return
    end

    -- build roles (if roles is a list of ids, try to look them up; otherwise show raw)
    local roleHtml = ""
    if type(targetUser.roles) == "table" and #targetUser.roles > 0 then
        local parts = {}
        for _, rid in ipairs(targetUser.roles) do
            local roleLabel = tostring(rid)
            if core.getRoleById then
                local ok, role = pcall(function() return core.getRoleById(rid) end)
                if ok and role and role.name then roleLabel = role.name end
            end
            table.insert(parts, "<li>" .. escapeHtml(roleLabel) .. "</li>")
        end
        roleHtml = "<ul>" .. table.concat(parts, "\n") .. "</ul>"
    else
        roleHtml = "<em>No roles</em>"
    end

    -- build posts list (try to resolve title if helper exists)
    local postsHtml = ""
    if type(targetUser.posts) == "table" and #targetUser.posts > 0 then
        local parts = {}
        for _, pid in ipairs(targetUser.posts) do
            local label = tostring(pid)
            if core.getPostById then
                local ok, post = pcall(function() return core.getPostById(pid) end)
                if ok and post and post.title then label = post.title end
            end
            local safeLabel = escapeHtml(label)
            table.insert(parts, string.format('<li><a href="/post?id=%s">%s</a></li>', escapeHtml(pid), safeLabel))
        end
        postsHtml = "<ul>" .. table.concat(parts, "\n") .. "</ul>"
    else
        postsHtml = "<em>No posts</em>"
    end

    -- build threads list
    local threadsHtml = ""
    if type(targetUser.threads) == "table" and #targetUser.threads > 0 then
        local parts = {}
        for _, tid in ipairs(targetUser.threads) do
            local label = tostring(tid)
            if core.getThreadById then
                local ok, thread = pcall(function() return core.getThreadById(tid) end)
                if ok and thread and thread.title then label = thread.title end
            end
            local safeLabel = escapeHtml(label)
            table.insert(parts, string.format('<li><a href="/thread?id=%s">%s</a></li>', escapeHtml(tid), safeLabel))
        end
        threadsHtml = "<ul>" .. table.concat(parts, "\n") .. "</ul>"
    else
        threadsHtml = "<em>No threads</em>"
    end

    -- avatar, banner, background with fallbacks
    local avatarUrl = targetUser.avatar and #targetUser.avatar > 0 and escapeHtml(targetUser.avatar) or nil
    local bannerUrl = targetUser.banner and #targetUser.banner > 0 and escapeHtml(targetUser.banner) or nil
    local backgroundUrl = targetUser.background and #targetUser.background > 0 and escapeHtml(targetUser.background) or nil
    local blurBackground = (targetUser.blurBackground == true) or (tonumber(targetUser.blurBackground) == 1) or false

    -- small last-login / timestamp formatting
    local createdAt = targetUser.timestamp and os.date("%Y-%m-%d %H:%M:%S", targetUser.timestamp) or "Unknown"

    -- Whether this viewer is the same user
    local isOwner = false
    if tokenUser and targetUser.userid and tokenUser.userid then
        isOwner = (tonumber(tokenUser.userid) == tonumber(targetUser.userid))
    end

    -- Build HTML
    res:setHeader('Content-Type', 'text/html; charset=utf-8')
    local html = {}
    table.insert(html, "<!doctype html>")
    table.insert(html, "<html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>")
    table.insert(html, ("<title>%s — Profile</title>"):format(escapeHtml(targetUser.displayName or targetUser.username or "User")))
    -- minimal inline CSS including background handling
    table.insert(html, [[
<style>
html,body { height:100%; margin:0; padding:0; }
body { font-family: Arial, Helvetica, sans-serif; background:#f7f7f7; color:#222; }
.page-bg {
  position:fixed; inset:0; z-index:0;
  background-position:center; background-size:cover; background-repeat:no-repeat;
  filter: none; transform: translateZ(0);
}
.page-bg--blur { filter: blur(12px) saturate(1.05); -webkit-filter: blur(12px) saturate(1.05); }
.page-bg--dim { background-color: rgba(0,0,0,0.35); mix-blend-mode:multiply; }
.header { position:relative; z-index:2; padding:20px; background:rgba(255,255,255,0.85); box-shadow:0 1px 0 rgba(0,0,0,0.05); }
.container { position:relative; z-index:2; max-width:900px; margin:20px auto; background:rgba(255,255,255,0.75); border-radius:6px; overflow:hidden; }
.banner { width:100%; height:180px; object-fit:cover; background:#ddd; display:block; }
.profile { display:flex; gap:20px; padding:20px; align-items:flex-start; }
.avatar { width:120px; height:120px; border-radius:8px; object-fit:cover; background:#e6e6e6; border:1px solid #ddd; }
.meta { flex:1; }
.meta h1 { margin:0 0 6px 0; font-size:22px; }
.meta p.lead { margin:0 0 12px 0; color:#666; }
.section { padding:20px; border-top:1px solid #eee; }
.small { color:#777; font-size:13px; }
a.button { display:inline-block; padding:8px 12px; border-radius:6px; text-decoration:none; border:1px solid #bbb; background:#fff; color:#222; margin-right:8px; }
</style>
]])
    table.insert(html, "</head><body>")

    -- full-page background (if provided)
    if backgroundUrl then
        -- create a wrapper div for background. When blurBackground is true, add blur class; also add a dim overlay for contrast
        local bgClasses = "page-bg"
        if blurBackground then bgClasses = bgClasses .. " page-bg--blur" end
        table.insert(html, ("<div class='%s' style=\"background-image:url('%s')\"></div>"):format(bgClasses, backgroundUrl))
        -- dim overlay element (semi-transparent) to improve readability
        table.insert(html, "<div style='position:fixed;inset:0;z-index:1;background:rgba(255,255,255,0.22)'></div>")
    end

    table.insert(html, "<div class='header'><div style='max-width:900px;margin:0 auto;display:flex;align-items:center;justify-content:space-between'><div><strong>Site</strong></div></div></div>")
    table.insert(html, "<div class='container'>")

    if bannerUrl then
        table.insert(html, ("<img class='banner' src='%s' alt='Banner' />"):format(bannerUrl))
    end

    table.insert(html, "<div class='profile'>")
    if avatarUrl then
        table.insert(html, ("<img class='avatar' src='%s' alt='Avatar' />"):format(avatarUrl))
    else
        table.insert(html, "<div class='avatar' style='display:flex;align-items:center;justify-content:center;font-weight:bold;color:#888'>N/A</div>")
    end

    table.insert(html, "<div class='meta'>")
    table.insert(html, ("<h1>%s</h1>"):format(escapeHtml(targetUser.displayName or targetUser.username)))
    table.insert(html, ("<p class='lead'>@%s</p>"):format(escapeHtml(targetUser.username or "")))
    table.insert(html, ("<p class='small'>Joined: %s</p>"):format(escapeHtml(createdAt)))
    if isOwner then
        table.insert(html, "<p><a class='button' href='/settings'>Edit profile</a><a class='button' href='/logout'>Logout</a></p>")
    else
        if tokenUser then
            table.insert(html, "<p><a class='button' href='/message?to=" .. escapeHtml(targetUser.userid) .. "'>Send message</a></p>")
        else
            table.insert(html, "<p><a class='button' href='/login'>Login to interact</a></p>")
        end
    end
    table.insert(html, "</div>") -- meta
    table.insert(html, "</div>") -- profile

    -- description
    table.insert(html, ("<div class='section'><h3>About</h3><p>%s</p></div>"):format(escapeHtml(targetUser.description or "<em>No description</em>")))

    -- roles
    table.insert(html, ("<div class='section'><h3>Roles</h3>%s</div>"):format(roleHtml))

    -- posts & threads columns
    table.insert(html, "<div class='section'><div style='display:flex;gap:40px'>")
    table.insert(html, ("<div style='flex:1'><h4>Threads</h4>%s</div>"):format(threadsHtml))
    table.insert(html, ("<div style='flex:1'><h4>Posts</h4>%s</div>"):format(postsHtml))
    table.insert(html, "</div></div>")

    table.insert(html, "</div>") -- container
    table.insert(html, "</body></html>")

    res:finish(table.concat(html, "\n"))
end, false, nil)

local testRoute = addRoute('/test', function(req, res, body, parsed, parsedQuery, tokenUser)
    
    local html = tostring(fs.readFileSync('./storage/web/profile.html'))
    local username = tokenUser.username
    local banner = tokenUser.banner
    local avatar = tokenUser.avatar
    local timestamp = tokenUser.timestamp
    local bio = tokenUser.description
    local background = tokenUser.background


   local fixed  = string.format(html, username or 'Unknown', background, banner, avatar, displayName, username, tostring(timestamp), bio)

    res:finish(tostring(fixed))

end, true, nil)

local function handler2(req, res, body)
    
    local ip = req.socket:address().ip
    
    local parsed = url.parse(req.url)
    local parsedQuery = (parsed.query and querystring.parse(parsed.query)) or {}

    local cookies = cookie.parse(req.headers.cookie)
    local token = cookies.token

    local tokenUser = core.getUserByToken(token)
    local userIsAdmin = tokenUser and isAdmin(tokenUser)

    local route = routes[parsed.pathname]

    if not route then fof(req, res, 'No such page') return end
    if (not tokenUser and route.requireAuth) then route.onNotAuth(req, res, body, parsed, parsedQuery) return end

    route.main(req, res, body, parsed, parsedQuery, tokenUser)

    return
end

web.handler = handler
web.events = events
web.isIpBlacklisted = isIpBlacklisted
web.fof = fof

local server = http.createServer(function(req, res)
    
    local body = ""

    local ip = req.socket:address().ip

    local ipBL = isIpBlacklisted(ip)
    if ipBL then
        res:setHeader('Content-Type', 'text/plain')
        res:finish('Youve been blacklisted')
        return
    end
    local rateLimited = rateLimitHandler(req, res)
    if rateLimited then return end

    req:on('data', function(chunk)
        body = body .. chunk
    end)

    req:on('end', function()
        handler2(req, res, body)
    end)

    onServerReqFire(req)

end):listen(web.port)


return web 