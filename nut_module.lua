--[[-----------------------------------------------------------------------------
    nut_module.lua
    -----------------------------------------------------------------------------
    Encapsulates the NUT (Network UPS Tools) protocol logic.
-------------------------------------------------------------------------------]]

local M = {}

--=============================================================================
-- MODULE VARIABLES
--=============================================================================
local gServerIp        = "192.168.1.100"
local gServerPort      = 3493
local gUpsName         = "ups"
local gUsername        = ""
local gPassword        = ""
local gPollInterval    = 60

local gTcpClient       = nil
local gPollingTimer    = nil
local gConnectionState = "DISCONNECTED"
local gReceivedBuffer  = ""

-- Some example statuses that we might retrieve from NUT
local gUpsStatusMap = {
    ["battery.charge"]  = 0,
    ["battery.voltage"] = 0,
    ["input.voltage"]   = 0,
    ["ups.load"]        = 0,
    ["ups.status"]      = ""
}

--=============================================================================
-- PRIVATE HELPER FUNCTIONS
--=============================================================================

local function parseLines(buffer)
    local lines = {}
    lines.complete = {}
    lines.partial = ""
    
    local start = 1
    while true do
        local b, e = string.find(buffer, "\r?\n", start)
        if not b then break end
        table.insert(lines.complete, string.sub(buffer, start, b - 1))
        start = e + 1
    end
    
    lines.partial = string.sub(buffer, start)
    return lines
end

local function processNutResponse(line)
    print("NUT Module: Received line: " .. line)
    
    if line:match("^VAR") then
        local upsname, var, val = line:match("^VAR%s+(%S+)%s+(%S+)%s+\"(.-)\"")
        if upsname and var and val then
            if gUpsStatusMap[var] ~= nil then
                if tonumber(val) then
                    gUpsStatusMap[var] = tonumber(val)
                else
                    gUpsStatusMap[var] = val
                end
                -- Update driver variables/properties if needed
                print("NUT Module: Updating " .. var .. " => " .. tostring(val))
                -- e.g., C4:UpdateProperty(var, tostring(val)) or custom logic
            end
        end
    elseif line:match("^ERR") then
        print("NUT Module: ERROR from NUT => " .. line)
    elseif line:match("^OK") then
        -- Acknowledgement
    end
end

local function onTcpClientDataReceived(data)
    gReceivedBuffer = gReceivedBuffer .. data
    local lines = parseLines(gReceivedBuffer)
    for _, line in ipairs(lines.complete) do
        processNutResponse(line)
    end
    gReceivedBuffer = lines.partial
end

local function onTcpClientDisconnected(errCode)
    print("NUT Module: Disconnected from server. Error code=" .. errCode)
    gConnectionState = "DISCONNECTED"

    -- Attempt to reconnect after 10 seconds
    C4:SetTimer(10 * 1000, function()
        M.connectToNutServer()
    end)
end

local function onTcpClientConnected(status)
    if status == 0 then
        print("NUT Module: Connected to " .. gServerIp .. ":" .. gServerPort)
        gConnectionState = "CONNECTED"

        -- If server requires authentication
        if gUsername ~= "" and gPassword ~= "" then
            local authCmd = "USERNAME " .. gUsername .. "\n" ..
                            "PASSWORD " .. gPassword .. "\n"
            gTcpClient:Send(authCmd)
        end
        
        -- Start polling
        if gPollingTimer then
            C4:KillTimer(gPollingTimer)
            gPollingTimer = nil
        end
        gPollingTimer = C4:AddTimer(gPollInterval, "SECONDS", true, function()
            M.pollNutServer()
        end)
        
    else
        print("NUT Module: Failed to connect, status=" .. status)
        gConnectionState = "DISCONNECTED"
        C4:SetTimer(10 * 1000, function()
            M.connectToNutServer()
        end)
    end
end

--=============================================================================
-- PUBLIC FUNCTIONS
--=============================================================================

function M.init(settings)
    print("NUT Module: init()")
    -- Called by the driver to initialize this module with user properties
    gServerIp     = settings.serverIp    or gServerIp
    gServerPort   = settings.serverPort  or gServerPort
    gUpsName      = settings.upsName     or gUpsName
    gUsername     = settings.username    or gUsername
    gPassword     = settings.password    or gPassword
    gPollInterval = settings.pollInterval or gPollInterval
end

function M.updateSettings(settings)
    print("NUT Module: updateSettings()")
    M.init(settings)
    -- If needed, reconnect or re-poll based on new settings
    if gConnectionState == "CONNECTED" then
        -- Reconnect or restart timers if necessary
        if gTcpClient then
            C4:DestroyTCPClient(gTcpClient)
            gTcpClient = nil
        end
        M.connectToNutServer()
    end
end

function M.connectToNutServer()
    print("NUT Module: connectToNutServer() -> " .. gServerIp .. ":" .. gServerPort)

    if gTcpClient then
        C4:DestroyTCPClient(gTcpClient)
        gTcpClient = nil
    end
    
    gTcpClient = C4:CreateTCPClient{
        host = gServerIp,
        port = gServerPort,
        timeout = 10
    }

    gConnectionState = "CONNECTING"

    gTcpClient:OnConnect(function(client, status)
        onTcpClientConnected(status)
    end)

    gTcpClient:OnMessageReceived(function(client, data)
        onTcpClientDataReceived(data)
    end)

    gTcpClient:OnDisconnect(function(client, errCode)
        onTcpClientDisconnected(errCode)
    end)

    gTcpClient:Connect()
end

function M.shutdown()
    print("NUT Module: shutdown()")
    if gPollingTimer then
        C4:KillTimer(gPollingTimer)
        gPollingTimer = nil
    end
    if gTcpClient then
        C4:DestroyTCPClient(gTcpClient)
        gTcpClient = nil
    end
end

function M.pollNutServer()
    if gTcpClient == nil or gConnectionState ~= "CONNECTED" then
        print("NUT Module: Not connected; skipping poll.")
        return
    end
    
    print("NUT Module: Polling NUT server for status...")

    -- Example: poll multiple variables
    local cmds = {
        "GET VAR " .. gUpsName .. " battery.charge\n",
        "GET VAR " .. gUpsName .. " battery.voltage\n",
        "GET VAR " .. gUpsName .. " input.voltage\n",
        "GET VAR " .. gUpsName .. " ups.load\n",
        "GET VAR " .. gUpsName .. " ups.status\n"
    }

    for _, cmd in ipairs(cmds) do
        gTcpClient:Send(cmd)
    end
end

return M
