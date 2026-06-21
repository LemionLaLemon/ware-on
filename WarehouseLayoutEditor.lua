---@diagnostic disable: undefined-global

local basalt

local hasBasalt, err = pcall(function()
    basalt = require("/basalt")
end)

if not hasBasalt then
    print("Basalt is not installed\nit will automatically be installed\n")
    sleep(3)

    local hasBasaltAgain, errAgain

    for i=1,3,1 do
        shell.execute("wget", "run", "https://raw.githubusercontent.com/Pyroxenium/Basalt2/main/install.lua", "-f")

        hasBasaltAgain, errAgain = pcall(function()
            basalt = require("/basalt")
        end)

        if hasBasaltAgain then break end

        print("Failed to get basalt (" .. i .. " of 3 attempts)\n")
        sleep(1.5^i)
    end

    if not hasBasaltAgain then
        print("Failed to require basalt: " .. errAgain .. "\n")
        print("Please install basalt manually.")
        return
    end
end

local main = basalt.getMainFrame()
main.background = colors.lightBlue

local termx,termy = term.getSize()

local newProject = main:addFrame({ width = 30, height = 9, x = math.floor((termx/2) - 14), y = math.floor((termy/2) - 4), background = colors.white })

newProject:addLabel({ text = "Warehouse Editor", width = 28, height = 1, x = 2, y = 2, foreground = colors.black })

local newWarehouse = newProject:addButton({ text = "New Warehouse", width = 28, height = 1, x = 2, y = 4, background = colors.lightGray })
local loadWarehouse = newProject:addButton({ text = "Load Warehouse", width = 28, height = 1, x = 2, y = 6, background = colors.lightGray }) 
local quit = newProject:addButton({ text = "Quit", width = 28, height = 1, x = 2, y = 8, background = colors.lightGray })

quit:onClick(function()
    basalt.stop()
end)

local warehouseFilePath
local warehouseFile

local function workspaceHandling()
    local workspace = main:addTabControl({ width = termx, height = termy, x = 1, y = 1, activeTabBackground = colors.lightBlue, headerBackground = colors.white, background =  colors.lightBlue })
    local inventoryTab = workspace:newTab("Inventory Assignment")
    local stationTab = workspace:newTab("Access Station Assignment")

    local close = main:addButton({ text = "x", width = 1, height = 1, x = termx, y = 1, background = colors.red, z = 10 })

    close:onClick(function() 
        basalt.stop()
    end)

    local inventoryScroll = inventoryTab:addScrollFrame({ width = termx, height = termy - 1, x = 1, y = 1, background = colors.lightBlue })
    local yindex = -2
    local saveButton = inventoryScroll:addButton({ text = "Save Inventory Assignment", width = 27, height = 1, x = 1, y = 1, background = colors.lime })
    local header = inventoryScroll:addFrame({ width = termx, height = 1, x = 1, y = 2, background = colors.purple })
    header:addLabel({ text = "Inventory", width = math.floor(0.65 * termx), height = 1, x = 1 })
    header:addLabel({ text = "Type", width = math.floor(0.35 * termx), height = 1, x = math.floor(0.65 * termx) })
    local InventoryAssignments = {}
    local count = 0
    for _ in pairs(warehouseFile) do
        count = count + 1
    end
    for item, data in pairs(warehouseFile) do
        yindex = yindex + 5
        local row = inventoryScroll:addFrame({ width = termx, height = 5, x = 1, y = yindex, background = (yindex % 2 == 0 and colors.lightGray or colors.gray), z=(count + 2)-yindex })
        local rowLabel = row:addLabel({ text = item, width = math.floor(0.65 * termx) })
        local rowDropdown = row:addDropDown({ width = math.floor(0.35 * termx), height = 1, x = math.floor(0.65 * termx), y = 1, background = colors.white })
        rowDropdown:setItems({{ text = "Dropoff Station", background = colors.lightGray },{ text = "Storage" },{ text = "Access Station", background = colors.lightGray }})
        rowDropdown:setSelectedText(data.type or "Storage")
        rowDropdown:onSelect(function(_, value)
            InventoryAssignments[item].selected = ({"Dropoff Station","Storage","Access Station"})[value]
            warehouseFile[item].type = ({"Dropoff Station","Storage","Access Station"})[value]
        end)

        InventoryAssignments[item] = { dropdown = rowDropdown, selected = data.type or "Storage" }
    end
    saveButton:onClick(function()
        for item, data in pairs(InventoryAssignments) do
            warehouseFile[item].type = data.selected
        end
        local file = fs.open(warehouseFilePath, "w")
        file.write(textutils.serializeJSON(warehouseFile))
        file.close()
    end)

    local stationScroll = stationTab:addScrollFrame({ width = termx, height = termy - 1, x = 1, y = 1, background = colors.lightBlue })
    local stationSaveButton = stationScroll:addButton({ text = "Save Access Stations", width = 22, height = 1, x = 1, y = 1, background = colors.lime })
    local stationRefreshButton = stationScroll:addButton({ text = "Refresh Inventories", width = 21, height = 1, x = 24, y = 1, background = colors.lightGray })
    local stationHeader = stationScroll:addFrame({ width = termx, height = 1, x = 1, y = 2, background = colors.purple })
    stationHeader:addLabel({ text = "Inventory", width = math.floor(0.65 * termx), height = 1, x = 1 })
    stationHeader:addLabel({ text = "Computer", width = math.floor(0.35 * termx), height = 1, x = math.floor(0.65 * termx) })
    
    local AccessPointAssignments

    local function refreshAccessStations()
        local stationyindex = 2
        if AccessPointAssignments then
            for item, data in pairs(AccessPointAssignments) do
                if data.row then
                    data.row:destroy()
                end
            end
        end
        AccessPointAssignments = {}
        for item, data in pairs(warehouseFile) do
            if data.type == "Access Station" then
                stationyindex = stationyindex + 1
                local row = stationScroll:addFrame({ width = termx, height = 1, x = 1, y = stationyindex, background = (stationyindex % 2 == 0 and colors.lightGray or colors.gray) })
                row:addLabel({ text = item, width = math.floor(0.65 * termx) })
                row:addLabel({ text = "Computer_", width = 9, height = 1, x = math.floor(0.65 * termx), y = 1 })
                local rowInput = row:addInput({ width = 3, height = 1, x = math.floor(0.65 * termx) + 9, y = 1, background = colors.white })
                AccessPointAssignments[item] = { row = row, input = rowInput }
                rowInput.text = warehouseFile[item].computer or ""
            end
        end
    end
    refreshAccessStations()
    stationRefreshButton:onClick(function()
        refreshAccessStations()
    end)
    stationSaveButton:onClick(function()
        for item, data in pairs(AccessPointAssignments) do
            warehouseFile[item].computer = data.input.text
        end
        local file = fs.open(warehouseFilePath, "w")
        file.write(textutils.serializeJSON(warehouseFile))
        file.close()
    end)
