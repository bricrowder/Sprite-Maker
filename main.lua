--[[]
Paste

Fill

windows!

map

]]

-- load requires
json = require "dkjson"

function love.load()
    -- setup graphics options - pixelated look when it is "zoomed in" on
    love.graphics.setDefaultFilter("nearest", "nearest")
    -- Load the config
    config = json.opendecode("config/config.json")

    -- global control vars
    mode = config.mode.draw

    -- grid draw flags
    sheetGrid = true
    drawGrid = true

    -- global canvases: CanvasBake = 1x spritesheet, Canvas = max scale spritesheet
    ssCanvasBake = love.graphics.newCanvas(config.spritesheetWindow.width,config.spritesheetWindow.height)
    ssCanvas = love.graphics.newCanvas(config.spritesheetWindow.width * config.pixelScale.spritesheetWindowMax,config.spritesheetWindow.height * config.pixelScale.spritesheetWindowMax)

    -- global modifier key states
    SHIFT = false
    MOUSE = false
    CTRL = false

    -- painting mode - 1=brush, 2=fill
    paintMode = 1

    -- load pixel data
    pixels = json.opendecode(config.spritesheet.pixelData)

    -- create pixel data if there isn't any
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

    -- load button textures and pre-determine positions based on padding (local coords to window)
    for i, v in ipairs(config.buttons) do
        v.texture = love.graphics.newImage(v.icon)

        v.pos = {
            -- vertical alignment for x
            x = config.buttonConfig.padding.x,
            y = (i-1)*v.texture:getHeight() + config.buttonConfig.padding.y*(i-1)*2+ config.buttonConfig.padding.y,
            w = v.texture:getWidth(),
            h = v.texture:getHeight()
        }
        v.hover = false
    end

    -- init colour window buttons (local coords to window)
    for i, v in ipairs(config.palette) do
        -- set x pos 8 and 8
        local x = 0
        local y = 0
        if i > #config.palette/2 then
            x = 64
            y = -512
        end
        v.pos = {
            -- for colour rect
            x = x + config.buttonConfig.padding.x,
            y = y + (i-1)*(config.buttonConfig.padding.y*2+config.buttonConfig.size)+config.buttonConfig.padding.y,
            w = config.buttonConfig.size,
            h = config.buttonConfig.size,
            -- for border
            xb = x + config.buttonConfig.padding.x - config.buttonConfig.padding.x/2,
            yb = y + (i-1)*(config.buttonConfig.padding.y*2+config.buttonConfig.size)+config.buttonConfig.padding.y - config.buttonConfig.padding.y/2,
            wb = config.buttonConfig.size+config.buttonConfig.padding.x,
            hb = config.buttonConfig.size+config.buttonConfig.padding.y
       }

       v.hover = false

    end
   
    -- global draw canvas pixels, init to transparent
    drawPixels = {}
    for i=1, config.pixelScale.pixelsPerSprite do
        drawPixels[i] = {}
        for j=1, config.pixelScale.pixelsPerSprite do
            drawPixels[i][j] = 1
        end
    end

    -- colour, init to first palette entry
    colour = 1

    -- spritesheet canvas position, min and max pos
    sx = 0
    sy = 0
    sxMin = -config.spritesheetWindow.width * config.pixelScale.spritesheetWindow + config.spritesheetWindow.width
    syMin = -config.spritesheetWindow.height * config.pixelScale.spritesheetWindow + config.spritesheetWindow.height
    sxMax = 0
    syMax = 0

    -- copy/paste table
    copyPixels = {}

    -- transparent background
    transbg = love.graphics.newCanvas(config.transparentBg.size, config.transparentBg.size)

    -- make a checkerboard, use odd/even checks
    love.graphics.setCanvas(transbg)
    for i=1, transbg:getWidth()/config.transparentBg.scale do
        for j=1, transbg:getWidth()/config.transparentBg.scale do
            if i%2==0 and j%2==0 then
                love.graphics.setColor(config.transparentBg.colour1)
            elseif  i%2==0 and j%2==1 then
                love.graphics.setColor(config.transparentBg.colour2)
            elseif  i%2==1 and j%2==0 then
                love.graphics.setColor(config.transparentBg.colour2)
            elseif  i%2==1 and j%2==1 then
                love.graphics.setColor(config.transparentBg.colour1)
            end
            love.graphics.rectangle("fill",(i-1)*config.transparentBg.scale,(j-1)*config.transparentBg.scale,config.transparentBg.scale,config.transparentBg.scale)
        end
    end
    love.graphics.setCanvas()

    -- transparent colour button (use grid instead of colour)
    transColour = love.graphics.newCanvas(config.buttonConfig.size, config.buttonConfig.size)
    love.graphics.setCanvas(transColour)
    for i=1, 2 do
        for j=1, 2 do
            if i%2==0 and j%2==0 then
                love.graphics.setColor(config.transparentBg.colour1)
            elseif  i%2==0 and j%2==1 then
                love.graphics.setColor(config.transparentBg.colour2)
            elseif  i%2==1 and j%2==0 then
                love.graphics.setColor(config.transparentBg.colour2)
            elseif  i%2==1 and j%2==1 then
                love.graphics.setColor(config.transparentBg.colour1)
            end
            love.graphics.rectangle("fill",(i-1)*transColour:getWidth()/2,(j-1)*transColour:getHeight()/2,transColour:getWidth()/2,transColour:getHeight()/2)
        end
    end
    love.graphics.setCanvas()

    -- + and - zoom buttons

    -- drawWindow grid
    drawGridCanvas = love.graphics.newCanvas(config.drawWindow.width,config.drawWindow.height)
    love.graphics.setCanvas(drawGridCanvas)

    -- just using width as I intent on keeping it square
    local cellSize = config.drawWindow.width / config.pixelScale.pixelsPerSprite

    love.graphics.setColor(config.gridColour.drawWindow)

    -- top to bottom
    for i=1, config.pixelScale.pixelsPerSprite do
        local x1 = (i-1) * cellSize
        local y1 = 0
        local x2 = (i-1) * cellSize
        local y2 = drawGridCanvas:getHeight()
        love.graphics.line(x1,y1,x2,y2)
    end

    -- left to right
    for i=1, config.pixelScale.pixelsPerSprite do
        local x1 = 0
        local y1 = (i-1) * cellSize
        local x2 = drawGridCanvas:getWidth()
        local y2 = (i-1) * cellSize
        love.graphics.line(x1,y1,x2,y2)
    end

    love.graphics.setCanvas()
    love.graphics.setColor(1,1,1,1)

    -- set first draw window as 1,1
    getPixels(1, 1)

    -- global status text
    statusText = "na"
