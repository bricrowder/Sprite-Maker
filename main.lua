--[[]
tools: brush (b), eraser (e) (100% transparent), zoom slider (-,+, mouse wheel?), save, quit
tools: animation

copy, cut, paste

checkered transparent background

colour picker



]]

-- load requires
json = require "dkjson"

function love.load()
    -- setup graphics options
    love.graphics.setDefaultFilter("nearest", "nearest")
    -- Load the config
    config = json.opendecode("config/config.json")

    -- global control vars
    mode = config.mode.draw

    -- global canvases: CanvasBake = 1x spritesheet, Canvas = max scale spritesheet
    ssCanvasBake = love.graphics.newCanvas(config.spritesheetWindow.width,config.spritesheetWindow.height)
    ssCanvas = love.graphics.newCanvas(config.spritesheetWindow.width * config.pixelScale.spritesheetWindowMax,config.spritesheetWindow.height * config.pixelScale.spritesheetWindowMax)

    -- global modifier key states
    SHIFT = false
    MOUSE = false
    CTRL = false

    -- load pixel data
    pixels = json.opendecode(config.spritesheet.pixelData)

    if not pixels then
        pixels = {}
        for i=1, config.spritesheetWindow.width do
            pixels[i] = {}
            for j=1, config.spritesheetWindow.height do
                -- draw
                pixels[i][j] = 2
            end
        end
    end

    -- grid selection tracking
    ssSelection = {
        start = {gx=1, gy=1},
        fin = {gx=1, gy=1}
    }


    -- global draw canvas pixels, init to transparent
    drawPixels = {}
    for i=1, config.pixelScale.pixelsPerSprite do
        drawPixels[i] = {}
        for j=1, config.pixelScale.pixelsPerSprite do
            drawPixels[i][j] = 1
        end
    end

    -- currently selected palette colour
    colour = 3

    -- spritesheet position, min and max pos
    sx = 0
    sy = 0
    sxMin = -config.spritesheetWindow.width * config.pixelScale.spritesheetWindow + config.spritesheetWindow.width
    syMin = -config.spritesheetWindow.height * config.pixelScale.spritesheetWindow + config.spritesheetWindow.height
    sxMax = 0
    syMax = 0

    -- copy/paste table
    copyPixels = {}

    -- global status text
    statusText = "na"
end

function love.update(dt)
    -- get mouse position
    local mx, my = love.mouse.getPosition()
    -- offset coords if sheet has been "moved", minus it because sx,sy is < 1
    local tx = mx - sx
    local ty = my - sy

    -- get mode/window
    local window = getWindow(mx, my)
    -- get window grid position (if applicable)

    -- get grid pos' based on actual and offset mouse pos
    local dx, dy = getGrid(window, mx, my)
    local gx, gy = getGrid(window, tx, ty)

    -- get modifier key states
    resetKeyStates()
    if love.keyboard.isDown("rshift", "lshift") then
        SHIFT = true
    end
    if love.keyboard.isDown("rctrl", "lctrl") then
        CTRL = true
    end
    -- get mouse clicks
    if love.mouse.isDown(1, 2) then
        MOUSE = true

        if window == "spritesheetWindow" and not SHIFT then
            -- set end of selection box while you are holding mouse btn down
            ssSelection.fin.gx = gx
            ssSelection.fin.gy = gy
        elseif window == "drawWindow" then        
            -- only set if it is a different colour
            if not(drawPixels[dx][dy] == colour) then
                setPixel(dx, dy, colour)
            end
        end

    end

    -- bake changes
    bakePixels()

    -- update status text with various positions and actions
    statusText = window .. ": ".. mx .. "," .. my .. "   Modified: " .. tx .. "," .. ty
    if gx and gy then
        statusText = statusText .. "\n " .. gx .. "," .. gy
    end
    if SHIFT then
        statusText = statusText .. "\nSHIFT"
    end
    if CTRL then
        statusText = statusText .. "\nCTRL"
    end
    if MOUSE then
        statusText = statusText .. "\nMOUSE"
    end
end

function love.mousemoved(x, y, dx, dy)
    if getWindow(x, y) == "spritesheetWindow" then
        if MOUSE and SHIFT then
            sx = sx + dx
            sy = sy + dy
            if sx < sxMin then
                sx = sxMin
            elseif sx > sxMax then
                sx = sxMax
            end
            if sy < syMin then
                sy = syMin
            elseif sy > syMax then
                sy = syMax
            end          
        end
    end
