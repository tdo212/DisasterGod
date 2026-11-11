--!strict
-- Server bootstrap: requires and starts every service in Server.Services.

local Services = script.Parent:WaitForChild("Services")

local MatchService = require(Services:WaitForChild("MatchService") :: ModuleScript)

MatchService.Start()