end

function love.update(dt)
    -- get mouse position
    local mx, my = love.mouse.getPosition()
    -- get mode/window
    local window = getWindow(mx, my)

    -- get modifier key states
    resetKeyStates()
    if love.keyboard.isDown("rshift", "lshift") then
        SHIFT = true
    end
    if love.keyboard.isDown("rctrl", "lctrl") then
        CTRL = true
    end

    if window == "spritesheetWindow" then
        -- get spritesheet grid, offsetting by the amount the canvas is moved from 0,0
        local gx, gy = getGrid(window, mx - sx, my - sy)
        -- set end of selection box while you are holding mouse btn down
        if love.mouse.isDown(1, 2) and not SHIFT then
            ssSelection.fin.gx = gx
            ssSelection.fin.gy = gy
            MOUSE = true            
        elseif love.mouse.isDown(1, 2) and SHIFT then
            MOUSE = true            
        end
    elseif window == "drawWindow" then
        local dx, dy = getGrid(window, mx, my)
        -- colour the pixel with the current colour
        if love.mouse.isDown(1, 2) then
            if paintMode==1 then
                setPixel(dx, dy, colour)
                MOUSE = true
            elseif paintMode==2 then

            end
        end        
    elseif window == "colourWindow" then
        -- capture if the mouse is hoving over a colour 
        local cx = mx - config.colourWindow.x
        local cy = my - config.colourWindow.y

        for i, v in ipairs(config.palette) do
            v.hover = false
            if cx >= v.pos.x and cx <= v.pos.x+v.pos.w and cy >= v.pos.y and cy <= v.pos.y+v.pos.h then
                v.hover = true
            end
        end
    elseif window == "toolWindow" then
        -- capture if the mouse is hoving over a button
        local twx = mx - config.toolWindow.x
        local twy = my - config.toolWindow.y
        
        for i, v in ipairs(config.buttons) do
            -- only check tool buttons
            v.hover = false
            if twx >= v.pos.x and twx <= v.pos.x+v.pos.w and twy >= v.pos.y and twy <= v.pos.y+v.pos.h then
                v.hover = true
            end
        end
   end

    -- bake changes
    bakePixels()

    -- update status text with various positions and actions
    statusText = window .. ": ".. mx .. "," .. my
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
    local window = getWindow(x, y)
    if window == "spritesheetWindow" then
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
    elseif window == "colourWindow" then
        for i, v in ipairs(config.palette) do
            -- hover was checked just before this, was it clided on too?
            if v.hover then
                -- set the colour
                colour = i
            end
        end
    elseif window == "toolWindow" then
        local but = nil
        for i, v in ipairs(config.buttons) do
            -- hover was checked just before this, was it clided on too?
            if v.hover then
                -- set the colour
                but = i
            end
        end

        if but then
            if but==1 then
                -- brush
                paintMode = 1
            elseif but==2 then
                -- fill
                paintMode = 2
            elseif but==3 then
                -- copy
                copySelectedPixels()
            elseif but==4 then
                -- cut
                cutSelectedPixels()                
            elseif but==5 then
                -- paste
                pasteCopiedPixels()
            elseif but==6 then
                -- delete
                deleteSelectedPixels()                
            elseif but==7 then
                -- zoom -
                zoom("left")
            elseif but==8 then
                -- zoom +
                zoom("right")
            elseif but==9 then
                -- save
                writeImage()
            elseif but==10 then
                -- exit
                love.event.quit()
            end
        end
    end