end

function love.mousepressed(x, y, button, isTouch, presses)
    local window = getWindow(x, y)
    local gx, gy = getGrid(window, x-sx, y-sy)
    if window == "spritesheetWindow" and not SHIFT then
        -- reset selection
        ssSelection.start.gx = gx
        ssSelection.start.gy = gy
        ssSelection.fin.gx = nil
        ssSelection.fin.gy = nil
    elseif window == "drawWindow" then

    end
end

function love.mousereleased(x, y, button, isTouch, presses)
    local window = getWindow(x, y)
    if window == "spritesheetWindow" and not SHIFT then
        local gx, gy = getGrid(window, x-sx, y-sy)
        ssSelection.fin.gx = gx
        ssSelection.fin.gy = gy

        if ssSelection.start.gx == ssSelection.fin.gx and ssSelection.start.gy == ssSelection.fin.gy then
            -- load cell into draw window
            getPixels(ssSelection.start.gx, ssSelection.start.gy)
        end

    elseif window == "drawWindow" then

    end
end

function love.keyreleased(key)
    if key=="s" then
        writeImage()
    end
    if key=="right" then
        if config.pixelScale.spritesheetWindow < config.pixelScale.spritesheetWindowMax  then
            config.pixelScale.spritesheetWindow = config.pixelScale.spritesheetWindow * 2
            sxMin = -config.spritesheetWindow.width * config.pixelScale.spritesheetWindow + config.spritesheetWindow.width
            syMin = -config.spritesheetWindow.height * config.pixelScale.spritesheetWindow + config.spritesheetWindow.height
            print(sxMin .. "," .. syMin)
        end
    end
    if key=="left" then
        if config.pixelScale.spritesheetWindow > 1 then
            config.pixelScale.spritesheetWindow = config.pixelScale.spritesheetWindow / 2
            sxMin = -config.spritesheetWindow.width * config.pixelScale.spritesheetWindow + config.spritesheetWindow.width
            syMin = -config.spritesheetWindow.height * config.pixelScale.spritesheetWindow + config.spritesheetWindow.height
            print(sxMin .. "," .. syMin)
        end
    end
    if key=="c" and CTRL then
        copySelectedPixels()
    end
end

