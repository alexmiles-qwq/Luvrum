
local json = require('json')
local fs = require('fs')
local timer = require('timer')
local services = require('./modules/services')

local core = {}
core.version = 2.65

local dbFile = './storage/db/db.json'

local db = {}

db.users = {}
db.categories = {}
db.threads = {}
db.posts = {}

db.nextids = {
    user = 0,
    thread = 0,
    post = 0,
    category = 0,
    roles = 0,
}

db.roles = {}

db.version = 1



local cevents = {}
local function createEvent(t, name)
    local event, fireFunc = event.new(true)

    if not cevents[t] then
        cevents[t] = {}
    end

    cevents[t][name] = event

    return fireFunc, event
end

local sc = function(o)
    return utils.shallowCopy(o)
end

niko:Log('Setting up events.', 'Core', 'INFO', 2)

-- database events
local onDatabaseSavedFire = createEvent('database', 'onSaved')
local onDatabaseLoadedFire = createEvent('database', 'onLoaded')

-- users events
local onUserRegisteredFire = createEvent('users', 'onRegistered')
local onUserLogInFire = createEvent('users', 'onLogIn')
local onUserBannedFire = createEvent('users', 'onBanned')
local onUserPassworChangedFire = createEvent('users', 'onPassworChanged')
local onUserRoleAddedFire = createEvent('users', 'onRoleAdded')
local onUserRoleRemovedFire = createEvent('users', 'onRoleRemoved')

-- category
local onCategoryCreatedFire = createEvent('categories', 'onCreated')
local onCategoryBannedFire = createEvent('categories', 'onBanned')

-- threads
local onThreadCreatedFire = createEvent('threads', 'onCreated')
local onThreadBannedFire = createEvent('threads', 'onBanned')

-- posts
local onPostCreatedFire = createEvent('posts', 'onCreated')
local onPostBannedFire = createEvent('posts', 'onBanned')

-- roles
local onRoleCreatedFire = createEvent('roles', 'onCreated')


local function saveDB()
    fs.writeFile(dbFile, json.encode(db), function(err)
        onDatabaseSavedFire(err)
    end)
end