end

newWarehouse:onClick(function()
    local step = 1
    newProject.visible = false
    local options = main:addFrame({ width = 40, height = 15, x = math.floor((termx/2) - 19), y = math.floor((termy/2) - 6), background = colors.white })
    local save

    local 
        filelocation, filelocationexists, filelocationcheck,
        inventories, inventorycheckboxes

    local function validatePath(path)
        if not path or path == "" then
            return "Path is empty", colors.red, false
        end
        if path:match("[<>:\"|?*]") then
            return "Path contains invalid characters", colors.red, false
        end
        if not path:match("%.ware$") then
            return "Path must end with [name].ware", colors.red, false
        end
        if fs.getDir(path) ~= "" and not fs.exists(fs.getDir(path)) then
            return "Directory does not exist", colors.red, false
        end
        return "Valid path", colors.lime, true
    end

    local steps = {
        {
            setup = function(frame)
                frame:addLabel({ text = "Save Warehouse To", width = 28, x=2, y=2})
                filelocation = frame:addInput({ placeholder = "/disk/WarehouseName.ware", width = 38, height = 1, x = 2, y = 4, background = colors.lightGray })
                filelocationcheck = frame:addButton({ text = "Validate", width = 10, height = 1, x = 2, y = 7, background = colors.lightGray})
                filelocationexists = frame:addLabel({ text = "", width = 28, x=2, y=5, foreground = colors.red })

                filelocationcheck:onClick(function()
                    local text,color = validatePath(filelocation.text)
                    filelocationexists.text = text
                    filelocationexists.foreground = color
                end)
            end
        },
        {
            setup = function(frame) 
                frame:addLabel({ text = "Select Inventory Peripherals", width = 28, x=2, y=2 })

                local function renderPeripherals()
                    if inventories then inventories:destroy() end
                    sleep(0.1)
                    inventories = frame:addScrollFrame({ x = 2, y = 4, width = 38, height = 8, background = colors.white })

                    local yindex = 0
                    inventorycheckboxes = {}
                    for _, item in ipairs(peripheral.getNames()) do
                        if peripheral.hasType(item, "inventory") then
                            yindex = yindex + 1
                            local row = inventories:addFrame({ width = 37, height = 1, y = yindex, background = (yindex % 2 == 0 and colors.lightGray or colors.gray) })
                            row:addLabel({ text = item, width = 36, height = 1, x = 5, foreground = colors.black, })
                            local checkbox = row:addCheckBox({ x = 1, text = "[ ]", checkedText = "[x]" })
                            table.insert(inventorycheckboxes, { name = item, checkbox = checkbox})
                        end
                    end
                end

                renderPeripherals()

                frame:addButton({ text = "Select All", width = 12, height = 1, x = 2, y = 12, background = colors.lightGray }):onClick(function()
                    for _, item in ipairs(inventorycheckboxes) do
                        item.checkbox.checked = true
                    end
                end)
                frame:addButton({ text = "Deselect All", width = 14, height = 1, x = 15, y = 12, background = colors.lightGray }):onClick(function()
                    for _, item in ipairs(inventorycheckboxes) do
                        item.checkbox.checked = false
                    end
                end)
                frame:addButton({ text = "Reload", width = 8, height = 1, x = 30, y = 12, background = colors.lightGray }):onClick(function()
                    renderPeripherals()
                end)
            end
        }
    }

    local cancel, previous, next, errorText
    local frames = {}

    for i, stepi in ipairs(steps) do
        frames[i] = options:addFrame({ width = 40, height = 12, background = colors.white })
        stepi.setup(frames[i])
        frames[i].visible = i == 1
    end

    local function showStep(stepToShow)
        frames[step].visible = false
        step = stepToShow
        frames[step].visible = true

        if step == #steps then
            next.text = "Save"
        else
            next.text = "Next"
        end
    end

    cancel = options:addButton({ text = "Cancel", width = 8, height = 1, x = 2, y = 14, background = colors.lightGray }):onClick(function()
        options:destroy()
        newProject.visible = true
    end)
    previous = options:addButton({ text = "Back", width = 6, height = 1, x = 26, y = 14, background = colors.lightGray }):onClick(function()
        if step > 1 then
            showStep(step - 1)
        end
    end)
    next = options:addButton({ text = "Next", width = 6, height = 1, x = 33, y = 14, background = colors.lime }):onClick(function()
        if step < #steps then
            showStep(step + 1)
            return
        end
        if step == #steps then
            save()
        end
    end)
    errorText = options:addLabel({ text = "", width = 38, height = 1, x = 2, y = 15, foreground = colors.red })

    function save()
        local FailedToSave = false
        local text,color,pathValid = validatePath(filelocation.text)
        if not pathValid then
            FailedToSave = true
            errorText.text = "Failure: " .. text
        end

        local checkboxesChecked = 0
        local toSave = {}
        for _, item in ipairs(inventorycheckboxes) do
            if item.checkbox.checked == true then
                checkboxesChecked = checkboxesChecked + 1
                toSave[item.name] = {
                    type = "Storage"
                }
            end
        end
        if not inventorycheckboxes or checkboxesChecked < 1 then
            FailedToSave = true
            errorText.text = "Failure: No inventories selected"
        end

        if FailedToSave then return end
        local file = fs.open(filelocation.text, "w")
        file.write(textutils.serializeJSON(toSave))
        file.close()

        warehouseFilePath = filelocation.text
        warehouseFile = toSave

        options:destroy()
        workspaceHandling()
    end
end)