function love.draw()
    love.graphics.stencil(spritesheetWindowStencil, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.draw(ssCanvas, config.spritesheetWindow.x + sx, config.spritesheetWindow.y + sy)
    love.graphics.setStencilTest()
    
    drawDrawWindow()
    
    love.graphics.rectangle("line",config.drawWindow.x, config.drawWindow.y, config.drawWindow.width, config.drawWindow.height)
    love.graphics.rectangle("line",config.spritesheetWindow.x, config.spritesheetWindow.y, config.spritesheetWindow.width, config.spritesheetWindow.height)
    love.graphics.rectangle("line",config.toolWindow.x, config.toolWindow.y, config.toolWindow.width, config.toolWindow.height)
    love.graphics.rectangle("line",config.statusWindow.x, config.statusWindow.y, config.statusWindow.width, config.statusWindow.height)

    drawGrid("drawWindow")

    love.graphics.print(statusText,config.statusWindow.x, config.statusWindow.y)
    love.graphics.print(sx .. "," .. sy, 10, 10)
end

-- returns the window that the mouse is in, depending on mode
function getWindow(x, y)
    local window="na"
    if mode == config.mode.map then
    elseif mode == config.mode.draw then
        if x >= config.drawWindow.x and x <= config.drawWindow.x+config.drawWindow.width and y >= config.drawWindow.y and y <= config.drawWindow.y+config.drawWindow.height then
            window = "drawWindow"
        elseif x >= config.spritesheetWindow.x and x <= config.spritesheetWindow.x+config.spritesheetWindow.width and y >= config.spritesheetWindow.y and y <= config.spritesheetWindow.y+config.spritesheetWindow.height then
            window = "spritesheetWindow"
        elseif x >= config.toolWindow.x and x <= config.toolWindow.x+config.toolWindow.width and y >= config.toolWindow.y and y <= config.toolWindow.y+config.toolWindow.height then
            window = "toolWindow"
        elseif x >= config.statusWindow.x and x <= config.statusWindow.x+config.statusWindow.width and y >= config.statusWindow.y and y <= config.statusWindow.y+config.statusWindow.height then
            window = "statusWindow"
        end
    end
    return window
end

-- returns the local grid position for the window that the mouse is in
-- map and spritesheet windows have a scale of 1, drawWindow has a variable scale
function getGrid(window, x, y)
    local gx, gy = nil, nil
    local s, lx, ly = nil, nil, nil
    if window == "drawWindow" then
        -- drawWindow is a pixel grid
        s = config.pixelScale.drawWindow
        lx = x - config.drawWindow.x
        ly = y - config.drawWindow.y
    elseif window == "spritesheetWindow" then
        -- make sure you consider the spritesheet scale!
        s = config.pixelScale.pixelsPerSprite * config.pixelScale.spritesheetWindow
        lx = x - config.spritesheetWindow.x
        ly = y - config.spritesheetWindow.y
    elseif window == "mapWindow" then

    end

    if s and lx and ly then
        gx = math.floor(lx/s) + 1
        gy = math.floor(ly/s) + 1
    end

    return gx, gy
end

function getButton(window, x, y)

end

function drawGrid(window)
    local s, lw, lh, xo, yo = nil, nil, nil, nil, nil
    local c = {1,1,1,1}
    if window == "drawWindow" then
        -- A 16x16 pixel grid
        c = {
            config.gridColour.drawWindow[1],
            config.gridColour.drawWindow[2],
            config.gridColour.drawWindow[3],
            config.gridColour.drawWindow[4],
        }
        s = config.pixelScale.drawWindow
        lw = config.drawWindow.width / s
        lh = config.drawWindow.height / s
        xo = config.drawWindow.x
        xw = config.drawWindow.x + config.drawWindow.width
        yo = config.drawWindow.y
        yh = config.drawWindow.y + config.drawWindow.height
    elseif window == "spritesheetWindow" then
        -- variable scale
        c = {
            config.gridColour.spritesheetWindow[1],
            config.gridColour.spritesheetWindow[2],
            config.gridColour.spritesheetWindow[3],
            config.gridColour.spritesheetWindow[4],
        }
        s = config.pixelScale.pixelsPerSprite * config.pixelScale.spritesheetWindow
        lw = config.spritesheetWindow.width * config.pixelScale.spritesheetWindow / s
        lh = config.spritesheetWindow.height * config.pixelScale.spritesheetWindow / s
        xo = config.spritesheetWindow.x
        xw = config.spritesheetWindow.x + config.spritesheetWindow.width* config.pixelScale.spritesheetWindow
        yo = config.spritesheetWindow.y
        yh = config.spritesheetWindow.y + config.spritesheetWindow.height* config.pixelScale.spritesheetWindow
    elseif window == "mapWindow" then

    end
    if s then
        love.graphics.setColor(c)
        for i=1, lw-1 do
            local x1 = i*s+xo
            local y1 = yo
            local x2 = i*s+xo
            local y2 = yh
            love.graphics.line(x1, y1, x2, y2)
        end
        for j=1, lh-1 do
            local x1 = xo
            local y1 = j*s+yo
            local x2 = xw
            local y2 = j*s+yo
            love.graphics.line(x1, y1, x2, y2)
        end
        love.graphics.setColor(1,1,1,1)
    end
end

function setPixel(dx, dy, c)
    drawPixels[dx][dy] = c
    local sx = (ssSelection.start.gx-1) * config.pixelScale.pixelsPerSprite + dx
    local sy = (ssSelection.start.gy-1) * config.pixelScale.pixelsPerSprite + dy
    pixels[sx][sy] = c
end

function getPixels(gx, gy)
    local iStart = (gx-1) * config.pixelScale.pixelsPerSprite+1
    local jStart = (gy-1) * config.pixelScale.pixelsPerSprite+1
    local iEnd = iStart + config.pixelScale.pixelsPerSprite-1
    local jEnd = jStart + config.pixelScale.pixelsPerSprite-1

    local di = 1
    local dj = 1

    -- print(iStart .. "," .. jStart .. " - " .. iEnd .. "," .. jEnd)
    for i=iStart, iEnd do
        for j=jStart, jEnd do
            drawPixels[di][dj] = pixels[i][j]
            dj = dj + 1
        end
        dj = 1
        di = di + 1
    end
end

function copySelectedPixels()
    local w, h, x, y = 0, 0, 0, 0
    if ssSelection.fin.gx >= ssSelection.start.gx then
        x = (ssSelection.start.gx-1) * config.pixelScale.pixelsPerSprite +1
        y = (ssSelection.start.gy-1) * config.pixelScale.pixelsPerSprite +1
        w = x + (ssSelection.fin.gx-ssSelection.start.gx+1) * config.pixelScale.pixelsPerSprite -1
        h = y + (ssSelection.fin.gy-ssSelection.start.gy+1) * config.pixelScale.pixelsPerSprite -1
    else
        x = (ssSelection.fin.gx-1) * config.pixelScale.pixelsPerSprite +1
        y = (ssSelection.fin.gy-1) * config.pixelScale.pixelsPerSprite +1
        w = x + (ssSelection.start.gx-ssSelection.fin.gx+1) * config.pixelScale.pixelsPerSprite -1
        h = y + (ssSelection.start.gy-ssSelection.fin.gy+1) * config.pixelScale.pixelsPerSprite -1
    end

    -- reset!
    copyPixels = {}
    -- copy!
    local ci = 1
    local cj = 1
    for i=x, w do
        copyPixels[ci] = {}
        cj = 1
        for j=y, h do
            copyPixels[ci][cj] = pixels[i][j]
            cj = cj + 1
        end
        ci = ci + 1
    end
    print("x: " .. x .. "\ny: " .. y .. "\nw: " .. w .. "\nh: " .. h)
    print("Copied " .. #copyPixels .. " x " .. #copyPixels[1])
end

function pastePixels(gx1, gy1, gx2, gy2)

end

function deletePixels(gx1, gy1, gx2, gy2)

end



function bakePixels()
    love.graphics.setCanvas(ssCanvasBake)
    for i=1, #pixels do
        for j=1, #pixels[i] do            
            love.graphics.setColor(config.palette[pixels[i][j]])
            love.graphics.rectangle("fill", i-1, j-1, 1, 1)
        end
    end
    love.graphics.setColor(1,1,1,1)
    love.graphics.setCanvas(ssCanvas)
    love.graphics.draw(ssCanvasBake, 0, 0, 0, config.pixelScale.spritesheetWindow)
    drawGrid("spritesheetWindow")

    if ssSelection.start.gx and ssSelection.fin.gx then
        local x = (ssSelection.start.gx-1) * config.pixelScale.pixelsPerSprite * config.pixelScale.spritesheetWindow
        local w = ssSelection.fin.gx * config.pixelScale.pixelsPerSprite * config.pixelScale.spritesheetWindow - x
        local y = (ssSelection.start.gy-1) * config.pixelScale.pixelsPerSprite * config.pixelScale.spritesheetWindow
        local h = ssSelection.fin.gy * config.pixelScale.pixelsPerSprite * config.pixelScale.spritesheetWindow - y
        love.graphics.rectangle("line",x,y,w,h)
    end

    love.graphics.setCanvas()
end

function drawDrawWindow()
    for i=1, config.pixelScale.pixelsPerSprite do
        for j=1, config.pixelScale.pixelsPerSprite do
            love.graphics.setColor(config.palette[drawPixels[i][j]])
            love.graphics.rectangle("fill", (i-1)*config.pixelScale.drawWindow + config.drawWindow.x, (j-1)*config.pixelScale.drawWindow + config.drawWindow.y, config.pixelScale.drawWindow, config.pixelScale.drawWindow)
        end
    end
    love.graphics.setColor(1,1,1,1)
end

function resetKeyStates()
    SHIFT = false
    CTRL = false
    MOUSE = false
end

function drawWindowStencil()
    love.graphics.rectangle("fill",config.drawWindow.x, config.drawWindow.y, config.drawWindow.width, config.drawWindow.height)
end

function spritesheetWindowStencil()
    love.graphics.rectangle("fill",config.spritesheetWindow.x, config.spritesheetWindow.y, config.spritesheetWindow.width, config.spritesheetWindow.height)
end

function writeImage()
    local imgData = ssCanvas:newImageData()
    local fileData = imgData:encode("png", config.spritesheet.filename)
    local jdata = json.encode(pixels, {indent = true})
    local s, m = love.filesystem.write(config.spritesheet.pixelData, jdata)
end

function writeNewImage()
    local canvas = love.graphics.newCanvas(512,512)
    love.graphics.setCanvas(canvas)
    for i=1,512 do
        for j=1,512 do
            love.graphics.points(
                {{
                    i,
                    j,
                    i/512,
                    j/512,
                    i*j/512,
                    1.0,
                }}
            )
        end
    end
    love.graphics.setCanvas()
    local imgData = canvas:newImageData()
    local fileData = imgData:encode("png", config.spritesheet.filename)
end