-- Multiple token support (and migration ??)
local function loadDB()
    local content = fs.readFileSync(dbFile)
    if content then
        db = json.decode(content)

        if db and db.users then
            for _, user in ipairs(db.users) do
                if user.token and (type(user.tokens) ~= "table" or #user.tokens == 0) then
                    user.tokens = {
                        {
                            token = user.token,
                            issuedAt = user.timestamp or os.time(),
                            ip = user.lastLoginIP or 'unknown',
                            device = user.lastLoginUA or 'unknown'
                        }
                    }
                    user.token = nil
                end

                if type(user.tokens) == "table" then
                    for i = #user.tokens, 1, -1 do
                        if type(user.tokens[i]) == "string" then
                            local oldTok = user.tokens[i]
                            user.tokens[i] = {
                                token = oldTok,
                                issuedAt = user.timestamp or os.time(),
                                ip = 'unknown',
                                device = 'unknown'
                            }
                        elseif type(user.tokens[i]) ~= "table" then
                            table.remove(user.tokens, i)
                        end
                    end
                else
                    user.tokens = {}
                end
            end
        end
    end

    onDatabaseLoadedFire(content ~= nil)
end



local function generateToken()
    return keygen:GenerateKey()
end

-- createUser now initializes tokens as an empty array (multiple tokens supported)
local function createUser(username, password)
    if type(username) ~= "string" then
        return nil, 'Wrong username type. Expected string, got '..tostring(type(username))
    end

    if type(password) ~= "string" then
        return nil, 'Wrong password type. Expected string, got '..tostring(type(password))
    end

    for _, usr in pairs(db.users) do
        if usr.username == username then
            return nil, 'Same user is already exist.'
        end
    end

    local id = db.nextids.user + 1

    local user = {}
    user.username = username
    user.password = sha2.sha256(password)
    user.tokens = {}         --  multiple tokens
    user.timestamp = os.time()
    user.loginHistory = {}
    user.userid = id
    user.banned = false
    user.banReason = '' -- for moderation
    user.posts = {}     -- ids
    user.threads = {}   -- ids
    user.roles = {}     -- ids
    user.displayName = username
    user.avatar = ''    -- link
    user.banner = ''    -- link
    user.description = ''
    user.background = ''    -- link
    user.blurBackground = true

    table.insert(db.users, user)
    db.nextids.user = id

    onUserRegisteredFire(sc(user))
    return user
end

local function loginUser(username, password, req, res)
    local hash = sha2.sha256(password)

    for k, user in pairs(db.users) do
        if user.username == username then
            local loginHistory = {}
            loginHistory.timestamp = os.time()
            loginHistory.address = (req and req.socket and req.socket.address and req.socket:address().ip) or 'unknown'
            loginHistory.successful = false

            if user.password == hash then
                loginHistory.successful = true
                table.insert(user.loginHistory, loginHistory)

                onUserLogInFire(sc(user))

                local tokenStr = generateToken()
                local tokenRecord = {
                    token = tokenStr,
                    issuedAt = os.time(),
                    ip = (req and req.socket and req.socket.address and req.socket:address().ip) or 'unknown',
                    device = (req and req.headers and (req.headers['user-agent'] or req.headers['User-Agent'])) or 'unknown'
                }

                if type(user.tokens) ~= "table" then user.tokens = {} end

                table.insert(user.tokens, tokenRecord)

                return tokenStr
            else
                table.insert(user.loginHistory, loginHistory)
                return nil, 'Wrong password'
            end
        end
    end

    return nil, 'User not found'
end


local function logoutUser(token)
    if not token then return false end

    for _, user in pairs(db.users) do
        if type(user.tokens) == "table" then
            for i = #user.tokens, 1, -1 do
                if user.tokens[i] and user.tokens[i].token == token then
                    table.remove(user.tokens, i)
                    niko:Log("Token revoked for user: " .. user.username, "Core", "INFO", 2)
                    return true
                end
            end
        end
    end

    return false
end

local function revokeAllTokensForUser(userid)
    local user = core.getUserById(userid)
    if not user then return nil, 'User not found' end
    user.tokens = {}
    return true
end

local function listTokensForUser(userid)
    local user = core.getUserById(userid)
    if not user then return nil, 'User not found' end
    return user.tokens or {}
end

local function revokeToken(token)
    return logoutUser(token)
end


local function getUserByToken(token)
    if not token then return nil end

    for _, user in pairs(db.users) do
        if type(user.tokens) == "table" then
            for _, tokrec in ipairs(user.tokens) do
                if tokrec and tokrec.token == token then
                    return user, tokrec
                end
            end
        end
    end

    return nil
end


local function getUserById(id)
    for k, user in pairs(db.users) do
        -- print(user, user.userid)
        if user.userid == id then
            return user
        end
    end
end

local function getUserByUsername(un)
    for k, user in pairs(db.users) do
        -- print(k, user, user.username)
        if user.username == un then
            return user
        end
    end
end


local function banUser(userid, reason)
    local user = getUserById(userid)
    if not user then
        error('User does not exist.')
    end

    user.banned = true
    user.banReason = reason

    onUserBannedFire(sc(user))
end

local function createRole(name)
    local id = db.nextids.roles  + 1

    for _, role in pairs(db.roles) do
        if role.name == name then
            error('Same role is already exist')
        end
    end

    local role = {}
    role.name = name or 'unknown'
    role.roleid = id
    role.diplayOrder = 1 -- the highest displays first 
    role.hidden = false

    table.insert(db.roles, role)
    db.nextids.roles = id

    onRoleCreatedFire(sc(role))
    return role
end

local function getRoleById(id)

    for i, role in pairs(db.roles) do
        if role.roleid == id then
            return role
        end
    end 
    
end


local function addRoleToUser(roleid, userid)
    local role = getRoleById(roleid)
    local user = getUserById(userid)

    if not role then
        error('Role does not exist')
    elseif not user then
        error('User does not exist')
    end

    for i, rroleid in ipairs(user.roles) do
        if rroleid == roleid then
            error('User already have this role')
        end
    end

    onUserRoleAddedFire(sc(user), sc(role))
    table.insert(user.roles, roleid)
end

local function returnUserHasRole(roleid, userid)
    local role = getRoleById(roleid)
    local user = getUserById(userid)

    if not role then
        error('Role does not exist')
    elseif not user then
        error('User does not exist')
    end

    for i, rroleid in ipairs(user.roles) do
        if rroleid == roleid then
            return true
        end
    end
end

local function removeRoleFromUser(roleid, userid)
    local role = getRoleById(roleid)
    local user = getUserById(userid)

    if not role then
        error('Role does not exist')
    elseif not user then
        error('User does not exist')
    end

    for i, rroleid in ipairs(user.roles) do
        if rroleid == roleid then
            table.remove(user.roles, i)
             onUserRoleAddedFire(sc(user), sc(role))
        end
    end

end

local function createPost(content, user)
   if type(content) ~= "string" then
        return nil, 'Content is not a string.'
   end

   if type(user) ~= "table" then
        return nil, 'User is not a table.'
   end
   
    local id = db.nextids.post + 1
    
    local post = {}
    post.content = content
    post.owner = user.userid
    post.postid = id
    post.timestamp = os.time()
    post.banned = false
    post.banReason = '' -- for moderation
    post.likes = {}    -- ids
    post.dislikes = {}  -- ids

    db.nextids.post = id
    table.insert(db.posts, post)
    table.insert(user.posts, id)

   onPostCreatedFire(sc(post))
    return post
end

local function getPostById(id)

     for k, post in pairs(db.posts) do
        if post.postid == id then
            return post
        end
    end
    
end

local function banPost(id, reason)
    local post = getPostById(id)
    if not post then return nil, 'Post with such id does not exist' end

    post.banned = true
    post.banReason = reason or 'No reason specified.'
    onPostBannedFire(sc(post))
end

local function unbanPost(id)
    local post = getPostById(id)
    if not post then return nil, 'Post with such id does not exist' end

    post.banned = false
    post.banReason = ''
end

local function createThread(title, catid)
    local id = db.nextids.thread + 1
    if not catid then
        error('Category ID is required in order to create thread.')
    end

    local categoryId = 0

    for i, cat in pairs(db.categories) do
        if cat.categoryid == catid then
            categoryId = catid
        end
    end

    if categoryId == 0 then
        error('Category does not exist.')
    end

    for i, thread in pairs(db.threads) do
        if thread.title == title then
            error('Thread with the same name is already exist.')
        end
    end

    local thread = {}
    thread.title = title
    thread.posts = {} -- ids
    thread.threadid = id
    thread.banned = false
    thread.banReason = ''

    db.nextids.thread = id
    table.insert(db.threads, thread)
    
    onThreadCreatedFire(sc(thread))
    return thread
end

local function getThreadById(id)
    for i, thread in pairs(db.threads) do
        if thread.threadid == id then
            return thread
        end
    end
end

local function banThread(id, reason)
    
    local thread = getThreadById(id)
    if not thread then
        error('Thread does not exist.')
    end

    thread.banned = true
    thread.banReason = reason or 'No reason specified.'

    onThreadBannedFire(sc(thread))
end

local function createCategory(name) 
    local id = db.nextids.category + 1

    for i, category in pairs(db.categories) do
        if category.name == name then
            error('Category with the same name is already exist.')
        end
    end

    local cat = {}
    cat.name = name
    cat.threads = {}    -- ids
    cat.banned = false
    cat.categoryid = id
    cat.banReason = ''

    db.nextids.category = id
    table.insert(db.categories, cat)

    onCategoryCreatedFire(sc(cat))
    return cat
end

local function getCategoryById(id)
    for i, category in pairs(db.categories) do
        if category.categoryid == id then
            return category
        end
    end
end

local function banCategory(id, reason)
    local c = getCategoryById(id)
    if not c then
        error('Category does not exist.')
    end

    c.banned = true
    c.banReason = reason or 'No reason specified.'

    onCategoryBannedFire(sc(c))
end

core.events = cevents
core.db = db

core.saveDB = saveDB
core.loadDB = loadDB

loadDB()


-- public stuff
function core.registerUser(username, password)
    return createUser(username, password)
end

function core.loginUser(...)
    return loginUser(...)
end

function core.logoutUser(...)
    return logoutUser(...)
end

function core.getUserByUsername(...)
    return getUserByUsername(...)
end

function core.getUserById(...)
    local user = getUserById(...)
    return user
end

function core.getUserByToken(token)
    return getUserByToken(token)
end

function core.banUser(...)
    return banUser(...)
end

function core.createPost(...)
    return createPost(...)
end

function core.banPost(...)
    return banPost(...)
end

function core.createThread(...)
    return createThread(...)
end

function core.banThread(...)
    return banThread(...)
end

function core.createCategory(...)
    return createCategory(...)
end

function core.banCategory(...)
    return banCategory(...)
end

function core.createRole(...)
    return createRole(...)
end

function core.getRoleById(...)
    return getRoleById(...)
end

function core.addRoleToUser(...)
    return addRoleToUser(...)
end

function core.removeRoleFromUser(...)
    return removeRoleFromUser(...)
end

function core.returnUserHasRole(...)
    return returnUserHasRole(...)
end

function core:getService(sn)
    return services.GetService(sn)
end

function core.revokeAllTokensForUser(...)
    return revokeAllTokensForUser(...)
end

function core.listTokensForUser(...)
    return listTokensForUser(...)
end

function core.revokeToken(...)
    return revokeToken(...)
end


local adminRole = getRoleById(1)
if not adminRole then
    createRole('Administrator')
end
timer.setInterval(1*1000, function()
    saveDB()
end)

-- aliases
core.Events = core.events

-- services: make things easier and readable. Roblox ahh services.  
-- Test Service - you can remove it if it hurts yo eyes :p
services.NewService('TestService', {

    Test = function (self, param)
        
        print('TEST: '..tostring(param))

    end

})

-- UserService - Manipulate users data
services.NewService('UserService', {

    GetUserById = function (self, id)
        return getUserById(id)
    end,

    GetUserByToken = function (self, token)
        return getUserByToken(token) -- returns user, tokenRecord
    end,

    GetUserTokens = function (self, userid)
        return listTokensForUser(userid)
    end,

    RevokeToken = function (self, token)
        return revokeToken(token)
    end,

    RevokeAllTokensForUser = function (self, userid)
        return revokeAllTokensForUser(userid)
    end

})



return core