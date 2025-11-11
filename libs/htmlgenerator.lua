local htmlgenerator = {}

local function tag(tag, content, class, id)
    local tg = {}
    print('Tag generation:', tag, content, class, id)

    function tg.gen()
        return '<'.. tag .. (class and ' class="'..class..'"' or '') .. (id and ' id="'..id..'"' or "") ..'>' .. content .. '</'..tag..'>'
    end

    return tg
end

function htmlgenerator.new()
    
    local htmlObject = {}
    local headTitle = ''

    local body = {}
    local css

    htmlObject.head = {}
    htmlObject.body = {}
    htmlObject.footer = {}
    htmlObject.css = {} -- :p

    function htmlObject.css.insert(content)
        css = content
    end

    function htmlObject.head.setTitle(str)
        if type(str) ~= "string" then
            error('expected string, got '..type(str))
        end
        
        headTitle = str
    end

    function htmlObject.body.h(num, content)
        table.insert(body, tag('h'..num, content))
    end
    function htmlObject.body.div(content, class, id)
        table.insert(body, tag('div', content, class, id))
    end

    function htmlObject.generate()
        local html = '<!DOCTYPE html>\n<html>\n'
        -- building head
        html = html .. '<head>\n'   -- start tag

        if headTitle and #headTitle > 0 then
            html = html .. '<title>' .. headTitle .. '\n</title>\n'
            if css then
                html = html .. '<style>\n'..css..'\n</style>\n'
            end
        end

        html = html .. '</head>\n'   -- end tag

        -- building body
        html = html .. '<body>\n'   -- start tag

        for i, tag in ipairs(body) do
            html = html .. tag.gen()
        end

        html = html .. '\n</body>\n'   -- end tag

        -- end
        html = html .. '\n</html>'

        return html
    end

    function htmlObject.gen()    -- macros
        return htmlObject.generate()
    end


    return htmlObject 

end

htmlgenerator.tag = tag
return htmlgenerator