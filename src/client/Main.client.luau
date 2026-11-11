--!strict
-- Client bootstrap: requires and starts every controller in Controllers.

local Controllers = script.Parent:WaitForChild("Controllers")

local HUDController = require(Controllers:WaitForChild("HUDController") :: ModuleScript)

HUDController.Start()
