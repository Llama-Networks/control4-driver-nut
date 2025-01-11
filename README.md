# control4-driver-nut
A driver for Network UPS Tools (NUT)

Driver Manifest (driver.xml)
Defines your driver’s name, type, properties, and references the Lua files.

driver.lua
Handles the main Control4 driver lifecycle calls:

OnDriverInit, OnDriverLateInit, OnDriverDestroyed, OnPropertyChanged.
Initializes and coordinates with your NUT logic module.
proxy.lua
(Optional) Contains logic if you need to implement a specific Control4 proxy interface (for example, a switch, dimmer, or AV device). If you don’t need advanced proxy behavior, this can remain minimal or empty.

nut_module.lua
Encapsulates all the NUT protocol logic and any direct communication to the NUT server (opening sockets, polling variables, parsing responses).

Deployment / Packaging
Zip these files into a single .c4z archive (with the .xml manifest plus the three Lua files).
Load the .c4z into Composer.
Configure properties (server IP, port, UPS name, etc.) in Composer.
Let the driver connect and start polling your NUT server.
