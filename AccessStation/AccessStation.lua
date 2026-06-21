---@diagnostic disable: undefined-global

local modem = peripheral.find("modem")
rednet.open(peripheral.getName(modem))

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

local function formatNumber(n)
    if n < 1000 then
        return tostring(n)
    elseif n < 1e6 then
        return string.format("%.2fK", n / 1e3)
    elseif n < 1e9 then
        return string.format("%.2fM", n / 1e6)
    elseif n < 1e12 then
        return string.format("%.2fB", n / 1e9)
    else
        return string.format("%.2fT", n / 1e12)
    end
end

local main = basalt.getMainFrame()
main.background = colors.blue

local termx,termy = term.getSize()

local configPath = fs.combine(fs.getDir(shell.getRunningProgram()), "config.json")
local config
local warehouseItems = {}
local renderItems
local request
local reRender
local renderCheckout
local checkout = {}

local function mainApp()
    local topBar = main:addFrame({ width = termx, height = 1, x = 1, y = 1, background = colors.black })
    local SearchBar = topBar:addInput({ placeholder = "Filter For..", width = 20, height = 1, x = 1, y = 1, foreground = colors.black, background = colors.gray, placeholderColor = colors.lightGray })
    SearchBar:onSubmit(
        function()
            renderItems(SearchBar.text)
        end
    )
    topBar:addButton({ text = "Filter", width = 8, height = 1, x = 22, y = 1, foreground = colors.lightGray, background = colors.gray }):onClick(
        function()
            renderItems(SearchBar.text)
        end
    )
    topBar:addButton({ text = "Clear", width = 7, height = 1, x = 31, y = 1, foreground = colors.lightGray, background = colors.gray }):onClick(
        function()
            SearchBar.text = ""
            renderItems()
        end
    )

    local bottomBar = main:addFrame({ width = termx, height = 1, x = 1, y = termy, background = colors.black })
    local requestButton = bottomBar:addButton({ text = "Request", width = 9, height = 1, x = termx-8, y = 1, background = colors.gray, foreground = colors.lightGray }):onClick(
        function()
            request()
        end
    )
    local reIndexButton = bottomBar:addButton({ text = "Re-Render", width = 11, height = 1, x = termx-20, y = 1, background = colors.gray, foreground = colors.lightGray })
    local Status = bottomBar:addLabel({ text = "Re-Render to start", width = termx-20, height = 1, x = 1, y = 1, foreground = colors.lightGray })

    local itemFrame = main:addScrollFrame({ width = math.floor((termx*2)/3)-3, height = termy - 2, x = 1, y = 2, background = colors.blue })
    local checkoutFrame = main:addScrollFrame({ width = (termx - math.ceil((termx*2)/3)+3), height = termy - 3, x = math.floor((termx*2)/3)-2, y = 3, background = colors.white })
    local checkoutTitleFrame = main:addFrame({ width = (termx - math.ceil((termx*2)/3)+3), height = 1, x = math.floor((termx*2)/3)-2, y = 2, background = colors.black })
    checkoutTitleFrame:addLabel({ text = " Checkout", width = 8, height = 1, x = 1, y = 1, foreground = colors.white })

    local itemDetailModal = main:addFrame({ width = 36, height = 15, x = 8, y = 3, z = 100, background = colors.lightGray, visible = false })
    local itemDetailModalTopBar = itemDetailModal:addFrame({ width = 36, height = 1, x = 1, y = 1, background = colors.black })
    local itemDetailTopBarLabel = itemDetailModalTopBar:addLabel({ text = "_ Details", width = 35, height = 1, x = 1, y = 1, foreground = colors.white })
    local itemDetailitemName = itemDetailModal:addLabel({ text = "..:..", width = 34, height = 2, x = 2, y = 3, autoSize = false, foreground = colors.black })
    local itemDetailCount = itemDetailModal:addLabel({ text = ".. \n.. Stacks", width = 34, height = 2, x = 2, y = 5, autoSize = false, foreground = colors.black })
    itemDetailModal:addLabel({ text = "Containers: ", width = 34, height = 2, x = 2, y = 8, autoSize = false, foreground = colors.black })
    local itemDetailContainers = itemDetailModal:addLabel({ text = "..", width = 34, height = 6, x = 2, y = 9, autoSize = false, foreground = colors.black })
    itemDetailModalTopBar:addButton({ text = "x", width = 1, height = 1, x = 36, y = 1, foreground = colors.white, background = colors.red }):onClick(
        function()
            itemDetailModal.visible = false
        end
    )

    local checkoutModal = main:addFrame({ width = 36, height = 15, x = 8, y = 3, z = 100, background = colors.lightGray, visible = false })
    local checkoutModalTopBar = checkoutModal:addFrame({ width = 36, height = 1, x = 1, y = 1, background = colors.black })
    checkoutModalTopBar:addLabel({ text = "Request Result", width = 35, height = 1, x = 1, y = 1, foreground = colors.white })
    local checkoutModalSummary = checkoutModal:addLabel({ text = ".. Requests .. Success .. Failed", width = 34, height = 2, x = 2, y = 3, autoSize = false, foreground = colors.black })
    local checkoutModalRequestFrame = checkoutModal:addScrollFrame({ width = 34, height = 10, x = 2, y = 5, background = colors.white })
    checkoutModalTopBar:addButton({ text = "x", width = 1, height = 1, x = 36, y = 1, foreground = colors.white, background = colors.red }):onClick(
        function()
            checkoutModal.visible = false
        end
    )

    function renderItems(filter)
        if itemFrame then
            itemFrame:destroy()
            itemFrame = nil
        end
        if filter then
            itemFrame = nil
        end
        itemFrame = main:addScrollFrame({ width = math.floor((termx*2)/3)-3, height = termy - 2, x = 1, y = 2, background = colors.blue })

        Status.text = "Rendering items.."

        local currItem = 0

        for _, item in pairs(warehouseItems) do
            if filter and filter ~= "" then
                if not item.name:lower():find(filter:lower(), 1, true) then
                    goto continue
                end
            end
            currItem = currItem + 1

            local frameForItem = itemFrame:addFrame({ width = math.floor((termx*2)/3)-3, height = 3, x = 1, y = (tonumber(currItem) * 3)-2, background = (tonumber(currItem) % 2 == 0 and colors.lightBlue or colors.blue) })
            frameForItem:addLabel({ text = item.name:gsub("^.-:", ""), width = 14, height = 1, foreground = colors.black })
            local countFrame = frameForItem:addFrame({ width = 28, height = 1, x = 2, y = 2, background = (currItem % 2 == 0 and colors.lightBlue or colors.blue) })
            countFrame:addLabel({ text = "Count: " .. formatNumber(item.count) .. " (" .. formatNumber(math.floor(item.count/item.maxCount)) .. " Stacks)", width = 20, height = 1, x = 1, y = 1, foreground = colors.black })
            local detail = frameForItem:addButton({ text = "Detail", width = 8, height = 1, x = 2, y = 3, foreground = colors.black, background = colors.lightGray})
            local addAmount = frameForItem:addInput({ text = tostring(item.count >= item.maxCount and item.maxCount or item.count), placeholder = "...", width = 5, height = 1, x = frameForItem.width - 9, y = 3, foreground = colors.black, background = colors.lightGray, placeholderColor = colors.gray  })
            local addButton = frameForItem:addButton({ text = "+", width = 3, height = 1, x = frameForItem.width - 3, y = 3, foreground = colors.white, background = colors.lime })
            local removeButton = frameForItem:addButton({ text = "-", width = 3, height = 1, x = frameForItem.width - 13, y = 3, foreground = colors.white, background = colors.red })

            addButton:onClick(function()
                if checkout[item.name] then
                    local finalCount = checkout[item.name].count + math.abs(tonumber(addAmount.text))
                    if finalCount <= item.count then
                        checkout[item.name].count = finalCount
                    else
                        checkout[item.name].count = item.count
                    end
                else
                    checkout[item.name] = {
                        count = math.abs(tonumber(addAmount.text)),
                        maxCount = item.maxCount
                    }
                end
                renderCheckout()
            end)
            removeButton:onClick(function()
                if checkout[item.name] then
                    local finalCount = checkout[item.name].count - math.abs(tonumber(addAmount.text))
                    if finalCount > 0 then
                        checkout[item.name].count = finalCount
                    else
                        checkout[item.name] = nil
                    end
                end
                renderCheckout()
            end)
            detail:onClick(function()
                itemDetailTopBarLabel.text = item.name:gsub("^.-:", "") .. " Details"
                itemDetailitemName.text = item.name
                itemDetailCount.text = item.count .. " Items\n" .. math.floor(item.count/item.maxCount) .. " Stacks" .. ((item.count - (math.floor(item.count/item.maxCount) * item.maxCount) > 0) and (" + " .. item.count - (math.floor(item.count/item.maxCount) * item.maxCount)) or "") .. " (" .. item.maxCount .. " per stack)"
                local containerstring = ""
                for container, _ in pairs(item.containers) do
                    containerstring = containerstring .. container:gsub("^.-:", "") .. ", "
                end
                itemDetailContainers.text = containerstring

                itemDetailModal.visible = true
            end)
            :: continue ::
        end

        Status.text = "Rendered all items"
    end

    function renderCheckout()
        if checkoutFrame then
            checkoutFrame:destroy()
            checkoutFrame = nil
        end
        checkoutFrame = main:addScrollFrame({ width = (termx - math.ceil((termx*2)/3)+3), height = termy - 3, x = math.floor((termx*2)/3)-2, y = 3, background = colors.white })
        
        local currItem = 0
        for item, data in pairs(checkout) do
            currItem = currItem + 1
            local frameForItem = checkoutFrame:addFrame({ width = checkoutFrame.width, height = 2, x = 1, y = currItem*2 - 1, background = (currItem % 2 == 0 and colors.white or colors.lightGray) })
            frameForItem:addLabel({ text = item:gsub("^.-:", ""), width = checkoutFrame.width, height = 1, x = 1, y = 1, foreground = colors.black })
            frameForItem:addLabel({ text = formatNumber(data.count) .. " (" .. formatNumber(math.floor(data.count/data.maxCount)) .. " Stks)", width = checkoutFrame.width - 1, height = 1, x = 1, y = 2, foreground = colors.black })
            frameForItem:addButton({ text = "x", width = 1, height = 1, x = checkoutFrame.width, y = 1, background = colors.red, foreground = colors.white }):onClick(
                function()
                    checkout[item] = nil
                    renderCheckout()
                end
            )
        end
    end

    function request()
        local status = {}
        local successes = 0
        local failures = 0
        local timeouts = 0
        local pending = 0
        for item, data in pairs(checkout) do
            pending = pending + 1
            local id = math.random(1, 1e9)

            rednet.send(tonumber(config.hostID), {
                id = id,
                type = "REQUEST",
                item = item,
                amount = tonumber(data.count)
            }, "warehouse-as")

            local timeoutTimer = os.startTimer(5)

            basalt.schedule(function()
                    while true do
                    local event, p1, p2, p3 = os.pullEvent()

                    if event == "rednet_message" then
                        local sender, message, protocol = p1, p2, p3

                        if protocol == "warehouse-se" and message.id == id then
                            if message.fail then
                                failures = failures + 1
                                Status.text = failures .. " Failures"
                            else
                                successes = successes + 1
                                Status.text = successes .. " Successes"
                            end

                            status[item] = {
                                fail = message.fail,
                                missing = message.missing,
                                recieveAmount = message.sentAmount
                            }
                            pending = pending - 1
                            return
                        end
                    end

                    if event == "timer" and p1 == timeoutTimer then
                        timeouts = timeouts + 1
                        Status.text = timeouts .. " Timed Out"
                        pending = pending - 1
                        return
                    end
                end
            end)
            sleep(0.5)
        end

        while pending > 0 do
            sleep(0)
        end

        if checkoutModalRequestFrame then
            checkoutModalRequestFrame:destroy()
            checkoutModalRequestFrame = nil
        end
        checkoutModalRequestFrame = checkoutModal:addScrollFrame({ width = 34, height = 10, x = 2, y = 5, background = colors.white })

        local currOffset = 0
        for item, data in pairs(status) do
            currOffset = currOffset + 1
            local frameForItem = checkoutModalRequestFrame:addFrame({ width = checkoutModalRequestFrame.width, height = 2, x = 1, y = currOffset*2 - 1, background = (currOffset % 2 == 0 and colors.white or colors.gray) })
            frameForItem:addLabel({ text = item:gsub("^.-:", ""), width = checkoutModalRequestFrame.width, height = 1, x = 1, y = 1 })
            frameForItem:addLabel({ text = formatNumber(tonumber(data.recieveAmount)) .. "/" .. formatNumber(tonumber(checkout[item].count)) .. " Recieved, " .. data.missing .. " Missing", width = checkoutModalRequestFrame.width, height = 1, x = 1, y = 2})
        end
        checkoutModalSummary.text = currOffset .. " Requests " .. successes .. " Success " .. failures .. " Failed"
        checkoutModal.visible = true

        sleep(0.5)
        checkout = {}
        renderCheckout()
        reRender()
        Status.text = "Request Finished"
    end

    function reRender()
        if itemFrame then
            itemFrame:destroy()
            itemFrame = nil
        end
        warehouseItems = {}
        Status.text = "Requesting new Index.."
        local id = math.random(1, 1e9)

        rednet.send(tonumber(config.hostID), {
            id = id,
            type = "INDEX"
        }, "warehouse-as")

        local timeoutTimer = os.startTimer(5)

        basalt.schedule(function()
            while true do
                local event, p1, p2, p3 = os.pullEvent()

                if event == "rednet_message" then
                    local sender, message, protocol = p1, p2, p3

                    if protocol == "warehouse-se" and message.id == id then
                        for item, data in pairs(message.index) do
                            table.insert(warehouseItems, {
                                name = item,
                                count = data.count,
                                maxCount = data.maxCount,
                                containers = data.containers
                            })
                        end
                        table.sort(warehouseItems, function (a, b)
                                local an = a.name:gsub("^.-:", ""):lower()
                                local bn = b.name:gsub("^.-:", ""):lower()

                                return an < bn
                        end)
                        Status.text = "Recieved new Index"
                        renderItems()
                        break
                    end
                end

                if event == "timer" and p1 == timeoutTimer then
                    Status.text = "Request timed out"
                    break
                end
            end
        end)
    end

    reIndexButton:onClick(function()
        reRender()
    end)
