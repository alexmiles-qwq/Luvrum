<<<<<<< HEAD
io.write("\27[2J\27[H") 

_G.main = {}
main.settings = {
    port = 80
}

_G.event = require('./libs/event')
_G.utils = require('./modules/utils')
_G.cookie = require('./libs/cookie')

_G.niko = require('./libs/niko')
_G.enum = require('./modules/enum')
_G.ansi = require('./libs/ansi')
_G.sha2 = require('./libs/sha2')
_G.keygen = require('./libs/keygen')
--_G.htmlgenerator = require('./libs/htmlgenerator')

niko.minPriority = 2
niko:Log('Server is starting..', 'Main', 2)

local http = require('http')
local neco = require('./modules/neco')
_G.core = require('./modules/core')
_G.web = require('./modules/web')

-- core.registerUser('zacky', 'foxi22815Qw')

neco:LoadAllPlugins()

-- niko:Log( ansi.customColor(10,125,115).. 'Web server is running on http://127.0.0.1:80' .. ansi.color.reset, 'Main-Web', 2)
niko:Log(ansi.gradient(ansi.gradientBackground(' Web server is running on http://127.0.0.1:' .. web.port .. ' ', {0,100,255}, {255,0,100}), {255, 255, 0}, {0, 255, 255}), 'Main-Web', 2)

niko:Log('Done! Took: ' .. os.clock() * 1000 .. ' ms.', 'Main', 2)

=======
io.write("\27[2J\27[H") 

_G.main = {}
main.settings = {
    port = 80
}

_G.event = require('./libs/event')
_G.utils = require('./modules/utils')
_G.cookie = require('./libs/cookie')

_G.niko = require('./libs/niko')
_G.enum = require('./modules/enum')
_G.ansi = require('./libs/ansi')
_G.sha2 = require('./libs/sha2')
_G.keygen = require('./libs/keygen')
--_G.htmlgenerator = require('./libs/htmlgenerator')

niko.minPriority = 2
niko:Log('Server is starting..', 'Main', 2)

local http = require('http')
local neco = require('./modules/neco')
_G.core = require('./modules/core')
_G.web = require('./modules/web')

-- core.registerUser('zacky', 'foxi22815Qw')
--o 
neco:LoadAllPlugins()

-- niko:Log( ansi.customColor(10,125,115).. 'Web server is running on http://127.0.0.1:80' .. ansi.color.reset, 'Main-Web', 2)
niko:Log(ansi.gradient(ansi.gradientBackground(' Web server is running on http://127.0.0.1:' .. web.port .. ' ', {0,100,255}, {255,0,100}), {255, 255, 0}, {0, 255, 255}), 'Main-Web', 2)

niko:Log('Done! Took: ' .. os.clock() * 1000 .. ' ms.', 'Main', 2)

>>>>>>> 08244ac (test)
