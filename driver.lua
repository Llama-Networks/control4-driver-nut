--[[-----------------------------------------------------------------------------
    driver.lua
    -----------------------------------------------------------------------------
    Main entry point for the NUT Integration driver. 
    Initializes the driver, reads/writes properties, and coordinates with nut_module.lua.
-------------------------------------------------------------------------------]]

-- Require the external Lua files (relative to this driver’s directory).
local nut = require "nut_module"   -- Our NUT logic
local proxy = require "proxy"      -- If you have proxy-specific code

--=============================================================================
-- DRIVER GLOBALS
--=============================================================================
-- We’ll store the user-settable properties here. They’ll get updated from driver.xml
NUT_SERVER_IP        = ""
NUT_SERVER_PORT      = 3493
UPS_NAME             = ""
USERNAME             = ""
PASSWORD             = ""
POLLING_INTERVAL     = 60

--=============================================================================
-- CONTROL4 DRIVER LIFECYCLE CALLBACKS
--=============================================================================

function OnDriverInit()
    print("NUT Driver: OnDriverInit()")

    -- Load initial property values
    NUT_SERVER_IP    = Properties["NUT Server IP"]
    NUT_SERVER_PORT  = tonumber(Properties["NUT Server Port"])  or 3493
    UPS_NAME         = Properties["UPS Name"]
    USERNAME         = Properties["Username"]
    PASSWORD         = Properties["Password"]
    POLLING_INTERVAL = tonumber(Properties["Polling Interval"]) or 60

    -- Initialize the NUT module with these settings
    nut.init({
        serverIp    = NUT_SERVER_IP,
        serverPort  = NUT_SERVER_PORT,
        upsName     = UPS_NAME,
        username    = USERNAME,
        password    = PASSWORD,
        pollInterval= POLLING_INTERVAL
    })
end

function OnDriverLateInit()
    print("NUT Driver: OnDriverLateInit()")
    -- Attempt to connect once the driver is fully loaded.
    nut.connectToNutServer()
end

function OnDriverDestroyed()
    print("NUT Driver: OnDriverDestroyed()")
    -- Clean up resources in the NUT module
    nut.shutdown()
end

function OnPropertyChanged(strProperty)
    print("NUT Driver: OnPropertyChanged(" .. strProperty .. ")")

    if strProperty == "NUT Server IP" then
        NUT_SERVER_IP = Properties["NUT Server IP"]
    elseif strProperty == "NUT Server Port" then
        NUT_SERVER_PORT = tonumber(Properties["NUT Server Port"]) or 3493
    elseif strProperty == "UPS Name" then
        UPS_NAME = Properties["UPS Name"]
    elseif strProperty == "Username" then
        USERNAME = Properties["Username"]
    elseif strProperty == "Password" then
        PASSWORD = Properties["Password"]
    elseif strProperty == "Polling Interval" then
        POLLING_INTERVAL = tonumber(Properties["Polling Interval"]) or 60
    end

    -- Tell the module to re-init with updated settings
    nut.updateSettings({
        serverIp    = NUT_SERVER_IP,
        serverPort  = NUT_SERVER_PORT,
        upsName     = UPS_NAME,
        username    = USERNAME,
        password    = PASSWORD,
        pollInterval= POLLING_INTERVAL
    })
end