end

function love.mousereleased(x, y, button, isTouch, presses)
    local window = getWindow(x, y)
    if window == "spritesheetWindow" and not SHIFT then
        local gx, gy = getGrid(window, x-sx, y-sy)
        ssSelection.fin.gx = gx
        ssSelection.fin.gy = gy

        if ssSelection.start.gx == ssSelection.fin.gx and ssSelection.start.gy == ssSelection.fin.gy then
            getPixels(ssSelection.start.gx, ssSelection.start.gy)
        end

    elseif window == "drawWindow" then

    end
end

function love.keyreleased(key)
    if key=="s" then
        writeImage()
    end
    if key=="right" or key=="left" then
        zoom(key)
        -- if config.pixelScale.spritesheetWindow < config.pixelScale.spritesheetWindowMax  then
        --     config.pixelScale.spritesheetWindow = config.pixelScale.spritesheetWindow * 2
        --     sxMin = -config.spritesheetWindow.width * config.pixelScale.spritesheetWindow + config.spritesheetWindow.width
        --     syMin = -config.spritesheetWindow.height * config.pixelScale.spritesheetWindow + config.spritesheetWindow.height
        --     print(sxMin .. "," .. syMin)
        -- end
    end
    -- if key=="left" then
    --     if config.pixelScale.spritesheetWindow > 1 then
    --         config.pixelScale.spritesheetWindow = config.pixelScale.spritesheetWindow / 2
    --         sxMin = -config.spritesheetWindow.width * config.pixelScale.spritesheetWindow + config.spritesheetWindow.width
    --         syMin = -config.spritesheetWindow.height * config.pixelScale.spritesheetWindow + config.spritesheetWindow.height
    --         print(sxMin .. "," .. syMin)
    --     end
    -- end
    if (key=="c" or key=="C") and CTRL then
        copySelectedPixels()
    end
    if (key=="x" or key=="X") and CTRL then
        cutSelectedPixels()
    end
    if (key=="v" or key=="V") and CTRL then
        pasteCopiedPixels()
    end
    if key=="delete" then
        deleteSelectedPixels()        
    end
    if key=="g" then
        sheetGrid = not(sheetGrid)
    end
    if key=="h" then
        drawGrid = not(drawGrid)
    end
