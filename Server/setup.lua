---@diagnostic disable: undefined-global

local function statusUpdate(text)
    local termx, termy = term.getCursorPos()
    term.setCursorPos(termx, termy - 1)
    term.clearLine()
    print(text)
end

print("Checking system compatability...\n")

print("[/] Computer is a computer")
print("[-] Searching for a .ware warehouse index...")
local wareindexes = fs.find(fs.combine(fs.getDir(shell.getRunningProgram()), "*.ware"))
local diskwareindexes = fs.find("/disk/*.ware")
for _, file in pairs(diskwareindexes) do
    table.insert(wareindexes, file)
end
statusUpdate((#wareindexes == 0 and "[x]" or "[/]") .. " Found " .. #wareindexes .. " .ware indexes")
if #wareindexes == 0 then
    printError("Please copy a .ware warehouse index into this folder or insert a disk with a .ware warehouse index")
    return
end

print("[-] Checking network connectivity...")
if peripheral.find("modem") then
    statusUpdate("[/] Server is connected to a network")
end

print("\n")

print("Please enter the path for the primary storage")
print("leave blank for current directory")
print("hint: use /disk for disk")
local primStoragePath
repeat
    primStoragePath = read() 
    if not fs.exists(primStoragePath) then
        printError("Path does not exist, try again")
    end
until fs.exists(primStoragePath)
if primStoragePath == "" then
    primStoragePath = shell.dir()
end

print("\n")

print("Please enter the number of the .ware warehouse index to be used")
for count, file in pairs(wareindexes) do
    print(count .. ": " .. file)
end
local wareIndexToUse
repeat
    wareIndexToUse = tonumber(read())
    if not wareindexes[wareIndexToUse] then
        printError("Selection is not valid, try again")
    end
until wareindexes[wareIndexToUse]
wareIndexToUse = wareindexes[wareIndexToUse]

local config, openError = fs.open(fs.combine(primStoragePath, "config.json"), "w")
if not config then
    printError("Config cannot be written: " .. openError)
    return
end

print("\n")

print("[-] Verifying all container peripherals exist...")
local warehouseIndex = fs.open(wareIndexToUse, "r")
local warehouseData = warehouseIndex.readAll()
warehouseIndex.close()
warehouseData = textutils.unserializeJSON(warehouseData)
local allContainersExist = true
for container, data in pairs(warehouseData) do
    if not peripheral.isPresent(container) then
        printError(container .. " does not exist in the network")
        allContainersExist = false
    end
end
if not allContainersExist then return end
statusUpdate("[/] All container peripherals exist")

print("\n")

print("Should the server stop when an item operation fails?")
print("[y/N]")
local serverFailStop
repeat
    serverFailStop = string.lower(read())
    if serverFailStop == "" then
        serverFailStop = false
    end
    if serverFailStop == "y" then
        serverFailStop = true
    end
    if serverFailStop == "n" then
        serverFailStop = false
    end
until serverFailStop == true or serverFailStop == false

print("Should the server print non-error logs?")
print("[Y/n]")
local nonErrorPrints
repeat
    nonErrorPrints = string.lower(read())
    if nonErrorPrints == "" then
        nonErrorPrints = true
    end
    if nonErrorPrints == "y" then
        nonErrorPrints = true
    end
    if nonErrorPrints == "n" then
        nonErrorPrints = false
    end
until nonErrorPrints == true or nonErrorPrints == false

print("Writing configuration file...")
local configTemp = {}
configTemp["warehouse-file"] = wareIndexToUse
configTemp["save-file-path"] = primStoragePath
configTemp["server-fail-stop"] = serverFailStop
configTemp["non-error-prints"] = nonErrorPrints

config.write(textutils.serializeJSON(configTemp))
config.close()

print("\n")

print("Config written!")

local serverFile = fs.open(fs.combine(primStoragePath, "server.lua"), "w")
local serverLua = string.format([[
local configPath = %q
local configFile = fs.open(configPath, "r")
if not configFile then
    error("Cannot read config file " .. configPath)
end
local config = textutils.unserializeJSON(configFile.readAll())
configFile.close()

local serverFailStop = config["server-fail-stop"]
local nonErrorPrints = config["non-error-prints"]
local saveFilePath = config["save-file-path"]
local warehouseFilePath = config["warehouse-file"]

local warehouseFile = fs.open(warehouseFilePath, "r")
local warehouseIndex = warehouseFile.readAll()
warehouseIndex = textutils.unserializeJSON(warehouseIndex)
warehouseFile.close()

print("Loaded warehouse file from " .. warehouseFilePath)

local peripherals = {}
for peripheralName in pairs(warehouseIndex) do
    peripherals[peripheralName] = peripheral.wrap(peripheralName)
end

print("Wrapped all peripherals")

local modem = peripheral.find("modem")
if not modem then
    printError("A connection to the network cannot be started")
    printError("Is a modem connected to the server?")
    return
end

rednet.open(peripheral.getName(modem))
print("Server started on channel " .. rednet.CHANNEL_BROADCAST)
print("Host ID: " .. os.getComputerID())

print("\n")

local function log(msg)
    if not msg then return end
    if nonErrorPrints then
        print(msg)
    end
end

local function logerror(msg)
    if msg then
        printError(msg)
    end
    if serverFailStop then
        error(msg)
    end
end

local function handleRednet(sender, message, protocol)
    if protocol == "warehouse-as" and message.type == "INDEX" then
        log(string.upper(message.type) .. " #" .. (message.id or "N/A"))
        local INDEX = {}
        for container, data in pairs(warehouseIndex) do
            if data.type == "Storage" then
                local items = peripherals[container].list()
                for index, item in pairs(items) do
                    if not INDEX[item.name] then
                        local detail = peripherals[container].getItemDetail(index)
                        INDEX[item.name] = {
                            count = 0,
                            maxCount = detail and detail.maxCount or 64,
                            containers = {}
                        }
                    end
                    INDEX[item.name].count = (INDEX[item.name].count or 0) + item.count
                    INDEX[item.name].containers[container] = true
                end
            end
        end
        rednet.send(
            sender,
            {
                id = (message.id or "N/A"),
                index = INDEX
            },
            "warehouse-se"
        )
    end
    if protocol == "warehouse-as" and message.type == "REQUEST" then
        log(string.upper(message.type) .. " #" ..(message.id or "N/A"))
        log("[" .. message.item .. ", COUNT: " .. message.amount .. ", FROM: " .. sender .. "]")
        
        local toPush = message.amount

        local stationStorage
        for container, data in pairs(warehouseIndex) do
            if data.type == "Access Station" and tonumber(data.computer) == tonumber(sender) then
                stationStorage = container
                break
            end
        end

        if not stationStorage then
            logerror("Station cannot be found for sender computer_" .. sender)
            return
        end

        local finished = false
        local sentAmount = 0
        for container, data in pairs(warehouseIndex) do
            if finished then break end
            if data.type == "Storage" then
                local items = peripherals[container].list()
                for index, item in pairs(items) do
                    if item.name == message.item then
                        local moved = peripherals[container].pushItems(stationStorage, index, toPush)
                        toPush = toPush - moved
                        sentAmount = sentAmount + moved

                        if moved > 0 then
                            log("MOVE [" .. container .. " TO " .. stationStorage .. "]")
                        end

                        if toPush == 0 then
                            finished = true
                            break
                        end
                    end
                end
            end
        end

        if sentAmount == 0 then
            logerror("MOVE (FAIL) [" .. message.item .. "] NOT FOUND")
            return
        end

        if toPush > 0 then
            logerror("MOVE (PART FAIL) [" .. message.item .. "] MISSING " .. toPush)
        end

        rednet.send(
            sender,
            {
                id = (message.id or "N/A"),
                fail = toPush > 0,
                sentAmount = sentAmount,
                missing = toPush
            },
            "warehouse-se"
        )
    end
end

local function tick()
    for container, data in pairs(warehouseIndex) do
        if data.type == "Dropoff Station" then
            local items = peripherals[container].list()
            if next(items) then
                for index, _ in pairs(items) do
                    for toContainer, toData in pairs(warehouseIndex) do
                        if toData.type == "Storage" then
                            local moved = peripherals[container].pushItems(toContainer, index)
                            
                            if moved > 0 then
                                log("MOVE [" .. container .. " TO " .. toContainer .. "]")
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end

while true do
    parallel.waitForAny(
        function()
            while true do
                tick()
                sleep(0.05)
            end
        end,
        function()
            while true do
                local sender, message, protocol = rednet.receive("warehouse-as")
                handleRednet(sender, message, protocol)
            end
        end
    )
end
]],fs.combine(primStoragePath, "config.json"))
serverFile.write(serverLua)
serverFile.close()

print("Server written!")
print("Run `./server.lua` in `" .. primStoragePath .. "` to start the server")
print("To autostart the server on boot, add `shell.run(\"" .. primStoragePath .. "/server.lua\")` to `/startup`")