end

if not fs.exists(configPath) then
    local configModal = main:addFrame({ width = 36, height = 15, x = 8, y = 3, background = colors.lightGray })
    local topBar = configModal:addFrame({ width = 36, height = 1, x = 1, y = 1, background = colors.black })
    topBar:addLabel({ text = "New Configuration Wizard", width = 36, height = 1, x = 1, y = 1, foreground = colors.white })
    topBar:addButton({ text = "x", width = 1, height = 1, x = 36, y = 1, background = colors.red, foreground = colors.white }):onClick(
        function()
            basalt.stop()
        end
    )
    configModal:addLabel({ text = "A config wasn't found, so you will have to make one", width = 34, height = 2, x = 2, y = 3, foreground = colors.black, autoSize = false })
    configModal:addLabel({ text = "Server Host ID", width = 34, height = 1, x = 2, y = 6, foreground = colors.black })
    local ServerHostID = configModal:addInput({ placeholder = "4", width = 34, height = 1, x = 2, y = 8, foreground = colors.black, background = colors.gray, placeholderColor = colors.lightGray })
    configModal:addButton({ text = "Done", width = 6, height = 1, x = 30, y = 14, foreground = colors.white, background = colors.lime }):onClick(
        function()
            local configFile = fs.open(configPath, "w")
            local configTemp = {
                hostID = ServerHostID.text
            }
            configFile.write(textutils.serializeJSON(configTemp))
            configFile.close()
            config = configTemp
            configModal:destroy()
            mainApp()
        end
    )
else
    local configFile = fs.open(configPath, "r")
    config = textutils.unserializeJSON(configFile.readAll())
    configFile.close()
    mainApp()
end

basalt.run()