end

function love.draw()
    -- draw the transparent backgrounds
    love.graphics.draw(transbg, config.spritesheetWindow.x, config.spritesheetWindow.y)
    love.graphics.draw(transbg, config.drawWindow.x, config.drawWindow.y)

    love.graphics.setColor(0.05,0.05,0.1,1.0)
    love.graphics.rectangle("fill",config.toolWindow.x, config.toolWindow.y, config.toolWindow.width, config.toolWindow.height)
    love.graphics.rectangle("fill",config.statusWindow.x, config.statusWindow.y, config.statusWindow.width, config.statusWindow.height)
    love.graphics.rectangle("fill",config.colourWindow.x, config.colourWindow.y, config.colourWindow.width, config.colourWindow.height)
    love.graphics.setColor(1,1,1,1)

    -- draw spritesheet window. limit to the spritesheet window location/size with a stencil
    love.graphics.stencil(spritesheetWindowStencil, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    love.graphics.draw(ssCanvas, config.spritesheetWindow.x + sx, config.spritesheetWindow.y + sy)
    love.graphics.setStencilTest()

    -- draw draw window
    drawDrawWindow()
    if drawGrid then
        love.graphics.draw(drawGridCanvas, config.drawWindow.x, config.drawWindow.y)
    end
    
    -- and so on
    drawToolWindow()
    drawColourWindow()

    love.graphics.setColor(0.05,0.05,0.1,1.0)
    -- window borders
    love.graphics.rectangle("line",config.drawWindow.x, config.drawWindow.y, config.drawWindow.width, config.drawWindow.height)
    love.graphics.rectangle("line",config.spritesheetWindow.x, config.spritesheetWindow.y, config.spritesheetWindow.width, config.spritesheetWindow.height)

    love.graphics.setColor(1,1,1,1)

    -- various status text
    love.graphics.print(statusText,config.statusWindow.x, config.statusWindow.y)
    love.graphics.print("Selection (Grid): " .. ssSelection.start.gx .. "," .. ssSelection.start.gy .. " - " .. ssSelection.fin.gx .. "," .. ssSelection.fin.gy, config.statusWindow.x + 300, config.statusWindow.y)
    local x, y, w, h = getSelectionRect()
    love.graphics.print("Selection (Pixels): " .. x .. "," .. y .. " - " .. w .. "," .. h, config.statusWindow.x + 300, config.statusWindow.y + 15)
    love.graphics.print("Spritesheet offset: " .. sx .. "," .. sy, config.statusWindow.x + 300, config.statusWindow.y + 30)
    
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
        elseif x >= config.colourWindow.x and x <= config.colourWindow.x+config.colourWindow.width and y >= config.colourWindow.y and y <= config.colourWindow.y+config.colourWindow.height then
            window = "colourWindow"
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
    end

    if s and lx and ly then
        gx = math.floor(lx/s) + 1
        gy = math.floor(ly/s) + 1
    end

    return gx, gy
end

function getSelectionRect()
    local x, y, w, h = 0, 0, 0, 0 

    -- returns a rect coords, start variable depends on relative location of fin
    if ssSelection.fin.gx >= ssSelection.start.gx then
        x = (ssSelection.start.gx-1) * config.pixelScale.pixelsPerSprite + 1
        w = (ssSelection.fin.gx-ssSelection.start.gx+1) * config.pixelScale.pixelsPerSprite - 1
    else
        x = (ssSelection.fin.gx-1) * config.pixelScale.pixelsPerSprite + 1
        w = (ssSelection.start.gx-ssSelection.fin.gx+1) * config.pixelScale.pixelsPerSprite - 1
    end

    if ssSelection.fin.gy >= ssSelection.start.gy then
        y = (ssSelection.start.gy-1) * config.pixelScale.pixelsPerSprite + 1
        h = (ssSelection.fin.gy-ssSelection.start.gy + 1) * config.pixelScale.pixelsPerSprite - 1
    else 
        y = (ssSelection.fin.gy-1) * config.pixelScale.pixelsPerSprite + 1
        h = (ssSelection.start.gy-ssSelection.fin.gy + 1) * config.pixelScale.pixelsPerSprite - 1
    end

    return x, y, w, h
end

-- sets the pixel on the draw grid and pixel grid
function setPixel(dx, dy, c)
    -- draw window
    drawPixels[dx][dy] = c
    -- calculate pixel and set
    local sx = (ssSelection.start.gx-1) * config.pixelScale.pixelsPerSprite + dx
    local sy = (ssSelection.start.gy-1) * config.pixelScale.pixelsPerSprite + dy
    pixels[sx][sy] = c
end

-- get pixels from the spritesheet and loads into the draw window
function getPixels(gx, gy)
    local iStart = (gx-1) * config.pixelScale.pixelsPerSprite+1
    local jStart = (gy-1) * config.pixelScale.pixelsPerSprite+1
    local iEnd = iStart + config.pixelScale.pixelsPerSprite-1
    local jEnd = jStart + config.pixelScale.pixelsPerSprite-1

    local di = 1
    local dj = 1

    for i=iStart, iEnd do
        for j=jStart, jEnd do
            drawPixels[di][dj] = pixels[i][j]
            dj = dj + 1
        end
        dj = 1
        di = di + 1
    end
end

-- copies the selected pixels and put them in a seperate variable
function copySelectedPixels()
    local x, y, w, h = getSelectionRect()
    w = w + x
    h = h + y
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
    print("Copied " .. #copyPixels .. " x " .. #copyPixels[1])
    print("x: " .. x .. "\ny: " .. y .. "\nw: " .. w .. "\nh: " .. h)
end

function pasteCopiedPixels()

end

-- deletes the selected pixels, turns the colour to 1 from the palette
function deleteSelectedPixels()
    -- get indices of selection
    local x, y, w, h = getSelectionRect()
    w = w + x
    h = h + y

    -- loop through and make transparent using colour 1
    for i=x, w do
        for j=y, h do
            pixels[i][j] = 1
        end
    end
    -- update the draw window
    getPixels(ssSelection.start.gx, ssSelection.start.gy)
    print("Deleted " .. w-x .. " x " .. h-y)
    print("x: " .. x .. "\ny: " .. y .. "\nw: " .. w .. "\nh: " .. h)
end

-- combination of copy and delete
function cutSelectedPixels()
    print("-- Cutting -- ")
    copySelectedPixels()
    deleteSelectedPixels()
end

function zoom(key)
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
end


-- "bakes" the pixel array to a canvas, also handles the grid
function bakePixels()
    -- scale of 1
    love.graphics.setCanvas(ssCanvasBake)
    love.graphics.clear()

    for i=1, #pixels do
        for j=1, #pixels[i] do
            love.graphics.setColor(config.palette[pixels[i][j]].colour)
            love.graphics.rectangle("fill", i-1, j-1, 1, 1)
        end
    end

    love.graphics.setColor(1,1,1,1) 

    -- scale of config.pixelScale.spritesheetWindow
    love.graphics.setCanvas(ssCanvas)
    love.graphics.clear()
    love.graphics.draw(ssCanvasBake, 0, 0, 0, config.pixelScale.spritesheetWindow)

    if sheetGrid then
        -- draw the grid here
        local cellSize = config.pixelScale.pixelsPerSprite * config.pixelScale.spritesheetWindow
        love.graphics.setColor(config.gridColour.spritesheetWindow)

        for i=1, config.spritesheetWindow.width / config.pixelScale.pixelsPerSprite do
            local x1 = (i-1) * cellSize
            local y1 = 0
            local x2 = (i-1) * cellSize
            local y2 = config.spritesheetWindow.height * config.pixelScale.spritesheetWindow
            love.graphics.line(x1,y1,x2,y2)
        end

        -- left to right
        for i=1, config.spritesheetWindow.height / config.pixelScale.pixelsPerSprite do
            local x1 = 0
            local y1 = (i-1) * cellSize
            local x2 = config.spritesheetWindow.width * config.pixelScale.spritesheetWindow
            local y2 = (i-1) * cellSize
            love.graphics.line(x1,y1,x2,y2)
        end
    end

    love.graphics.setColor(1,1,1,1) 
    
    -- draw selection rectangle
    x, y, w, h = getSelectionRect()

    x = x * config.pixelScale.spritesheetWindow - 1
    y = y * config.pixelScale.spritesheetWindow - 1
    w = w * config.pixelScale.spritesheetWindow + 1
    h = h * config.pixelScale.spritesheetWindow + 1

    love.graphics.setColor(config.selection.highlightColour)
    love.graphics.rectangle("line",x,y,w,h)

    love.graphics.setColor(1,1,1,1)
    love.graphics.setCanvas()
end

function drawDrawWindow()
    for i=1, config.pixelScale.pixelsPerSprite do
        for j=1, config.pixelScale.pixelsPerSprite do
            love.graphics.setColor(config.palette[drawPixels[i][j]].colour)
            love.graphics.rectangle("fill", (i-1)*config.pixelScale.drawWindow + config.drawWindow.x, (j-1)*config.pixelScale.drawWindow + config.drawWindow.y, config.pixelScale.drawWindow, config.pixelScale.drawWindow)
        end
    end

    love.graphics.setColor(1,1,1,1)
end

function drawToolWindow()
    for i, v in ipairs(config.buttons) do
        if v.hover then
            love.graphics.setColor(v.hoverColour)
        else
            love.graphics.setColor(1,1,1,1)
        end
        if v.texture then
            love.graphics.draw(v.texture, config.toolWindow.x + v.pos.x, config.toolWindow.y + v.pos.y)
        else
            love.graphics.rectangle("line",config.toolWindow.x + v.pos.x, config.toolWindow.y + v.pos.y, v.pos.w, v.pos.h)
        end
    end
    love.graphics.setColor(config.buttonConfig.indicatorColour)
    -- draw paintmode indicatorColour
    love.graphics.circle("fill", config.toolWindow.x + config.toolWindow.width - (config.toolWindow.width * 0.2), config.toolWindow.y + (config.toolWindow.width * 0.2) + ((paintMode-1) * 64), 4)
end

function drawColourWindow()
    for i, v in ipairs(config.palette) do
        love.graphics.setColor(config.buttonConfig.borderColour)
        if i==colour then
            love.graphics.setColor(config.buttonConfig.borderColourHighlight)
        end
        love.graphics.rectangle("fill", config.colourWindow.x + v.pos.xb, config.colourWindow.y + v.pos.yb, v.pos.wb, v.pos.hb)
        love.graphics.setColor(v.colour)
        love.graphics.rectangle("fill", config.colourWindow.x + v.pos.x, config.colourWindow.y + v.pos.y, v.pos.w, v.pos.h)
        if i==1 or i==3 then  -- crude way to make this line for transparent and white
            if i==1 then  -- crude way to get the transparent background in
                love.graphics.setColor(1,1,1,1)
                love.graphics.draw(transColour, config.colourWindow.x + v.pos.x, config.colourWindow.y + v.pos.y)
            end
            love.graphics.setColor(0,0,0,1)
            love.graphics.rectangle("line", config.colourWindow.x + v.pos.x, config.colourWindow.y + v.pos.y, v.pos.w, v.pos.h)
        end

    end
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
    local imgData = ssCanvasBake:newImageData()
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