loadWarehouse:onClick(function()

    local step = 1
    newProject.visible = false
    local options = main:addFrame({ width = 40, height = 15, x = math.floor((termx/2) - 19), y = math.floor((termy/2) - 6), background = colors.white })
    local load

    local filelocation, filelocationexists

    local function validatePath(path)
        if not path or path == "" then
            return "Path is empty", colors.red, false
        end
        if path:match("[<>:\"|?*]") then
            return "Path contains invalid characters", colors.red, false
        end
        if not path:match("%.ware$") then
            return "Path must end with [name].ware", colors.red, false
        end
        if fs.getDir(path) ~= "" and not fs.exists(fs.getDir(path)) then
            return "Directory does not exist", colors.red, false
        end
        return "Valid path", colors.lime, true
    end

    local steps = {
        {
            setup = function(frame)
                frame:addLabel({ text = "Load Warehouse From", width = 28, x=2, y=2})
                filelocation = frame:addInput({ placeholder = "/disk/WarehouseName.ware", width = 38, height = 1, x = 2, y = 4, background = colors.lightGray })
                filelocationexists = frame:addLabel({ text = "", width = 28, x=2, y=5, foreground = colors.red })
            end
        }
    }

    local cancel, next, errorText
    local frames = {}

    for i, stepi in ipairs(steps) do
        frames[i] = options:addFrame({ width = 40, height = 12, background = colors.white })
        stepi.setup(frames[i])
        frames[i].visible = i == 1
    end

    local function showStep(stepToShow)
        frames[step].visible = false
        step = stepToShow
        frames[step].visible = true
    end

    cancel = options:addButton({ text = "Cancel", width = 8, height = 1, x = 2, y = 14, background = colors.lightGray }):onClick(function()
        options:destroy()
        newProject.visible = true
    end)
    next = options:addButton({ text = "Open", width = 6, height = 1, x = 33, y = 14, background = colors.lime }):onClick(function()
        if step < #steps then
            showStep(step + 1)
            return
        end
        if step == #steps then
            load()
        end
    end)
    errorText = options:addLabel({ text = "", width = 38, height = 1, x = 2, y = 15, foreground = colors.red })

    function load()
        local FailedToLoad = false
        local text,color,pathValid = validatePath(filelocation.text)
        if not pathValid then
            FailedToLoad = true
            errorText.text = "Failure: " .. text
        end

        if FailedToLoad then return end
        warehouseFilePath = filelocation.text
        local file = fs.open(warehouseFilePath, "r")
        warehouseFile = textutils.unserializeJSON(file.readAll())
        file.close()
        workspaceHandling()
    end
end)

basalt.run()